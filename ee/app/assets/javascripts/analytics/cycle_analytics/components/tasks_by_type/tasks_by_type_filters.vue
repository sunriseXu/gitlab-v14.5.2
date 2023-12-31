<script>
import { GlDropdownDivider, GlSegmentedControl, GlIcon, GlSprintf } from '@gitlab/ui';
import { removeFlash } from '~/cycle_analytics/utils';
import createFlash from '~/flash';
import { s__, sprintf } from '~/locale';
import {
  TASKS_BY_TYPE_FILTERS,
  TASKS_BY_TYPE_SUBJECT_ISSUE,
  TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS,
  TASKS_BY_TYPE_MAX_LABELS,
} from '../../constants';
import LabelsSelector from '../labels_selector.vue';

export default {
  name: 'TasksByTypeFilters',
  components: {
    GlSegmentedControl,
    GlDropdownDivider,
    GlIcon,
    LabelsSelector,
    GlSprintf,
  },
  props: {
    selectedLabelIds: {
      type: Array,
      required: true,
    },
    maxLabels: {
      type: Number,
      required: false,
      default: TASKS_BY_TYPE_MAX_LABELS,
    },
    subjectFilter: {
      type: String,
      required: true,
    },
    hasData: {
      type: Boolean,
      required: true,
    },
    defaultGroupLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    subjectFilterOptions() {
      return Object.entries(TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS).map(([value, text]) => ({
        text,
        value,
      }));
    },
    selectedSubjectFilter() {
      const { subjectFilter } = this;
      return TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[subjectFilter]
        ? TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[subjectFilter]
        : TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[TASKS_BY_TYPE_SUBJECT_ISSUE];
    },
    selectedLabelsCount() {
      return this.selectedLabelIds.length;
    },
    maxLabelsSelected() {
      return this.selectedLabelIds.length >= this.maxLabels;
    },
  },
  methods: {
    canUpdateLabelFilters(value) {
      // we can always remove a filter
      return this.selectedLabelIds.includes(value) || !this.maxLabelsSelected;
    },
    handleLabelSelected(value) {
      removeFlash('notice');
      if (this.canUpdateLabelFilters(value)) {
        this.$emit('update-filter', { filter: TASKS_BY_TYPE_FILTERS.LABEL, value });
      } else {
        const { maxLabels } = this;
        const message = sprintf(
          s__('CycleAnalytics|Only %{maxLabels} labels can be selected at this time'),
          { maxLabels },
        );
        createFlash({
          message,
          type: 'notice',
        });
      }
    },
  },
  TASKS_BY_TYPE_FILTERS,
};
</script>
<template>
  <div
    class="js-tasks-by-type-chart-filters d-flex flex-row justify-content-between align-items-center"
  >
    <div class="flex-column">
      <h4>{{ s__('CycleAnalytics|Tasks by type') }}</h4>
      <p v-if="hasData">
        <gl-sprintf
          :message="
            n__(
              'CycleAnalytics|Showing %{subjectFilterText} and %{selectedLabelsCount} label',
              'CycleAnalytics|Showing %{subjectFilterText} and %{selectedLabelsCount} labels',
              selectedLabelsCount,
            )
          "
        >
          <template #selectedLabelsCount>{{ selectedLabelsCount }}</template>
          <template #subjectFilterText>{{ selectedSubjectFilter }}</template>
        </gl-sprintf>
      </p>
    </div>
    <div class="flex-column">
      <labels-selector
        data-testid="type-of-work-filters-label"
        :initial-data="defaultGroupLabels"
        :max-labels="maxLabels"
        :aria-label="__('CycleAnalytics|Display chart filters')"
        :selected-label-ids="selectedLabelIds"
        aria-expanded="false"
        multiselect
        right
        @select-label="handleLabelSelected"
      >
        <template #label-dropdown-button>
          <gl-icon class="vertical-align-top" name="settings" />
          <gl-icon name="chevron-down" />
        </template>
        <template #label-dropdown-list-header>
          <div class="mb-3 px-3">
            <p class="font-weight-bold text-left mb-2">{{ s__('CycleAnalytics|Show') }}</p>
            <gl-segmented-control
              data-testid="type-of-work-filters-subject"
              :checked="subjectFilter"
              :options="subjectFilterOptions"
              @input="
                (value) =>
                  $emit('update-filter', { filter: $options.TASKS_BY_TYPE_FILTERS.SUBJECT, value })
              "
            />
          </div>
          <gl-dropdown-divider />
          <div class="mb-3 px-3">
            <p class="font-weight-bold text-left my-2">
              {{ s__('CycleAnalytics|Select labels') }}
              <br /><small>
                <gl-sprintf
                  :message="
                    s__('CycleAnalytics|%{selectedLabelsCount} selected (%{maxLabels} max)')
                  "
                >
                  <template #selectedLabelsCount>{{ selectedLabelsCount }}</template>
                  <template #maxLabels>{{ maxLabels }}</template>
                </gl-sprintf>
              </small>
            </p>
          </div>
        </template>
      </labels-selector>
    </div>
  </div>
</template>
