<script>
import { mapState } from 'vuex';

import eventHub from '../event_hub';

import epicsListSection from './epics_list_section.vue';
import milestonesListSection from './milestones_list_section.vue';
import roadmapTimelineSection from './roadmap_timeline_section.vue';

export default {
  components: {
    epicsListSection,
    milestonesListSection,
    roadmapTimelineSection,
  },
  props: {
    presetType: {
      type: String,
      required: true,
    },
    epics: {
      type: Array,
      required: true,
    },
    milestones: {
      type: Array,
      required: true,
    },
    timeframe: {
      type: Array,
      required: true,
    },
    currentGroupId: {
      type: Number,
      required: true,
    },
    hasFiltersApplied: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    ...mapState(['defaultInnerHeight']),
    displayMilestones() {
      return Boolean(this.milestones.length);
    },
  },
  methods: {
    handleScroll() {
      const { scrollTop, scrollLeft, clientHeight, scrollHeight } = this.$el;

      eventHub.$emit('epicsListScrolled', { scrollTop, scrollLeft, clientHeight, scrollHeight });
    },
  },
};
</script>

<template>
  <div
    class="js-roadmap-shell gl-relative gl-h-full gl-w-full gl-overflow-x-auto"
    data-qa-selector="roadmap_shell"
    @scroll="handleScroll"
  >
    <roadmap-timeline-section
      ref="roadmapTimeline"
      :preset-type="presetType"
      :epics="epics"
      :timeframe="timeframe"
    />
    <milestones-list-section
      v-if="displayMilestones"
      :preset-type="presetType"
      :milestones="milestones"
      :timeframe="timeframe"
      :current-group-id="currentGroupId"
    />
    <epics-list-section
      :preset-type="presetType"
      :epics="epics"
      :timeframe="timeframe"
      :current-group-id="currentGroupId"
      :has-filters-applied="hasFiltersApplied"
    />
  </div>
</template>
