<script>
import { GlIcon, GlPopover, GlLink } from '@gitlab/ui';
import { REPLICATION_STATUS_UI, REPLICATION_PAUSE_URL } from 'ee/geo_nodes/constants';
import { __, s__ } from '~/locale';

export default {
  name: 'GeoNodeReplicationStatus',
  i18n: {
    pauseHelpText: s__('Geo|Geo sites are paused using a command run on the site'),
    learnMore: __('Learn more'),
  },
  components: {
    GlIcon,
    GlPopover,
    GlLink,
  },
  props: {
    node: {
      type: Object,
      required: true,
    },
  },
  computed: {
    replicationStatusUi() {
      return this.node.enabled ? REPLICATION_STATUS_UI.enabled : REPLICATION_STATUS_UI.disabled;
    },
  },
  REPLICATION_PAUSE_URL,
};
</script>

<template>
  <div class="gl-display-flex gl-align-items-center">
    <span
      class="gl-font-weight-bold"
      :class="replicationStatusUi.color"
      data-testid="replication-status-text"
      >{{ replicationStatusUi.text }}</span
    >
    <gl-icon
      ref="replicationStatus"
      name="question"
      class="gl-text-blue-500 gl-cursor-pointer gl-ml-2"
    />
    <gl-popover :target="() => $refs.replicationStatus.$el" placement="top" triggers="hover focus">
      <p class="gl-font-base">
        {{ $options.i18n.pauseHelpText }}
      </p>
      <gl-link :href="$options.REPLICATION_PAUSE_URL" target="_blank">{{
        $options.i18n.learnMore
      }}</gl-link>
    </gl-popover>
  </div>
</template>
