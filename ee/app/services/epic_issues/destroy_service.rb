# frozen_string_literal: true

module EpicIssues
  class DestroyService < IssuableLinks::DestroyService
    extend ::Gitlab::Utils::Override

    private

    override :after_destroy
    def after_destroy
      super

      Epics::UpdateDatesService.new([link.epic]).execute
      track_usage_ping_event
    end

    def track_usage_ping_event
      ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_issue_removed(author: current_user)
    end

    def source
      @source ||= link.epic
    end

    def target
      @target ||= link.issue
    end

    def permission_to_remove_relation?
      can?(current_user, :admin_epic_issue, target) && can?(current_user, :read_epic, source)
    end

    def create_notes
      SystemNoteService.epic_issue(source, target, current_user, :removed)
      SystemNoteService.issue_on_epic(target, source, current_user, :removed)
    end
  end
end
