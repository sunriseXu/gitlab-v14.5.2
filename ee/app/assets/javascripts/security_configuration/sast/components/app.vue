<script>
import { GlAlert, GlLink, GlLoadingIcon, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import DismissibleFeedbackAlert from '~/vue_shared/components/dismissible_feedback_alert.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ConfigurationPageLayout from '../../components/configuration_page_layout.vue';
import sastCiConfigurationQuery from '../graphql/sast_ci_configuration.query.graphql';
import ConfigurationForm from './configuration_form.vue';

export default {
  components: {
    ConfigurationForm,
    ConfigurationPageLayout,
    DismissibleFeedbackAlert,
    GlAlert,
    GlLink,
    GlLoadingIcon,
    GlSprintf,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: {
    sastDocumentationPath: {
      from: 'sastDocumentationPath',
      default: '',
    },
    projectPath: {
      from: 'projectPath',
      default: '',
    },
  },
  apollo: {
    sastCiConfiguration: {
      query: sastCiConfigurationQuery,
      variables() {
        return {
          fullPath: this.projectPath,
        };
      },
      update({ project }) {
        return project?.sastCiConfiguration;
      },
      result({ loading }) {
        if (!loading && !this.sastCiConfiguration) {
          this.onError();
        }
      },
      error() {
        this.onError();
      },
    },
  },
  data() {
    return {
      sastCiConfiguration: null,
      hasLoadingError: false,
    };
  },
  methods: {
    onError() {
      this.hasLoadingError = true;
    },
  },
  i18n: {
    feedbackAlertMessage: __(`
      As we continue to build more features for SAST, we'd love your feedback
      on the SAST configuration feature in %{linkStart}this issue%{linkEnd}.`),
    helpText: s__(
      `SecurityConfiguration|Customize common SAST settings to suit your
      requirements. Configuration changes made here override those provided by
      GitLab and are excluded from updates. For details of more advanced
      configuration options, see the %{linkStart}GitLab SAST documentation%{linkEnd}.`,
    ),
    loadingErrorText: s__(
      `SecurityConfiguration|Could not retrieve configuration data. Please
      refresh the page, or try again later.`,
    ),
  },
  feedbackIssue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/225991',
};
</script>

<template>
  <configuration-page-layout>
    <template #alert>
      <dismissible-feedback-alert
        feature-name="sast"
        class="gl-mt-4"
        data-testid="configuration-page-alert"
      >
        <gl-sprintf :message="$options.i18n.feedbackAlertMessage">
          <template #link="{ content }">
            <gl-link :href="$options.feedbackIssue" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </dismissible-feedback-alert>
    </template>

    <template #heading> {{ s__('SecurityConfiguration|SAST Configuration') }} </template>
    <template #description>
      <gl-sprintf :message="$options.i18n.helpText">
        <template #link="{ content }">
          <gl-link :href="sastDocumentationPath" target="_blank" v-text="content" />
        </template>
      </gl-sprintf>
    </template>

    <gl-loading-icon v-if="$apollo.loading" size="lg" />

    <gl-alert
      v-else-if="hasLoadingError"
      variant="danger"
      :dismissible="false"
      data-testid="error-alert"
      >{{ $options.i18n.loadingErrorText }}</gl-alert
    >

    <configuration-form v-else :sast-ci-configuration="sastCiConfiguration" />
  </configuration-page-layout>
</template>
