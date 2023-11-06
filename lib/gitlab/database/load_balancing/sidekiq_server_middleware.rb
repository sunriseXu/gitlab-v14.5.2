# frozen_string_literal: true

module Gitlab
  module Database
    module LoadBalancing
      class SidekiqServerMiddleware
        JobReplicaNotUpToDate = Class.new(StandardError)

        def call(worker, job, _queue)
          worker_class = worker.class
          strategy = select_load_balancing_strategy(worker_class, job)

          job['load_balancing_strategy'] = strategy.to_s

          if use_primary?(strategy)
            ::Gitlab::Database::LoadBalancing::Session.current.use_primary!
          elsif strategy == :retry
            raise JobReplicaNotUpToDate, "Sidekiq job #{worker_class} JID-#{job['jid']} couldn't use the replica."\
              "  Replica was not up to date."
          else
            # this means we selected an up-to-date replica, but there is nothing to do in this case.
          end

          yield
        ensure
          clear
        end

        private

        def clear
          ::Gitlab::Database::LoadBalancing.release_hosts
          ::Gitlab::Database::LoadBalancing::Session.clear_session
        end

        def use_primary?(strategy)
          strategy.start_with?('primary')
        end

        def select_load_balancing_strategy(worker_class, job)
          return :primary unless load_balancing_available?(worker_class)

          wal_locations = get_wal_locations(job)

          return :primary_no_wal unless wal_locations

          if databases_in_sync?(wal_locations)
            # Happy case: we can read from a replica.
            retried_before?(worker_class, job) ? :replica_retried : :replica
          elsif can_retry?(worker_class, job)
            # Optimistic case: The worker allows retries and we have retries left.
            :retry
          else
            # Sad case: we need to fall back to the primary.
            :primary
          end
        end

        def get_wal_locations(job)
          job['dedup_wal_locations'] || job['wal_locations'] || legacy_wal_location(job)
        end

        # Already scheduled jobs could still contain legacy database write location.
        # TODO: remove this in the next iteration
        # https://gitlab.com/gitlab-org/gitlab/-/issues/338213
        def legacy_wal_location(job)
          wal_location = job['database_write_location'] || job['database_replica_location']

          { ::Gitlab::Database::MAIN_DATABASE_NAME.to_sym => wal_location } if wal_location
        end

        def load_balancing_available?(worker_class)
          worker_class.include?(::ApplicationWorker) &&
            worker_class.utilizes_load_balancing_capabilities? &&
            worker_class.get_data_consistency_feature_flag_enabled?
        end

        def can_retry?(worker_class, job)
          worker_class.get_data_consistency == :delayed && not_yet_retried?(job)
        end

        def retried_before?(worker_class, job)
          worker_class.get_data_consistency == :delayed && !not_yet_retried?(job)
        end

        def not_yet_retried?(job)
          # if `retry_count` is `nil` it indicates that this job was never retried
          # the `0` indicates that this is a first retry
          job['retry_count'].nil?
        end

        def databases_in_sync?(wal_locations)
          ::Gitlab::Database::LoadBalancing.each_load_balancer.all? do |lb|
            if (location = wal_locations[lb.name])
              lb.select_up_to_date_host(location)
            else
              # If there's no entry for a load balancer it means the Sidekiq
              # job doesn't care for it. In this case we'll treat the load
              # balancer as being in sync.
              true
            end
          end
        end
      end
    end
  end
end
