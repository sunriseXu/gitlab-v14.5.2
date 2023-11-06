import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

export const MOCK_GEO_REPLICATION_SVG_PATH = 'illustrations/empty-state/geo-replication-empty.svg';

export const MOCK_GEO_TROUBLESHOOTING_LINK =
  'https://docs.gitlab.com/ee/administration/geo/replication/troubleshooting.html';

export const MOCK_REPLICABLE_TYPE = 'designs';

export const MOCK_GRAPHQL_REGISTRY = 'designsRegistry';

export const MOCK_BASIC_FETCH_RESPONSE = {
  data: [
    {
      id: 1,
      project_id: 1,
      name: 'zack test 1',
      state: 'pending',
      last_synced_at: null,
    },
    {
      id: 2,
      project_id: 2,
      name: 'zack test 2',
      state: 'synced',
      last_synced_at: null,
    },
  ],
  headers: {
    'x-per-page': 20,
    'x-total': 100,
  },
};

export const MOCK_BASIC_FETCH_DATA_MAP = convertObjectPropsToCamelCase(
  MOCK_BASIC_FETCH_RESPONSE.data,
  { deep: true },
);

export const MOCK_RESTFUL_PAGINATION_DATA = {
  perPage: MOCK_BASIC_FETCH_RESPONSE.headers['x-per-page'],
  total: MOCK_BASIC_FETCH_RESPONSE.headers['x-total'],
};

export const MOCK_GRAPHQL_PAGINATION_DATA = {
  hasNextPage: true,
  hasPreviousPage: true,
  startCursor: 'abc123',
  endCursor: 'abc124',
};

export const MOCK_BASIC_GRAPHQL_QUERY_RESPONSE = {
  geoNode: {
    [MOCK_GRAPHQL_REGISTRY]: {
      pageInfo: MOCK_GRAPHQL_PAGINATION_DATA,
      nodes: [
        {
          id: 'git/1',
          state: 'PENDING',
          lastSyncedAt: null,
        },
        {
          id: 'git/2',
          state: 'SYNCED',
          lastSyncedAt: null,
        },
      ],
    },
  },
};

export const MOCK_BASIC_POST_RESPONSE = {
  status: 'ok',
};
