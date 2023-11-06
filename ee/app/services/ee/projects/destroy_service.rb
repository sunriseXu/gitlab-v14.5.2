# frozen_string_literal: true

module EE
  module Projects
    module DestroyService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        super.tap do
          # It's possible that some error occurred, but at the end of the day
          # if the project is destroyed from the database, we should log events
          # and clean up where we can.
          if project&.destroyed?
            mirror_cleanup(project)
          end
        end
      end

      # Removes physical repository in a Geo replicated secondary node
      # There is no need to do any database operation as it will be
      # replicated by itself.
      def geo_replicate
        return unless ::Gitlab::Geo.secondary?

        # Flush the cache for both repositories. This has to be done _before_
        # removing the physical repositories as some expiration code depends on
        # Git data (e.g. a list of branch names).
        flush_caches(project)

        trash_project_repositories!

        log_info("Project \"#{project.name}\" was removed")
      end

      private

      override :destroy_project_related_records
      def destroy_project_related_records(project)
        super && log_destroy_events
      end

      def log_destroy_events
        log_geo_event(project)
        log_audit_event(project)
      end

      def mirror_cleanup(project)
        return unless project.mirror?

        ::Gitlab::Mirror.decrement_capacity(project.id)
      end

      def log_geo_event(project)
        ::Geo::RepositoryDeletedEventStore.new(
          project,
          repo_path: project.disk_path,
          wiki_path: project.wiki.disk_path
        ).create!
      end

      def log_audit_event(project)
        ::AuditEventService.new(
          current_user,
          project,
          action: :destroy
        ).for_project.security_event
      end
    end
  end
end
