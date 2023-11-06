import { GlFormInput } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { noop } from 'lodash';
import Vue from 'vue';
import Vuex from 'vuex';
import BoardSettingsWipLimit from 'ee_component/boards/components/board_settings_wip_limit.vue';
import waitForPromises from 'helpers/wait_for_promises';
import { mockLabelList } from 'jest/boards/mock_data';

Vue.use(Vuex);

describe('BoardSettingsWipLimit', () => {
  let wrapper;
  let storeActions;
  const listId = mockLabelList.id;
  const currentWipLimit = 1; // Needs to be other than null to trigger requests

  const clickEdit = () => wrapper.find('.js-edit-button').vm.$emit('click');
  const findRemoveWipLimit = () => wrapper.find('.js-remove-limit');
  const findWipLimit = () => wrapper.find('.js-wip-limit');
  const findInput = () => wrapper.find(GlFormInput);

  const createComponent = ({
    vuexState = { activeId: listId },
    actions = {},
    localState = {},
    props = { maxIssueCount: 0 },
  }) => {
    storeActions = actions;

    const store = new Vuex.Store({
      state: vuexState,
      actions: storeActions,
    });

    wrapper = shallowMount(BoardSettingsWipLimit, {
      propsData: props,
      store,
      data() {
        return localState;
      },
    });
  };

  const triggerBlur = (type) => {
    if (type === 'blur') {
      findInput().vm.$emit('blur');
    }

    if (type === 'enter') {
      findInput().trigger('keydown.enter');
    }
  };

  afterEach(() => {
    jest.restoreAllMocks();
    wrapper.destroy();
  });

  describe('when activeList is present', () => {
    describe('when activeListWipLimit is 0', () => {
      it('renders "None" in the block', () => {
        createComponent({
          vuexState: {
            activeId: listId,
          },
        });

        expect(findWipLimit().text()).toBe('None');
      });
    });

    describe('when activeListWipLimit is greater than 0', () => {
      it.each`
        num   | expected
        ${1}  | ${'1 issue'}
        ${11} | ${'11 issues'}
      `('it renders $num', ({ num, expected }) => {
        createComponent({
          vuexState: {
            activeId: listId,
          },
          props: { maxIssueCount: num },
        });

        expect(findWipLimit().text()).toBe(expected);
      });
    });
  });

  describe('when clicking edit', () => {
    const maxIssueCount = 4;
    beforeEach(async () => {
      createComponent({
        vuexState: {
          activeId: listId,
        },
        actions: { updateListWipLimit: noop },
        props: { maxIssueCount },
      });

      clickEdit();

      await wrapper.vm.$nextTick();
    });

    it('renders an input', () => {
      expect(findInput().exists()).toBe(true);
    });

    it('does not render current wipLimit text', () => {
      expect(findWipLimit().exists()).toBe(false);
    });

    it('sets wipLimit to be the value of list.maxIssueCount', () => {
      expect(findInput().attributes('value')).toBe(String(maxIssueCount));
    });
  });

  describe('remove limit', () => {
    describe('when wipLimit is set', () => {
      const spy = jest.fn().mockResolvedValue({
        data: { boardListUpdateLimitMetrics: { list: { maxIssueCount: 0 } } },
      });
      beforeEach(() => {
        createComponent({
          vuexState: {
            activeId: listId,
          },
          actions: { updateListWipLimit: spy },
          props: { maxIssueCount: 4 },
        });
      });

      it('resets wipLimit to 0', async () => {
        expect(findWipLimit().text()).toContain(4);

        findRemoveWipLimit().vm.$emit('click');

        await waitForPromises();
        await wrapper.vm.$nextTick();

        expect(spy).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({ listId, maxIssueCount: 0 }),
        );
      });
    });

    describe('when wipLimit is not set', () => {
      beforeEach(() => {
        createComponent({
          vuexState: { activeId: listId },
          actions: { updateListWipLimit: noop },
        });
      });

      it('does not render the remove limit button', () => {
        expect(findRemoveWipLimit().exists()).toBe(false);
      });
    });
  });

  describe('when edit is true', () => {
    describe.each`
      blurMethod
      ${'enter'}
      ${'blur'}
    `('$blurMethod', ({ blurMethod }) => {
      describe(`when blur is triggered by ${blurMethod}`, () => {
        it('calls updateListWipLimit', async () => {
          const spy = jest.fn().mockResolvedValue({
            data: { boardListUpdateLimitMetrics: { list: { maxIssueCount: 4 } } },
          });
          createComponent({
            vuexState: {
              activeId: listId,
            },
            actions: { updateListWipLimit: spy },
            localState: { edit: true, currentWipLimit },
          });

          triggerBlur(blurMethod);

          await wrapper.vm.$nextTick();

          expect(spy).toHaveBeenCalledTimes(1);
        });

        describe('when component wipLimit and List.maxIssueCount are equal', () => {
          it('does not call updateListWipLimit', async () => {
            const spy = jest.fn().mockResolvedValue({});
            createComponent({
              vuexState: {
                activeId: listId,
              },
              actions: { updateListWipLimit: spy },
              localState: { edit: true, currentWipLimit: 2 },
              props: { maxIssueCount: 2 },
            });

            triggerBlur(blurMethod);

            await wrapper.vm.$nextTick();

            expect(spy).toHaveBeenCalledTimes(0);
          });
        });

        describe('when currentWipLimit is null', () => {
          it('does not call updateListWipLimit', async () => {
            const spy = jest.fn().mockResolvedValue({});
            createComponent({
              vuexState: { activeId: listId },
              actions: { updateListWipLimit: spy },
              localState: { edit: true, currentWipLimit: null },
            });

            triggerBlur(blurMethod);

            await wrapper.vm.$nextTick();

            expect(spy).toHaveBeenCalledTimes(0);
          });
        });

        describe('when response is successful', () => {
          const maxIssueCount = 11;

          beforeEach(() => {
            const spy = jest.fn().mockResolvedValue({});
            createComponent({
              vuexState: {
                activeId: listId,
              },
              actions: { updateListWipLimit: spy },
              localState: { edit: true, currentWipLimit: maxIssueCount },
              props: { maxIssueCount },
            });

            triggerBlur(blurMethod);

            return waitForPromises();
          });

          it('sets activeWipLimit to new maxIssueCount value', () => {
            expect(findWipLimit().text()).toContain(maxIssueCount);
          });

          it('toggles GlFormInput on blur', () => {
            expect(findInput().exists()).toBe(false);
            expect(findWipLimit().exists()).toBe(true);
            expect(wrapper.vm.updating).toBe(false);
          });
        });

        describe('when response fails', () => {
          beforeEach(() => {
            const spy = jest.fn().mockRejectedValue();
            createComponent({
              vuexState: { activeId: listId },
              actions: { updateListWipLimit: spy, unsetActiveId: noop },
              localState: { edit: true, currentWipLimit },
            });
            jest.spyOn(wrapper.vm, 'setError').mockImplementation(() => {});

            triggerBlur(blurMethod);

            return waitForPromises();
          });

          it('calls flash with expected error', () => {
            expect(wrapper.vm.setError).toHaveBeenCalledTimes(1);
          });
        });
      });
    });

    describe('passing of props to gl-form-input', () => {
      beforeEach(() => {
        createComponent({
          vuexState: { activeId: listId },
          actions: { updateListWipLimit: noop },
          localState: { edit: true },
        });
      });

      it('passes `trim`', () => {
        expect(findInput().attributes().trim).toBeDefined();
      });

      it('passes `number`', () => {
        expect(findInput().attributes().number).toBeDefined();
      });
    });
  });
});
