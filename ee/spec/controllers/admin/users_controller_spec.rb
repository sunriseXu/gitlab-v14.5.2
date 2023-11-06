# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::UsersController do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }

  before do
    sign_in(admin)
  end

  describe 'GET #index' do
    it 'eager loads obstacles to user deletion' do
      get :index

      expect(assigns(:users).first.association(:oncall_schedules)).to be_loaded
      expect(assigns(:users).first.association(:escalation_policies)).to be_loaded
    end
  end

  describe 'POST update' do
    context 'updating name' do
      shared_examples_for 'admin can update the name of a user' do
        it 'updates the name' do
          params = {
            id: user.to_param,
            user: {
              name: 'New Name'
            }
          }

          put :update, params: params

          expect(response).to redirect_to(admin_user_path(user))
          expect(user.reload.name).to eq('New Name')
        end
      end

      context 'when `disable_name_update_for_users` feature is available' do
        before do
          stub_licensed_features(disable_name_update_for_users: true)
        end

        context 'when the ability to update their name is disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: true)
          end

          it_behaves_like 'admin can update the name of a user'
        end

        context 'when the ability to update their name is not disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: false)
          end

          it_behaves_like 'admin can update the name of a user'
        end
      end

      context 'when `disable_name_update_for_users` feature is not available' do
        before do
          stub_licensed_features(disable_name_update_for_users: false)
        end

        it_behaves_like 'admin can update the name of a user'
      end
    end
  end

  describe 'POST #reset_runner_minutes' do
    subject { post :reset_runners_minutes, params: { id: user } }

    before do
      allow_next_instance_of(Ci::Minutes::ResetUsageService) do |instance|
        allow(instance).to receive(:execute).and_return(clear_runners_minutes_service_result)
      end
    end

    context 'when the reset is successful' do
      let(:clear_runners_minutes_service_result) { true }

      it 'redirects to group path' do
        subject

        expect(response).to redirect_to(admin_user_path(user))
        expect(controller).to set_flash[:notice]
      end
    end

    context 'when the reset is not successful' do
      let(:clear_runners_minutes_service_result) { false }

      it 'redirects back to group edit page' do
        subject

        expect(response).to render_template(:edit)
        expect(controller).to set_flash.now[:error]
      end
    end
  end

  describe "POST #impersonate" do
    let_it_be(:user) { create(:user) }

    before do
      stub_licensed_features(extended_audit_events: true)
    end

    it 'creates an AuditEvent record' do
      expect { post :impersonate, params: { id: user.username } }.to change { AuditEvent.count }.by(1)
    end
  end
end
