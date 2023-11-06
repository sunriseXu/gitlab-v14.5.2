# frozen_string_literal: true

module Geo
  module Scheduler
    module Secondary
      class PerShardSchedulerWorker < Geo::Scheduler::PerShardSchedulerWorker # rubocop:disable Scalability/IdempotentWorker
        def perform
          unless Gitlab::Geo.geo_database_configured?
            log_info('Geo database not configured')
            return
          end

          unless Gitlab::Geo.secondary?
            log_info('Current node not a secondary')
            return
          end

          super
        end

        def eligible_shard_names
          selective_sync_filter(healthy_shard_names)
        end

        def selective_sync_filter(shards)
          return shards unless ::Gitlab::Geo.current_node&.selective_sync_by_shards?

          shards & ::Gitlab::Geo.current_node.selective_sync_shards
        end
      end
    end
  end
end
