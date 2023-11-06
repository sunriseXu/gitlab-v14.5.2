# frozen_string_literal: true

module Boards
  module Epics
    class MoveService < Boards::BaseItemMoveService
      extend ::Gitlab::Utils::Override

      private

      def update(epic, epic_modification_params)
        ::Epics::UpdateService.new(group: epic.group, current_user: current_user, params: epic_modification_params).execute(epic)
      end

      def board
        @board ||= parent.epic_boards.find(params[:board_id])
      end

      override :board_label_ids
      def board_label_ids
        ::Label.ids_on_epic_board(board.id)
      end

      override :reposition_params
      def reposition_params(reposition_ids)
        super.merge(list_id: params[:to_list_id], board_group: parent)
      end

      def reposition_parent
        { board_id: board.id }
      end
    end
  end
end
