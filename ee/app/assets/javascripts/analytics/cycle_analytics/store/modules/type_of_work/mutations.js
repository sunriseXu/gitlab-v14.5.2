import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { TASKS_BY_TYPE_FILTERS } from '../../../constants';
import { transformRawTasksByTypeData, toggleSelectedLabel } from '../../../utils';
import * as types from './mutation_types';

export default {
  [types.SET_LOADING](state, loading) {
    state.isLoadingTasksByTypeChartTopLabels = loading;
    state.isLoadingTasksByTypeChart = loading;
  },
  [types.REQUEST_TOP_RANKED_GROUP_LABELS](state) {
    state.isLoadingTasksByTypeChartTopLabels = true;
    state.topRankedLabels = [];
    state.selectedLabelIds = [];
    state.errorCode = null;
    state.errorMessage = '';
  },
  [types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS](state, data = []) {
    state.isLoadingTasksByTypeChartTopLabels = false;
    state.topRankedLabels = data.map(convertObjectPropsToCamelCase);
    state.selectedLabelIds = data.map(({ id }) => id);
    state.errorCode = null;
    state.errorMessage = '';
  },
  [types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR](state, { errorCode = null, message = '' } = {}) {
    state.isLoadingTasksByTypeChartTopLabels = false;
    state.isLoadingTasksByTypeChart = false;
    state.topRankedLabels = [];
    state.selectedLabelIds = [];
    state.errorCode = errorCode;
    state.errorMessage = message;
  },
  [types.REQUEST_TASKS_BY_TYPE_DATA](state) {
    state.isLoadingTasksByTypeChart = true;
  },
  [types.RECEIVE_TASKS_BY_TYPE_DATA_ERROR](state) {
    state.isLoadingTasksByTypeChart = false;
  },
  [types.RECEIVE_TASKS_BY_TYPE_DATA_SUCCESS](state, data = []) {
    state.isLoadingTasksByTypeChart = false;
    state.data = transformRawTasksByTypeData(data);
  },
  [types.SET_TASKS_BY_TYPE_FILTERS](state, { filter, value }) {
    const { selectedLabelIds } = state;
    switch (filter) {
      case TASKS_BY_TYPE_FILTERS.LABEL:
        state.selectedLabelIds = toggleSelectedLabel({ selectedLabelIds, value });
        break;
      case TASKS_BY_TYPE_FILTERS.SUBJECT:
        state.subject = value;
        break;
      default:
        break;
    }
  },
};
