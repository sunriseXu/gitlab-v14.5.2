import Api from 'ee/api';
import { getGroupValueStreamStageMedian } from 'ee/api/analytics_api';
import {
  I18N_VSA_ERROR_STAGES,
  I18N_VSA_ERROR_STAGE_MEDIAN,
  I18N_VSA_ERROR_SELECTED_STAGE,
} from '~/cycle_analytics/constants';
import createFlash from '~/flash';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';
import { OVERVIEW_STAGE_CONFIG } from '../../constants';
import { checkForDataError, flashErrorIfStatusNotOk, throwIfUserForbidden } from '../../utils';
import * as types from '../mutation_types';

export const setSelectedStage = ({ commit }, stage) => commit(types.SET_SELECTED_STAGE, stage);

export const setDefaultSelectedStage = ({ dispatch }) =>
  dispatch('setSelectedStage', OVERVIEW_STAGE_CONFIG);

export const requestStageData = ({ commit }) => commit(types.REQUEST_STAGE_DATA);

export const receiveStageDataError = ({ commit }, error) => {
  const { message = '' } = error;
  flashErrorIfStatusNotOk({ error, message: I18N_VSA_ERROR_SELECTED_STAGE });
  commit(types.RECEIVE_STAGE_DATA_ERROR, message);
};

export const fetchStageData = ({ dispatch, getters, commit }, stageId) => {
  const {
    cycleAnalyticsRequestParams = {},
    currentValueStreamId,
    currentGroupPath,
    paginationParams,
  } = getters;
  dispatch('requestStageData');

  return Api.cycleAnalyticsStageEvents({
    groupId: currentGroupPath,
    valueStreamId: currentValueStreamId,
    stageId,
    params: {
      ...cycleAnalyticsRequestParams,
      ...paginationParams,
    },
  })
    .then(checkForDataError)
    .then(({ data, headers }) => {
      const { page = null, nextPage = null } = parseIntPagination(normalizeHeaders(headers));
      commit(types.RECEIVE_STAGE_DATA_SUCCESS, data);
      commit(types.SET_PAGINATION, { ...paginationParams, page, hasNextPage: Boolean(nextPage) });
    })
    .catch((error) => dispatch('receiveStageDataError', error));
};

export const requestStageMedianValues = ({ commit }) => commit(types.REQUEST_STAGE_MEDIANS);

export const receiveStageMedianValuesError = ({ commit }, error) => {
  commit(types.RECEIVE_STAGE_MEDIANS_ERROR, error);
  createFlash({ message: I18N_VSA_ERROR_STAGE_MEDIAN });
};

const fetchStageMedian = ({ groupId, valueStreamId, stageId, params }) =>
  getGroupValueStreamStageMedian({ groupId, valueStreamId, stageId }, params).then(({ data }) => {
    return {
      id: stageId,
      ...(data?.error
        ? {
            error: data.error,
            value: null,
          }
        : data),
    };
  });

export const fetchStageMedianValues = ({ dispatch, commit, getters }) => {
  const {
    currentGroupPath,
    cycleAnalyticsRequestParams,
    activeStages,
    currentValueStreamId,
  } = getters;
  const stageIds = activeStages.map((s) => s.id);

  dispatch('requestStageMedianValues');
  return Promise.all(
    stageIds.map((stageId) =>
      fetchStageMedian({
        groupId: currentGroupPath,
        valueStreamId: currentValueStreamId,
        stageId,
        params: cycleAnalyticsRequestParams,
      }),
    ),
  )
    .then((data) => commit(types.RECEIVE_STAGE_MEDIANS_SUCCESS, data))
    .catch((error) => dispatch('receiveStageMedianValuesError', error));
};

const fetchStageCount = ({ groupId, valueStreamId, stageId, params }) =>
  Api.cycleAnalyticsStageCount({ groupId, valueStreamId, stageId, params }).then(({ data }) => {
    return {
      id: stageId,
      ...(data?.error
        ? {
            error: data.error,
            value: null,
          }
        : data),
    };
  });

export const fetchStageCountValues = ({ commit, getters }) => {
  const {
    currentGroupPath,
    cycleAnalyticsRequestParams,
    activeStages,
    currentValueStreamId,
  } = getters;
  const stageIds = activeStages.map((s) => s.id);

  commit(types.REQUEST_STAGE_COUNTS);
  return Promise.all(
    stageIds.map((stageId) =>
      fetchStageCount({
        groupId: currentGroupPath,
        valueStreamId: currentValueStreamId,
        stageId,
        params: cycleAnalyticsRequestParams,
      }),
    ),
  )
    .then((data) => commit(types.RECEIVE_STAGE_COUNTS_SUCCESS, data))
    .catch((error) => commit(types.RECEIVE_STAGE_COUNTS_ERROR, error));
};

export const requestGroupStages = ({ commit }) => commit(types.REQUEST_GROUP_STAGES);

export const receiveGroupStagesError = ({ commit }, error) => {
  commit(types.RECEIVE_GROUP_STAGES_ERROR, error);
  createFlash({ message: I18N_VSA_ERROR_STAGES });
};

export const receiveGroupStagesSuccess = ({ commit }, stages) =>
  commit(types.RECEIVE_GROUP_STAGES_SUCCESS, stages);

export const fetchGroupStagesAndEvents = ({ dispatch, commit, getters }) => {
  const {
    currentValueStreamId: valueStreamId,
    currentGroupPath: groupId,
    cycleAnalyticsRequestParams: { created_after, project_ids },
  } = getters;

  dispatch('requestGroupStages');
  commit(types.SET_STAGE_EVENTS, []);

  return Api.cycleAnalyticsGroupStagesAndEvents({
    groupId,
    valueStreamId,
    params: {
      start_date: created_after,
      project_ids,
    },
  })
    .then(({ data: { stages = [], events = [] } }) => {
      dispatch('receiveGroupStagesSuccess', stages);
      commit(types.SET_STAGE_EVENTS, events);
    })
    .catch((error) => {
      throwIfUserForbidden(error);
      return dispatch('receiveGroupStagesError', error);
    });
};
