import { chartKeys } from '../../../constants';
import * as types from './mutation_types';

export const setInitialData = ({ commit, dispatch }, { skipFetch = false, data }) => {
  commit(types.SET_INITIAL_DATA, data);

  if (skipFetch) return Promise.resolve();

  return dispatch('charts/fetchChartData', chartKeys.main, { root: true }).then(() => {
    dispatch('charts/fetchSecondaryChartData', null, { root: true });
    // let's reset the page on the MR table and fetch data
    dispatch('table/setPage', 0, { root: true });
  });
};

export const setGroupNamespace = ({ commit, dispatch }, groupNamespace) => {
  commit(types.SET_GROUP_NAMESPACE, groupNamespace);

  // let's reset the current selection first
  // with skipReload=true we avoid data from being fetched here
  dispatch('charts/resetMainChartSelection', true, { root: true });

  // let's fetch the main chart data first to see if the user has access to the selected group
  // if there's no 403, then we fetch all remaining chart data and table data
  return dispatch('charts/fetchChartData', chartKeys.main, { root: true }).then(() => {
    dispatch('charts/fetchSecondaryChartData', null, { root: true });
    // let's reset the page on the MR table and fetch data
    dispatch('table/setPage', 0, { root: true });
  });
};

export const setProjectPath = ({ commit, dispatch }, projectPath) => {
  commit(types.SET_PROJECT_PATH, projectPath);

  dispatch('charts/resetMainChartSelection', true, { root: true });

  return dispatch('charts/fetchChartData', chartKeys.main, { root: true }).then(() => {
    dispatch('charts/fetchSecondaryChartData', null, { root: true });
    // let's reset the page on the MR table and fetch data
    dispatch('table/setPage', 0, { root: true });
  });
};

export const setFilters = (
  { commit, dispatch },
  { author_username, label_name, milestone_title },
) => {
  commit(types.SET_FILTERS, {
    authorUsername: author_username,
    labelName: label_name,
    milestoneTitle: milestone_title,
  });

  dispatch('charts/resetMainChartSelection', true, { root: true });

  return dispatch('charts/fetchChartData', chartKeys.main, { root: true }).then(() => {
    dispatch('charts/fetchSecondaryChartData', null, { root: true });
    // let's reset the page on the MR table and fetch data
    dispatch('table/setPage', 0, { root: true });
  });
};

export const setDateRange = ({ commit, dispatch }, { startDate, endDate }) => {
  commit(types.SET_DATE_RANGE, { startDate, endDate });

  dispatch('charts/resetMainChartSelection', true, { root: true });

  return dispatch('charts/fetchChartData', chartKeys.main, { root: true }).then(() => {
    dispatch('charts/fetchSecondaryChartData', null, { root: true });
    // let's reset the page on the MR table and fetch data
    dispatch('table/setPage', 0, { root: true });
  });
};
