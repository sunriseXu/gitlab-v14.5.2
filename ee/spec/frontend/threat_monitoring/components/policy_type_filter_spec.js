import { POLICY_TYPE_OPTIONS } from 'ee/threat_monitoring/components/constants';
import PolicyTypeFilter from 'ee/threat_monitoring/components/policy_type_filter.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('PolicyTypeFilter component', () => {
  let wrapper;

  const createWrapper = (value = '') => {
    wrapper = mountExtended(PolicyTypeFilter, {
      propsData: {
        value,
      },
    });
  };

  const findToggle = () => wrapper.find('button[aria-haspopup="true"]');

  afterEach(() => {
    wrapper.destroy();
  });

  it.each`
    value                                                   | expectedToggleText
    ${POLICY_TYPE_OPTIONS.ALL.value}                        | ${POLICY_TYPE_OPTIONS.ALL.text}
    ${POLICY_TYPE_OPTIONS.POLICY_TYPE_NETWORK.value}        | ${POLICY_TYPE_OPTIONS.POLICY_TYPE_NETWORK.text}
    ${POLICY_TYPE_OPTIONS.POLICY_TYPE_SCAN_EXECUTION.value} | ${POLICY_TYPE_OPTIONS.POLICY_TYPE_SCAN_EXECUTION.text}
  `('selects the correct option when value is "$value"', ({ value, expectedToggleText }) => {
    createWrapper(value);

    expect(findToggle().text()).toBe(expectedToggleText);
  });

  it('emits an event when an option is selected', () => {
    createWrapper();

    expect(wrapper.emitted('input')).toBeUndefined();

    wrapper
      .findByTestId(`policy-type-${POLICY_TYPE_OPTIONS.POLICY_TYPE_NETWORK.value}-option`)
      .trigger('click');

    expect(wrapper.emitted('input')).toEqual([[POLICY_TYPE_OPTIONS.POLICY_TYPE_NETWORK.value]]);
  });
});
