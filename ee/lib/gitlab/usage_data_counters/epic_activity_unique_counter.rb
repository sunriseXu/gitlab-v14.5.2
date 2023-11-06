# frozen_string_literal: true

module Gitlab
  module UsageDataCounters
    module EpicActivityUniqueCounter
      # The 'g_project_management' prefix need to be present
      # on epic event names, because they are persisted at the same
      # slot of issue events to allow data aggregation.
      # More information in: https://gitlab.com/gitlab-org/gitlab/-/issues/322405
      EPIC_CREATED = 'g_project_management_epic_created'
      EPIC_TITLE_CHANGED = 'g_project_management_users_updating_epic_titles'
      EPIC_DESCRIPTION_CHANGED = 'g_project_management_users_updating_epic_descriptions'
      EPIC_NOTE_CREATED = 'g_project_management_users_creating_epic_notes'
      EPIC_NOTE_UPDATED = 'g_project_management_users_updating_epic_notes'
      EPIC_NOTE_DESTROYED = 'g_project_management_users_destroying_epic_notes'
      EPIC_EMOJI_AWARDED = 'g_project_management_users_awarding_epic_emoji'
      EPIC_EMOJI_REMOVED = 'g_project_management_users_removing_epic_emoji'
      EPIC_START_DATE_SET_AS_FIXED = 'g_project_management_users_setting_epic_start_date_as_fixed'
      EPIC_START_DATE_SET_AS_INHERITED = 'g_project_management_users_setting_epic_start_date_as_inherited'
      EPIC_DUE_DATE_SET_AS_FIXED = 'g_project_management_users_setting_epic_due_date_as_fixed'
      EPIC_DUE_DATE_SET_AS_INHERITED = 'g_project_management_users_setting_epic_due_date_as_inherited'
      EPIC_FIXED_START_DATE_UPDATED = 'g_project_management_users_updating_fixed_epic_start_date'
      EPIC_FIXED_DUE_DATE_UPDATED = 'g_project_management_users_updating_fixed_epic_due_date'
      EPIC_ISSUE_ADDED = 'g_project_management_epic_issue_added'
      EPIC_ISSUE_REMOVED = 'g_project_management_epic_issue_removed'
      EPIC_ISSUE_MOVED_FROM_PROJECT = 'g_project_management_epic_issue_moved_from_project'
      EPIC_PARENT_UPDATED = 'g_project_management_users_updating_epic_parent'
      EPIC_CLOSED = 'g_project_management_epic_closed'
      EPIC_REOPENED = 'g_project_management_epic_reopened'
      ISSUE_PROMOTED_TO_EPIC = 'g_project_management_issue_promoted_to_epic'
      EPIC_CONFIDENTIAL = 'g_project_management_users_setting_epic_confidential'
      EPIC_VISIBLE = 'g_project_management_users_setting_epic_visible'
      EPIC_LABELS = 'g_project_management_epic_users_changing_labels'
      EPIC_DESTROYED = 'g_project_management_epic_destroyed'
      EPIC_TASK_CHECKED = 'project_management_users_checking_epic_task'
      EPIC_TASK_UNCHECKED = 'project_management_users_unchecking_epic_task'
      EPIC_CROSS_REFERENCED = 'g_project_management_epic_cross_referenced'

      class << self
        def track_epic_created_action(author:)
          track_unique_action(EPIC_CREATED, author)
        end

        def track_epic_title_changed_action(author:)
          track_unique_action(EPIC_TITLE_CHANGED, author)
        end

        def track_epic_description_changed_action(author:)
          track_unique_action(EPIC_DESCRIPTION_CHANGED, author)
        end

        def track_epic_note_created_action(author:)
          track_unique_action(EPIC_NOTE_CREATED, author)
        end

        def track_epic_note_updated_action(author:)
          track_unique_action(EPIC_NOTE_UPDATED, author)
        end

        def track_epic_note_destroyed_action(author:)
          track_unique_action(EPIC_NOTE_DESTROYED, author)
        end

        def track_epic_emoji_awarded_action(author:)
          track_unique_action(EPIC_EMOJI_AWARDED, author)
        end

        def track_epic_emoji_removed_action(author:)
          track_unique_action(EPIC_EMOJI_REMOVED, author)
        end

        def track_epic_start_date_set_as_fixed_action(author:)
          track_unique_action(EPIC_START_DATE_SET_AS_FIXED, author)
        end

        def track_epic_start_date_set_as_inherited_action(author:)
          track_unique_action(EPIC_START_DATE_SET_AS_INHERITED, author)
        end

        def track_epic_due_date_set_as_fixed_action(author:)
          track_unique_action(EPIC_DUE_DATE_SET_AS_FIXED, author)
        end

        def track_epic_due_date_set_as_inherited_action(author:)
          track_unique_action(EPIC_DUE_DATE_SET_AS_INHERITED, author)
        end

        def track_epic_fixed_start_date_updated_action(author:)
          track_unique_action(EPIC_FIXED_START_DATE_UPDATED, author)
        end

        def track_epic_fixed_due_date_updated_action(author:)
          track_unique_action(EPIC_FIXED_DUE_DATE_UPDATED, author)
        end

        def track_epic_issue_added(author:)
          track_unique_action(EPIC_ISSUE_ADDED, author)
        end

        def track_epic_issue_removed(author:)
          track_unique_action(EPIC_ISSUE_REMOVED, author)
        end

        def track_epic_issue_moved_from_project(author:)
          track_unique_action(EPIC_ISSUE_MOVED_FROM_PROJECT, author)
        end

        def track_epic_parent_updated_action(author:)
          track_unique_action(EPIC_PARENT_UPDATED, author)
        end

        def track_epic_closed_action(author:)
          track_unique_action(EPIC_CLOSED, author)
        end

        def track_epic_reopened_action(author:)
          track_unique_action(EPIC_REOPENED, author)
        end

        def track_issue_promoted_to_epic(author:)
          track_unique_action(ISSUE_PROMOTED_TO_EPIC, author)
        end

        def track_epic_confidential_action(author:)
          track_unique_action(EPIC_CONFIDENTIAL, author)
        end

        def track_epic_visible_action(author:)
          track_unique_action(EPIC_VISIBLE, author)
        end

        def track_epic_labels_changed_action(author:)
          track_unique_action(EPIC_LABELS, author)
        end

        def track_epic_destroyed(author:)
          track_unique_action(EPIC_DESTROYED, author)
        end

        def track_epic_task_checked(author:)
          track_unique_action(EPIC_TASK_CHECKED, author)
        end

        def track_epic_task_unchecked(author:)
          track_unique_action(EPIC_TASK_UNCHECKED, author)
        end

        def track_epic_cross_referenced(author:)
          track_unique_action(EPIC_CROSS_REFERENCED, author)
        end

        private

        def track_unique_action(action, author)
          return unless Feature.enabled?(:track_epics_activity, default_enabled: true)
          return unless author

          Gitlab::UsageDataCounters::HLLRedisCounter.track_event(action, values: author.id)
        end
      end
    end
  end
end
