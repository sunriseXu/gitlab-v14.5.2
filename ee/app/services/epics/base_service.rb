# frozen_string_literal: true

module Epics
  class BaseService < IssuableBaseService
    extend ::Gitlab::Utils::Override

    def self.constructor_container_arg(value)
      # TODO: Dynamically determining the type of a constructor arg based on the class is an antipattern,
      # but the root cause is that Epics::BaseService has some issues that inheritance may not be the
      # appropriate pattern. See more details in comments at the top of Epics::BaseService#initialize.
      # Follow on issue to address this:
      # https://gitlab.com/gitlab-org/gitlab/-/issues/328438

      { group: value }
    end

    attr_reader :group, :parent_epic, :child_epic

    # TODO: This constructor does NOT call `super`, because it has
    # no `project` associated. Thus, the first argument is named
    # `group`, even though it only a `group` in this sub-hierarchy of `IssuableBaseClass`,
    # but is a `project` everywhere else.  This is because named arguments
    # were added after the class was already in use. We use `.constructor_container_arg`
    # to determine the correct keyword to use.
    #
    # This is revealing an inconsistency which already existed,
    # where sometimes a `project` is passed as the first argument but ignored.  For example,
    # in `IssuableBaseService#change_state` method, as well as many others.
    #
    # This is a form of violation of the Liskov Substitution Principle
    # (https://en.wikipedia.org/wiki/Liskov_substitution_principle),
    # in that we cannot determine which form of the constructor to call without
    # knowing what the type of subclass is.
    #
    # This implies that inheritance may not be the proper relationship to "issuable",
    # because it may not be an "is a" relationship.
    #
    # All other `IssuableBaseService` subclasses are in the context of a
    # project, and take the project as the first argument to the constructor.
    #
    # Instead, is seems like there is are some concerns such as state management, and
    # having notes, which are applicable to "epic" services, but not necessarily all aspects
    # of "issuable" services.
    #
    # See the following links for more context:
    # - Original discussion thread: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/59182#note_555401711
    # - Issue to address inheritance problems: https://gitlab.com/gitlab-org/gitlab/-/issues/328438
    def initialize(group:, current_user:, params: {})
      # NOTE: this does NOT call `super`! See details in comment above.

      @group = group
      @current_user = current_user
      @params = params
    end

    private

    override :handle_quick_actions
    def handle_quick_actions(epic)
      super

      set_quick_action_params
    end

    def set_quick_action_params
      @parent_epic = params.delete(:quick_action_assign_to_parent_epic)
      @child_epic = params.delete(:quick_action_assign_child_epic)
    end

    def assign_parent_epic_for(epic)
      return unless parent_epic

      result = EpicLinks::CreateService.new(parent_epic, current_user, { target_issuable: epic }).execute

      unless result[:status] == :error
        track_epic_parent_updated
      end

      result
    end

    def assign_child_epic_for(epic)
      return unless child_epic

      result = EpicLinks::CreateService.new(epic, current_user, { target_issuable: child_epic }).execute

      unless result[:status] == :error
        track_epic_parent_updated
      end

      result
    end

    def available_labels
      @available_labels ||= LabelsFinder.new(
        current_user,
        group_id: group.id,
        only_group_labels: true,
        include_ancestor_groups: true
      ).execute
    end

    def parent
      group
    end

    def close_service
      Epics::CloseService
    end

    def reopen_service
      Epics::ReopenService
    end

    def track_epic_parent_updated
      ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_parent_updated_action(author: current_user)
    end
  end
end
