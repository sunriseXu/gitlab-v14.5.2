import {
  formatListIssues,
  formatListsPageInfo,
  fullBoardId,
  getMoveData,
  filterVariables,
} from '~/boards/boards_util';
import { BoardType } from '~/boards/constants';
import { gqlClient } from '~/boards/graphql';
import groupBoardMembersQuery from '~/boards/graphql/group_board_members.query.graphql';
import listsIssuesQuery from '~/boards/graphql/lists_issues.query.graphql';
import projectBoardMembersQuery from '~/boards/graphql/project_board_members.query.graphql';
import actionsCE from '~/boards/stores/actions';
import * as typesCE from '~/boards/stores/mutation_types';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { historyPushState, convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { mergeUrlParams, removeParams, queryToObject } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import groupBoardIterationsQuery from 'ee/boards/graphql/group_board_iterations.query.graphql';
import projectBoardIterationsQuery from 'ee/boards/graphql/project_board_iterations.query.graphql';
import {
  fullEpicBoardId,
  formatEpic,
  formatListEpics,
  formatEpicListsPageInfo,
  formatEpicInput,
  FiltersInfo,
} from '../boards_util';

import { EpicFilterType, GroupByParamType, FilterFields } from '../constants';
import createEpicBoardListMutation from '../graphql/epic_board_list_create.mutation.graphql';
import epicCreateMutation from '../graphql/epic_create.mutation.graphql';
import epicMoveListMutation from '../graphql/epic_move_list.mutation.graphql';
import epicsSwimlanesQuery from '../graphql/epics_swimlanes.query.graphql';
import listUpdateLimitMetricsMutation from '../graphql/list_update_limit_metrics.mutation.graphql';
import listsEpicsQuery from '../graphql/lists_epics.query.graphql';
import subGroupsQuery from '../graphql/sub_groups.query.graphql';
import updateBoardEpicUserPreferencesMutation from '../graphql/update_board_epic_user_preferences.mutation.graphql';
import updateEpicLabelsMutation from '../graphql/update_epic_labels.mutation.graphql';

import * as types from './mutation_types';

const fetchAndFormatListIssues = (state, extraVariables) => {
  const { fullPath, boardId, boardType, filterParams } = state;

  const variables = {
    fullPath,
    boardId: fullBoardId(boardId),
    filters: { ...filterParams },
    isGroup: boardType === BoardType.group,
    isProject: boardType === BoardType.project,
    ...extraVariables,
  };

  return gqlClient
    .query({
      query: listsIssuesQuery,
      context: {
        isSingleRequest: true,
      },
      variables,
    })
    .then(({ data }) => {
      const { lists } = data[boardType]?.board;
      return { listItems: formatListIssues(lists), listPageInfo: formatListsPageInfo(lists) };
    });
};

const fetchAndFormatListEpics = (state, extraVariables) => {
  const { fullPath, boardId, filterParams } = state;

  const variables = {
    fullPath,
    boardId: fullEpicBoardId(boardId),
    filters: { ...filterParams },
    ...extraVariables,
  };

  return gqlClient
    .query({
      query: listsEpicsQuery,
      context: {
        isSingleRequest: true,
      },
      variables,
    })
    .then(({ data }) => {
      const { lists } = data.group?.epicBoard;
      return { listItems: formatListEpics(lists), listPageInfo: formatEpicListsPageInfo(lists) };
    });
};

export { gqlClient };

export default {
  ...actionsCE,

  setFilters: ({ commit, dispatch, state: { issuableType } }, filters) => {
    if (filters.groupBy === GroupByParamType.epic) {
      dispatch('setEpicSwimlanes');
    }

    commit(
      types.SET_FILTERS,
      filterVariables({
        filters,
        issuableType,
        filterInfo: FiltersInfo,
        filterFields: FilterFields,
      }),
    );
  },

  fetchIterations({ state, commit }, title) {
    commit(types.RECEIVE_ITERATIONS_REQUEST);

    const { fullPath, boardType } = state;

    const variables = {
      fullPath,
      title,
    };

    let query;
    if (boardType === BoardType.project) {
      query = projectBoardIterationsQuery;
    }
    if (boardType === BoardType.group) {
      query = groupBoardIterationsQuery;
    }

    if (!query) {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      throw new Error('Unknown board type');
    }

    return gqlClient
      .query({
        query,
        variables,
      })
      .then(({ data }) => {
        const errors = data[boardType]?.errors;
        const iterations = data[boardType]?.iterations.nodes;

        if (errors?.[0]) {
          throw new Error(errors[0]);
        }

        commit(types.RECEIVE_ITERATIONS_SUCCESS, iterations);

        return iterations;
      })
      .catch((e) => {
        commit(types.RECEIVE_ITERATIONS_FAILURE);
        throw e;
      });
  },

  performSearch({ dispatch, getters }) {
    dispatch(
      'setFilters',
      convertObjectPropsToCamelCase(queryToObject(window.location.search, { gatherArrays: true })),
    );

    if (getters.isSwimlanesOn) {
      dispatch('resetEpics');
      dispatch('fetchEpicsSwimlanes');
    }

    dispatch('fetchLists');
    dispatch('resetIssues');
  },

  fetchEpicsSwimlanes({ state, commit }, { fetchNext = false } = {}) {
    const { fullPath, boardId, boardType, filterParams, epicsEndCursor } = state;

    if (fetchNext) {
      commit(types.REQUEST_MORE_EPICS);
    }

    const variables = {
      fullPath,
      boardId: `gid://gitlab/Board/${boardId}`,
      issueFilters: filterParams,
      isGroup: boardType === BoardType.group,
      isProject: boardType === BoardType.project,
      after: fetchNext ? epicsEndCursor : undefined,
    };

    return gqlClient
      .query({
        query: epicsSwimlanesQuery,
        variables,
      })
      .then(({ data }) => {
        const { epics } = data[boardType]?.board;
        const epicsFormatted = epics.edges.map((e) => ({
          ...e.node,
        }));

        if (epicsFormatted) {
          commit(types.RECEIVE_EPICS_SUCCESS, {
            epics: epicsFormatted,
            canAdminEpic: epics.edges[0]?.node?.userPermissions?.adminEpic,
            hasMoreEpics: epics.pageInfo?.hasNextPage,
            epicsEndCursor: epics.pageInfo?.endCursor,
          });
        }
      })
      .catch(() => commit(types.RECEIVE_SWIMLANES_FAILURE));
  },

  fetchIssuesForEpic: ({ state, commit }, epicId) => {
    commit(types.REQUEST_ISSUES_FOR_EPIC, epicId);

    const { filterParams } = state;

    const variables = {
      filters: { ...filterParams, epicId },
    };

    return fetchAndFormatListIssues(state, variables)
      .then(({ listItems }) => {
        commit(types.RECEIVE_ISSUES_FOR_EPIC_SUCCESS, { ...listItems, epicId });
      })
      .catch(() => commit(types.RECEIVE_ISSUES_FOR_EPIC_FAILURE, epicId));
  },

  updateBoardEpicUserPreferences({ commit, state }, { epicId, collapsed }) {
    const { boardId } = state;

    const variables = {
      boardId: fullBoardId(boardId),
      epicId,
      collapsed,
    };

    return gqlClient
      .mutate({
        mutation: updateBoardEpicUserPreferencesMutation,
        variables,
      })
      .then(({ data }) => {
        if (data?.updateBoardEpicUserPreferences?.errors.length) {
          throw new Error();
        }

        const { epicUserPreferences: userPreferences } = data?.updateBoardEpicUserPreferences;
        commit(types.SET_BOARD_EPIC_USER_PREFERENCES, { epicId, userPreferences });
      })
      .catch(() => {
        commit(types.SET_BOARD_EPIC_USER_PREFERENCES, {
          epicId,
          userPreferences: {
            collapsed: !collapsed,
          },
        });
      });
  },

  setShowLabels({ commit }, val) {
    commit(types.SET_SHOW_LABELS, val);
  },

  updateListWipLimit({ commit, dispatch }, { maxIssueCount, listId }) {
    return gqlClient
      .mutate({
        mutation: listUpdateLimitMetricsMutation,
        variables: {
          input: {
            listId,
            maxIssueCount,
          },
        },
      })
      .then(({ data }) => {
        if (data?.boardListUpdateLimitMetrics?.errors.length) {
          throw new Error();
        }

        commit(types.UPDATE_LIST_SUCCESS, {
          listId,
          list: data.boardListUpdateLimitMetrics?.list,
        });
      })
      .catch(() => {
        dispatch('handleUpdateListFailure');
      });
  },

  fetchItemsForList: (
    { state, commit, getters },
    { listId, fetchNext = false, noEpicIssues = false },
  ) => {
    if (!listId) return null;

    if (!fetchNext && !state.isShowingEpicsSwimlanes) {
      commit(types.RESET_ITEMS_FOR_LIST, listId);
    }
    commit(types.REQUEST_ITEMS_FOR_LIST, { listId, fetchNext });

    const { epicId, ...filterParams } = state.filterParams;
    if (noEpicIssues && epicId !== undefined) {
      return null;
    }

    const variables = {
      id: listId,
      filters: noEpicIssues
        ? { ...filterParams, epicWildcardId: EpicFilterType.none.toUpperCase() }
        : { ...filterParams, epicId },
      after: fetchNext ? state.pageInfoByListId[listId].endCursor : undefined,
      first: 10,
    };

    if (getters.isEpicBoard) {
      return fetchAndFormatListEpics(state, variables)
        .then(({ listItems, listPageInfo }) => {
          commit(types.RECEIVE_ITEMS_FOR_LIST_SUCCESS, {
            listItems,
            listPageInfo,
            listId,
            noEpicIssues,
          });
        })
        .catch(() => commit(types.RECEIVE_ITEMS_FOR_LIST_FAILURE, listId));
    }

    return fetchAndFormatListIssues(state, variables)
      .then(({ listItems, listPageInfo }) => {
        commit(types.RECEIVE_ITEMS_FOR_LIST_SUCCESS, {
          listItems,
          listPageInfo,
          listId,
          noEpicIssues,
        });
      })
      .catch(() => commit(types.RECEIVE_ITEMS_FOR_LIST_FAILURE, listId));
  },

  toggleEpicSwimlanes: ({ state, commit, dispatch }) => {
    commit(types.TOGGLE_EPICS_SWIMLANES);

    if (state.isShowingEpicsSwimlanes) {
      historyPushState(
        mergeUrlParams({ group_by: GroupByParamType.epic }, window.location.href, {
          spreadArrays: true,
        }),
      );
      dispatch('fetchEpicsSwimlanes');
      dispatch('fetchLists');
    } else {
      historyPushState(removeParams(['group_by']), window.location.href, true);
    }
  },

  setEpicSwimlanes: ({ commit }) => {
    commit(types.SET_EPICS_SWIMLANES);
  },

  doneLoadingSwimlanesItems: ({ commit }) => {
    commit(types.DONE_LOADING_SWIMLANES_ITEMS);
  },

  resetEpics: ({ commit }) => {
    commit(types.RESET_EPICS);
  },

  setActiveItemWeight: async ({ commit, getters }, weight) => {
    commit(typesCE.UPDATE_BOARD_ITEM_BY_ID, {
      itemId: getters.activeBoardItem.id,
      prop: 'weight',
      value: weight,
    });
  },

  moveItem: ({ getters, dispatch }, params) => {
    if (!getters.isEpicBoard) {
      dispatch('moveIssue', params);
    } else {
      dispatch('moveEpic', params);
    }
  },

  moveIssue: ({ dispatch, state }, params) => {
    const { itemId, epicId } = params;
    const moveData = getMoveData(state, params);

    dispatch('moveIssueCard', moveData);
    dispatch('updateMovedIssue', moveData);
    dispatch('updateEpicForIssue', { itemId, epicId });
    dispatch('updateIssueOrder', {
      moveData,
      mutationVariables: { epicId },
    });
  },

  updateEpicForIssue: ({ commit, state: { boardItems } }, { itemId, epicId }) => {
    const issue = boardItems[itemId];

    if (epicId === null) {
      commit(types.UPDATE_BOARD_ITEM_BY_ID, {
        itemId: issue.id,
        prop: 'epic',
        value: null,
      });
    } else if (epicId !== undefined) {
      commit(types.UPDATE_BOARD_ITEM_BY_ID, {
        itemId: issue.id,
        prop: 'epic',
        value: { id: epicId },
      });
    }
  },

  moveEpic: ({ state, commit }, { itemId, fromListId, toListId, moveBeforeId, moveAfterId }) => {
    const originalEpic = state.boardItems[itemId];
    const fromList = state.boardItemsByListId[fromListId];
    const originalIndex = fromList.indexOf(Number(itemId));
    commit(types.MOVE_EPIC, {
      originalEpic,
      fromListId,
      toListId,
      moveBeforeId,
      moveAfterId,
    });

    const { boardId } = state;

    gqlClient
      .mutate({
        mutation: epicMoveListMutation,
        variables: {
          epicId: itemId,
          boardId: fullEpicBoardId(boardId),
          fromListId,
          toListId,
          moveBeforeId,
          moveAfterId,
        },
      })
      .then(({ data }) => {
        if (data?.epicMoveList?.errors.length) {
          throw new Error();
        }
      })
      .catch(() =>
        commit(types.MOVE_EPIC_FAILURE, { originalEpic, fromListId, toListId, originalIndex }),
      );
  },

  fetchAssignees({ state, commit }, search) {
    commit(types.RECEIVE_ASSIGNEES_REQUEST);

    const { fullPath, boardType } = state;

    const variables = {
      fullPath,
      search,
    };

    let query;
    if (boardType === BoardType.project) {
      query = projectBoardMembersQuery;
    }
    if (boardType === BoardType.group) {
      query = groupBoardMembersQuery;
    }

    if (!query) {
      // eslint-disable-next-line @gitlab/require-i18n-strings
      throw new Error('Unknown board type');
    }

    return gqlClient
      .query({
        query,
        variables,
      })
      .then(({ data }) => {
        const [firstError] = data.workspace.errors || [];
        const assignees = data.workspace.assignees.nodes
          .filter((x) => x?.user)
          .map(({ user }) => user);

        if (firstError) {
          throw new Error(firstError);
        }
        commit(
          types.RECEIVE_ASSIGNEES_SUCCESS,
          // User field is nullable and we only want to display non-null users
          assignees,
        );
      })
      .catch((e) => {
        commit(types.RECEIVE_ASSIGNEES_FAILURE);
        throw e;
      });
  },

  fetchSubGroups: ({ commit, state }, { search = '', fetchNext = false } = {}) => {
    commit(types.REQUEST_SUB_GROUPS, fetchNext);

    const { fullPath } = state;

    const variables = {
      fullPath,
      search: search !== '' ? search : undefined,
      after: fetchNext ? state.subGroupsFlags.pageInfo.endCursor : undefined,
    };

    return gqlClient
      .query({
        query: subGroupsQuery,
        variables,
      })
      .then(({ data }) => {
        const { id, name, fullName, descendantGroups, __typename } = data.group;
        const currentGroup = {
          __typename,
          id,
          name,
          fullName,
          fullPath: data.group.fullPath,
        };
        const subGroups = [currentGroup, ...descendantGroups.nodes];
        commit(types.RECEIVE_SUB_GROUPS_SUCCESS, {
          subGroups,
          pageInfo: descendantGroups.pageInfo,
          fetchNext,
        });
        commit(types.SET_SELECTED_GROUP, currentGroup);
      })
      .catch(() => commit(types.RECEIVE_SUB_GROUPS_FAILURE));
  },

  setSelectedGroup: ({ commit }, group) => {
    commit(types.SET_SELECTED_GROUP, group);
  },

  createList: (
    { getters, dispatch },
    { backlog, labelId, milestoneId, assigneeId, iterationId },
  ) => {
    if (!getters.isEpicBoard) {
      dispatch('createIssueList', { backlog, labelId, milestoneId, assigneeId, iterationId });
    } else {
      dispatch('createEpicList', { backlog, labelId });
    }
  },

  createEpicList: ({ state, commit, dispatch, getters }, { backlog, labelId }) => {
    const { boardId } = state;

    const existingList = getters.getListByLabelId(labelId);

    if (existingList) {
      dispatch('highlightList', existingList.id);
      return;
    }

    gqlClient
      .mutate({
        mutation: createEpicBoardListMutation,
        variables: {
          boardId: fullEpicBoardId(boardId),
          backlog,
          labelId,
        },
      })
      .then(({ data }) => {
        if (data?.epicBoardListCreate?.errors.length) {
          commit(types.CREATE_LIST_FAILURE, data.epicBoardListCreate.errors[0]);
        } else {
          const list = data.epicBoardListCreate?.list;
          dispatch('addList', list);
          dispatch('highlightList', list.id);
        }
      })
      .catch((e) => {
        commit(types.CREATE_LIST_FAILURE);
        throw e;
      });
  },

  addListNewEpic: (
    { state: { boardConfig }, dispatch, commit },
    { epicInput, list, placeholderId = `tmp-${new Date().getTime()}` },
  ) => {
    const placeholderEpic = {
      ...epicInput,
      id: placeholderId,
      isLoading: true,
      labels: [],
      assignees: [],
    };

    dispatch('addListItem', { list, item: placeholderEpic, position: 0, inProgress: true });

    gqlClient
      .mutate({
        mutation: epicCreateMutation,
        variables: { input: formatEpicInput(epicInput, boardConfig) },
      })
      .then(({ data }) => {
        if (data.createEpic.errors?.length) {
          throw new Error(data.createEpic.errors[0]);
        }

        const rawEpic = data.createEpic?.epic;
        const formattedEpic = formatEpic(rawEpic);
        dispatch('removeListItem', { listId: list.id, itemId: placeholderId });
        dispatch('addListItem', { list, item: formattedEpic, position: 0 });
      })
      .catch(() => {
        dispatch('removeListItem', { listId: list.id, itemId: placeholderId });
        commit(
          types.SET_ERROR,
          s__('Boards|An error occurred while creating the epic. Please try again.'),
        );
      });
  },

  setActiveBoardItemLabels: ({ getters, dispatch }, params) => {
    if (!getters.isEpicBoard) {
      dispatch('setActiveIssueLabels', params);
    } else {
      dispatch('setActiveEpicLabels', params);
    }
  },

  setActiveEpicLabels: async ({ commit, getters, state }, input) => {
    const { activeBoardItem } = getters;

    if (!gon.features?.labelsWidget) {
      const { data } = await gqlClient.mutate({
        mutation: updateEpicLabelsMutation,
        variables: {
          input: {
            iid: String(activeBoardItem.iid),
            addLabelIds: input.addLabelIds ?? [],
            removeLabelIds: input.removeLabelIds ?? [],
            groupPath: state.fullPath,
          },
        },
      });

      if (data.updateEpic?.errors?.length > 0) {
        throw new Error(data.updateEpic.errors);
      }

      commit(typesCE.UPDATE_BOARD_ITEM_BY_ID, {
        itemId: activeBoardItem.id,
        prop: 'labels',
        value: data.updateEpic.epic.labels.nodes,
      });

      return;
    }

    let labels = input?.labels || [];
    if (input.removeLabelIds) {
      labels = activeBoardItem.labels.filter(
        (label) => input.removeLabelIds[0] !== getIdFromGraphQLId(label.id),
      );
    }
    commit(types.UPDATE_BOARD_ITEM_BY_ID, {
      itemId: input.id || activeBoardItem.id,
      prop: 'labels',
      value: labels,
    });
  },
};
