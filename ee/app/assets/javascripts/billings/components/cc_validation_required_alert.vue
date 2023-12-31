<script>
import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import AccountVerificationModal from './account_verification_modal.vue';

const i18n = {
  successAlert: {
    title: s__('Billings|User successfully validated'),
    text: s__(
      'Billings|Your user account has been successfully validated. You can now use free pipeline minutes.',
    ),
  },
  dangerAlert: {
    title: s__('Billings|User validation required'),
    text: s__(`Billings|To use free pipeline minutes on shared runners, you’ll need to validate your account with a credit or debit card. If you prefer not to provide one, you can run pipelines by bringing your own runners and disabling shared runners for your project.
    This is required to discourage and reduce abuse on GitLab infrastructure.
    %{strongStart}GitLab will not charge or store your card, it will only be used for validation.%{strongEnd} %{linkStart}Learn more%{linkEnd}.`),
    primaryButtonText: s__('Billings|Validate account'),
  },
  pipelineVerificationLink: 'https://about.gitlab.com/blog/2021/05/17/prevent-crypto-mining-abuse/',
};

export default {
  name: 'CreditCardValidationRequiredAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    AccountVerificationModal,
  },
  props: {
    customMessage: {
      type: String,
      default: null,
      required: false,
    },
  },
  data() {
    return {
      shouldRenderSuccess: false,
    };
  },
  computed: {
    iframeUrl() {
      return gon.payment_form_url;
    },
    allowedOrigin() {
      return gon.subscriptions_url;
    },
  },
  methods: {
    showModal() {
      this.$refs.modal.show();
    },
    handleSuccessfulVerification() {
      this.$refs.modal.hide();
      this.shouldRenderSuccess = true;
      this.$emit('verifiedCreditCard');
    },
  },
  i18n,
};
</script>

<template>
  <div data-testid="creditCardValidationRequiredAlert">
    <gl-alert
      v-if="shouldRenderSuccess"
      variant="success"
      :title="$options.i18n.successAlert.title"
      :dismissible="false"
    >
      {{ $options.i18n.successAlert.text }}
    </gl-alert>
    <gl-alert
      v-else
      variant="danger"
      :title="$options.i18n.dangerAlert.title"
      :primary-button-text="$options.i18n.dangerAlert.primaryButtonText"
      @primaryAction="showModal"
      @dismiss="$emit('dismiss')"
    >
      <template v-if="customMessage">
        {{ customMessage }}
      </template>
      <gl-sprintf v-else :message="$options.i18n.dangerAlert.text">
        <template #strong="{ content }">
          <strong>{{ content }}</strong>
        </template>
        <template #link="{ content }">
          <gl-link :href="$options.i18n.pipelineVerificationLink">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <account-verification-modal
      ref="modal"
      :iframe-url="iframeUrl"
      :allowed-origin="allowedOrigin"
      @success="handleSuccessfulVerification"
    />
  </div>
</template>
