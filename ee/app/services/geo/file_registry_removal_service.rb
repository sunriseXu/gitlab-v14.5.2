# frozen_string_literal: true

module Geo
  class FileRegistryRemovalService < BaseFileService
    include ::Gitlab::Utils::StrongMemoize

    LEASE_TIMEOUT = 8.hours.freeze

    # There is a possibility that the replicable's record does not exist
    # anymore. In this case, you need to pass the file_path parameter
    # explicitly.
    def initialize(object_type, object_db_id, file_path = nil)
      @object_type = object_type.to_sym
      @object_db_id = object_db_id
      @object_file_path = file_path
    end

    def execute
      log_info('Executing')

      try_obtain_lease do
        log_info('Lease obtained')

        unless file_registry
          log_error('Could not find file_registry')
          break
        end

        destroy_file
        destroy_registry

        log_info('Local file & registry removed')
      end
    rescue SystemCallError => e
      log_error('Could not remove file', e.message)
      raise
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord
    def file_registry
      strong_memoize(:file_registry) do
        if job_artifact?
          ::Geo::JobArtifactRegistry.find_by(artifact_id: object_db_id)
        elsif replicator
          replicator.registry
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def destroy_file
      if file_path && File.exist?(file_path)
        log_info('Unlinking file', file_path: file_path)
        File.unlink(file_path)
      else
        log_error('Unable to unlink file because file path is unknown. A file may be orphaned', object_type: object_type, object_db_id: object_db_id)
      end
    end

    def destroy_registry
      log_info('Removing file registry', file_registry_id: file_registry.id)

      file_registry.destroy
    end

    def replicator
      strong_memoize(:replicator) do
        Gitlab::Geo::Replicator.for_replicable_params(replicable_name: object_type.to_s, replicable_id: object_db_id)
      rescue NotImplementedError
        nil
      end
    end

    def blob_path_from_replicator
      replicator.blob_path
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def file_path
      strong_memoize(:file_path) do
        next @object_file_path if @object_file_path
        next blob_path_from_replicator if replicator
        # When local storage is used, just rely on the existing methods
        next if file_uploader.nil?
        next file_uploader.file.path if file_uploader.object_store == ObjectStorage::Store::LOCAL

        file_uploader.class.absolute_path(file_uploader.file)
      end
    end

    def file_uploader
      strong_memoize(:file_uploader) do
        case object_type
        when :job_artifact
          Ci::JobArtifact.find(object_db_id).file
        when *Gitlab::Geo::Replication::USER_UPLOADS_OBJECT_TYPES
          Upload.find(object_db_id).retrieve_uploader
        else
          raise NameError, "Unrecognized type: #{object_type}"
        end
      rescue RuntimeError, NameError, ActiveRecord::RecordNotFound => err
        # When cleaning up registries, there are some cases where
        # it's impossible to unlink the file:
        #
        # 1. The replicable record does not exist anymore;
        # 2. The replicable file is stored on Object Storage,
        #    but the node is not configured to use Object Store;
        # 3. Unrecognized replicable type;
        #
        log_error('Could not build uploader', err.message)

        nil
      end
    end

    def lease_key
      "file_registry_removal_service:#{object_type}:#{object_db_id}"
    end

    def lease_timeout
      LEASE_TIMEOUT
    end
  end
end
