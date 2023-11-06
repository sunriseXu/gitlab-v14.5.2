# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SubscriptionsController do
  let_it_be(:user) { create(:user) }

  shared_examples 'unauthenticated subscription request' do |redirect_from|
    it { is_expected.to have_gitlab_http_status(:redirect) }
    it { is_expected.to redirect_to new_user_registration_path(redirect_from: redirect_from) }

    it 'stores subscription URL for later' do
      subject

      expected_subscription_path = new_subscriptions_path(plan_id: 'bronze_id') if redirect_from == 'checkout'
      expected_subscription_path = buy_minutes_subscriptions_path(plan_id: 'bronze_id') if redirect_from == 'buy_minutes'
      expected_subscription_path = buy_storage_subscriptions_path(plan_id: 'bronze_id') if redirect_from == 'buy_storage'

      expect(controller.stored_location_for(:user)).to eq(expected_subscription_path)
    end
  end

  describe 'GET #new' do
    subject(:get_new) { get :new, params: { plan_id: 'bronze_id' } }

    it_behaves_like 'unauthenticated subscription request', 'checkout'

    context 'with authenticated user' do
      before do
        sign_in(user)
      end

      it { is_expected.to render_template 'layouts/checkout' }
      it { is_expected.to render_template :new }

      context 'when there are groups eligible for the subscription' do
        let_it_be(:group) { create(:group) }

        before do
          group.add_owner(user)

          allow_next_instance_of(
            GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
            user: user,
            namespaces: [group],
            any_self_service_plan: true
          ) do |instance|
            allow(instance).to receive(:execute).and_return(
              instance_double(ServiceResponse, success?: true, payload: [{ namespace: group, account_id: nil }])
            )
          end
        end

        it 'assigns the eligible groups for the subscription' do
          get_new

          expect(assigns(:eligible_groups)).to eq [group]
        end
      end

      context 'when there are no eligible groups for the subscription' do
        it 'assigns eligible groups as an empty array' do
          allow_next_instance_of(
            GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
            user: user,
            namespaces: [],
            any_self_service_plan: true
          ) do |instance|
            allow(instance).to receive(:execute).and_return(instance_double(ServiceResponse, success?: true, payload: []))
          end

          get_new

          expect(assigns(:eligible_groups)).to eq []
        end
      end
    end
  end

  describe 'GET #buy_minutes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:plan_id) { 'ci_minutes' }

    subject(:buy_minutes) { get :buy_minutes, params: { selected_group: group.id } }

    context 'with authenticated user' do
      before do
        group.add_owner(user)
        stub_feature_flags(new_route_ci_minutes_purchase: group)
        sign_in(user)
      end

      context 'when the add-on plan cannot be found' do
        let_it_be(:group) { create(:group) }

        before do
          group.add_owner(user)

          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['CI_1000_MINUTES_PLAN'])
            .and_return({ success: false, data: [] })
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when there are groups eligible for the addon' do
        let_it_be(:group) { create(:group) }

        before do
          group.add_owner(user)

          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['CI_1000_MINUTES_PLAN'])
            .and_return({ success: true, data: [{ 'id' => 'ci_minutes' }] })

          allow_next_instance_of(
            GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
            user: user,
            plan_id: 'ci_minutes',
            namespaces: [group]
          ) do |instance|
            allow(instance).to receive(:execute).and_return(
              instance_double(ServiceResponse, success?: true, payload: [{ namespace: group, account_id: nil }])
            )
          end
        end

        it { is_expected.to render_template 'layouts/checkout' }
        it { is_expected.to render_template :buy_minutes }

        it 'assigns the group for the addon' do
          buy_minutes

          expect(assigns(:group)).to eq group
          expect(assigns(:account_id)).to eq nil
        end

        context 'with :new_route_ci_minutes_purchase disabled' do
          before do
            stub_feature_flags(new_route_ci_minutes_purchase: false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end
    end
  end

  describe 'GET #buy_storage' do
    let_it_be(:group) { create(:group) }

    subject(:buy_storage) { get :buy_storage, params: { selected_group: group.id } }

    context 'with authenticated user' do
      before do
        group.add_owner(user)
        stub_feature_flags(new_route_storage_purchase: group)
        sign_in(user)
      end

      context 'when the add-on plan cannot be found' do
        let_it_be(:group) { create(:group) }

        before do
          group.add_owner(user)

          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['STORAGE_PLAN'])
            .and_return({ success: false, data: [] })
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      context 'when there are groups eligible for the addon' do
        let_it_be(:group) { create(:group) }

        before do
          group.add_owner(user)

          allow(Gitlab::SubscriptionPortal::Client)
            .to receive(:get_plans).with(tags: ['STORAGE_PLAN'])
            .and_return({ success: true, data: [{ 'id' => 'storage' }] })

          allow_next_instance_of(
            GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
            user: user,
            plan_id: 'storage',
            namespaces: [group]
          ) do |instance|
            allow(instance).to receive(:execute).and_return(
              instance_double(ServiceResponse, success?: true, payload: [{ namespace: group, account_id: nil }])
            )
          end
        end

        it { is_expected.to render_template 'layouts/checkout' }
        it { is_expected.to render_template :buy_storage }

        it 'assigns the group for the addon' do
          buy_storage

          expect(assigns(:group)).to eq group
          expect(assigns(:account_id)).to eq nil
        end

        context 'with :new_route_storage_purchase disabled' do
          before do
            stub_feature_flags(new_route_storage_purchase: false)
          end

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end
    end
  end

  describe 'GET #payment_form' do
    subject { get :payment_form, params: { id: 'cc' } }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'with authorized user' do
      before do
        sign_in(user)
        client_response = { success: true, data: { signature: 'x', token: 'y' } }
        allow(Gitlab::SubscriptionPortal::Client).to receive(:payment_form_params).with('cc').and_return(client_response)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns the data attribute of the client response in JSON format' do
        subject
        expect(response.body).to eq('{"signature":"x","token":"y"}')
      end
    end
  end

  describe 'GET #payment_method' do
    subject { get :payment_method, params: { id: 'xx' } }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:redirect) }
      it { is_expected.to redirect_to new_user_session_path }
    end

    context 'with authorized user' do
      before do
        sign_in(user)
        client_response = { success: true, data: { credit_card_type: 'Visa' } }
        allow(Gitlab::SubscriptionPortal::Client).to receive(:payment_method).with('xx').and_return(client_response)
      end

      it { is_expected.to have_gitlab_http_status(:ok) }

      it 'returns the data attribute of the client response in JSON format' do
        subject
        expect(response.body).to eq('{"credit_card_type":"Visa"}')
      end
    end
  end

  describe 'POST #create' do
    subject do
      post :create,
        params: params,
        as: :json
    end

    let(:params) do
      {
        setup_for_company: setup_for_company,
        customer: { company: 'My company', country: 'NL' },
        subscription: { plan_id: 'x', quantity: 2, source: 'some_source' }
      }
    end

    let(:setup_for_company) { true }

    context 'with unauthorized user' do
      it { is_expected.to have_gitlab_http_status(:unauthorized) }
    end

    context 'with authorized user' do
      let_it_be(:service_response) { { success: true, data: 'foo' } }
      let_it_be(:group) { create(:group) }

      before do
        sign_in(user)
        allow_any_instance_of(Subscriptions::CreateService).to receive(:execute).and_return(service_response)
        allow_any_instance_of(EE::Groups::CreateService).to receive(:execute).and_return(group)
      end

      context 'when setting up for a company' do
        it 'updates the setup_for_company attribute of the current user' do
          expect { subject }.to change { user.reload.setup_for_company }.from(nil).to(true)
        end

        it 'creates a group based on the company' do
          expect(Namespace).to receive(:clean_name).with(params.dig(:customer, :company)).and_call_original
          expect_any_instance_of(EE::Groups::CreateService).to receive(:execute)

          subject
        end
      end

      context 'when not setting up for a company' do
        let(:params) do
          {
            setup_for_company: setup_for_company,
            customer: { country: 'NL' },
            subscription: { plan_id: 'x', quantity: 1, source: 'some_source' }
          }
        end

        let(:setup_for_company) { false }

        it 'does not update the setup_for_company attribute of the current user' do
          expect { subject }.not_to change { user.reload.setup_for_company }
        end

        it 'creates a group based on the user' do
          expect(Namespace).to receive(:clean_name).with(user.name).and_call_original
          expect_any_instance_of(EE::Groups::CreateService).to receive(:execute)

          subject
        end
      end

      context 'when an error occurs creating a group' do
        let(:group) { Group.new(path: 'foo') }

        it 'returns the errors in json format' do
          group.valid?
          subject

          expect(response.body).to include({ name: ["can't be blank"] }.to_json)
        end

        context 'when invalid name is passed' do
          let(:group) { Group.new(path: 'foo', name: '<script>alert("attack")</script>') }

          it 'returns the errors in json format' do
            group.valid?
            subject

            expect(Gitlab::Json.parse(response.body)['name']).to match_array([Gitlab::Regex.group_name_regex_message, HtmlSafetyValidator.error_message])
          end
        end
      end

      context 'on successful creation of a subscription' do
        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'returns the group edit location in JSON format' do
          subject

          expect(response.body).to eq({ location: "/-/subscriptions/groups/#{group.path}/edit?plan_id=x&quantity=2" }.to_json)
        end
      end

      context 'on unsuccessful creation of a subscription' do
        let(:service_response) { { success: false, data: { errors: 'error message' } } }

        it { is_expected.to have_gitlab_http_status(:ok) }

        it 'returns the error message in JSON format' do
          subject

          expect(response.body).to eq('{"errors":"error message"}')
        end
      end

      context 'when selecting an existing group' do
        let(:params) do
          {
            selected_group: selected_group.id,
            customer: { country: 'NL' },
            subscription: { plan_id: 'x', quantity: 1, source: 'another_source' },
            redirect_after_success: redirect_after_success
          }
        end

        let_it_be(:redirect_after_success) { nil }

        context 'when the selected group is eligible for a new subscription' do
          let_it_be(:selected_group) { create(:group) }

          before do
            selected_group.add_owner(user)

            allow_next_instance_of(
              GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
              user: user,
              plan_id: params[:subscription][:plan_id],
              namespaces: [selected_group]
            ) do |instance|
              allow(instance)
                .to receive(:execute)
                .and_return(
                  instance_double(ServiceResponse, success?: true, payload: [{ namespace: selected_group, account_id: nil }])
                )
            end
          end

          it 'does not create a group' do
            expect { subject }.to not_change { Group.count }
          end

          it 'returns the selected group location in JSON format' do
            subject

            plan_id = params[:subscription][:plan_id]
            quantity = params[:subscription][:quantity]

            expect(response.body).to eq({ location: "/#{selected_group.path}?plan_id=#{plan_id}&purchased_quantity=#{quantity}" }.to_json)
          end

          it 'tracks for the force_company_trial experiment', :experiment do
            expect(experiment(:force_company_trial)).to track(:create_subscription, namespace: selected_group, user: user).with_context(user: user).on_next_instance

            subject
          end

          context 'when having an explicit redirect' do
            let_it_be(:redirect_after_success) { '/-/path/to/redirect' }

            it { is_expected.to have_gitlab_http_status(:ok) }

            it 'returns the provided redirect path as location' do
              subject

              expect(response.body).to eq({ location: redirect_after_success }.to_json)
            end
          end
        end

        context 'when the selected group is ineligible for a new subscription' do
          let_it_be(:selected_group) { create(:group) }

          before do
            selected_group.add_owner(user)

            allow_next_instance_of(
              GitlabSubscriptions::FetchPurchaseEligibleNamespacesService,
              user: user,
              plan_id: params[:subscription][:plan_id],
              namespaces: [selected_group]
            ) do |instance|
              allow(instance)
                .to receive(:execute)
                .and_return(instance_double(ServiceResponse, success?: true, payload: []))
            end
          end

          it 'does not create a group' do
            expect { subject }.to not_change { Group.count }
          end

          it 'returns a 404 not found' do
            subject

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when selected group is a sub group' do
          let(:selected_group) { create(:group, parent: create(:group))}

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end
      end

      context 'when selecting a non existing group' do
        let(:params) do
          {
            selected_group: non_existing_record_id,
            customer: { country: 'NL' },
            subscription: { plan_id: 'x', quantity: 1, source: 'new_source' }
          }
        end

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end
    end
  end
end
