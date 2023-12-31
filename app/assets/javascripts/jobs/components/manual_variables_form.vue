<script>
import {
  GlFormInputGroup,
  GlInputGroupText,
  GlFormInput,
  GlButton,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { mapActions } from 'vuex';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';

export default {
  name: 'ManualVariablesForm',
  components: {
    GlFormInputGroup,
    GlInputGroupText,
    GlFormInput,
    GlButton,
    GlLink,
    GlSprintf,
  },
  props: {
    action: {
      type: Object,
      required: false,
      default: null,
      validator(value) {
        return (
          value === null ||
          (Object.prototype.hasOwnProperty.call(value, 'path') &&
            Object.prototype.hasOwnProperty.call(value, 'method') &&
            Object.prototype.hasOwnProperty.call(value, 'button_title'))
        );
      },
    },
  },
  inputTypes: {
    key: 'key',
    value: 'value',
  },
  i18n: {
    header: s__('CiVariables|Variables'),
    keyLabel: s__('CiVariables|Key'),
    valueLabel: s__('CiVariables|Value'),
    keyPlaceholder: s__('CiVariables|Input variable key'),
    valuePlaceholder: s__('CiVariables|Input variable value'),
    formHelpText: s__(
      'CiVariables|Specify variable values to be used in this run. The values specified in %{linkStart}CI/CD settings%{linkEnd} will be used as default',
    ),
  },
  data() {
    return {
      variables: [
        {
          key: '',
          secretValue: '',
          id: uniqueId(),
        },
      ],
      triggerBtnDisabled: false,
    };
  },
  computed: {
    variableSettings() {
      return helpPagePath('ci/variables/index', { anchor: 'add-a-cicd-variable-to-a-project' });
    },
    preparedVariables() {
      // we need to ensure no empty variables are passed to the API
      // and secretValue should be snake_case when passed to the API
      return this.variables
        .filter((variable) => variable.key !== '')
        .map(({ key, secretValue }) => ({ key, secret_value: secretValue }));
    },
  },
  methods: {
    ...mapActions(['triggerManualJob']),
    canRemove(index) {
      return index < this.variables.length - 1;
    },
    addEmptyVariable() {
      const lastVar = this.variables[this.variables.length - 1];

      if (lastVar.key === '') {
        return;
      }

      this.variables.push({
        key: '',
        secret_value: '',
        id: uniqueId(),
      });
    },
    deleteVariable(id) {
      this.variables.splice(
        this.variables.findIndex((el) => el.id === id),
        1,
      );
    },
    trigger() {
      this.triggerBtnDisabled = true;

      this.triggerManualJob(this.preparedVariables);
    },
  },
};
</script>
<template>
  <div class="row gl-justify-content-center">
    <div class="col-10" data-testid="manual-vars-form">
      <label>{{ $options.i18n.header }}</label>

      <div
        v-for="(variable, index) in variables"
        :key="variable.id"
        class="gl-display-flex gl-align-items-center gl-mb-4"
        data-testid="ci-variable-row"
      >
        <gl-form-input-group class="gl-mr-4 gl-flex-grow-1">
          <template #prepend>
            <gl-input-group-text>
              {{ $options.i18n.keyLabel }}
            </gl-input-group-text>
          </template>
          <gl-form-input
            :ref="`${$options.inputTypes.key}-${variable.id}`"
            v-model="variable.key"
            :placeholder="$options.i18n.keyPlaceholder"
            data-testid="ci-variable-key"
            @change="addEmptyVariable"
          />
        </gl-form-input-group>

        <gl-form-input-group class="gl-flex-grow-2">
          <template #prepend>
            <gl-input-group-text>
              {{ $options.i18n.valueLabel }}
            </gl-input-group-text>
          </template>
          <gl-form-input
            :ref="`${$options.inputTypes.value}-${variable.id}`"
            v-model="variable.secretValue"
            :placeholder="$options.i18n.valuePlaceholder"
            data-testid="ci-variable-value"
          />
        </gl-form-input-group>

        <!-- delete variable button placeholder to not break flex layout  -->
        <div
          v-if="!canRemove(index)"
          class="gl-w-7 gl-mr-3"
          data-testid="delete-variable-btn-placeholder"
        ></div>

        <gl-button
          v-if="canRemove(index)"
          class="gl-flex-grow-0 gl-flex-basis-0"
          category="tertiary"
          variant="danger"
          icon="clear"
          :aria-label="__('Delete variable')"
          data-testid="delete-variable-btn"
          @click="deleteVariable(variable.id)"
        />
      </div>

      <div class="gl-text-center gl-mt-5">
        <gl-sprintf :message="$options.i18n.formHelpText">
          <template #link="{ content }">
            <gl-link :href="variableSettings" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </div>
      <div class="gl-display-flex gl-justify-content-center gl-mt-5">
        <gl-button
          class="gl-mt-5"
          variant="info"
          category="primary"
          :aria-label="__('Trigger manual job')"
          :disabled="triggerBtnDisabled"
          data-testid="trigger-manual-job-btn"
          @click="trigger"
        >
          {{ action.button_title }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
