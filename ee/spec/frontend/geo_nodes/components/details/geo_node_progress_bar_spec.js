import { GlPopover } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import GeoNodeProgressBar from 'ee/geo_nodes/components/details/geo_node_progress_bar.vue';
import { MOCK_PRIMARY_VERIFICATION_INFO } from 'ee_jest/geo_nodes/mock_data';
import StackedProgressBar from '~/vue_shared/components/stacked_progress_bar.vue';

describe('GeoNodeProgressBar', () => {
  let wrapper;

  const defaultProps = {
    title: MOCK_PRIMARY_VERIFICATION_INFO[0].title,
    values: MOCK_PRIMARY_VERIFICATION_INFO[0].values,
  };

  const createComponent = (props) => {
    wrapper = shallowMount(GeoNodeProgressBar, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findStackedProgressBar = () => wrapper.findComponent(StackedProgressBar);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findCounts = () => findGlPopover().findAll('section > div');

  describe('template', () => {
    describe('always', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the stacked progress bar', () => {
        expect(findStackedProgressBar().exists()).toBe(true);
      });

      it('renders the GlPopover', () => {
        expect(findGlPopover().exists()).toBe(true);
      });

      it('renders a popover count for total, successful, queued, and failed', () => {
        expect(findCounts()).toHaveLength(4);
      });
    });

    describe.each`
      values                                             | expectedUiCounts
      ${{ success: 5, failed: 3, total: 10 }}            | ${['Total 10', 'Synced 5', 'Queued 2', 'Failed 3']}
      ${{ success: '5', failed: '3', total: '10' }}      | ${['Total 10', 'Synced 5', 'Queued 2', 'Failed 3']}
      ${{ success: null, failed: null, total: null }}    | ${['Total 0', 'Synced 0', 'Queued 0', 'Failed 0']}
      ${{ success: 'abc', failed: 'def', total: 'ghi' }} | ${['Total 0', 'Synced 0', 'Queued 0', 'Failed 0']}
    `(`status counts`, ({ values, expectedUiCounts }) => {
      beforeEach(() => {
        createComponent({ values });
      });

      describe(`when values are { total: ${values.total}, success: ${values.success}, failed: ${values.failed}} `, () => {
        it(`should render the ui counts as ${expectedUiCounts}`, () => {
          expect(findCounts().wrappers.map((w) => w.text())).toStrictEqual(expectedUiCounts);
        });
      });
    });

    describe('when status counts labels are over written', () => {
      const expectedUiCounts = ['Total 0', 'label1 0', 'label2 0', 'label3 0'];
      const values = { success: 0, failed: 0, total: 0 };

      beforeEach(() => {
        createComponent({
          successLabel: 'label1',
          queuedLabel: 'label2',
          failedLabel: 'label3',
          values,
        });
      });

      it('uses the custom labels instead of the default', () => {
        expect(findCounts().wrappers.map((w) => w.text())).toStrictEqual(expectedUiCounts);
      });
    });

    describe('popoverTarget', () => {
      describe('when target prop is null', () => {
        beforeEach(() => {
          createComponent();
        });

        it(`sets the popoverTarget to syncProgress-${MOCK_PRIMARY_VERIFICATION_INFO[0].title}`, () => {
          expect(findStackedProgressBar().attributes('id')).toBe(
            `syncProgress-${MOCK_PRIMARY_VERIFICATION_INFO[0].title}`,
          );
          expect(findGlPopover().attributes('target')).toBe(
            `syncProgress-${MOCK_PRIMARY_VERIFICATION_INFO[0].title}`,
          );
        });
      });

      describe('when target prop is set', () => {
        beforeEach(() => {
          createComponent({ target: 'test-target' });
        });

        it('sets the popoverTarget to test-target', () => {
          expect(findStackedProgressBar().attributes('id')).toBe('test-target');
          expect(findGlPopover().attributes('target')).toBe('test-target');
        });
      });
    });
  });
});
