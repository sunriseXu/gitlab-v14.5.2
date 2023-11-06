import { mount } from '@vue/test-utils';
import fixture from 'test_fixtures/pipelines/pipelines.json';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import PipelinesTable from '~/pipelines/components/pipelines_list/pipelines_table.vue';
import { PipelineKeyOptions } from '~/pipelines/constants';

import { triggeredBy, triggered } from './mock_data';

jest.mock('~/pipelines/event_hub');

describe('Pipelines Table', () => {
  let pipeline;
  let wrapper;

  const defaultProps = {
    pipelines: [],
    viewType: 'root',
    pipelineKeyOption: PipelineKeyOptions[0],
  };

  const createMockPipeline = () => {
    // Clone fixture as it could be modified by tests
    const { pipelines } = JSON.parse(JSON.stringify(fixture));
    return pipelines.find((p) => p.user !== null && p.commit !== null);
  };

  const createComponent = (props = {}) => {
    wrapper = extendedWrapper(
      mount(PipelinesTable, {
        propsData: {
          ...defaultProps,
          ...props,
        },
      }),
    );
  };

  const findUpstream = () => wrapper.findByTestId('mini-graph-upstream');
  const findDownstream = () => wrapper.findByTestId('mini-graph-downstream');

  beforeEach(() => {
    pipeline = createMockPipeline();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('Pipelines Table', () => {
    describe('upstream linked pipelines', () => {
      beforeEach(() => {
        pipeline = createMockPipeline();
        pipeline.triggered_by = triggeredBy;

        createComponent({ pipelines: [pipeline] });
      });

      it('should render only a upstream pipeline', () => {
        expect(findUpstream().exists()).toBe(true);
        expect(findDownstream().exists()).toBe(false);
      });

      it('should pass an array of the correct data to the linked pipeline component', () => {
        const triggeredByProps = findUpstream().props('triggeredBy');

        expect(triggeredByProps).toEqual(expect.any(Array));
        expect(triggeredByProps).toHaveLength(1);
        expect(triggeredByProps[0]).toBe(triggeredBy);
      });
    });

    describe('downstream linked pipelines', () => {
      beforeEach(() => {
        pipeline = createMockPipeline();
        pipeline.triggered = triggered;

        createComponent({ pipelines: [pipeline] });
      });

      it('should pass the pipeline path prop for the counter badge', () => {
        expect(findDownstream().props('pipelinePath')).toBe(pipeline.path);
      });

      it('should render only a downstream pipeline', () => {
        expect(findDownstream().exists()).toBe(true);
        expect(findUpstream().exists()).toBe(false);
      });
    });

    describe('upstream and downstream linked pipelines', () => {
      beforeEach(() => {
        pipeline = createMockPipeline();
        pipeline.triggered = triggered;
        pipeline.triggered_by = triggeredBy;

        createComponent({ pipelines: [pipeline] });
      });

      it('should render both downstream and upstream pipelines', () => {
        expect(findDownstream().exists()).toBe(true);
        expect(findUpstream().exists()).toBe(true);
      });
    });
  });
});
