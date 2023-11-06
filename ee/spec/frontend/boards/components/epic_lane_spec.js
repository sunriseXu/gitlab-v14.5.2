import { GlButton, GlIcon, GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import Vuex from 'vuex';
import EpicLane from 'ee/boards/components/epic_lane.vue';
import IssuesLaneList from 'ee/boards/components/issues_lane_list.vue';
import getters from 'ee/boards/stores/getters';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockEpic, mockLists, mockIssuesByListId, issues } from '../mock_data';

Vue.use(Vuex);

describe('EpicLane', () => {
  let wrapper;

  const updateBoardEpicUserPreferencesSpy = jest.fn();

  const findChevronButton = () => wrapper.findComponent(GlButton);

  const createStore = ({ boardItemsByListId = mockIssuesByListId, isLoading = false }) => {
    return new Vuex.Store({
      actions: {
        updateBoardEpicUserPreferences: updateBoardEpicUserPreferencesSpy,
        fetchIssuesForEpic: jest.fn(),
      },
      state: {
        boardItemsByListId,
        boardItems: issues,
        epicsFlags: {
          [mockEpic.id]: {
            isLoading,
          },
        },
      },
      getters,
    });
  };

  const createComponent = ({
    props = {},
    boardItemsByListId = mockIssuesByListId,
    isLoading = false,
  } = {}) => {
    const store = createStore({ boardItemsByListId, isLoading });

    const defaultProps = {
      epic: mockEpic,
      lists: mockLists,
      disabled: false,
    };

    wrapper = shallowMountExtended(EpicLane, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      store,
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays count of issues in epic which belong to board', () => {
      expect(wrapper.findByTestId('epic-lane-issue-count').text()).toContain(2);
    });

    it('displays 1 icon', () => {
      expect(wrapper.findAll(GlIcon)).toHaveLength(1);
    });

    it('displays epic title', () => {
      expect(wrapper.text()).toContain(mockEpic.title);
    });

    it('renders one IssuesLaneList component per list passed in props', () => {
      expect(wrapper.findAll(IssuesLaneList)).toHaveLength(wrapper.props('lists').length);
    });

    it('hides issues when collapsing', () => {
      expect(wrapper.findAll(IssuesLaneList)).toHaveLength(wrapper.props('lists').length);
      expect(wrapper.vm.isCollapsed).toBe(false);

      findChevronButton().vm.$emit('click');

      return wrapper.vm.$nextTick().then(() => {
        expect(wrapper.findAll(IssuesLaneList)).toHaveLength(0);
        expect(wrapper.vm.isCollapsed).toBe(true);
      });
    });

    it('does not display loading icon when issues are not loading', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(false);
    });

    it('displays loading icon and hides issues count when issues are loading', () => {
      createComponent({ isLoading: true });
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
      expect(wrapper.findByTestId('epic-lane-issue-count').exists()).toBe(false);
    });

    it('invokes `updateBoardEpicUserPreferences` method on collapse', () => {
      const collapsedValue = false;

      expect(wrapper.vm.isCollapsed).toBe(collapsedValue);

      findChevronButton().vm.$emit('click');

      return wrapper.vm.$nextTick().then(() => {
        expect(updateBoardEpicUserPreferencesSpy).toHaveBeenCalled();

        const payload = updateBoardEpicUserPreferencesSpy.mock.calls[0][1];

        expect(payload).toEqual({
          collapsed: !collapsedValue,
          epicId: mockEpic.id,
        });

        expect(wrapper.vm.isCollapsed).toBe(true);
      });
    });

    it('does not render when issuesCount is 0', () => {
      createComponent({ boardItemsByListId: {} });
      expect(wrapper.findByTestId('board-epic-lane').exists()).toBe(false);
    });
  });
});
