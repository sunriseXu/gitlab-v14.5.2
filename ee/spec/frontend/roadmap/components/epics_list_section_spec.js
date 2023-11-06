import { GlIntersectionObserver, GlLoadingIcon } from '@gitlab/ui';

import { createLocalVue } from '@vue/test-utils';
import EpicItem from 'ee/roadmap/components/epic_item.vue';
import EpicsListSection from 'ee/roadmap/components/epics_list_section.vue';
import {
  DATE_RANGES,
  PRESET_TYPES,
  EPIC_DETAILS_CELL_WIDTH,
  TIMELINE_CELL_MIN_WIDTH,
} from 'ee/roadmap/constants';
import createStore from 'ee/roadmap/store';
import { REQUEST_EPICS_FOR_NEXT_PAGE } from 'ee/roadmap/store/mutation_types';
import { scrollToCurrentDay } from 'ee/roadmap/utils/epic_utils';
import { getTimeframeForRangeType } from 'ee/roadmap/utils/roadmap_utils';
import {
  mockFormattedChildEpic1,
  mockFormattedChildEpic2,
  mockTimeframeInitialDate,
  mockGroupId,
  rawEpics,
  mockEpicsWithParents,
  mockSortedBy,
  mockPageInfo,
  basePath,
} from 'ee_jest/roadmap/mock_data';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

jest.mock('ee/roadmap/utils/epic_utils', () => ({
  ...jest.requireActual('ee/roadmap/utils/epic_utils'),
  scrollToCurrentDay: jest.fn(),
}));

const mockTimeframeMonths = getTimeframeForRangeType({
  timeframeRangeType: DATE_RANGES.CURRENT_YEAR,
  presetType: PRESET_TYPES.MONTHS,
  initialDate: mockTimeframeInitialDate,
});
const store = createStore();
store.dispatch('setInitialData', {
  currentGroupId: mockGroupId,
  sortedBy: mockSortedBy,
  presetType: PRESET_TYPES.MONTHS,
  timeframe: mockTimeframeMonths,
  filterQueryString: '',
  basePath,
});

store.dispatch('receiveEpicsSuccess', {
  rawEpics,
  pageInfo: mockPageInfo,
  appendToList: true,
});

const mockEpics = store.state.epics;

store.state.childrenEpics[mockEpics[0].id] = [mockFormattedChildEpic1, mockFormattedChildEpic2];

const localVue = createLocalVue();

const createComponent = ({
  epics = mockEpics,
  timeframe = mockTimeframeMonths,
  currentGroupId = mockGroupId,
  presetType = PRESET_TYPES.MONTHS,
  hasFiltersApplied = false,
} = {}) => {
  return shallowMountExtended(EpicsListSection, {
    localVue,
    store,
    stubs: {
      EpicItem: false,
      VirtualList: false,
    },
    propsData: {
      presetType,
      epics,
      timeframe,
      currentGroupId,
      hasFiltersApplied,
    },
  });
};

