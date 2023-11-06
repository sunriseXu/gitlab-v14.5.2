import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import GroupSecurityDashboard from 'ee/security_dashboard/components/group/group_security_dashboard.vue';
import ReportNotConfiguredGroup from 'ee/security_dashboard/components/shared/empty_states/report_not_configured_group.vue';
import VulnerabilitySeverities from 'ee/security_dashboard/components/shared/project_security_status_chart.vue';
import SecurityDashboardLayout from 'ee/security_dashboard/components/shared/security_dashboard_layout.vue';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_chart.vue';
import vulnerabilityGradesQuery from 'ee/security_dashboard/graphql/queries/group_vulnerability_grades.query.graphql';
import vulnerabilityHistoryQuery from 'ee/security_dashboard/graphql/queries/group_vulnerability_history.query.graphql';
import { TEST_HOST } from 'helpers/test_constants';

jest.mock('ee/security_dashboard/graphql/queries/group_vulnerability_grades.query.graphql', () => ({
  mockGrades: true,
}));
jest.mock(
  'ee/security_dashboard/graphql/queries/group_vulnerability_history.query.graphql',
  () => ({
    mockHistory: true,
  }),
);

describe('Group Security Dashboard component', () => {
  let wrapper;

  const groupFullPath = `${TEST_HOST}/group/5`;

  const findSecurityChartsLayoutComponent = () => wrapper.find(SecurityDashboardLayout);
  const findLoadingIcon = () => wrapper.find(GlLoadingIcon);
  const findVulnerabilitiesOverTimeChart = () => wrapper.find(VulnerabilitiesOverTimeChart);
  const findVulnerabilitySeverities = () => wrapper.find(VulnerabilitySeverities);
  const findReportNotConfigured = () => wrapper.find(ReportNotConfiguredGroup);

  const createWrapper = ({ loading = false } = {}) => {
    wrapper = shallowMount(GroupSecurityDashboard, {
      mocks: {
        $apollo: {
          queries: {
            projects: {
              loading,
            },
          },
        },
      },
      provide: { groupFullPath },
      stubs: {
        SecurityDashboardLayout,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  it('renders the loading page', () => {
    createWrapper({ loading: true });

    const securityChartsLayout = findSecurityChartsLayoutComponent();
    const reportNotConfigured = findReportNotConfigured();
    const loadingIcon = findLoadingIcon();
    const vulnerabilitiesOverTimeChart = findVulnerabilitiesOverTimeChart();
    const vulnerabilitySeverities = findVulnerabilitySeverities();

    expect(securityChartsLayout.exists()).toBe(true);
    expect(reportNotConfigured.exists()).toBe(false);
    expect(loadingIcon.exists()).toBe(true);
    expect(vulnerabilitiesOverTimeChart.exists()).toBe(false);
    expect(vulnerabilitySeverities.exists()).toBe(false);
  });

  it('renders the empty state', () => {
    createWrapper();

    const securityChartsLayout = findSecurityChartsLayoutComponent();
    const reportNotConfigured = findReportNotConfigured();
    const loadingIcon = findLoadingIcon();
    const vulnerabilitiesOverTimeChart = findVulnerabilitiesOverTimeChart();
    const vulnerabilitySeverities = findVulnerabilitySeverities();

    expect(securityChartsLayout.exists()).toBe(true);
    expect(reportNotConfigured.exists()).toBe(true);
    expect(loadingIcon.exists()).toBe(false);
    expect(vulnerabilitiesOverTimeChart.exists()).toBe(false);
    expect(vulnerabilitySeverities.exists()).toBe(false);
  });

  it('renders the default page', async () => {
    createWrapper();
    wrapper.setData({ projects: [{ name: 'project1' }] });
    await wrapper.vm.$nextTick();

    const securityChartsLayout = findSecurityChartsLayoutComponent();
    const reportNotConfigured = findReportNotConfigured();
    const loadingIcon = findLoadingIcon();
    const vulnerabilitiesOverTimeChart = findVulnerabilitiesOverTimeChart();
    const vulnerabilitySeverities = findVulnerabilitySeverities();

    expect(securityChartsLayout.exists()).toBe(true);
    expect(reportNotConfigured.exists()).toBe(false);
    expect(loadingIcon.exists()).toBe(false);
    expect(vulnerabilitiesOverTimeChart.exists()).toBe(true);
    expect(vulnerabilitiesOverTimeChart.props()).toEqual({ query: vulnerabilityHistoryQuery });
    expect(vulnerabilitySeverities.exists()).toBe(true);
    expect(vulnerabilitySeverities.props()).toEqual({
      query: vulnerabilityGradesQuery,
      helpPagePath: '',
    });
  });
});
