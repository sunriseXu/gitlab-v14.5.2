import { shallowMount } from '@vue/test-utils';
import BoardFilteredSearch from 'ee/boards/components/board_filtered_search.vue';
import IssueBoardFilteredSpec from 'ee/boards/components/issue_board_filtered_search.vue';
import issueBoardFilters from '~/boards/issue_board_filters';
import { mockTokens } from '../mock_data';

jest.mock('~/boards/issue_board_filters');

describe('IssueBoardFilter', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(IssueBoardFilteredSpec, {
      propsData: { fullPath: 'gitlab-org', boardType: 'group' },
      provide: { isSignedIn: true },
    });
  };

  let fetchAuthorsSpy;
  let fetchLabelsSpy;
  beforeEach(() => {
    fetchAuthorsSpy = jest.fn();
    fetchLabelsSpy = jest.fn();

    issueBoardFilters.mockReturnValue({
      fetchAuthors: fetchAuthorsSpy,
      fetchLabels: fetchLabelsSpy,
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('finds BoardFilteredSearch', () => {
      expect(wrapper.find(BoardFilteredSearch).exists()).toBe(true);
    });

    it('passes the correct tokens to BoardFilteredSearch including epics', () => {
      const tokens = mockTokens(fetchLabelsSpy, fetchAuthorsSpy, wrapper.vm.fetchMilestones);

      expect(wrapper.find(BoardFilteredSearch).props('tokens')).toEqual(tokens);
    });
  });
});
