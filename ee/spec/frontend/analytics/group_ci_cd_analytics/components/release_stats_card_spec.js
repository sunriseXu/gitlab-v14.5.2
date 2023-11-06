import { GlSkeletonLoader, GlCard } from '@gitlab/ui';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { merge } from 'lodash';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import ReleaseStatsCard from 'ee/analytics/group_ci_cd_analytics/components/release_stats_card.vue';
import groupReleaseStatsQuery from 'ee/analytics/group_ci_cd_analytics/graphql/group_release_stats.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import { groupReleaseStatsQueryResponse } from './mock_data';

const localVue = createLocalVue();
Vue.use(VueApollo);

describe('Release stats card', () => {
  let wrapper;

  const createComponent = ({ apolloProvider }) => {
    wrapper = shallowMount(ReleaseStatsCard, {
      localVue,
      apolloProvider,
      stubs: {
        GlCard,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
    wrapper = null;
  });

  const findLoadingIndicators = () => wrapper.findAll(GlSkeletonLoader);
  const findStats = () => wrapper.find('[data-testid="stats-container"]');

  const expectLoadingIndicators = () => {
    expect(findLoadingIndicators()).toHaveLength(2);
  };

  const expectNoLoadingIndicators = () => {
    expect(findLoadingIndicators()).toHaveLength(0);
  };

  describe('when the component is loading data', () => {
    beforeEach(() => {
      const apolloProvider = createMockApollo([
        [groupReleaseStatsQuery, jest.fn().mockReturnValueOnce(new Promise(() => {}))],
      ]);
      createComponent({ apolloProvider });
    });

    it('renders loading indicators', () => {
      expectLoadingIndicators();
    });
  });

  describe('when the data has successfully loaded', () => {
    beforeEach(() => {
      const apolloProvider = createMockApollo([
        [groupReleaseStatsQuery, jest.fn().mockResolvedValueOnce(groupReleaseStatsQueryResponse)],
      ]);

      createComponent({ apolloProvider });
    });

    it('does not render loading indicators', () => {
      expectNoLoadingIndicators();
    });

    it('renders the card header', () => {
      const header = wrapper.find('header');

      expect(header.find('h1').text()).toMatchInterpolatedText('Releases');
      expect(header.find('h2').text()).toMatchInterpolatedText('All time');
    });

    it('renders the statistics', () => {
      expect(findStats().text()).toMatchInterpolatedText('2811 Releases 9% Projects with releases');
    });
  });

  describe('when the data is successfully returned, but the stats are all 0', () => {
    beforeEach(() => {
      const responseWithZeros = merge({}, groupReleaseStatsQueryResponse, {
        data: {
          group: {
            stats: {
              releaseStats: {
                releasesCount: 0,
                releasesPercentage: 0,
              },
            },
          },
        },
      });

      const apolloProvider = createMockApollo([
        [groupReleaseStatsQuery, jest.fn().mockResolvedValueOnce(responseWithZeros)],
      ]);

      createComponent({ apolloProvider });
    });

    it('renders the statistics', () => {
      expect(findStats().text()).toMatchInterpolatedText('0 Releases 0% Projects with releases');
    });
  });

  describe('when an error occurs while loading data', () => {
    beforeEach(() => {
      const apolloProvider = createMockApollo([
        [groupReleaseStatsQuery, jest.fn().mockRejectedValueOnce(new Error('network error'))],
      ]);

      createComponent({ apolloProvider });
    });

    it('does not render loading indicators', () => {
      expectNoLoadingIndicators();
    });

    it('renders questions marks in place of the numbers', () => {
      expect(findStats().text()).toMatchInterpolatedText('- Releases - Projects with releases');
    });
  });
});
