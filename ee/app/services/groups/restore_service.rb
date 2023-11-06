# frozen_string_literal: true

module Groups
  class RestoreService < Groups::BaseService
    def execute
      return error(_('You are not authorized to perform this action')) unless can?(current_user, :admin_group, group)
      return error(_('Group has not been marked for deletion')) unless group.marked_for_deletion?

      result = remove_deletion_schedule

      group.reset

      log_audit_event if result[:status] == :success

      result
    end

    private

    def remove_deletion_schedule
      deletion_schedule = group.deletion_schedule

      if deletion_schedule.destroy
        success
      else
        error(_('Could not restore the group'))
      end
    end

    def log_audit_event
      AuditEvents::CustomAuditEventService.new(
        current_user,
        group,
        nil,
        'Group restored'
      ).for_group.security_event
    end
  end
end
