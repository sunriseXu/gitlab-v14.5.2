# frozen_string_literal: true

module Geo
  module RepositoryReplicatorStrategy
    extend ActiveSupport::Concern

    include ::Geo::VerifiableReplicator
    include Gitlab::Geo::LogHelpers

    included do
      event :created
      event :updated
      event :deleted
    end

    class_methods do
      def sync_timeout
        ::Geo::FrameworkRepositorySyncService::LEASE_TIMEOUT
      end

      def data_type
        'repository'
      end

      def data_type_title
        _('Git')
      end
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_updated(**params)
      return unless in_replicables_for_current_secondary?

      sync_repository
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_created(**params)
      consume_event_updated(**params)
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_deleted(**params)
      replicate_destroy(params)
    end

    def replicate_destroy(params)
      Geo::RepositoryRegistryRemovalService.new(self, params).execute
    end

    def sync_repository
      Geo::FrameworkRepositorySyncService.new(self).execute
    end

    def reschedule_sync
      Geo::EventWorker.perform_async(replicable_name, 'updated', { model_record_id: model_record.id })
    end

    def remote_url
      Gitlab::Geo.primary_node.repository_url(repository)
    end

    def jwt_authentication_header
      ::Gitlab::Geo::RepoSyncRequest.new(
        scope: repository.full_path
      ).authorization
    end

    def deleted_params
      event_params.merge(
        repository_storage: model_record.repository_storage,
        disk_path: model_record.repository.disk_path,
        full_path: model_record.repository.full_path
      )
    end

    # Returns a checksum of the repository refs as defined by Gitaly
    #
    # @return [String] checksum of the repository refs
    def calculate_checksum
      repository.checksum
    rescue Gitlab::Git::Repository::NoRepository => e
      log_error('Repository cannot be checksummed because it does not exist', e, self.replicable_params)

      raise
    end

    # Return whether it's capable of generating a checksum of itself
    #
    # @return [Boolean] whether it can generate a checksum
    def checksummable?
      repository.exists?
    end

    # Return whether it's immutable
    #
    # @return [Boolean] whether the replicable is immutable
    def immutable?
      false
    end
  end
end
