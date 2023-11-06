import { GlSprintf } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import lastWeekData from 'test_fixtures/api/dora/metrics/daily_lead_time_for_changes_for_last_week.json';
import lastMonthData from 'test_fixtures/api/dora/metrics/daily_lead_time_for_changes_for_last_month.json';
import last90DaysData from 'test_fixtures/api/dora/metrics/daily_lead_time_for_changes_for_last_90_days.json';
import { useFixturesFakeDate } from 'helpers/fake_date';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import httpStatus from '~/lib/utils/http_status';
import CiCdAnalyticsCharts from '~/vue_shared/components/ci_cd_analytics/ci_cd_analytics_charts.vue';

jest.mock('~/flash');

describe('lead_time_charts.vue', () => {
  useFixturesFakeDate();

  let LeadTimeCharts;
  let DoraChartHeader;

  // Import these components _after_ the date has been set using `useFakeDate`, so
  // that any calls to `new Date()` during module initialization use the fake date
  beforeAll(async () => {
    LeadTimeCharts = (await import('ee_component/dora/components/lead_time_charts.vue')).default;
    DoraChartHeader = (await import('ee/dora/components/dora_chart_header.vue')).default;
  });

  let wrapper;
  let mock;
  const defaultMountOptions = {
    provide: {
      projectPath: 'test/project',
    },
    stubs: { GlSprintf },
  };

  const createComponent = ({ mountFn = shallowMount, mountOptions = defaultMountOptions } = {}) => {
    wrapper = mountFn(LeadTimeCharts, mountOptions);
  };

  // Initializes the mock endpoint to return a specific set of lead time data for a given "from" date.
  const setUpMockLeadTime = ({ start_date, data }) => {
    mock
      .onGet(/projects\/test%2Fproject\/dora\/metrics/, {
        params: {
          metric: 'lead_time_for_changes',
          interval: 'daily',
          per_page: 100,
          end_date: '2015-07-04T00:00:00+0000',
          start_date,
        },
      })
      .replyOnce(httpStatus.OK, data);
  };

  afterEach(() => {
    wrapper.destroy();
    mock.restore();
  });

  const getTooltipValue = () => wrapper.find('[data-testid="tooltip-value"]').text();
  const findCiCdAnalyticsCharts = () => wrapper.findComponent(CiCdAnalyticsCharts);

  describe('when there are no network errors', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);

      setUpMockLeadTime({
        start_date: '2015-06-27T00:00:00+0000',
        data: lastWeekData,
      });
      setUpMockLeadTime({
        start_date: '2015-06-04T00:00:00+0000',
        data: lastMonthData,
      });
      setUpMockLeadTime({
        start_date: '2015-04-05T00:00:00+0000',
        data: last90DaysData,
      });

      createComponent();

      await axios.waitForAll();
    });

    it('makes 3 GET requests - one for each chart', () => {
      expect(mock.history.get).toHaveLength(3);
    });

    it('does not show a flash message', () => {
      expect(createFlash).not.toHaveBeenCalled();
    });

    it('renders a header', () => {
      expect(wrapper.findComponent(DoraChartHeader).exists()).toBe(true);
    });

    describe('methods', () => {
      describe('formatTooltipText', () => {
        it('displays a humanized version of the time interval in the tooltip', async () => {
          createComponent({ mountFn: mount });

          await axios.waitForAll();

          const params = { seriesData: [{}, { data: ['Apr 7', 5328] }] };

          // Simulate the child CiCdAnalyticsCharts component calling the
          // function bound to the `format-tooltip-text`.
          const formatTooltipText = findCiCdAnalyticsCharts().vm.$attrs['format-tooltip-text'];
          formatTooltipText(params);

          await wrapper.vm.$nextTick();

          expect(getTooltipValue()).toBe('1.5 hours');
        });
      });
    });
  });

  describe('when there are network errors', () => {
    beforeEach(async () => {
      mock = new MockAdapter(axios);

      createComponent();

      await axios.waitForAll();
    });

    it('shows a flash message', () => {
      expect(createFlash).toHaveBeenCalledTimes(1);
      expect(createFlash.mock.calls[0]).toEqual([
        {
          message: 'Something went wrong while getting lead time data.',
          captureError: true,
          error: expect.any(Error),
        },
      ]);
    });
  });

  describe('group/project behavior', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);

      mock.onGet(/projects\/test%2Fproject\/dora\/metrics/).reply(httpStatus.OK, lastWeekData);
      mock.onGet(/groups\/test%2Fgroup\/dora\/metrics/).reply(httpStatus.OK, lastWeekData);
    });

    describe('when projectPath is provided', () => {
      beforeEach(async () => {
        createComponent({
          mountOptions: {
            provide: {
              projectPath: 'test/project',
            },
          },
        });

        await axios.waitForAll();
      });

      it('makes a call to the project API endpoint', () => {
        expect(mock.history.get.length).toBe(3);
        expect(mock.history.get[0].url).toMatch('/projects/test%2Fproject/dora/metrics');
      });

      it('does not throw an error', () => {
        expect(createFlash).not.toHaveBeenCalled();
      });
    });

    describe('when groupPath is provided', () => {
      beforeEach(async () => {
        createComponent({
          mountOptions: {
            provide: {
              groupPath: 'test/group',
            },
          },
        });

        await axios.waitForAll();
      });

      it('makes a call to the group API endpoint', () => {
        expect(mock.history.get.length).toBe(3);
        expect(mock.history.get[0].url).toMatch('/groups/test%2Fgroup/dora/metrics');
      });

      it('does not throw an error', () => {
        expect(createFlash).not.toHaveBeenCalled();
      });
    });

    describe('when both projectPath and groupPath are provided', () => {
      beforeEach(async () => {
        createComponent({
          mountOptions: {
            provide: {
              projectPath: 'test/project',
              groupPath: 'test/group',
            },
          },
        });

        await axios.waitForAll();
      });

      it('throws an error (which shows a flash message)', () => {
        expect(createFlash).toHaveBeenCalled();
      });
    });

    describe('when neither projectPath nor groupPath are provided', () => {
      beforeEach(async () => {
        createComponent({
          mountOptions: {
            provide: {},
          },
        });

        await axios.waitForAll();
      });

      it('throws an error (which shows a flash message)', () => {
        expect(createFlash).toHaveBeenCalled();
      });
    });
  });
});
