<script>
import { GlTooltipDirective, GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';
import query from '../queries/issues.query.graphql';
import Suggestion from './item.vue';

export default {
  components: {
    Suggestion,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    projectPath: {
      type: String,
      required: true,
    },
    search: {
      type: String,
      required: true,
    },
  },
  apollo: {
    issues: {
      query,
      debounce: 1000,
      skip() {
        return this.isSearchEmpty;
      },
      update: (data) => data.project.issues.edges.map(({ node }) => node),
      variables() {
        return {
          fullPath: this.projectPath,
          search: this.search,
        };
      },
    },
  },
  data() {
    return {
      issues: [],
      loading: 0,
    };
  },
  computed: {
    isSearchEmpty() {
      return !this.search.length;
    },
    showSuggestions() {
      return !this.isSearchEmpty && this.issues.length && !this.loading;
    },
  },
  watch: {
    search() {
      if (this.isSearchEmpty) {
        this.issues = [];
      }
    },
  },
  helpText: __(
    'These existing issues have a similar title. It might be better to comment there instead of creating another similar issue.',
  ),
};
</script>

<template>
  <div v-show="showSuggestions" class="form-group row issuable-suggestions">
    <div v-once class="col-form-label col-sm-2 pt-0">
      {{ __('Similar issues') }}
      <gl-icon
        v-gl-tooltip.bottom
        :title="$options.helpText"
        :aria-label="$options.helpText"
        name="question-o"
        class="text-secondary gl-cursor-help"
      />
    </div>
    <div class="col-sm-10">
      <ul class="list-unstyled m-0">
        <li
          v-for="(suggestion, index) in issues"
          :key="suggestion.id"
          :class="{
            'gl-mb-3': index !== issues.length - 1,
          }"
        >
          <suggestion :suggestion="suggestion" />
        </li>
      </ul>
    </div>
  </div>
</template>
