# frozen_string_literal: true

module EE
  module Issues
    module CloneService
      extend ::Gitlab::Utils::Override

      override :update_new_entity
      def update_new_entity
        super
        add_epic
      end

      private

      def add_epic
        return unless epic = original_entity.epic
        return unless can?(current_user, :update_epic, epic.group)

        updated = ::Issues::UpdateService.new(project: target_project, current_user: current_user, params: { epic: epic }).execute(new_entity)

        ::Gitlab::UsageDataCounters::IssueActivityUniqueCounter.track_issue_changed_epic_action(author: current_user) if updated
      end
    end
  end
end
