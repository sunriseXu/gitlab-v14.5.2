import { GlLink, GlModal } from '@gitlab/ui';
import { createLocalVue, shallowMount, mount } from '@vue/test-utils';
import merge from 'lodash/merge';
import Vuex from 'vuex';
import MetricsImage from 'ee/issue_show/components/incidents/metrics_image.vue';
import createStore from 'ee/issue_show/components/incidents/store';
import waitForPromises from 'helpers/wait_for_promises';

const defaultProps = {
  id: 1,
  filePath: 'test_file_path',
  filename: 'test_file_name',
};

const mockEvent = { preventDefault: jest.fn() };

const localVue = createLocalVue();
localVue.use(Vuex);

describe('Metrics upload item', () => {
  let wrapper;
  let store;

  const mountComponent = (options = {}, mountMethod = mount) => {
    store = createStore();

    wrapper = mountMethod(
      MetricsImage,
      merge(
        {
          localVue,
          store,
          propsData: {
            ...defaultProps,
          },
          provide: { canUpdate: true },
        },
        options,
      ),
    );
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
      wrapper = null;
    }
  });

  const findImageLink = () => wrapper.find(GlLink);
  const findCollapseButton = () => wrapper.find('[data-testid="collapse-button"]');
  const findMetricImageBody = () => wrapper.find('[data-testid="metric-image-body"]');
  const findModal = () => wrapper.find(GlModal);
  const findDeleteButton = () => wrapper.find('[data-testid="delete-button"]');

  const closeModal = () => findModal().vm.$emit('hidden');
  const submitModal = () => findModal().vm.$emit('primary', mockEvent);
  const deleteImage = () => findDeleteButton().vm.$emit('click');

  it('render the metrics image component', () => {
    mountComponent({}, shallowMount);

    expect(wrapper.element).toMatchSnapshot();
  });

  it('shows a link with the correct url', () => {
    const testUrl = 'test_url';
    mountComponent({ propsData: { url: testUrl } });

    expect(findImageLink().attributes('href')).toBe(testUrl);
    expect(findImageLink().text()).toBe(defaultProps.filename);
  });

  describe('expand and collapse', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('the card is expanded by default', () => {
      expect(findMetricImageBody().isVisible()).toBe(true);
    });

    it('the card is collapsed when clicked', async () => {
      findCollapseButton().trigger('click');

      await waitForPromises();

      expect(findMetricImageBody().isVisible()).toBe(false);
    });
  });

  describe('delete functionality', () => {
    it('should open the modal when clicked', async () => {
      mountComponent({ stubs: { GlModal: true } });

      deleteImage();

      await waitForPromises();

      expect(findModal().attributes('visible')).toBe('true');
    });

    describe('when the modal is open', () => {
      beforeEach(() => {
        mountComponent(
          {
            data() {
              return { modalVisible: true };
            },
          },
          shallowMount,
        );
      });

      it('should close the modal when cancelled', async () => {
        closeModal();

        await waitForPromises();

        expect(findModal().attributes('visible')).toBeFalsy();
      });

      it('should delete the image when selected', async () => {
        const dispatchSpy = jest.spyOn(store, 'dispatch').mockImplementation(jest.fn());

        submitModal();

        await waitForPromises();

        expect(dispatchSpy).toHaveBeenCalledWith('deleteImage', defaultProps.id);
      });
    });

    describe('canUpdate permission', () => {
      it('delete button is hidden when user lacks update permissions', () => {
        mountComponent({ provide: { canUpdate: false } });

        expect(findDeleteButton().exists()).toBe(false);
      });
    });
  });
});
