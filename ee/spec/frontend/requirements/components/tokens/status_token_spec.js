import { GlIcon, GlFilteredSearchToken, GlToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';

import StatusToken from 'ee/requirements/components/tokens/status_token.vue';
import { stubComponent } from 'helpers/stub_component';

import { mockStatusToken } from '../../mock_data';

const mockStatuses = [
  {
    text: 'Satisfied',
    icon: 'status_success',
  },
  {
    text: 'Failed',
    icon: 'status_failed',
  },
  {
    text: 'Missing',
    icon: 'status-waiting',
  },
];

function createComponent(options = {}) {
  const { config = mockStatusToken, value = { data: '' } } = options;

  return shallowMount(StatusToken, {
    propsData: {
      config,
      value,
    },
    stubs: {
      GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
        template: `
          <div>
            <slot name="view-token"></slot>
            <slot name="suggestions"></slot>
          </div>
        `,
      }),
    },
  });
}

describe('StatusToken', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('template', () => {
    it('renders gl-filtered-search-token component', () => {
      const token = wrapper.find(GlFilteredSearchToken);
      expect(token.exists()).toBe(true);
      expect(token.props('config')).toMatchObject(mockStatusToken);
    });

    it.each`
      value          | text           | icon
      ${'satisfied'} | ${'Satisfied'} | ${'status_success'}
      ${'failed'}    | ${'Failed'}    | ${'status_failed'}
      ${'missing'}   | ${'Missing'}   | ${'status-waiting'}
    `(
      'renders token icon and text representing status "$text" when `value.data` is set to "$value"',
      ({ value, text, icon }) => {
        wrapper = createComponent({ value: { data: value } });

        expect(wrapper.find(GlToken).text()).toContain(text);
        expect(wrapper.find(GlIcon).props('name')).toBe(icon);
      },
    );

    it('renders provided statuses as suggestions', async () => {
      const suggestions = wrapper.findAll(GlFilteredSearchSuggestion);

      expect(suggestions).toHaveLength(mockStatuses.length);
      mockStatuses.forEach((status, index) => {
        const iconEl = suggestions.at(index).find(GlIcon);

        expect(iconEl.exists()).toBe(true);
        expect(iconEl.props('name')).toBe(status.icon);
        expect(suggestions.at(index).text()).toBe(status.text);
      });
    });
  });
});
