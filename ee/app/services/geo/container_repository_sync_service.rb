# frozen_string_literal: true

module Geo
  class ContainerRepositorySyncService
    include ExclusiveLeaseGuard
    include ::Gitlab::Geo::ContainerRepositoryLogHelpers

    LEASE_TIMEOUT = 8.hours.freeze
    LEASE_KEY = 'geo_container_sync'

    attr_reader :container_repository

    def initialize(container_repository)
      @container_repository = container_repository
    end

    def execute
      try_obtain_lease do
        sync_repository
      end
    end

    def sync_repository
      log_info('Marking sync as started')
      registry.start_sync!

      Geo::ContainerRepositorySync.new(container_repository).execute

      mark_sync_as_successful

      log_info('Finished sync')
    rescue StandardError => e
      fail_registry_sync!("Container repository sync failed", e)
    end

    private

    def mark_sync_as_successful
      persisted = registry.finish_sync!

      reschedule_sync unless persisted
    end

    def reschedule_sync
      log_info("Reschedule container sync because a ContainerRepositoryUpdatedEvent was processed during the sync")

      Geo::ContainerRepositorySyncWorker.perform_async(container_repository.id)
    end

    def fail_registry_sync!(message, error)
      log_error(message, error)

      registry.fail_sync!(message, error)
    end

    def lease_key
      @lease_key ||= "#{LEASE_KEY}:#{container_repository.id}"
    end

    def lease_timeout
      LEASE_TIMEOUT
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def registry
      @registry ||= begin
        Geo::ContainerRepositoryRegistry.find_or_initialize_by(
          container_repository_id: container_repository.id
        )
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
