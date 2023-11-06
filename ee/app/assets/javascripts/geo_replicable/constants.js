import { __ } from '~/locale';

export const FILTER_STATES = {
  ALL: {
    label: __('All'),
    value: '',
  },
  PENDING: {
    label: __('In progress'),
    value: 'pending',
  },
  FAILED: {
    label: __('Failed'),
    value: 'failed',
  },
  SYNCED: {
    label: __('Synced'),
    value: 'synced',
  },
};

export const DEFAULT_STATUS = 'never';

export const STATUS_ICON_NAMES = {
  [FILTER_STATES.SYNCED.value]: 'status_closed',
  [FILTER_STATES.PENDING.value]: 'status_scheduled',
  [FILTER_STATES.FAILED.value]: 'status_failed',
  [DEFAULT_STATUS]: 'status_notfound',
};

export const STATUS_ICON_CLASS = {
  [FILTER_STATES.SYNCED.value]: 'text-success',
  [FILTER_STATES.PENDING.value]: 'text-warning',
  [FILTER_STATES.FAILED.value]: 'text-danger',
  [DEFAULT_STATUS]: 'text-muted',
};

export const DEFAULT_SEARCH_DELAY = 500;

export const ACTION_TYPES = {
  RESYNC: 'resync',
  // Below not implemented yet
  REVERIFY: 'reverify',
  FORCE_REDOWNLOAD: 'force_redownload',
};

export const PREV = 'prev';

export const NEXT = 'next';

export const DEFAULT_PAGE_SIZE = 20;

export const RESYNC_MODAL_ID = 'resync-all-geo';
