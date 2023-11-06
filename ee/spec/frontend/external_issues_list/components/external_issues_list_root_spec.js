import { GlAlert } from '@gitlab/ui';
import * as Sentry from '@sentry/browser';
import { shallowMount, createLocalVue, mount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import VueApollo from 'vue-apollo';

import ExternalIssuesListRoot from 'ee/external_issues_list/components/external_issues_list_root.vue';
import jiraIssuesResolver from 'ee/integrations/jira/issues_list/graphql/resolvers/jira_issues';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import IssuableList from '~/issuable_list/components/issuable_list_root.vue';
import { i18n } from '~/issues_list/constants';
import axios from '~/lib/utils/axios_utils';
import httpStatus from '~/lib/utils/http_status';

import {
  mockProvide,
  mockJiraIssues as mockExternalIssues,
  mockJiraIssue4 as mockJiraIssueNoReference,
} from '../mock_data';

jest.mock('~/flash');
jest.mock('~/issuable_list/constants', () => ({
  DEFAULT_PAGE_SIZE: 2,
  IssuableStates: jest.requireActual('~/issuable_list/constants').IssuableStates,
  IssuableListTabs: jest.requireActual('~/issuable_list/constants').IssuableListTabs,
  AvailableSortOptions: jest.requireActual('~/issuable_list/constants').AvailableSortOptions,
}));
jest.mock(
  '~/vue_shared/components/filtered_search_bar/tokens/label_token.vue',
  () => 'LabelTokenMock',
);

const resolvedValue = {
  headers: {
    'x-page': 1,
    'x-total': mockExternalIssues.length,
  },
  data: mockExternalIssues,
};

const localVue = createLocalVue();

const resolvers = {
  Query: {
    externalIssues: jiraIssuesResolver,
  },
};

function createMockApolloProvider(mockResolvers = resolvers) {
  localVue.use(VueApollo);
  return createMockApollo([], mockResolvers);
}

describe('ExternalIssuesListRoot', () => {
  let wrapper;
  let mock;

  const mockSearchTerm = 'test issue';
  const mockLabel = 'ecosystem';

  const findIssuableList = () => wrapper.findComponent(IssuableList);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findAlertMessage = () => findAlert().find('span');
  const createLabelFilterEvent = (data) => ({ type: 'labels', value: { data } });
  const createSearchFilterEvent = (data) => ({ type: 'filtered-search-term', value: { data } });

  const expectErrorHandling = (expectedRenderedErrorMessage) => {
    const issuesList = findIssuableList();
    const alert = findAlert();

    expect(issuesList.exists()).toBe(false);

    expect(alert.exists()).toBe(true);
    expect(alert.text()).toBe(expectedRenderedErrorMessage);
    expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
  };

  const createComponent = ({
    apolloProvider = createMockApolloProvider(),
    provide = mockProvide,
    initialFilterParams = {},
  } = {}) => {
    wrapper = shallowMount(ExternalIssuesListRoot, {
      propsData: {
        initialFilterParams,
      },
      provide,
      localVue,
      apolloProvider,
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    wrapper.destroy();
    mock.restore();
  });

  describe('while loading', () => {
    it('sets issuesListLoading to `true`', async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(new Promise(() => {}));

      createComponent();
      await wrapper.vm.$nextTick();

      const issuableList = findIssuableList();
      expect(issuableList.props('issuablesLoading')).toBe(true);
    });

    it('calls `axios.get` with `issuesFetchPath` and query params', async () => {
      jest.spyOn(axios, 'get');

      createComponent();
      await waitForPromises();

      expect(axios.get).toHaveBeenCalledWith(
        mockProvide.issuesFetchPath,
        expect.objectContaining({
          params: {
            with_labels_details: true,
            page: wrapper.vm.currentPage,
            per_page: wrapper.vm.$options.defaultPageSize,
            state: wrapper.vm.currentState,
            sort: wrapper.vm.sortedBy,
            search: wrapper.vm.filterParams.search,
          },
        }),
      );
    });
  });

  describe('with `initialFilterParams` prop', () => {
    beforeEach(async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

      createComponent({
        initialFilterParams: {
          labels: [mockLabel],
          search: mockSearchTerm,
        },
      });
      await waitForPromises();
    });

    it('renders issuable-list component with correct props', () => {
      const issuableList = findIssuableList();

      expect(issuableList.props('initialFilterValue')).toEqual([
        { type: 'labels', value: { data: mockLabel } },
        { type: 'filtered-search-term', value: { data: mockSearchTerm } },
      ]);
      expect(issuableList.props('urlParams').search).toBe(mockSearchTerm);
    });
  });

  describe('when request succeeds', () => {
    beforeEach(async () => {
      jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

      createComponent();
      await waitForPromises();
    });

    it('renders issuable-list component with correct props', () => {
      const issuableList = findIssuableList();
      expect(issuableList.exists()).toBe(true);
      expect(issuableList.props()).toMatchSnapshot();
    });

    describe('issuable-list reference section', () => {
      it('renders issuable-list component with correct reference', async () => {
        jest.spyOn(axios, 'get').mockResolvedValue(resolvedValue);

        wrapper = mount(ExternalIssuesListRoot, {
          propsData: {
            initialFilterParams: {},
          },
          provide: mockProvide,
          localVue,
          apolloProvider: createMockApolloProvider(),
        });
        await waitForPromises();
        expect(wrapper.find('.issuable-info').text()).toContain(
          resolvedValue.data[0].references.relative,
        );
      });

      it('renders issuable-list component with id when references is not presence', async () => {
        jest.spyOn(axios, 'get').mockResolvedValue({
          ...resolvedValue,
          data: [mockJiraIssueNoReference],
        });

        wrapper = mount(ExternalIssuesListRoot, {
          propsData: {
            initialFilterParams: {},
          },
          provide: mockProvide,
          localVue,
          apolloProvider: createMockApolloProvider(),
        });
        await waitForPromises();
        // Since Jira transformer transforms references.relative into id, we can only test
        // whether it exists.
        expect(wrapper.find('.issuable-info').exists()).toBe(false);
      });
    });

    describe('issuable-list events', () => {
      it('"click-tab" event executes GET request correctly', async () => {
        const issuableList = findIssuableList();

        issuableList.vm.$emit('click-tab', 'closed');
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
          params: {
            labels: undefined,
            page: 1,
            per_page: 2,
            search: undefined,
            sort: 'created_desc',
            state: 'closed',
            with_labels_details: true,
          },
        });
        expect(issuableList.props('currentTab')).toBe('closed');
      });

      it('"page-change" event executes GET request correctly', async () => {
        const mockPage = 2;
        const issuableList = findIssuableList();
        jest.spyOn(axios, 'get').mockResolvedValue({
          ...resolvedValue,
          headers: { 'x-page': mockPage, 'x-total': mockExternalIssues.length },
        });

        issuableList.vm.$emit('page-change', mockPage);
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
          params: {
            labels: undefined,
            page: mockPage,
            per_page: 2,
            search: undefined,
            sort: 'created_desc',
            state: 'opened',
            with_labels_details: true,
          },
        });

        await wrapper.vm.$nextTick();
        expect(issuableList.props()).toMatchObject({
          currentPage: mockPage,
          previousPage: mockPage - 1,
          nextPage: mockPage + 1,
        });
      });

      it('"sort" event executes GET request correctly', async () => {
        const mockSortBy = 'updated_asc';
        const issuableList = findIssuableList();

        issuableList.vm.$emit('sort', mockSortBy);
        await waitForPromises();

        expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
          params: {
            labels: undefined,
            page: 1,
            per_page: 2,
            search: undefined,
            sort: 'created_desc',
            state: 'opened',
            with_labels_details: true,
          },
        });
        expect(issuableList.props('initialSortBy')).toBe(mockSortBy);
      });

      it.each`
        desc                        | input                                                                           | expected
        ${'with label and search'}  | ${[createLabelFilterEvent(mockLabel), createSearchFilterEvent(mockSearchTerm)]} | ${{ labels: [mockLabel], search: mockSearchTerm }}
        ${'with multiple lables'}   | ${[createLabelFilterEvent('label1'), createLabelFilterEvent('label2')]}         | ${{ labels: ['label1', 'label2'], search: undefined }}
        ${'with multiple searches'} | ${[createSearchFilterEvent('foo bar'), createSearchFilterEvent('lorem')]}       | ${{ labels: undefined, search: 'foo bar lorem' }}
      `(
        '$desc, filter event sets "filterParams" value and calls fetchIssues',
        async ({ input, expected }) => {
          const issuableList = findIssuableList();

          issuableList.vm.$emit('filter', input);
          await waitForPromises();

          expect(axios.get).toHaveBeenCalledWith(mockProvide.issuesFetchPath, {
            params: {
              page: 1,
              per_page: 2,
              sort: 'created_desc',
              state: 'opened',
              with_labels_details: true,
              ...expected,
            },
          });
        },
      );
    });
  });

  describe('error handling', () => {
    beforeEach(() => {
      jest.spyOn(Sentry, 'captureException');
    });

    describe('when request fails', () => {
      it.each`
        APIErrors                                         | expectedRenderedErrorText
        ${['API error']}                                  | ${'API error'}
        ${['API <a href="gitlab.com">error</a>']}         | ${'API error'}
        ${['API <script src="hax0r.xyz">error</script>']} | ${'API'}
        ${undefined}                                      | ${i18n.errorFetchingIssues}
      `(
        'displays error alert with "$expectedRenderedErrorText" when API responds with "$APIErrors"',
        async ({ APIErrors, expectedRenderedErrorText }) => {
          jest.spyOn(axios, 'get');
          mock
            .onGet(mockProvide.issuesFetchPath)
            .replyOnce(httpStatus.INTERNAL_SERVER_ERROR, { errors: APIErrors });

          createComponent();
          await waitForPromises();

          expectErrorHandling(expectedRenderedErrorText);
          expect(findAlertMessage().html()).toMatchSnapshot();
        },
      );
    });

    describe('when GraphQL network error is encountered', () => {
      it('displays error alert with default error message', async () => {
        createComponent({
          apolloProvider: createMockApolloProvider({
            Query: {
              externalIssues: jest.fn().mockRejectedValue(new Error('GraphQL networkError')),
            },
          }),
        });
        await waitForPromises();

        expectErrorHandling(i18n.errorFetchingIssues);
      });
    });
  });

  describe('pagination', () => {
    it.each`
      scenario                 | issues                | shouldShowPaginationControls
      ${'returns no issues'}   | ${[]}                 | ${false}
      ${`returns some issues`} | ${mockExternalIssues} | ${true}
    `(
      'sets `showPaginationControls` prop to $shouldShowPaginationControls when request $scenario',
      async ({ issues, shouldShowPaginationControls }) => {
        jest.spyOn(axios, 'get');
        mock.onGet(mockProvide.issuesFetchPath).replyOnce(httpStatus.OK, issues, {
          'x-page': 1,
          'x-total': issues.length,
        });

        createComponent();
        await waitForPromises();

        expect(findIssuableList().props('showPaginationControls')).toBe(
          shouldShowPaginationControls,
        );
      },
    );
  });
});
