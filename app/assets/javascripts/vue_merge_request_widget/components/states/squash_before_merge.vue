<script>
import { GlIcon, GlTooltipDirective, GlFormCheckbox, GlLink } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { SQUASH_BEFORE_MERGE } from '../../i18n';

export default {
  components: {
    GlIcon,
    GlFormCheckbox,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  i18n: {
    ...SQUASH_BEFORE_MERGE,
  },
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    helpPath: {
      type: String,
      required: false,
      default: '',
    },
    isDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    tooltipTitle() {
      return this.isDisabled ? this.$options.i18n.tooltipTitle : null;
    },
    helpIconName() {
      return this.glFeatures.restructuredMrWidget ? 'question-o' : 'question';
    },
  },
};
</script>

<template>
  <div class="gl-display-flex gl-align-items-center">
    <gl-form-checkbox
      v-gl-tooltip
      :checked="value"
      :disabled="isDisabled"
      name="squash"
      class="js-squash-checkbox gl-mr-2 gl-display-flex gl-align-items-center"
      data-qa-selector="squash_checkbox"
      :title="tooltipTitle"
      @change="(checked) => $emit('input', checked)"
    >
      {{ $options.i18n.checkboxLabel }}
    </gl-form-checkbox>
    <gl-link
      v-if="helpPath"
      v-gl-tooltip
      :href="helpPath"
      :title="$options.i18n.helpLabel"
      :class="{ 'gl-text-blue-600': glFeatures.restructuredMrWidget }"
      target="_blank"
    >
      <gl-icon :name="helpIconName" />
      <span class="sr-only">
        {{ $options.i18n.helpLabel }}
      </span>
    </gl-link>
  </div>
</template>
