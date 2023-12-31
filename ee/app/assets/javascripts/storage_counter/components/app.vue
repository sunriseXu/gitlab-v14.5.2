<script>
import {
  GlLink,
  GlSprintf,
  GlModalDirective,
  GlButton,
  GlIcon,
  GlKeysetPagination,
} from '@gitlab/ui';
import { parseBoolean } from '~/lib/utils/common_utils';
import UsageGraph from '~/vue_shared/components/storage_counter/usage_graph.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { PROJECTS_PER_PAGE } from '../constants';
import query from '../queries/storage.query.graphql';
import { formatUsageSize, parseGetStorageResults } from '../utils';
import ProjectsTable from './projects_table.vue';
import StorageInlineAlert from './storage_inline_alert.vue';
import TemporaryStorageIncreaseModal from './temporary_storage_increase_modal.vue';
import UsageStatistics from './usage_statistics.vue';

export default {
  name: 'StorageCounterApp',
  components: {
    GlLink,
    GlIcon,
    GlButton,
    GlSprintf,
    UsageGraph,
    ProjectsTable,
    UsageStatistics,
    StorageInlineAlert,
    GlKeysetPagination,
    TemporaryStorageIncreaseModal,
  },
  directives: {
    GlModalDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    namespacePath: {
      type: String,
      required: true,
    },
    helpPagePath: {
      type: String,
      required: true,
    },
    purchaseStorageUrl: {
      type: String,
      required: false,
      default: null,
    },
    isTemporaryStorageIncreaseVisible: {
      type: String,
      required: false,
      default: 'false',
    },
  },
  apollo: {
    namespace: {
      query,
      variables() {
        return {
          fullPath: this.namespacePath,
          searchTerm: this.searchTerm,
          withExcessStorageData: this.isAdditionalStorageFlagEnabled,
          first: PROJECTS_PER_PAGE,
        };
      },
      update: parseGetStorageResults,
      result() {
        this.firstFetch = false;
      },
    },
  },
  data() {
    return {
      namespace: {},
      searchTerm: '',
      firstFetch: true,
    };
  },
  computed: {
    namespaceProjects() {
      return this.namespace?.projects?.data ?? [];
    },
    isStorageIncreaseModalVisible() {
      return parseBoolean(this.isTemporaryStorageIncreaseVisible);
    },
    isAdditionalStorageFlagEnabled() {
      return this.glFeatures.additionalRepoStorageByNamespace;
    },

    formattedNamespaceLimit() {
      return formatUsageSize(this.namespace.limit);
    },
    storageStatistics() {
      if (!this.namespace) {
        return null;
      }

      return {
        totalRepositorySize: this.namespace.totalRepositorySize,
        actualRepositorySizeLimit: this.namespace.actualRepositorySizeLimit,
        totalRepositorySizeExcess: this.namespace.totalRepositorySizeExcess,
        additionalPurchasedStorageSize: this.namespace.additionalPurchasedStorageSize,
      };
    },
    isQueryLoading() {
      return this.$apollo.queries.namespace.loading;
    },
    pageInfo() {
      return this.namespace.projects?.pageInfo ?? {};
    },
    shouldShowStorageInlineAlert() {
      if (this.firstFetch) {
        // for initial load check if the data fetch is done (isQueryLoading)
        return this.isAdditionalStorageFlagEnabled && !this.isQueryLoading;
      }
      // for all subsequent queries the storage inline alert doesn't
      // have to be re-rendered as the data from graphql will remain
      // the same.
      return this.isAdditionalStorageFlagEnabled;
    },
    showPagination() {
      return Boolean(this.pageInfo?.hasPreviousPage || this.pageInfo?.hasNextPage);
    },
  },
  methods: {
    handleSearch(input) {
      // if length === 0 clear the search, if length > 2 update the search term
      if (input.length === 0 || input.length > 2) {
        this.searchTerm = input;
      }
    },
    fetchMoreProjects(vars) {
      this.$apollo.queries.namespace.fetchMore({
        variables: {
          fullPath: this.namespacePath,
          withExcessStorageData: this.isAdditionalStorageFlagEnabled,
          first: PROJECTS_PER_PAGE,
          ...vars,
        },
        updateQuery(previousResult, { fetchMoreResult }) {
          return fetchMoreResult;
        },
      });
    },
    onPrev(before) {
      if (this.pageInfo?.hasPreviousPage) {
        this.fetchMoreProjects({ before });
      }
    },
    onNext(after) {
      if (this.pageInfo?.hasNextPage) {
        this.fetchMoreProjects({ after });
      }
    },
  },
  modalId: 'temporary-increase-storage-modal',
};
</script>
<template>
  <div>
    <storage-inline-alert
      v-if="shouldShowStorageInlineAlert"
      :contains-locked-projects="namespace.containsLockedProjects"
      :repository-size-excess-project-count="namespace.repositorySizeExcessProjectCount"
      :total-repository-size-excess="namespace.totalRepositorySizeExcess"
      :total-repository-size="namespace.totalRepositorySize"
      :additional-purchased-storage-size="namespace.additionalPurchasedStorageSize"
      :actual-repository-size-limit="namespace.actualRepositorySizeLimit"
    />
    <div v-if="isAdditionalStorageFlagEnabled && storageStatistics">
      <usage-statistics
        :root-storage-statistics="storageStatistics"
        :purchase-storage-url="purchaseStorageUrl"
      />
    </div>
    <div v-else class="gl-py-4 gl-px-2 gl-m-0">
      <div class="gl-display-flex gl-align-items-center">
        <div class="gl-w-half">
          <gl-sprintf :message="s__('UsageQuota|You used: %{usage} %{limit}')">
            <template #usage>
              <span class="gl-font-weight-bold" data-testid="total-usage">
                {{ namespace.totalUsage }}
              </span>
            </template>
            <template #limit>
              <gl-sprintf
                v-if="namespace.limit"
                :message="s__('UsageQuota|out of %{formattedLimit} of your namespace storage')"
              >
                <template #formattedLimit>
                  <span class="gl-font-weight-bold">{{ formattedNamespaceLimit }}</span>
                </template>
              </gl-sprintf>
            </template>
          </gl-sprintf>
          <gl-link
            :href="helpPagePath"
            target="_blank"
            :aria-label="s__('UsageQuota|Usage quotas help link')"
          >
            <gl-icon name="question" :size="12" />
          </gl-link>
        </div>
        <div class="gl-w-half gl-text-right">
          <gl-button
            v-if="isStorageIncreaseModalVisible"
            v-gl-modal-directive="$options.modalId"
            category="secondary"
            variant="success"
            data-testid="temporary-storage-increase-button"
            >{{ s__('UsageQuota|Increase storage temporarily') }}</gl-button
          >
          <gl-link
            v-if="purchaseStorageUrl"
            :href="purchaseStorageUrl"
            class="btn btn-success gl-ml-2"
            target="_blank"
            data-testid="purchase-storage-link"
            >{{ s__('UsageQuota|Purchase more storage') }}</gl-link
          >
        </div>
      </div>
      <div v-if="namespace.rootStorageStatistics" class="gl-w-full">
        <usage-graph
          :root-storage-statistics="namespace.rootStorageStatistics"
          :limit="namespace.limit"
        />
      </div>
    </div>
    <projects-table
      :projects="namespaceProjects"
      :is-loading="isQueryLoading"
      :additional-purchased-storage-size="namespace.additionalPurchasedStorageSize || 0"
      @search="handleSearch"
    />
    <div class="gl-display-flex gl-justify-content-center gl-mt-5">
      <gl-keyset-pagination v-if="showPagination" v-bind="pageInfo" @prev="onPrev" @next="onNext" />
    </div>
    <temporary-storage-increase-modal
      v-if="isStorageIncreaseModalVisible"
      :limit="formattedNamespaceLimit"
      :modal-id="$options.modalId"
    />
  </div>
</template>
