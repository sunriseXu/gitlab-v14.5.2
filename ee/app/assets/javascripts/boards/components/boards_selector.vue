<script>
// This is a false violation of @gitlab/no-runtime-template-compiler, since it
// extends a valid Vue single file component.
/* eslint-disable @gitlab/no-runtime-template-compiler */
import { mapGetters } from 'vuex';
import BoardsSelectorFoss from '~/boards/components/boards_selector.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import Tracking from '~/tracking';
import epicBoardsQuery from '../graphql/epic_boards.query.graphql';
import epicBoardQuery from '../graphql/epic_board.query.graphql';

export default {
  extends: BoardsSelectorFoss,
  mixins: [Tracking.mixin()],
  computed: {
    ...mapGetters(['isEpicBoard']),
    showCreate() {
      return this.isEpicBoard || this.multipleIssueBoardsAvailable;
    },
    showDelete() {
      return this.boards.length > 1;
    },
    currentBoardQuery() {
      return this.isEpicBoard ? epicBoardQuery : this.currentBoardQueryCE;
    },
  },
  methods: {
    epicBoardUpdate(data) {
      if (!data?.group) {
        return [];
      }
      return data.group.epicBoards.nodes.map((node) => ({
        id: getIdFromGraphQLId(node.id),
        name: node.name,
      }));
    },
    epicBoardQuery() {
      return epicBoardsQuery;
    },
    loadBoards(toggleDropdown = true) {
      if (this.isEpicBoard) {
        this.track('click_dropdown', { label: 'board_switcher' });
      }

      if (toggleDropdown && this.boards.length > 0) {
        return;
      }

      this.$apollo.addSmartQuery('boards', {
        variables() {
          return { fullPath: this.fullPath };
        },
        query: this.isEpicBoard ? this.epicBoardQuery : this.boardQuery,
        loadingKey: 'loadingBoards',
        update: this.isEpicBoard ? this.epicBoardUpdate : this.boardUpdate,
      });

      if (!this.isEpicBoard) {
        this.loadRecentBoards();
      }
    },
  },
};
</script>
