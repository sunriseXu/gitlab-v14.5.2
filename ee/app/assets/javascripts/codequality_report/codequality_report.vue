<script>
import { mapActions, mapState, mapGetters } from 'vuex';
import { componentNames } from 'ee/reports/components/issue_body';
import reportsMixin from 'ee/vue_shared/security_reports/mixins/reports_mixin';
import { n__, s__, sprintf } from '~/locale';
import ReportSection from '~/reports/components/report_section.vue';
import PaginationLinks from '~/vue_shared/components/pagination_links.vue';

export default {
  components: {
    ReportSection,
    PaginationLinks,
  },
  mixins: [reportsMixin],
  componentNames,
  computed: {
    ...mapState(['isLoadingCodequality', 'loadingCodequalityFailed', 'pageInfo']),
    ...mapGetters(['codequalityIssues', 'codequalityIssueTotal']),
    hasCodequalityIssues() {
      return this.codequalityIssueTotal > 0;
    },
    codequalityText() {
      const text = [];
      const { codequalityIssueTotal } = this;

      if (codequalityIssueTotal === 0) {
        return s__('ciReport|No code quality issues found');
      } else if (codequalityIssueTotal > 0) {
        return sprintf(s__('ciReport|Found %{issuesWithCount}'), {
          issuesWithCount: n__(
            '%d code quality issue',
            '%d code quality issues',
            codequalityIssueTotal,
          ),
        });
      }

      return text.join('');
    },
    codequalityStatus() {
      return this.checkReportStatus(this.isLoadingCodequality, this.loadingCodequalityFailed);
    },
  },
  i18n: {
    subHeading: s__('ciReport|This report contains all Code Quality issues in the source branch.'),
  },
  methods: {
    ...mapActions(['setPage']),
    translateText(type) {
      return {
        error: sprintf(s__('ciReport|Failed to load %{reportName} report'), {
          reportName: type,
        }),
        loading: sprintf(s__('ciReport|Loading %{reportName} report'), {
          reportName: type,
        }),
      };
    },
  },
};
</script>

<template>
  <div>
    <report-section
      always-open
      :status="codequalityStatus"
      :loading-text="translateText('Code Quality').loading"
      :error-text="translateText('Code Quality').error"
      :success-text="codequalityText"
      :unresolved-issues="codequalityIssues"
      :resolved-issues="[]"
      :has-issues="hasCodequalityIssues"
      :component="$options.componentNames.CodequalityIssueBody"
      class="codequality-report"
    >
      <template v-if="hasCodequalityIssues" #sub-heading>{{ $options.i18n.subHeading }}</template>
    </report-section>
    <pagination-links
      :change="setPage"
      :page-info="pageInfo"
      class="d-flex justify-content-center gl-mt-3"
    />
  </div>
</template>
