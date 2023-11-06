import { GlSprintf } from '@gitlab/ui';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import ModalRuleRemove from 'ee/approvals/components/modal_rule_remove.vue';
import { stubComponent } from 'helpers/stub_component';
import GlModalVuex from '~/vue_shared/components/gl_modal_vuex.vue';

const MODAL_MODULE = 'deleteModal';
const TEST_MODAL_ID = 'test-delete-modal-id';
const TEST_RULE = {
  id: 7,
  name: 'Lorem',
  approvers: Array(5)
    .fill(1)
    .map((x, id) => ({ id })),
};
const SINGLE_APPROVER = {
  ...TEST_RULE,
  approvers: [{ id: 1 }],
};

const localVue = createLocalVue();
localVue.use(Vuex);

describe('Approvals ModalRuleRemove', () => {
  let wrapper;
  let actions;
  let deleteModalState;

  const findModal = () => wrapper.findComponent(GlModalVuex);

  const factory = (options = {}) => {
    const store = new Vuex.Store({
      actions,
      modules: {
        [MODAL_MODULE]: {
          namespaced: true,
          state: deleteModalState,
        },
      },
    });

    const propsData = {
      modalId: TEST_MODAL_ID,
      ...options.propsData,
    };

    wrapper = shallowMount(ModalRuleRemove, {
      ...options,
      localVue,
      store,
      propsData,
      stubs: {
        GlModalVuex: stubComponent(GlModalVuex, {
          props: ['modalModule', 'modalId', 'actionPrimary', 'actionCancel'],
        }),
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    deleteModalState = {
      data: TEST_RULE,
    };
    actions = {
      deleteRule: jest.fn(),
    };
  });

  it('renders modal', () => {
    factory();

    const modal = findModal();

    expect(modal.exists()).toBe(true);
    expect(modal.props()).toEqual(
      expect.objectContaining({
        modalModule: MODAL_MODULE,
        modalId: TEST_MODAL_ID,
        actionPrimary: {
          text: 'Remove approvers',
          attributes: [{ variant: 'danger' }],
        },
        actionCancel: { text: 'Cancel' },
      }),
    );
  });

  it.each`
    type                    | rule
    ${'multiple approvers'} | ${TEST_RULE}
    ${'singular approver'}  | ${SINGLE_APPROVER}
  `('matches the snapshot for $type', ({ rule }) => {
    deleteModalState.data = rule;
    factory();

    expect(findModal().element).toMatchSnapshot();
  });

  it('calls deleteRule when the modal is submitted', () => {
    deleteModalState.data = TEST_RULE;
    factory();

    expect(actions.deleteRule).not.toHaveBeenCalled();

    const modal = findModal();
    modal.vm.$emit('ok', new Event('submit'));

    expect(actions.deleteRule).toHaveBeenCalledWith(expect.anything(), TEST_RULE.id);
  });
});
