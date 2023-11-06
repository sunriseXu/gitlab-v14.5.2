import { GlModal, GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { cloneDeep } from 'lodash';
import VueApollo from 'vue-apollo';
import DeleteEscalationPolicyModal, {
  i18n,
} from 'ee/escalation_policies/components/delete_escalation_policy_modal.vue';
import { deleteEscalationPolicyModalId } from 'ee/escalation_policies/constants';
import destroyEscalationPolicyMutation from 'ee/escalation_policies/graphql/mutations/destroy_escalatiion_policy.mutation.graphql';
import getEscalationPoliciesQuery from 'ee/escalation_policies/graphql/queries/get_escalation_policies.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  destroyPolicyResponse,
  destroyPolicyResponseWithErrors,
  getEscalationPoliciesQueryResponse,
} from './mocks/apollo_mock';
import mockPolicies from './mocks/mockPolicies.json';

const projectPath = 'group/project';
const mutate = jest.fn();
const mockHideModal = jest.fn();
const localVue = createLocalVue();

describe('DeleteEscalationPolicyModal', () => {
  let wrapper;
  let fakeApollo;
  let destroyPolicyHandler;

  const escalationPolicy = cloneDeep(mockPolicies[0]);
  const cachedPolicy =
    getEscalationPoliciesQueryResponse.data.project.incidentManagementEscalationPolicies.nodes[0];

  const createComponent = ({ data = {}, props = {} } = {}) => {
    wrapper = shallowMount(DeleteEscalationPolicyModal, {
      data() {
        return {
          ...data,
        };
      },
      propsData: {
        modalId: deleteEscalationPolicyModalId,
        escalationPolicy,
        ...props,
      },
      provide: {
        projectPath,
      },
      mocks: {
        $apollo: {
          mutate,
        },
      },
      stubs: { GlSprintf },
    });
    wrapper.vm.$refs.deleteEscalationPolicyModal.hide = mockHideModal;
  };

  function createComponentWithApollo({
    destroyHandler = jest.fn().mockResolvedValue(destroyPolicyResponse),
  } = {}) {
    localVue.use(VueApollo);
    destroyPolicyHandler = destroyHandler;

    const requestHandlers = [
      [getEscalationPoliciesQuery, jest.fn().mockResolvedValue(getEscalationPoliciesQueryResponse)],
      [destroyEscalationPolicyMutation, destroyPolicyHandler],
    ];

    fakeApollo = createMockApollo(requestHandlers);

    fakeApollo.clients.defaultClient.cache.writeQuery({
      query: getEscalationPoliciesQuery,
      variables: {
        projectPath: 'group/project',
      },
      data: getEscalationPoliciesQueryResponse.data,
    });

    wrapper = shallowMount(DeleteEscalationPolicyModal, {
      localVue,
      apolloProvider: fakeApollo,
      propsData: {
        escalationPolicy: cachedPolicy,
        modalId: deleteEscalationPolicyModalId,
      },
      provide: {
        projectPath,
      },
      stubs: {
        GlSprintf,
      },
    });
  }

  const findModal = () => wrapper.findComponent(GlModal);
  const findAlert = () => wrapper.findComponent(GlAlert);

  async function awaitApolloDomMock() {
    await wrapper.vm.$nextTick(); // kick off the DOM update
    await jest.runOnlyPendingTimers(); // kick off the mocked GQL stuff (promises)
    await wrapper.vm.$nextTick(); // kick off the DOM update
  }

  async function deleteEscalationPolicy(localWrapper) {
    localWrapper.findComponent(GlModal).vm.$emit('primary', { preventDefault: jest.fn() });
  }

  afterEach(() => {
    wrapper.destroy();
  });

  describe('layout', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets correct `modalId`', () => {
      expect(findModal().props('modalId')).toBe(deleteEscalationPolicyModalId);
    });

    it('renders the confirmation message with provided policy name', () => {
      expect(wrapper.text()).toBe(
        i18n.deleteEscalationPolicyMessage.replace('%{escalationPolicy}', escalationPolicy.name),
      );
    });
  });

  describe('actions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('makes a request to delete an escalation policy on delete confirmation', () => {
      mutate.mockResolvedValueOnce({});
      deleteEscalationPolicy(wrapper);
      expect(mutate).toHaveBeenCalledWith({
        mutation: destroyEscalationPolicyMutation,
        update: expect.any(Function),
        variables: { input: { id: escalationPolicy.id } },
      });
    });

    it('hides the modal on successful escalation policy deletion', async () => {
      mutate.mockResolvedValueOnce({ data: { escalationPolicyDestroy: { errors: [] } } });
      findModal().vm.$emit('primary', { preventDefault: jest.fn() });
      await waitForPromises();
      expect(mockHideModal).toHaveBeenCalled();
    });

    it("doesn't hide the modal and shows an error alert on deletion fail", async () => {
      const error = 'some error';
      mutate.mockResolvedValueOnce({ data: { escalationPolicyDestroy: { errors: [error] } } });
      deleteEscalationPolicy(wrapper);
      await waitForPromises();
      const alert = findAlert();
      expect(mockHideModal).not.toHaveBeenCalled();
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain(error);
    });
  });

  describe('with mocked Apollo client', () => {
    it('has the name of the escalation policy to delete based on `getEscalationPoliciesQuery` response', async () => {
      createComponentWithApollo();

      await jest.runOnlyPendingTimers();
      await wrapper.vm.$nextTick();

      expect(findModal().text()).toContain(cachedPolicy.name);
    });

    it('calls a mutation with correct parameters to a policy', async () => {
      createComponentWithApollo();

      await deleteEscalationPolicy(wrapper);

      expect(destroyPolicyHandler).toHaveBeenCalledWith({
        input: { id: cachedPolicy.id },
      });
    });

    it('displays alert if mutation had a recoverable error', async () => {
      createComponentWithApollo({
        destroyHandler: jest.fn().mockResolvedValue(destroyPolicyResponseWithErrors),
      });

      await deleteEscalationPolicy(wrapper);
      await awaitApolloDomMock();

      const alert = findAlert();
      expect(alert.exists()).toBe(true);
      expect(alert.text()).toContain(
        destroyPolicyResponseWithErrors.data.escalationPolicyDestroy.errors[0],
      );
    });
  });
});
