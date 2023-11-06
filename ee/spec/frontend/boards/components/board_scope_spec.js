import { mount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import Vuex from 'vuex';
import BoardScope from 'ee/boards/components/board_scope.vue';
import BoardLabelsSelect from 'ee/boards/components/labels_select.vue';

import { mockLabel1 } from 'jest/boards/mock_data';

Vue.use(Vuex);

describe('BoardScope', () => {
  let wrapper;
  let store;

  const createStore = ({ isIssueBoard }) => {
    return new Vuex.Store({
      getters: {
        isIssueBoard: () => isIssueBoard,
        isEpicBoard: () => !isIssueBoard,
      },
    });
  };

  function mountComponent({ isIssueBoard = true } = []) {
    store = createStore({ isIssueBoard });
    wrapper = mount(BoardScope, {
      store,
      propsData: {
        collapseScope: false,
        canAdminBoard: true,
        board: {
          labels: [],
          assignee: {},
        },
      },
      stubs: {
        AssigneeSelect: true,
        BoardMilestoneSelect: true,
        BoardLabelsSelect: true,
      },
    });
  }

  beforeEach(() => {
    mountComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  const findLabelSelect = () => wrapper.findComponent(BoardLabelsSelect);

  describe('BoardScope', () => {
    it('emits selected labels to be added and removed from the board', async () => {
      const labels = [mockLabel1];
      expect(findLabelSelect().exists()).toBe(true);
      findLabelSelect().vm.$emit('set-labels', labels);
      await nextTick();
      expect(wrapper.emitted('set-board-labels')).toEqual([[labels]]);
    });
  });

  it.each`
    isIssueBoard | text
    ${true}      | ${'Board scope affects which issues are displayed for anyone who visits this board'}
    ${false}     | ${'Board scope affects which epics are displayed for anyone who visits this board'}
  `('displays $text when isIssueBoard is $isIssueBoard', ({ isIssueBoard, text }) => {
    mountComponent({ isIssueBoard });
    expect(wrapper.find('p.text-secondary').text()).toEqual(text);
  });
});
