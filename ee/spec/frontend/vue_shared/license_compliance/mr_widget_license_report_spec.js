import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import LicenseManagement from 'ee/vue_shared/license_compliance/mr_widget_license_report.vue';
import { stubComponent } from 'helpers/stub_component';
import { TEST_HOST } from 'spec/test_constants';
import ReportItem from '~/reports/components/report_item.vue';
import ReportSection from '~/reports/components/report_section.vue';
import { LOADING, ERROR, SUCCESS } from '~/reports/constants';
import {
  approvedLicense,
  blacklistedLicense,
  licenseReport as licenseReportMock,
  generateReportGroup,
} from './mock_data';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('License Report MR Widget', () => {
  const apiUrl = `${TEST_HOST}/license_management`;
  const licenseComplianceDocsPath = `${TEST_HOST}/path/to/security/approvals/help`;
  let wrapper;

  const defaultState = {
    managedLicenses: [approvedLicense, blacklistedLicense],
    currentLicenseInModal: licenseReportMock[0],
    isLoadingManagedLicenses: true,
  };

  const defaultGetters = {
    isLoading() {
      return false;
    },
    licenseReport() {
      return licenseReportMock;
    },
    licenseSummaryText() {
      return 'FOO';
    },
    reportContainsBlacklistedLicense() {
      return false;
    },
    licenseReportGroups() {
      return [];
    },
  };

  const defaultProps = {
    loadingText: 'LOADING',
    errorText: 'ERROR',
    licensesApiPath: `${TEST_HOST}/parsed_license_report.json`,
    approvalsApiPath: `${TEST_HOST}/path/to/approvals`,
    canManageLicenses: true,
    licenseManagementSettingsPath: `${TEST_HOST}/lm_settings`,
    fullReportPath: `${TEST_HOST}/path/to/the/full/report`,
    apiUrl,
    licenseComplianceDocsPath,
  };

  const defaultActions = {
    setAPISettings: () => {},
    fetchManagedLicenses: () => {},
    fetchParsedLicenseReport: () => {},
    fetchLicenseCheckApprovalRule: () => {},
  };

  const mountComponent = ({
    props = defaultProps,
    getters = defaultGetters,
    state = defaultState,
    actions = defaultActions,
    stubs = { ReportSection },
  } = {}) => {
    const store = new Vuex.Store({
      modules: {
        licenseManagement: {
          namespaced: true,
          state,
          getters,
          actions,
        },
      },
    });
    wrapper = shallowMount(LicenseManagement, {
      localVue,
      propsData: props,
      store,
      stubs,
    });
  };

  const findAllReportItems = () => wrapper.findAll(ReportItem);

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('computed', () => {
    describe('hasLicenseReportIssues', () => {
      it('should be false, if the report is empty', () => {
        const getters = {
          ...defaultGetters,
          licenseReport() {
            return [];
          },
        };
        mountComponent({ getters });

        expect(wrapper.vm.hasLicenseReportIssues).toBe(false);
      });

      it('should be true, if the report is not empty', () => {
        mountComponent();

        expect(wrapper.vm.hasLicenseReportIssues).toBe(true);
      });
    });

    describe('licenseReportStatus', () => {
      it('should be `LOADING`, if the report is loading', () => {
        const getters = {
          ...defaultGetters,
          isLoading() {
            return true;
          },
        };
        mountComponent({ getters });

        expect(wrapper.vm.licenseReportStatus).toBe(LOADING);
      });

      it('should be `ERROR`, if the report is has an error', () => {
        const state = { ...defaultState, loadLicenseReportError: new Error('test') };
        mountComponent({ state });

        expect(wrapper.vm.licenseReportStatus).toBe(ERROR);
      });

      it('should be `SUCCESS`, if the report is successful', () => {
        mountComponent();

        expect(wrapper.vm.licenseReportStatus).toBe(SUCCESS);
      });
    });

    describe('showActionButtons', () => {
      const { fullReportPath, licenseManagementSettingsPath, ...otherProps } = defaultProps;

      it('should be true if fullReportPath AND licenseManagementSettingsPath prop are provided', () => {
        const props = { ...otherProps, fullReportPath, licenseManagementSettingsPath };
        mountComponent({ props });

        expect(wrapper.vm.showActionButtons).toBe(true);
      });

      it('should be true if only licenseManagementSettingsPath is provided', () => {
        const props = { ...otherProps, fullReportPath: null, licenseManagementSettingsPath };
        mountComponent({ props });

        expect(wrapper.vm.showActionButtons).toBe(true);
      });

      it('should be true if only fullReportPath is provided', () => {
        const props = {
          ...otherProps,
          fullReportPath,
          licenseManagementSettingsPath: null,
        };
        mountComponent({ props });

        expect(wrapper.vm.showActionButtons).toBe(true);
      });

      it('should be false if fullReportPath and licenseManagementSettingsPath prop are not provided', () => {
        const props = {
          ...otherProps,
          fullReportPath: null,
          licenseManagementSettingsPath: null,
        };
        mountComponent({ props });

        expect(wrapper.vm.showActionButtons).toBe(false);
      });
    });
  });

  describe('report section', () => {
    describe('report body', () => {
      it('should render correctly', () => {
        const mockReportGroups = [generateReportGroup()];

        mountComponent({
          getters: {
            ...defaultGetters,
            licenseReportGroups() {
              return mockReportGroups;
            },
          },
        });

        expect(wrapper.find({ ref: 'reportSectionBody' }).element).toMatchSnapshot();
      });

      it.each`
        givenStatuses                       | expectedNumberOfReportHeadings
        ${[]}                               | ${0}
        ${['failed', 'neutral']}            | ${2}
        ${['failed', 'neutral', 'success']} | ${3}
      `(
        'given reports for: $givenStatuses it has $expectedNumberOfReportHeadings report headings',
        ({ givenStatuses, expectedNumberOfReportHeadings }) => {
          const mockReportGroups = givenStatuses.map((status) => generateReportGroup({ status }));

          mountComponent({
            getters: {
              ...defaultGetters,
              licenseReportGroups() {
                return mockReportGroups;
              },
            },
          });

          expect(wrapper.findAll({ ref: 'reportHeading' })).toHaveLength(
            expectedNumberOfReportHeadings,
          );
        },
      );

      it.each([0, 1, 2])(
        'should include %d report items when section has that many licenses',
        (numberOfLicenses) => {
          const mockReportGroups = [
            generateReportGroup({
              numberOfLicenses,
            }),
          ];

          mountComponent({
            getters: {
              ...defaultGetters,
              licenseReportGroups() {
                return mockReportGroups;
              },
            },
          });

          expect(findAllReportItems()).toHaveLength(numberOfLicenses);
        },
      );

      it('renders the report items in the correct order', () => {
        const mockReportGroups = [
          generateReportGroup({ status: 'failed', numberOfLicenses: 1 }),
          generateReportGroup({ status: 'neutral', numberOfLicenses: 1 }),
          generateReportGroup({ status: 'success', numberOfLicenses: 1 }),
        ];

        mountComponent({
          getters: {
            ...defaultGetters,
            licenseReportGroups() {
              return mockReportGroups;
            },
          },
        });

        const allReportItems = findAllReportItems();
        mockReportGroups.forEach((group, index) => {
          expect(allReportItems.at(index).props('status')).toBe(group.status);
        });
      });
    });
  });

  describe('`View full report` button', () => {
    const selector = '[data-testid="full-report-button"]';

    it('should be rendered when fullReportPath prop is provided', () => {
      mountComponent();

      const linkEl = wrapper.find(selector);

      expect(linkEl.exists()).toBe(true);
      expect(linkEl.attributes('href')).toEqual(defaultProps.fullReportPath);
      expect(linkEl.text()).toBe('View full report');
    });

    it('should not be rendered when fullReportPath prop is not provided', () => {
      const props = { ...defaultProps, fullReportPath: null };
      mountComponent({ props });

      expect(wrapper.find(selector).exists()).toBe(false);
    });
  });

  describe('`Manage licenses` button', () => {
    const selector = '[data-testid="manage-licenses-button"]';

    it('should be rendered when licenseManagementSettingsPath prop is provided', () => {
      mountComponent();

      const linkEl = wrapper.find(selector);

      expect(linkEl.exists()).toBe(true);
      expect(linkEl.attributes('href')).toEqual(defaultProps.licenseManagementSettingsPath);
      expect(linkEl.text()).toBe('Manage licenses');
    });

    it('should not be rendered when licenseManagementSettingsPath prop is not provided', () => {
      const props = { ...defaultProps, licenseManagementSettingsPath: null };
      mountComponent({ props });

      expect(wrapper.find(selector).exists()).toBe(false);
    });

    it('has gl-mr-3 class when isCollapsbile is true', () => {
      mountComponent({
        stubs: {
          ReportSection: stubComponent(ReportSection, {
            template: `
              <div>
                <slot name="action-buttons" :is-collapsible="true" />
              </div>
            `,
          }),
        },
      });
      expect(wrapper.find(selector).classes()).toContain('gl-mr-3');
    });

    it('does not have gl-mr-3 class when isCollapsbile is false', () => {
      mountComponent({
        stubs: {
          ReportSection: stubComponent(ReportSection, {
            template: `
              <div>
                <slot name="action-buttons" :is-collapsible="false" />
              </div>
            `,
          }),
        },
      });
      expect(wrapper.find(selector).classes()).not.toContain('gl-mr-3');
    });
  });

  it('should init store after mount', () => {
    const actions = {
      setAPISettings: jest.fn(),
      fetchParsedLicenseReport: jest.fn(),
      fetchLicenseCheckApprovalRule: jest.fn(),
    };
    mountComponent({ actions });

    expect(actions.setAPISettings).toHaveBeenCalledWith(expect.any(Object), {
      apiUrlManageLicenses: apiUrl,
      licensesApiPath: defaultProps.licensesApiPath,
      approvalsApiPath: defaultProps.approvalsApiPath,
      canManageLicenses: true,
    });

    expect(actions.fetchParsedLicenseReport).toHaveBeenCalledWith(expect.any(Object), undefined);

    expect(actions.fetchLicenseCheckApprovalRule).toHaveBeenCalledWith(
      expect.any(Object),
      undefined,
    );
  });

  describe('approval status', () => {
    const findLicenseComplianceHelpLink = () =>
      wrapper.find('[data-testid="security-approval-help-link"]');

    it('does not show a link to security approval help page if report does not contain blacklisted licenses', () => {
      mountComponent();

      expect(findLicenseComplianceHelpLink().exists()).toBe(false);
    });

    it('shows a link to security approval help page if report contains blacklisted licenses', () => {
      const getters = {
        ...defaultGetters,
        reportContainsBlacklistedLicense() {
          return true;
        },
      };
      mountComponent({
        getters,
      });

      const licenseComplianceHelpLink = findLicenseComplianceHelpLink();

      expect(findLicenseComplianceHelpLink().exists()).toBe(true);
      expect(licenseComplianceHelpLink.attributes('href')).toBe(licenseComplianceDocsPath);
    });
  });
});
