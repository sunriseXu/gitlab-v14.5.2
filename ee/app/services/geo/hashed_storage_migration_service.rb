# frozen_string_literal: true

module Geo
  class HashedStorageMigrationService
    include ::Gitlab::Geo::LogHelpers

    attr_reader :project_id, :old_disk_path, :new_disk_path, :old_storage_version

    def initialize(project_id, old_disk_path:, new_disk_path:, old_storage_version:)
      @project_id = project_id
      @old_disk_path = old_disk_path
      @new_disk_path = new_disk_path
      @old_storage_version = old_storage_version
    end

    def async_execute
      Geo::HashedStorageMigrationWorker.perform_async(
        project_id,
        old_disk_path,
        new_disk_path,
        old_storage_version
      )
    end

    def execute
      project.expire_caches_before_rename(old_disk_path)

      if migrating_from_legacy_storage? && !move_repository
        log_error("Repository could not be migrated to Hashed Storage: move_repository failed", project_id: project.id, source: old_disk_path, target: new_disk_path)
        raise RepositoryCannotBeRenamed, "Repository #{old_disk_path} could not be renamed to #{new_disk_path}"
      end

      log_info("Repository migrated to Hashed Storage", project_id: project.id, source: old_disk_path, target: new_disk_path)

      true
    end

    private

    def project
      @project ||= Project.find(project_id)
    end

    def migrating_from_legacy_storage?
      from_legacy_storage? && project.hashed_storage?(:repository)
    end

    def from_legacy_storage?
      old_storage_version.nil? || old_storage_version == 0
    end

    def move_repository
      Geo::MoveRepositoryService.new(project, old_disk_path, new_disk_path).execute
    end
  end
end
