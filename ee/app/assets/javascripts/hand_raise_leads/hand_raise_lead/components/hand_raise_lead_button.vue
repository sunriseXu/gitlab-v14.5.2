<script>
import {
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlFormTextarea,
  GlModal,
  GlModalDirective,
} from '@gitlab/ui';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import createFlash, { FLASH_TYPES } from '~/flash';
import { sprintf } from '~/locale';
import Tracking from '~/tracking';
import countriesQuery from 'ee/subscriptions/graphql/queries/countries.query.graphql';
import statesQuery from 'ee/subscriptions/graphql/queries/states.query.graphql';
import autofocusonshow from '~/vue_shared/directives/autofocusonshow';
import { i18n, companySizes, COUNTRIES_WITH_STATES_ALLOWED } from '../constants';

export default {
  name: 'HandRaiseLeadButton',
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlFormTextarea,
    GlModal,
  },
  directives: {
    GlModal: GlModalDirective,
    autofocusonshow,
  },
  mixins: [Tracking.mixin()],
  inject: ['user'],
  data() {
    return {
      isLoading: false,
      firstName: this.user.firstName,
      lastName: this.user.lastName,
      companyName: this.user.companyName,
      companySize: null,
      phoneNumber: '',
      country: null,
      state: null,
      countries: [],
      states: [],
      comment: '',
    };
  },
  apollo: {
    countries: {
      query: countriesQuery,
    },
    states: {
      query: statesQuery,
      skip() {
        return !this.country;
      },
      variables() {
        return {
          countryId: this.country,
        };
      },
    },
  },
  computed: {
    modalHeaderText() {
      return sprintf(this.$options.i18n.modalHeaderText, {
        userName: this.user.userName,
      });
    },
    mustEnterState() {
      return COUNTRIES_WITH_STATES_ALLOWED.includes(this.country);
    },
    canSubmit() {
      return (
        this.firstName &&
        this.lastName &&
        this.companyName &&
        this.companySize &&
        this.phoneNumber &&
        this.country &&
        (this.mustEnterState ? this.state : true)
      );
    },
    actionPrimary() {
      return {
        text: this.$options.i18n.modalPrimary,
        attributes: [{ variant: 'success' }, { disabled: !this.canSubmit }],
      };
    },
    actionCancel() {
      return {
        text: this.$options.i18n.modalCancel,
      };
    },
    tracking() {
      return {
        label: 'hand_raise_lead_form',
      };
    },
    showState() {
      return !this.$apollo.loading.states && this.states && this.country && this.mustEnterState;
    },
    companySizeOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.companySizeSelectPrompt,
          id: null,
        },
        ...companySizes,
      ];
    },
    countryOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.countrySelectPrompt,
          id: null,
        },
        ...this.countries,
      ];
    },
    stateOptionsWithDefault() {
      return [
        {
          name: this.$options.i18n.stateSelectPrompt,
          id: null,
        },
        ...this.states,
      ];
    },
    formParams() {
      return {
        namespaceId: Number(this.user.namespaceId),
        firstName: this.firstName,
        lastName: this.lastName,
        companyName: this.companyName,
        companySize: this.companySize,
        phoneNumber: this.phoneNumber,
        country: this.country,
        state: this.mustEnterState ? this.state : null,
        comment: this.comment,
      };
    },
  },
  methods: {
    resetForm() {
      this.firstName = '';
      this.lastName = '';
      this.companyName = '';
      this.companySize = null;
      this.phoneNumber = '';
      this.country = null;
      this.state = null;
      this.comment = '';
    },
    async submit() {
      this.isLoading = true;

      await SubscriptionsApi.sendHandRaiseLead(this.formParams)
        .then(() => {
          createFlash({
            message: this.$options.i18n.handRaiseActionSuccess,
            type: FLASH_TYPES.SUCCESS,
          });
          this.resetForm();
          this.track('hand_raise_submit_form_succeeded');
        })
        .catch((error) => {
          createFlash({
            message: this.$options.i18n.handRaiseActionError,
            captureError: true,
            error,
          });
          this.track('hand_raise_submit_form_failed');
        })
        .finally(() => {
          this.isLoading = false;
        });
    },
  },
  i18n,
};
</script>

<template>
  <div>
    <gl-button
      v-gl-modal.hand-raise-lead
      :loading="isLoading"
      category="secondary"
      variant="success"
    >
      {{ $options.i18n.buttonText }}
    </gl-button>
    <gl-modal
      ref="modal"
      modal-id="hand-raise-lead"
      size="sm"
      :title="$options.i18n.modalTitle"
      :action-primary="actionPrimary"
      :action-cancel="actionCancel"
      @primary="submit"
      @cancel="track('hand_raise_form_canceled')"
      @change="track('hand_raise_form_viewed')"
    >
      {{ modalHeaderText }}
      <div class="combined d-flex gl-mt-5">
        <gl-form-group
          :label="$options.i18n.firstNameLabel"
          label-size="sm"
          label-for="firstName"
          class="mr-3 w-50"
        >
          <gl-form-input
            id="first-Name"
            v-model="firstName"
            type="text"
            class="form-control"
            data-testid="first-name"
          />
        </gl-form-group>
        <gl-form-group
          :label="$options.i18n.lastNameLabel"
          label-size="sm"
          label-for="lastName"
          class="w-50"
        >
          <gl-form-input
            id="last-Name"
            v-model="lastName"
            type="text"
            class="form-control"
            data-testid="last-name"
          />
        </gl-form-group>
      </div>
      <div class="combined d-flex">
        <gl-form-group
          :label="$options.i18n.companyNameLabel"
          label-size="sm"
          label-for="companyName"
          class="mr-3 w-50"
        >
          <gl-form-input
            id="company-name"
            v-model="companyName"
            type="text"
            class="form-control"
            data-testid="company-name"
          />
        </gl-form-group>
        <gl-form-group
          :label="$options.i18n.companySizeLabel"
          label-size="sm"
          label-for="companySize"
          class="w-50"
        >
          <gl-form-select
            v-model="companySize"
            v-autofocusonshow
            :options="companySizeOptionsWithDefault"
            value-field="id"
            text-field="name"
            data-testid="company-size"
          />
        </gl-form-group>
      </div>
      <gl-form-group
        :label="$options.i18n.phoneNumberLabel"
        label-size="sm"
        :description="$options.i18n.phoneNumberDescription"
        label-for="phoneNumber"
      >
        <gl-form-input
          id="phone-number"
          v-model="phoneNumber"
          type="text"
          class="form-control"
          data-testid="phone-number"
        />
      </gl-form-group>
      <gl-form-group
        v-if="!$apollo.loading.countries"
        :label="$options.i18n.countryLabel"
        label-size="sm"
        label-for="country"
      >
        <gl-form-select
          v-model="country"
          v-autofocusonshow
          :options="countryOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="country"
        />
      </gl-form-group>
      <gl-form-group
        v-if="showState"
        :label="$options.i18n.stateLabel"
        label-size="sm"
        label-for="state"
      >
        <gl-form-select
          v-model="state"
          v-autofocusonshow
          :options="stateOptionsWithDefault"
          value-field="id"
          text-field="name"
          data-testid="state"
        />
      </gl-form-group>

      <gl-form-group :label="$options.i18n.commentLabel" label-size="sm" label-for="comment">
        <gl-form-textarea v-model="comment" />
      </gl-form-group>

      <p class="gl-text-gray-400">
        {{ $options.i18n.modalFooterText }}
      </p>
    </gl-modal>
  </div>
</template>
