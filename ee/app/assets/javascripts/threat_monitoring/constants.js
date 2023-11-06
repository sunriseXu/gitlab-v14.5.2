import { __, s__ } from '~/locale';

export const DEFAULT_ASSIGNED_POLICY_PROJECT = { fullPath: '', branch: '' };

export const LOADING_TEXT = __('Loading...');

export const INVALID_CURRENT_ENVIRONMENT_NAME = '-';

export const PREDEFINED_NETWORK_POLICIES = [
  {
    __typename: 'NetworkPolicy',
    name: 'drop-outbound',
    enabled: false,
    kind: 'CiliumNetworkPolicy',
    yaml: `---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: drop-outbound
spec:
  endpointSelector: {}
  egress:
  - {}`,
  },
  {
    __typename: 'NetworkPolicy',
    name: 'allow-inbound-http',
    enabled: false,
    kind: 'CiliumNetworkPolicy',
    yaml: `---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-inbound-http
spec:
  endpointSelector: {}
  ingress:
  - toPorts:
    - ports:
      - port: '80'
      - port: '443'`,
  },
];

export const ALL_ENVIRONMENT_NAME = s__('ThreatMonitoring|All Environments');

export const PAGE_SIZE = 20;
