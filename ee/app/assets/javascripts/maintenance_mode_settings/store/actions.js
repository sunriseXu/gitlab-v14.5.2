import Api from 'ee/api';
import createFlash from '~/flash';
import { __ } from '~/locale';
import * as types from './mutation_types';

export const updateMaintenanceModeSettings = ({ commit, state }) => {
  commit(types.REQUEST_UPDATE_MAINTENANCE_MODE_SETTINGS);
  Api.updateApplicationSettings({
    maintenance_mode: state.maintenanceEnabled,
    maintenance_mode_message: state.bannerMessage,
  })
    .then(({ data }) => {
      commit(types.RECEIVE_UPDATE_MAINTENANCE_MODE_SETTINGS_SUCCESS, {
        maintenanceEnabled: data.maintenance_mode,
        bannerMessage: data.maintenance_mode_message,
      });
    })
    .catch(() => {
      createFlash({ message: __('There was an error updating the Maintenance Mode Settings') });
      commit(types.RECEIVE_UPDATE_MAINTENANCE_MODE_SETTINGS_ERROR);
    });
};

export const setMaintenanceEnabled = ({ commit }, { maintenanceEnabled }) => {
  commit(types.SET_MAINTENANCE_ENABLED, maintenanceEnabled);
};

export const setBannerMessage = ({ commit }, { bannerMessage }) => {
  commit(types.SET_BANNER_MESSAGE, bannerMessage);
};
