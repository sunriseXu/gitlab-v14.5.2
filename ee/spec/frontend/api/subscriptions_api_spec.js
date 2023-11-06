import MockAdapter from 'axios-mock-adapter';
import * as SubscriptionsApi from 'ee/api/subscriptions_api';
import axios from '~/lib/utils/axios_utils';
import httpStatus from '~/lib/utils/http_status';

describe('SubscriptionsApi', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('Hand raise leads', () => {
    describe('sendHandRaiseLead', () => {
      const expectedUrl = `/-/trials/create_hand_raise_lead`;
      const params = {
        namespaceId: 1000,
        companyName: 'ACME',
        companySize: '1-99',
        firstName: 'Joe',
        lastName: 'Doe',
        phoneNumber: '1-234567890',
        country: 'US',
        state: 'CA',
        comment: 'A comment',
      };
      const formParams = {
        namespace_id: 1000,
        company_name: 'ACME',
        company_size: '1-99',
        first_name: 'Joe',
        last_name: 'Doe',
        phone_number: '1-234567890',
        country: 'US',
        state: 'CA',
        comment: 'A comment',
      };

      it('sends hand raise lead parameters', async () => {
        jest.spyOn(axios, 'post');
        mock.onPost(expectedUrl).replyOnce(httpStatus.OK, []);

        const { data } = await SubscriptionsApi.sendHandRaiseLead(params);

        expect(data).toEqual([]);
        expect(axios.post).toHaveBeenCalledWith(expectedUrl, formParams);
      });
    });
  });
});
