# frozen_string_literal: true

module Epics
  class UpdateService < Epics::BaseService
    EPIC_DATE_FIELDS = %I[
      start_date_fixed
      start_date_is_fixed
      due_date_fixed
      due_date_is_fixed
    ].freeze

    def execute(epic)
      reposition_on_board(epic)

      # start_date and end_date columns are no longer writable by users because those
      # are composite fields managed by the system.
      params.extract!(:start_date, :end_date)

      update_task_event(epic) || update(epic)

      if saved_change_to_epic_dates?(epic)
        Epics::UpdateDatesService.new([epic]).execute

        track_start_date_fixed_events(epic)
        track_due_date_fixed_events(epic)
        track_fixed_dates_updated_events(epic)

        epic.reset
      end

      track_changes(epic)

      assign_parent_epic_for(epic)
      assign_child_epic_for(epic)

      epic
    end

    def handle_changes(epic, options)
      old_associations = options.fetch(:old_associations, {})
      old_mentioned_users = old_associations.fetch(:mentioned_users, [])
      old_labels = old_associations.fetch(:labels, [])

      if has_changes?(epic, old_labels: old_labels)
        todo_service.resolve_todos_for_target(epic, current_user)
      end

      todo_service.update_epic(epic, current_user, old_mentioned_users)

      if epic.saved_change_to_attribute?(:confidential)
        handle_confidentiality_change(epic)
      end
    end

    def handle_confidentiality_change(epic)
      if epic.confidential?
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_confidential_action(author: current_user)
        # don't enqueue immediately to prevent todos removal in case of a mistake
        ::TodosDestroyer::ConfidentialEpicWorker.perform_in(::Todo::WAIT_FOR_DELETE, epic.id)
      else
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_visible_action(author: current_user)
      end
    end

    def handle_task_changes(epic)
      todo_service.resolve_todos_for_target(epic, current_user)
      todo_service.update_epic(epic, current_user)
    end

    private

    def track_fixed_dates_updated_events(epic)
      fixed_start_date_updated = epic.saved_change_to_attribute?(:start_date_fixed)
      fixed_due_date_updated = epic.saved_change_to_attribute?(:due_date_fixed)
      return unless fixed_start_date_updated || fixed_due_date_updated

      if fixed_start_date_updated
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_fixed_start_date_updated_action(author: current_user)
      end

      if fixed_due_date_updated
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_fixed_due_date_updated_action(author: current_user)
      end
    end

    def track_start_date_fixed_events(epic)
      return unless epic.saved_change_to_attribute?(:start_date_is_fixed)

      if epic.start_date_is_fixed?
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_start_date_set_as_fixed_action(author: current_user)
      else
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_start_date_set_as_inherited_action(author: current_user)
      end
    end

    def track_due_date_fixed_events(epic)
      return unless epic.saved_change_to_attribute?(:due_date_is_fixed)

      if epic.due_date_is_fixed?
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_due_date_set_as_fixed_action(author: current_user)
      else
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_due_date_set_as_inherited_action(author: current_user)
      end
    end

    def reposition_on_board(epic)
      return unless params[:move_between_ids]
      return unless epic_board_id

      fill_missing_positions_before

      epic_board_position = issuable_for_positioning(epic.id, epic_board_id, create_missing: true)
      handle_move_between_ids(epic_board_position)

      epic_board_position.save!
    end

    # we want to create missing only for the epic being moved
    # other records are handled by PositionCreateService
    def issuable_for_positioning(id, board_id, create_missing: false)
      return unless id

      position = Boards::EpicBoardPosition.find_by_epic_id_and_epic_board_id(id, board_id)

      return position if position

      Boards::EpicBoardPosition.create!(epic_id: id, epic_board_id: board_id) if create_missing
    end

    def fill_missing_positions_before
      before_id = params[:move_between_ids].compact.max
      list_id = params.delete(:list_id)
      board_group = params.delete(:board_group)

      return unless before_id
      # if position for the epic above exists we don't need to create positioning records
      return if issuable_for_positioning(before_id, epic_board_id)

      service_params = {
        board_id: epic_board_id,
        list_id: list_id, # we need to have positions only for the current list
        from_id: before_id # we need to have positions only for the epics above
      }

      Boards::Epics::PositionCreateService.new(board_group, current_user, service_params).execute
    end

    def epic_board_id
      params[positioning_scope_key]
    end

    def positioning_scope_key
      :board_id
    end

    def saved_change_to_epic_dates?(epic)
      (epic.saved_changes.keys.map(&:to_sym) & EPIC_DATE_FIELDS).present?
    end

    def track_changes(epic)
      if epic.saved_change_to_attribute?(:title)
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_title_changed_action(author: current_user)
      end

      if epic.saved_change_to_attribute?(:description)
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_description_changed_action(author: current_user)
        track_task_changes(epic)
      end
    end

    def track_task_changes(epic)
      return if epic.updated_tasks.blank?

      epic.updated_tasks.each do |task|
        if task.complete?
          Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_task_checked(author: current_user)
        else
          Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_task_unchecked(author: current_user)
        end
      end
    end
  end
end