describe('EpicsListSectionComponent', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  describe('data', () => {
    it('returns default data props', () => {
      // Destroy the existing wrapper, and create a new one. This works around
      // a race condition between how Jest runs tests and the $nextTick call in
      // EpicsListSectionComponent's mounted hook.
      // https://gitlab.com/gitlab-org/gitlab/-/merge_requests/27992#note_319213990
      wrapper.destroy();
      wrapper = createComponent();

      expect(wrapper.vm.offsetLeft).toBe(0);
      expect(wrapper.vm.emptyRowContainerStyles).toEqual({});
      expect(wrapper.vm.showBottomShadow).toBe(false);
      expect(wrapper.vm.roadmapShellEl).toBeDefined();
    });
  });

  describe('computed', () => {
    describe('emptyRowContainerVisible', () => {
      it('returns true when total epics are less than buffer size', () => {
        wrapper.vm.setBufferSize(wrapper.vm.epics.length + 1);

        expect(wrapper.vm.emptyRowContainerVisible).toBe(true);
      });
    });

    describe('sectionContainerStyles', () => {
      it('returns style string for container element based on sectionShellWidth', () => {
        expect(wrapper.vm.sectionContainerStyles.width).toBe(
          `${EPIC_DETAILS_CELL_WIDTH + TIMELINE_CELL_MIN_WIDTH * wrapper.vm.timeframe.length}px`,
        );
      });
    });

    describe('shadowCellStyles', () => {
      it('returns computed style object based on `offsetLeft` prop value', () => {
        expect(wrapper.vm.shadowCellStyles.left).toBe('0px');
      });
    });

    describe('epicsWithAssociatedParents', () => {
      it('should return epics which contain parent associations', () => {
        wrapper.setProps({
          epics: mockEpicsWithParents,
        });

        return wrapper.vm.$nextTick(() => {
          expect(wrapper.vm.epicsWithAssociatedParents).toEqual(mockEpicsWithParents);
        });
      });
    });

    describe('displayedEpics', () => {
      beforeAll(() => {
        store.state.epicIds = ['1', '2', '3'];
      });

      it('returns epicsWithAssociatedParents computed prop by default', () => {
        expect(wrapper.vm.displayedEpics).toEqual(wrapper.vm.epicsWithAssociatedParents);
      });

      it('returns all epics if epicIid is specified', () => {
        store.state.epicIid = '23';
        expect(wrapper.vm.displayedEpics).toEqual(mockEpics);
      });
    });
  });

  describe('methods', () => {
    describe('initMounted', () => {
      beforeEach(() => {
        // Destroy the existing wrapper, and create a new one. This works
        // around a race condition between how Jest runs tests and the
        // $nextTick call in EpicsListSectionComponent's mounted hook.
        // https://gitlab.com/gitlab-org/gitlab/-/merge_requests/27992#note_319213990
        wrapper.destroy();
        wrapper = createComponent();
      });

      it('calls action `setBufferSize` with value based on window.innerHeight and component element position', () => {
        expect(wrapper.vm.bufferSize).toBe(16);
      });

      it('sets value of `offsetLeft` with parentElement.offsetLeft', () => {
        return wrapper.vm.$nextTick(() => {
          // During tests, there's no `$el.parentElement` present
          // hence offsetLeft is 0.
          expect(wrapper.vm.offsetLeft).toBe(0);
        });
      });

      it('calls `scrollToCurrentDay` following the component render', async () => {
        // Original method implementation waits for render cycle
        // to complete at 2 levels before scrolling.
        await wrapper.vm.$nextTick(); // set offsetLeft value
        await wrapper.vm.$nextTick(); // Wait for nextTick before scroll
        expect(scrollToCurrentDay).toHaveBeenCalledWith(wrapper.vm.$el);
      });

      it('sets style object to `emptyRowContainerStyles`', () => {
        return wrapper.vm.$nextTick(() => {
          expect(wrapper.vm.emptyRowContainerStyles).toEqual(
            expect.objectContaining({
              height: '0px',
            }),
          );
        });
      });
    });

    describe('getEmptyRowContainerStyles', () => {
      it('returns empty object when there are no epics available to render', () => {
        wrapper.setProps({
          epics: [],
        });

        return wrapper.vm.$nextTick(() => {
          expect(wrapper.vm.getEmptyRowContainerStyles()).toEqual({});
        });
      });

      it('returns object containing `height` when there epics available to render', () => {
        expect(wrapper.vm.getEmptyRowContainerStyles()).toEqual(
          expect.objectContaining({
            height: '0px',
          }),
        );
      });
    });

    describe('handleEpicsListScroll', () => {
      it('toggles value of `showBottomShadow` based on provided `scrollTop`, `clientHeight` & `scrollHeight`', () => {
        wrapper.vm.handleEpicsListScroll({
          scrollTop: 5,
          clientHeight: 5,
          scrollHeight: 15,
        });

        // Math.ceil(scrollTop) + clientHeight < scrollHeight
        expect(wrapper.vm.showBottomShadow).toBe(true);

        wrapper.vm.handleEpicsListScroll({
          scrollTop: 15,
          clientHeight: 5,
          scrollHeight: 15,
        });

        // Math.ceil(scrollTop) + clientHeight < scrollHeight
        expect(wrapper.vm.showBottomShadow).toBe(false);
      });
    });
  });

  describe('template', () => {
    const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

    it('renders component container element with class `epics-list-section`', () => {
      expect(wrapper.classes('epics-list-section')).toBe(true);
    });

    it('renders epic-item', () => {
      expect(wrapper.find(EpicItem).exists()).toBe(true);
    });

    it('renders empty row element when `epics.length` is less than `bufferSize`', () => {
      wrapper.vm.setBufferSize(50);

      expect(wrapper.find('.epics-list-item-empty').exists()).toBe(true);
    });

    it('renders gl-intersection-observer component', () => {
      expect(findIntersectionObserver().exists()).toBe(true);
    });

    it('calls action `fetchEpics` when gl-intersection-observer appears in viewport', () => {
      const fakeFetchEpics = jest.spyOn(wrapper.vm, 'fetchEpics').mockImplementation();

      findIntersectionObserver().vm.$emit('appear');

      expect(fakeFetchEpics).toHaveBeenCalledWith({
        endCursor: mockPageInfo.endCursor,
      });
    });

    it('renders gl-loading icon when epicsFetchForNextPageInProgress is true', async () => {
      wrapper.vm.$store.commit(REQUEST_EPICS_FOR_NEXT_PAGE);

      await wrapper.vm.$nextTick();

      expect(wrapper.findByTestId('next-page-loading').text()).toContain('Loading epics');
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('renders bottom shadow element when `showBottomShadow` prop is true', () => {
      wrapper.setData({
        showBottomShadow: true,
      });

      expect(wrapper.find('.epic-scroll-bottom-shadow').exists()).toBe(true);
    });
  });

  it('expands to show child epics when epic is toggled', () => {
    const epic = mockEpics[0];

    expect(store.state.childrenFlags[epic.id].itemExpanded).toBe(false);

    wrapper.vm.toggleIsEpicExpanded(epic);

    return wrapper.vm.$nextTick().then(() => {
      expect(store.state.childrenFlags[epic.id].itemExpanded).toBe(true);
    });
  });
});
