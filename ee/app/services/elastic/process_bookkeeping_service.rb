# frozen_string_literal: true

module Elastic
  class ProcessBookkeepingService
    SHARD_LIMIT = 1_000
    SHARDS_NUMBER = 16
    SHARDS = 0.upto(SHARDS_NUMBER - 1).to_a

    class << self
      def shard_number(data)
        Elastic::BookkeepingShardService.shard_number(number_of_shards: SHARDS_NUMBER, data: data)
      end

      def redis_set_key(shard_number)
        "elastic:incremental:updates:#{shard_number}:zset"
      end

      def redis_score_key(shard_number)
        "elastic:incremental:updates:#{shard_number}:score"
      end

      # Add some records to the processing queue. Items must be serializable to
      # a Gitlab::Elastic::DocumentReference
      def track!(*items)
        return true if items.empty?

        items.map! { |item| ::Gitlab::Elastic::DocumentReference.serialize(item) }

        items_by_shard = items.group_by { |item| shard_number(item) }

        with_redis do |redis|
          items_by_shard.each do |shard_number, shard_items|
            set_key = redis_set_key(shard_number)

            # Efficiently generate a guaranteed-unique score for each item
            max = redis.incrby(redis_score_key(shard_number), shard_items.size)
            min = (max - shard_items.size) + 1

            (min..max).zip(shard_items).each_slice(1000) do |group|
              logger.debug(class: self.name,
                          redis_set: set_key,
                          message: 'track_items',
                          count: group.count,
                          tracked_items_encoded: group.to_json)

              redis.zadd(set_key, group)
            end
          end
        end

        true
      end

      def queue_size
        with_redis do |redis|
          SHARDS.sum do |shard_number|
            redis.zcard(redis_set_key(shard_number))
          end
        end
      end

      def queued_items
        {}.tap do |hash|
          with_redis do |redis|
            each_queued_items_by_shard(redis) do |shard_number, specs|
              hash[shard_number] = specs if specs.present?
            end
          end
        end
      end

      def clear_tracking!
        with_redis do |redis|
          Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
            keys = SHARDS.map { |m| [redis_set_key(m), redis_score_key(m)] }.flatten

            redis.unlink(*keys)
          end
        end
      end

      def each_queued_items_by_shard(redis)
        SHARDS.each do |shard_number|
          set_key = redis_set_key(shard_number)
          specs = redis.zrangebyscore(set_key, '-inf', '+inf', limit: [0, SHARD_LIMIT], with_scores: true)

          yield shard_number, specs
        end
      end

      def logger
        # build already caches the logger via request store
        ::Gitlab::Elasticsearch::Logger.build
      end

      def with_redis(&blk)
        Gitlab::Redis::SharedState.with(&blk) # rubocop:disable CodeReuse/ActiveRecord
      end

      def maintain_indexed_associations(object, associations)
        each_indexed_association(object, associations) do |_, association|
          association.find_in_batches do |group|
            track!(*group)
          end
        end
      end

      private

      def each_indexed_association(object, associations)
        associations.each do |association_name|
          association = object.association(association_name)
          scope = association.scope
          klass = association.klass

          if klass == Note
            scope = scope.searchable
          end

          yield klass, scope
        end
      end
    end

    def execute
      self.class.with_redis { |redis| execute_with_redis(redis) }
    end

    private

    def execute_with_redis(redis)
      start_time = Time.current

      specs_buffer = []
      scores = {}

      self.class.each_queued_items_by_shard(redis) do |shard_number, specs|
        next if specs.empty?

        set_key = self.class.redis_set_key(shard_number)
        first_score = specs.first.last
        last_score = specs.last.last

        logger.info(
          message: 'bulk_indexing_start',
          redis_set: set_key,
          records_count: specs.count,
          first_score: first_score,
          last_score: last_score
        )

        specs_buffer += specs

        scores[set_key] = [first_score, last_score, specs.count]
      end

      return 0 if specs_buffer.blank?

      refs = deserialize_all(specs_buffer)
      refs.preload_database_records.each { |ref| submit_document(ref) }

      failures = bulk_indexer.flush

      # Re-enqueue any failures so they are retried
      self.class.track!(*failures) if failures.present?

      # Remove all the successes
      scores.each do |set_key, (first_score, last_score, count)|
        redis.zremrangebyscore(set_key, first_score, last_score)

        logger.info(
          message: 'bulk_indexing_end',
          redis_set: set_key,
          records_count: count,
          first_score: first_score,
          last_score: last_score,
          failures_count: failures.count,
          bulk_execution_duration_s: Time.current - start_time
        )
      end

      specs_buffer.count
    end

    def deserialize_all(specs)
      refs = ::Gitlab::Elastic::DocumentReference::Collection.new
      specs.each do |spec, _|
        refs.deserialize_and_add(spec)
      rescue ::Gitlab::Elastic::DocumentReference::InvalidError => err
        logger.warn(
          message: 'submit_document_failed',
          reference: spec,
          error_class: err.class.to_s,
          error_message: err.message
        )
      end

      refs
    end

    def submit_document(ref)
      bulk_indexer.process(ref)
    end

    def bulk_indexer
      @bulk_indexer ||= ::Gitlab::Elastic::BulkIndexer.new(logger: logger)
    end

    def logger
      self.class.logger
    end
  end
end
