<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import DetailsRow from '~/vue_shared/components/registry/details_row.vue';

export default {
  i18n: {
    targetShaCopyButton: s__('PackageRegistry|Copy target SHA'),
    targetSha: s__('PackageRegistry|Target SHA: %{sha}'),
    composerJson: s__(
      'PackageRegistry|Composer.json with license: %{license} and version: %{version}',
    ),
  },
  components: {
    DetailsRow,
    GlSprintf,
    ClipboardButton,
  },
  props: {
    packageEntity: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <details-row icon="information-o" padding="gl-p-4" dashed data-testid="composer-target-sha">
      <gl-sprintf :message="$options.i18n.targetSha">
        <template #sha>
          <strong>{{ packageEntity.metadata.targetSha }}</strong>
          <clipboard-button
            :title="$options.i18n.targetShaCopyButton"
            :text="packageEntity.metadata.targetSha"
            category="tertiary"
            css-class="gl-p-0!"
          />
        </template>
      </gl-sprintf>
    </details-row>
    <details-row icon="information-o" padding="gl-p-4" data-testid="composer-json">
      <gl-sprintf :message="$options.i18n.composerJson">
        <template #license>
          <strong>{{ packageEntity.metadata.composerJson.license }}</strong>
        </template>
        <template #version>
          <strong>{{ packageEntity.metadata.composerJson.version }}</strong>
        </template>
      </gl-sprintf>
    </details-row>
  </div>
</template>
