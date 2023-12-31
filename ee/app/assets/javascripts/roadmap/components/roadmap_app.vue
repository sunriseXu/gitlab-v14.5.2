<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { mapState, mapActions } from 'vuex';

import { DATE_RANGES } from '../constants';
import EpicsListEmpty from './epics_list_empty.vue';
import RoadmapFilters from './roadmap_filters.vue';
import RoadmapShell from './roadmap_shell.vue';

export default {
  components: {
    EpicsListEmpty,
    GlLoadingIcon,
    RoadmapFilters,
    RoadmapShell,
  },
  props: {
    timeframeRangeType: {
      type: String,
      required: false,
      default: DATE_RANGES.CURRENT_QUARTER,
    },
    presetType: {
      type: String,
      required: true,
    },
    emptyStateIllustrationPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState([
      'currentGroupId',
      'epicIid',
      'epics',
      'milestones',
      'timeframe',
      'epicsFetchInProgress',
      'epicsFetchResultEmpty',
      'epicsFetchFailure',
      'isChildEpics',
      'hasFiltersApplied',
      'filterParams',
    ]),
    showFilteredSearchbar() {
      if (this.epicsFetchResultEmpty) {
        return this.hasFiltersApplied;
      }
      return true;
    },
    timeframeStart() {
      return this.timeframe[0];
    },
    timeframeEnd() {
      const last = this.timeframe.length - 1;
      return this.timeframe[last];
    },
    isWarningVisible() {
      return !this.isWarningDismissed && this.epics.length > gon?.roadmap_epics_limit;
    },
  },
  mounted() {
    this.fetchEpics();
    this.fetchMilestones();
  },
  methods: {
    ...mapActions(['fetchEpics', 'fetchMilestones']),
  },
};
</script>

<template>
  <div class="roadmap-app-container gl-h-full">
    <roadmap-filters
      v-if="showFilteredSearchbar && !epicIid"
      :timeframe-range-type="timeframeRangeType"
    />
    <div :class="{ 'overflow-reset': epicsFetchResultEmpty }" class="roadmap-container">
      <gl-loading-icon v-if="epicsFetchInProgress" class="gl-mt-5" size="md" />
      <epics-list-empty
        v-else-if="epicsFetchResultEmpty"
        :preset-type="presetType"
        :timeframe-start="timeframeStart"
        :timeframe-end="timeframeEnd"
        :has-filters-applied="hasFiltersApplied"
        :empty-state-illustration-path="emptyStateIllustrationPath"
        :is-child-epics="isChildEpics"
        :filter-params="filterParams"
      />
      <roadmap-shell
        v-else-if="!epicsFetchFailure"
        :preset-type="presetType"
        :epics="epics"
        :milestones="milestones"
        :timeframe="timeframe"
        :current-group-id="currentGroupId"
        :has-filters-applied="hasFiltersApplied"
      />
    </div>
  </div>
</template>
