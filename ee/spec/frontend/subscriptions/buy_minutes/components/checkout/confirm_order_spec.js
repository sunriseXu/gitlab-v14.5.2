import { GlButton, GlLoadingIcon } from '@gitlab/ui';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import VueApollo from 'vue-apollo';
import Api from 'ee/api';
import { STEPS } from 'ee/subscriptions/constants';
import stateQuery from 'ee/subscriptions/graphql/queries/state.query.graphql';
import ConfirmOrder from 'ee/vue_shared/purchase_flow/components/checkout/confirm_order.vue';
import { GENERAL_ERROR_MESSAGE } from 'ee/vue_shared/purchase_flow/constants';
import { stateData as initialStateData, subscriptionName } from 'ee_jest/subscriptions/mock_data';
import { createMockApolloProvider } from 'ee_jest/vue_shared/purchase_flow/spec_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import flash from '~/flash';
import * as UrlUtility from '~/lib/utils/url_utility';
import flushPromises from 'helpers/flush_promises';

jest.mock('~/lib/utils/url_utility');
jest.mock('~/flash');
jest.mock('ee/api.js');

describe('Confirm Order', () => {
  let mockApolloProvider;
  let wrapper;

  const findRootElement = () => wrapper.findByTestId('confirm-order-root');
  const findConfirmButton = () => wrapper.findComponent(GlButton);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const localVue = createLocalVue();
  localVue.use(VueApollo);
  const createComponent = (options = {}) => {
    wrapper = extendedWrapper(
      shallowMount(ConfirmOrder, {
        localVue,
        ...options,
      }),
    );
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when rendering', () => {
    describe('when receiving proper step data', () => {
      beforeEach(() => {
        mockApolloProvider = createMockApolloProvider(STEPS, 3);
        createComponent({ apolloProvider: mockApolloProvider });
      });

      it('shows the text "Confirm purchase"', () => {
        expect(findConfirmButton().text()).toBe('Confirm purchase');
      });

      it('the loading indicator should not be visible', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });
    });

    describe('when confirming the order', () => {
      beforeEach(() => {
        mockApolloProvider = createMockApolloProvider([]);
        mockApolloProvider.clients.defaultClient.cache.writeQuery({
          query: stateQuery,
          data: { ...initialStateData, stepList: STEPS, activeStep: STEPS[3] },
        });
        createComponent({ apolloProvider: mockApolloProvider });
        Api.confirmOrder = jest.fn().mockReturnValue(new Promise(jest.fn()));
        findConfirmButton().vm.$emit('click');
      });

      it('calls the confirmOrder API method with the correct params', () => {
        expect(Api.confirmOrder).toHaveBeenCalledTimes(1);
        expect(Api.confirmOrder.mock.calls[0][0]).toEqual({
          setup_for_company: true,
          selected_group: '30',
          active_subscription: subscriptionName,
          new_user: false,
          redirect_after_success: '/path/to/redirect/',
          customer: {
            country: null,
            address_1: null,
            address_2: null,
            city: null,
            state: null,
            zip_code: null,
            company: null,
          },
          subscription: {
            plan_id: null,
            is_addon: true,
            payment_method_id: null,
            quantity: 1,
          },
        });
      });

      it('shows the text "Confirming..."', () => {
        expect(findConfirmButton().text()).toBe('Confirming...');
      });

      it('the loading indicator should be visible', () => {
        expect(findLoadingIcon().exists()).toBe(true);
      });
    });

    describe('when confirming the purchase', () => {
      const location = 'group/location/path';

      beforeEach(() => {
        mockApolloProvider = createMockApolloProvider(STEPS, 3);
        createComponent({ apolloProvider: mockApolloProvider });
      });

      it('redirects to the location if it succeeds', async () => {
        Api.confirmOrder = jest.fn().mockResolvedValueOnce({ data: { location } });
        findConfirmButton().vm.$emit('click');
        await flushPromises();

        expect(UrlUtility.redirectTo).toHaveBeenCalledTimes(1);
        expect(UrlUtility.redirectTo).toHaveBeenCalledWith(location);
      });

      it('shows an error if it fails', async () => {
        const errors = 'an error';
        Api.confirmOrder = jest.fn().mockResolvedValueOnce({ data: { errors } });
        findConfirmButton().vm.$emit('click');
        await flushPromises();

        expect(flash.mock.calls[0][0]).toMatchObject({
          message: GENERAL_ERROR_MESSAGE,
          captureError: true,
          error: new Error(JSON.stringify(errors)),
        });
      });
    });

    describe('when failing to receive step data', () => {
      beforeEach(() => {
        mockApolloProvider = createMockApolloProvider([]);
        createComponent({ apolloProvider: mockApolloProvider });
        mockApolloProvider.clients.defaultClient.clearStore();
      });

      afterEach(() => {
        flash.mockClear();
      });

      it('displays an error', () => {
        expect(flash.mock.calls[0][0]).toMatchObject({
          message: GENERAL_ERROR_MESSAGE,
          captureError: true,
          error: expect.any(Error),
        });
      });

      it('does not render the root element', () => {
        expect(findRootElement().exists()).toBe(false);
      });
    });
  });

  describe('when inactive', () => {
    it('does not show buttons', () => {
      mockApolloProvider = createMockApolloProvider(STEPS, 1);
      createComponent({ apolloProvider: mockApolloProvider });

      expect(findConfirmButton().exists()).toBe(false);
    });
  });
});
