import MockAdapter from 'axios-mock-adapter';
import * as actions from 'ee/geo_nodes/store/actions';
import * as types from 'ee/geo_nodes/store/mutation_types';
import createState from 'ee/geo_nodes/store/state';
import testAction from 'helpers/vuex_action_helper';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import {
  MOCK_PRIMARY_VERSION,
  MOCK_REPLICABLE_TYPES,
  MOCK_NODES,
  MOCK_NODES_RES,
  MOCK_NODE_STATUSES_RES,
} from '../mock_data';

jest.mock('~/flash');

describe('GeoNodes Store Actions', () => {
  let mock;
  let state;

  beforeEach(() => {
    state = createState({
      primaryVersion: MOCK_PRIMARY_VERSION.version,
      primaryRevision: MOCK_PRIMARY_VERSION.revision,
      replicableTypes: MOCK_REPLICABLE_TYPES,
    });
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    state = null;
    mock.restore();
  });

  describe('fetchNodes', () => {
    describe('on success', () => {
      beforeEach(() => {
        mock.onGet(/api\/(.*)\/geo_nodes/).replyOnce(200, MOCK_NODES_RES);
        mock.onGet(/api\/(.*)\/geo_nodes\/status/).replyOnce(200, MOCK_NODE_STATUSES_RES);
      });

      it('should dispatch the correct mutations', () => {
        return testAction({
          action: actions.fetchNodes,
          payload: null,
          state,
          expectedMutations: [
            { type: types.REQUEST_NODES },
            { type: types.RECEIVE_NODES_SUCCESS, payload: MOCK_NODES },
          ],
        });
      });
    });

    describe('on error', () => {
      beforeEach(() => {
        mock.onGet(/api\/(.*)\/geo_nodes/).reply(500);
        mock.onGet(/api\/(.*)\/geo_nodes\/status/).reply(500);
      });

      it('should dispatch the correct mutations', () => {
        return testAction({
          action: actions.fetchNodes,
          payload: null,
          state,
          expectedMutations: [{ type: types.REQUEST_NODES }, { type: types.RECEIVE_NODES_ERROR }],
        }).then(() => {
          expect(createFlash).toHaveBeenCalledTimes(1);
          createFlash.mockClear();
        });
      });
    });
  });

  describe('removeNode', () => {
    describe('on success', () => {
      beforeEach(() => {
        mock.onDelete(/api\/.*\/geo_nodes/).replyOnce(200, {});
      });

      it('should dispatch the correct mutations', () => {
        return testAction({
          action: actions.removeNode,
          payload: null,
          state,
          expectedMutations: [
            { type: types.REQUEST_NODE_REMOVAL },
            { type: types.RECEIVE_NODE_REMOVAL_SUCCESS },
          ],
        });
      });
    });

    describe('on error', () => {
      beforeEach(() => {
        mock.onDelete(/api\/(.*)\/geo_nodes/).reply(500);
      });

      it('should dispatch the correct mutations', () => {
        return testAction({
          action: actions.removeNode,
          payload: null,
          state,
          expectedMutations: [
            { type: types.REQUEST_NODE_REMOVAL },
            { type: types.RECEIVE_NODE_REMOVAL_ERROR },
          ],
        }).then(() => {
          expect(createFlash).toHaveBeenCalledTimes(1);
          createFlash.mockClear();
        });
      });
    });
  });

  describe('prepNodeRemoval', () => {
    it('should dispatch the correct mutations', () => {
      return testAction({
        action: actions.prepNodeRemoval,
        payload: 1,
        state,
        expectedMutations: [{ type: types.STAGE_NODE_REMOVAL, payload: 1 }],
      });
    });
  });

  describe('cancelNodeRemoval', () => {
    it('should dispatch the correct mutations', () => {
      return testAction({
        action: actions.cancelNodeRemoval,
        payload: null,
        state,
        expectedMutations: [{ type: types.UNSTAGE_NODE_REMOVAL }],
      });
    });
  });
});
