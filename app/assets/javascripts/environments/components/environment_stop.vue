<script>
/**
 * Renders the stop "button" that allows stop an environment.
 * Used in environments table.
 */

import { GlTooltipDirective, GlButton, GlModalDirective } from '@gitlab/ui';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import eventHub from '../event_hub';

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    GlModalDirective,
  },
  props: {
    environment: {
      type: Object,
      required: true,
    },
  },
  i18n: {
    title: s__('Environments|Stop environment'),
    stop: s__('Environments|Stop'),
  },
  data() {
    return {
      isLoading: false,
    };
  },
  mounted() {
    eventHub.$on('stopEnvironment', this.onStopEnvironment);
  },
  beforeDestroy() {
    eventHub.$off('stopEnvironment', this.onStopEnvironment);
  },
  methods: {
    onClick() {
      this.$root.$emit(BV_HIDE_TOOLTIP, this.$options.stopEnvironmentTooltipId);
      eventHub.$emit('requestStopEnvironment', this.environment);
    },
    onStopEnvironment(environment) {
      if (this.environment.id === environment.id) {
        this.isLoading = true;
      }
    },
  },
  stopEnvironmentTooltipId: 'stop-environment-button-tooltip',
};
</script>
<template>
  <gl-button
    v-gl-tooltip="{ id: $options.stopEnvironmentTooltipId }"
    v-gl-modal-directive="'stop-environment-modal'"
    :loading="isLoading"
    :title="$options.i18n.title"
    :aria-label="$options.i18n.title"
    icon="stop"
    category="secondary"
    variant="danger"
    @click="onClick"
  >
    {{ $options.i18n.stop }}
  </gl-button>
</template>
