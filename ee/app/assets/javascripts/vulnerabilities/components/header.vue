<script>
import { GlLoadingIcon, GlButton, GlBadge } from '@gitlab/ui';
import vulnerabilityStateMutations from 'ee/security_dashboard/graphql/mutate_vulnerability_state';
import SplitButton from 'ee/vue_shared/security_reports/components/split_button.vue';
import createFlash from '~/flash';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPE_VULNERABILITY } from '~/graphql_shared/constants';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import download from '~/lib/utils/downloader';
import { redirectTo } from '~/lib/utils/url_utility';
import UsersCache from '~/lib/utils/users_cache';
import { s__ } from '~/locale';
import { VULNERABILITY_STATE_OBJECTS, FEEDBACK_TYPES, HEADER_ACTION_BUTTONS } from '../constants';
import { normalizeGraphQLVulnerability } from '../helpers';
import ResolutionAlert from './resolution_alert.vue';
import StatusDescription from './status_description.vue';
import VulnerabilityStateDropdown from './vulnerability_state_dropdown.vue';

export default {
  name: 'VulnerabilityHeader',

  components: {
    GlLoadingIcon,
    GlButton,
    GlBadge,
    ResolutionAlert,
    VulnerabilityStateDropdown,
    SplitButton,
    StatusDescription,
  },

  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
  },

  data() {
    return {
      isProcessingAction: false,
      isLoadingVulnerability: false,
      isLoadingUser: false,
      user: undefined,
    };
  },

  badgeVariants: {
    confirmed: 'danger',
    resolved: 'success',
    detected: 'warning',
  },

  computed: {
    stateVariant() {
      return this.$options.badgeVariants[this.vulnerability.state] || 'neutral';
    },
    actionButtons() {
      const buttons = [];

      if (this.canCreateMergeRequest) {
        buttons.push(HEADER_ACTION_BUTTONS.mergeRequestCreation);
      }

      if (this.canDownloadPatch) {
        buttons.push(HEADER_ACTION_BUTTONS.patchDownload);
      }

      return buttons;
    },
    canDownloadPatch() {
      return (
        this.vulnerability.state !== VULNERABILITY_STATE_OBJECTS.resolved.state &&
        !this.vulnerability.hasMr &&
        this.hasRemediation
      );
    },
    hasIssue() {
      return Boolean(this.vulnerability.issueFeedback?.issueIid);
    },
    hasRemediation() {
      const { remediations } = this.vulnerability;
      return Boolean(remediations && remediations[0]?.diff?.length > 0);
    },
    canCreateMergeRequest() {
      return (
        !this.vulnerability.mergeRequestFeedback?.mergeRequestPath &&
        Boolean(this.vulnerability.createMrUrl) &&
        this.hasRemediation
      );
    },
    showResolutionAlert() {
      return (
        this.vulnerability.resolvedOnDefaultBranch &&
        this.vulnerability.state !== VULNERABILITY_STATE_OBJECTS.resolved.state
      );
    },
  },

  watch: {
    'vulnerability.state': {
      immediate: true,
      handler(state) {
        const id = this.vulnerability[`${state}ById`];

        if (!id) {
          return;
        }

        this.isLoadingUser = true;

        UsersCache.retrieveById(id)
          .then((userData) => {
            this.user = userData;
          })
          .catch(() => {
            createFlash({
              message: s__('VulnerabilityManagement|Something went wrong, could not get user.'),
            });
          })
          .finally(() => {
            this.isLoadingUser = false;
          });
      },
    },
  },

  methods: {
    triggerClick(action) {
      const fn = this[action];
      if (typeof fn === 'function') fn();
    },

    async changeVulnerabilityState({ action, payload }) {
      this.isLoadingVulnerability = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: vulnerabilityStateMutations[action],
          variables: {
            id: convertToGraphQLId(TYPE_VULNERABILITY, this.vulnerability.id),
            ...payload,
          },
        });
        const [queryName] = Object.keys(data);

        this.$emit('vulnerability-state-change', {
          ...this.vulnerability,
          ...normalizeGraphQLVulnerability(data[queryName].vulnerability),
        });
      } catch (error) {
        createFlash({
          message: {
            error,
            captureError: true,
            message: s__(
              'VulnerabilityManagement|Something went wrong, could not update vulnerability state.',
            ),
          },
        });
      } finally {
        this.isLoadingVulnerability = false;
      }
    },

    createMergeRequest() {
      this.isProcessingAction = true;

      const {
        reportType: category,
        pipeline: { sourceBranch },
        projectFingerprint,
      } = this.vulnerability;

      // note: this direct API call will be replaced when migrating the vulnerability details page to GraphQL
      // related epic: https://gitlab.com/groups/gitlab-org/-/epics/3657
      axios
        .post(this.vulnerability.createMrUrl, {
          vulnerability_feedback: {
            feedback_type: FEEDBACK_TYPES.MERGE_REQUEST,
            category,
            project_fingerprint: projectFingerprint,
            vulnerability_data: {
              ...convertObjectPropsToSnakeCase(this.vulnerability),
              category,
              target_branch: sourceBranch,
            },
          },
        })
        .then(({ data: { merge_request_path: mergeRequestPath } }) => {
          redirectTo(mergeRequestPath);
        })
        .catch(() => {
          this.isProcessingAction = false;
          createFlash({
            message: s__(
              'ciReport|There was an error creating the merge request. Please try again.',
            ),
          });
        });
    },
    downloadPatch() {
      download({
        fileData: this.vulnerability.remediations[0].diff,
        fileName: `remediation.patch`,
      });
    },
  },
};
</script>

<template>
  <div data-qa-selector="vulnerability_header">
    <resolution-alert
      v-if="showResolutionAlert"
      :vulnerability-id="vulnerability.id"
      :default-branch-name="vulnerability.projectDefaultBranch"
    />
    <div class="detail-page-header">
      <div
        class="detail-page-header-body align-items-center"
        data-testid="vulnerability-detail-body"
      >
        <gl-loading-icon v-if="isLoadingVulnerability" size="sm" class="mr-2" />
        <gl-badge v-else class="gl-mr-4 text-capitalize" :variant="stateVariant">
          {{ vulnerability.state }}
        </gl-badge>

        <status-description
          class="issuable-meta"
          :vulnerability="vulnerability"
          :user="user"
          :is-loading-vulnerability="isLoadingVulnerability"
          :is-loading-user="isLoadingUser"
        />
      </div>

      <div class="detail-page-header-actions align-items-center">
        <label class="mb-0 mx-2">{{ __('Status') }}</label>
        <gl-loading-icon v-if="isLoadingVulnerability" size="sm" class="d-inline" />
        <vulnerability-state-dropdown
          v-else
          :initial-state="vulnerability.state"
          @change="changeVulnerabilityState"
        />
        <split-button
          v-if="actionButtons.length > 1"
          :buttons="actionButtons"
          :disabled="isProcessingAction"
          class="js-split-button"
          @createMergeRequest="createMergeRequest"
          @downloadPatch="downloadPatch"
        />
        <gl-button
          v-else-if="actionButtons.length > 0"
          class="ml-2"
          variant="success"
          category="secondary"
          :loading="isProcessingAction"
          @click="triggerClick(actionButtons[0].action)"
        >
          {{ actionButtons[0].name }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
