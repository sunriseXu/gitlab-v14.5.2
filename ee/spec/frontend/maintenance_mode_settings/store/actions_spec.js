import MockAdapter from 'axios-mock-adapter';
import {
  DEFAULT_MAINTENANCE_ENABLED,
  DEFAULT_BANNER_MESSAGE,
} from 'ee/maintenance_mode_settings/constants';
import * as actions from 'ee/maintenance_mode_settings/store/actions';
import { createState } from 'ee/maintenance_mode_settings/store/state';
import testAction from 'helpers/vuex_action_helper';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { ACTIONS_TEST_DATA } from '../mock_data';

jest.mock('~/flash');

describe('MaintenanceModeSettings Store Actions', () => {
  let mock;
  let state;

  const noCallback = () => {};
  const flashCallback = () => {
    expect(createFlash).toHaveBeenCalledTimes(1);
    createFlash.mockClear();
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
    state = createState({
      maintenanceEnabled: DEFAULT_MAINTENANCE_ENABLED,
      bannerMessage: DEFAULT_BANNER_MESSAGE,
    });
  });

  afterEach(() => {
    mock.restore();
    state = null;
  });

  describe.each`
    action                           | data                                           | mutationCall
    ${actions.setMaintenanceEnabled} | ${ACTIONS_TEST_DATA.setMaintenanceEnabledData} | ${ACTIONS_TEST_DATA.setMaintenanceEnabledMutations}
    ${actions.setBannerMessage}      | ${ACTIONS_TEST_DATA.setBannerMessageData}      | ${ACTIONS_TEST_DATA.setBannerMessageMutations}
  `(`non-axios calls`, ({ action, data, mutationCall }) => {
    describe(action.name, () => {
      it(`should commit mutation ${mutationCall.type}`, () => {
        return testAction(action, data, state, [mutationCall], []).then(() => noCallback());
      });
    });
  });

  describe.each`
    action                                   | axiosMock                                | type         | mutationCalls                               | callback
    ${actions.updateMaintenanceModeSettings} | ${ACTIONS_TEST_DATA.successfulAxiosCall} | ${'success'} | ${ACTIONS_TEST_DATA.updateSuccessMutations} | ${noCallback}
    ${actions.updateMaintenanceModeSettings} | ${ACTIONS_TEST_DATA.errorAxiosCall}      | ${'error'}   | ${ACTIONS_TEST_DATA.updateErrorMutations}   | ${flashCallback}
  `(`axios calls`, ({ action, axiosMock, type, mutationCalls, callback }) => {
    describe(action.name, () => {
      describe(`on ${type}`, () => {
        beforeEach(() => {
          mock[axiosMock.method]().replyOnce(axiosMock.code, axiosMock.res);
        });
        it(`should dispatch the correct mutations`, () => {
          return testAction(action, null, state, mutationCalls, []).then(() => callback());
        });
      });
    });
  });
});
