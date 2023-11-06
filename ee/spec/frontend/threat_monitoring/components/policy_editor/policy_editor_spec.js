import { GlAlert, GlFormSelect } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/threat_monitoring/components/constants';
import EnvironmentPicker from 'ee/threat_monitoring/components/environment_picker.vue';
import NetworkPolicyEditor from 'ee/threat_monitoring/components/policy_editor/network_policy/network_policy_editor.vue';
import PolicyEditor from 'ee/threat_monitoring/components/policy_editor/policy_editor.vue';
import ScanExecutionPolicyEditor from 'ee/threat_monitoring/components/policy_editor/scan_execution_policy/scan_execution_policy_editor.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/threat_monitoring/constants';
import { mockDastScanExecutionObject, mockL3Manifest } from '../../mocks/mock_data';

describe('PolicyEditor component', () => {
  let wrapper;

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEnvironmentPicker = () => wrapper.findComponent(EnvironmentPicker);
  const findFormSelect = () => wrapper.findComponent(GlFormSelect);
  const findNeworkPolicyEditor = () => wrapper.findComponent(NetworkPolicyEditor);
  const findScanExecutionPolicyEditor = () => wrapper.findComponent(ScanExecutionPolicyEditor);

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(PolicyEditor, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        policyType: undefined,
        ...provide,
      },
      stubs: { GlFormSelect },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('default', () => {
    beforeEach(factory);

    it.each`
      component               | status                | findComponent            | state
      ${'environment picker'} | ${'does display'}     | ${findEnvironmentPicker} | ${true}
      ${'alert'}              | ${'does not display'} | ${findAlert}             | ${false}
    `('$status the $component', ({ findComponent, state }) => {
      expect(findComponent().exists()).toBe(state);
    });

    it('renders the network policy editor component', () => {
      expect(findNeworkPolicyEditor().props('existingPolicy')).toBe(null);
    });

    it('renders the form select', () => {
      const formSelect = findFormSelect();
      expect(formSelect.attributes('value')).toBe(POLICY_TYPE_COMPONENT_OPTIONS.container.value);
      expect(formSelect.attributes('disabled')).toBe(undefined);
    });

    it('shows an alert when "error" is emitted from the component', async () => {
      const errorMessage = 'test';
      findNeworkPolicyEditor().vm.$emit('error', errorMessage);
      await wrapper.vm.$nextTick();
      const alert = findAlert();
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toBe(errorMessage);
    });

    it.each`
      policyType         | option                                         | findComponent
      ${'container'}     | ${POLICY_TYPE_COMPONENT_OPTIONS.container}     | ${findNeworkPolicyEditor}
      ${'scanExecution'} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution} | ${findScanExecutionPolicyEditor}
    `(
      'renders the policy editor of type $policyType when selected',
      async ({ findComponent, option, policyType }) => {
        const formSelect = findFormSelect();
        formSelect.vm.$emit('change', policyType);
        await wrapper.vm.$nextTick();
        const component = findComponent();
        expect(formSelect.attributes('value')).toBe(option.value);
        expect(component.exists()).toBe(true);
        expect(component.props('isEditing')).toBe(false);
      },
    );
  });

  describe('when an existing policy is present', () => {
    it.each`
      policyType                 | option                                         | existingPolicy                                                              | findComponent
      ${'container_policy'}      | ${POLICY_TYPE_COMPONENT_OPTIONS.container}     | ${{ manifest: mockL3Manifest, creation_timestamp: '2020-04-14T00:08:30Z' }} | ${findNeworkPolicyEditor}
      ${'scan_execution_policy'} | ${POLICY_TYPE_COMPONENT_OPTIONS.scanExecution} | ${mockDastScanExecutionObject}                                              | ${findScanExecutionPolicyEditor}
    `(
      'renders the disabled form select for existing policy of type $policyType',
      async ({ existingPolicy, findComponent, option, policyType }) => {
        factory({ propsData: { existingPolicy }, provide: { policyType } });
        await wrapper.vm.$nextTick();
        const formSelect = findFormSelect();
        expect(formSelect.exists()).toBe(true);
        expect(formSelect.attributes('value')).toBe(option.value);
        expect(formSelect.attributes('disabled')).toBe('true');
        const component = findComponent();
        expect(component.exists()).toBe(true);
        expect(component.props('isEditing')).toBe(true);
      },
    );
  });
});
