<script>
import { GlDropdown, GlDropdownForm, GlFormTextarea, GlButton } from '@gitlab/ui';
import { __, n__ } from '~/locale';

export default {
  components: { GlDropdown, GlDropdownForm, GlFormTextarea, GlButton },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    defaultCommitMessage: {
      type: String,
      required: true,
    },
    batchSuggestionsCount: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      message: null,
    };
  },
  computed: {
    dropdownText() {
      if (this.batchSuggestionsCount <= 1) {
        return __('Apply suggestion');
      }

      return n__('Apply %d suggestion', 'Apply %d suggestions', this.batchSuggestionsCount);
    },
  },
  methods: {
    onApply() {
      this.$emit('apply', this.message);
    },
  },
};
</script>

<template>
  <gl-dropdown
    :text="dropdownText"
    :disabled="disabled"
    boundary="window"
    right
    lazy
    menu-class="gl-w-full!"
    data-qa-selector="apply_suggestion_dropdown"
    @shown="$refs.commitMessage.$el.focus()"
  >
    <gl-dropdown-form class="gl-px-4! gl-m-0!">
      <label for="commit-message">{{ __('Commit message') }}</label>
      <gl-form-textarea
        id="commit-message"
        ref="commitMessage"
        v-model="message"
        :placeholder="defaultCommitMessage"
        submit-on-enter
        data-qa-selector="commit_message_field"
        @submit="onApply"
      />
      <gl-button
        class="gl-w-auto! gl-mt-3 gl-text-center! gl-hover-text-white! gl-transition-medium! float-right"
        category="primary"
        variant="success"
        data-qa-selector="commit_with_custom_message_button"
        @click="onApply"
      >
        {{ __('Apply') }}
      </gl-button>
    </gl-dropdown-form>
  </gl-dropdown>
</template>
