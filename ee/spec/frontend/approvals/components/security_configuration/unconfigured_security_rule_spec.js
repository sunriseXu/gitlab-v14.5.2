import { GlSprintf, GlButton } from '@gitlab/ui';
import { mount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import UnconfiguredSecurityRule from 'ee/approvals/components/security_configuration/unconfigured_security_rule.vue';
import {
  LICENSE_CHECK_NAME,
  VULNERABILITY_CHECK_NAME,
  COVERAGE_CHECK_NAME,
} from 'ee/approvals/constants';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('UnconfiguredSecurityRule component', () => {
  let wrapper;
  let description;

  const findDescription = () => wrapper.find(GlSprintf);
  const findButton = () => wrapper.find(GlButton);

  const vulnCheckRule = {
    name: VULNERABILITY_CHECK_NAME,
    description: 'vuln-check description with enable button',
    docsPath: 'docs/vuln-check',
  };

  const licenseCheckRule = {
    name: LICENSE_CHECK_NAME,
    description: 'license-check description with enable button',
    docsPath: 'docs/license-check',
  };

  const coverageCheckRule = {
    name: COVERAGE_CHECK_NAME,
    description: 'coverage-check description with enable button',
    docsPath: 'docs/coverage-check',
  };

  const createWrapper = (props = {}, options = {}) => {
    wrapper = mount(UnconfiguredSecurityRule, {
      localVue,
      propsData: {
        ...props,
      },
      ...options,
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe.each`
    rule                 | ruleName                  | descriptionText
    ${licenseCheckRule}  | ${licenseCheckRule.name}  | ${licenseCheckRule.description}
    ${vulnCheckRule}     | ${vulnCheckRule.name}     | ${vulnCheckRule.description}
    ${coverageCheckRule} | ${coverageCheckRule.name} | ${coverageCheckRule.description}
  `('with $ruleName', ({ rule, descriptionText }) => {
    beforeEach(() => {
      createWrapper({
        rule: { ...rule },
      });
      description = findDescription();
    });

    it('should render the row with the enable decription and enable button', () => {
      expect(description.exists()).toBe(true);
      expect(description.text()).toBe(descriptionText);
      expect(findButton().exists()).toBe(true);
    });

    it('should emit the "enable" event when the button is clicked', () => {
      findButton().trigger('click');
      expect(wrapper.emitted('enable')).toEqual([[]]);
    });
  });
});
