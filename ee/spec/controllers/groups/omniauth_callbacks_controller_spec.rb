# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::OmniauthCallbacksController do
  include LoginHelpers
  include ForgeryProtection

  let(:uid) { 'my-uid' }
  let(:user) { create(:user) }
  let(:provider) { :group_saml }
  let(:group) { create(:group, :private) }
  let!(:saml_provider) { create(:saml_provider, group: group) }
  let(:in_response_to) { '12345' }
  let(:last_request_id) { in_response_to }
  let(:saml_response) { instance_double(OneLogin::RubySaml::Response, in_response_to: in_response_to) }

  before do
    stub_licensed_features(group_saml: true)
  end

  def linked_accounts
    Identity.where(user: user, extern_uid: uid, provider: provider)
  end

  def create_linked_user
    create(:omniauth_user, extern_uid: uid, provider: provider, saml_provider: saml_provider)
  end

  def stub_last_request_id(id)
    session["last_authn_request_id"] = id
  end

  context "when request hasn't been validated by omniauth middleware" do
    it "prevents authentication" do
      sign_in(user)

      expect do
        post provider, params: { group_id: group }
      end.to raise_error(AbstractController::ActionNotFound)
    end
  end

  context "valid credentials" do
    before do
      @original_env_config_omniauth_auth = mock_auth_hash(provider, uid, user.email, response_object: saml_response)
      stub_omniauth_provider(provider, context: request)
      stub_last_request_id(last_request_id)
    end

    after do
      Rails.application.env_config['omniauth.auth'] = @original_env_config_omniauth_auth
    end

    shared_examples 'works with session enforcement' do
      it 'stores that a SAML session is active' do
        expect(Gitlab::Auth::GroupSaml::SsoEnforcer).to receive(:new).with(saml_provider).and_call_original
        expect_any_instance_of(Gitlab::Auth::GroupSaml::SsoEnforcer).to receive(:update_session)

        post provider, params: { group_id: group }
      end
    end

    shared_examples "SAML session initiated" do
      it "redirects to RelayState" do
        post provider, params: { group_id: group, RelayState: '/explore' }

        expect(response).to redirect_to('/explore')
      end

      it 'logs group audit event for authentication' do
        audit_event_service = instance_double(AuditEventService)

        allow(AuditEventService).to receive(:new).and_call_original
        expect(AuditEventService).to receive(:new).with(user, group, with: provider)
          .and_return(audit_event_service)
        expect(audit_event_service).to receive_message_chain(:for_authentication, :security_event)

        post provider, params: { group_id: group }
      end

      include_examples 'works with session enforcement'
    end

    shared_examples "and identity already linked" do
      let!(:user) { create_linked_user }

      it_behaves_like "SAML session initiated"

      it "displays a flash message verifying group sign in" do
        post provider, params: { group_id: group }

        expect(flash[:notice]).to match(/Signed in with SAML/i)
      end

      it 'uses existing linked identity' do
        expect { post provider, params: { group_id: group } }.not_to change(linked_accounts, :count)
      end

      it 'skips authenticity token based forgery protection' do
        with_forgery_protection do
          post provider, params: { group_id: group }

          expect(response).not_to be_client_error
          expect(response).not_to be_server_error
        end
      end

      context 'with 2FA' do
        before do
          user.update!(otp_required_for_login: true)
        end

        include_examples 'works with session enforcement'
      end
    end

    context 'when user used to be a member of a group' do
      before do
        user.provisioned_by_group = group
        user.save!
      end

      it "displays a flash message verifying group sign in" do
        post provider, params: { group_id: group }

        expect(flash[:notice]).to match(/Signed in with SAML/i)
      end

      it 'adds linked identity' do
        expect { post provider, params: { group_id: group } }.to change(linked_accounts, :count)
      end

      it 'adds group membership' do
        expect { post provider, params: { group_id: group } }.to change { group.members.count }
      end
    end

    context 'when user was provisioned by other group' do
      before do
        user.provisioned_by_group = create(:group)
        user.save!
      end

      it "displays a flash message verifying group sign in" do
        post provider, params: { group_id: group }

        expect(flash[:notice]).to eq('Login to a GitLab account to link with your SAML identity')
      end

      it 'does not add linked identity' do
        expect { post provider, params: { group_id: group } }.not_to change(linked_accounts, :count)
      end

      it 'does not add group membership' do
        expect { post provider, params: { group_id: group } }.not_to change { group.members.count }
      end
    end

    context "when signed in" do
      before do
        sign_in(user)
      end

      it_behaves_like "and identity already linked"

      context 'oauth linked with different NameID' do
        before do
          create(:identity, user: user, extern_uid: 'some-other-name-id', provider: provider, saml_provider: saml_provider)
        end

        it 'displays warning to user' do
          post provider, params: { group_id: group }

          expect(flash[:notice]).to match(/has already been taken*/)
        end
      end

      context 'oauth already linked to another account' do
        before do
          create_linked_user
        end

        it 'displays warning to user' do
          post provider, params: { group_id: group }

          expect(flash[:notice]).to match(/has already been taken*/)
        end
      end

      context "and identity hasn't been linked" do
        it "links the identity" do
          post provider, params: { group_id: group }

          expect(group).to be_member(user)
        end

        context 'when a default access level is specified in the SAML provider' do
          let!(:saml_provider) do
            create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER)
          end

          it 'sets the access level of the member as per the specified `default_membership_role`' do
            post provider, params: { group_id: group }

            created_member = group.members.find_by(user: user)
            expect(created_member.access_level).to eq(Gitlab::Access::DEVELOPER)
          end
        end

        it_behaves_like "SAML session initiated"

        it "displays a flash indicating the account has been linked" do
          post provider, params: { group_id: group }

          expect(flash[:notice]).to match(/SAML for .* was added/)
        end

        it 'logs group audit event for being added to the group' do
          audit_event_service = instance_double(AuditEventService)

          expect(AuditEventService).to receive(:new).ordered.and_call_original
          expect(AuditEventService).to receive(:new).ordered.with(user, group, action: :create)
            .and_return(audit_event_service)
          expect(audit_event_service).to receive_message_chain(:for_member, :security_event)

          post provider, params: { group_id: group }
        end

        context 'with IdP initiated request' do
          let(:last_request_id) { '99999' }

          it 'redirects to account link page' do
            post provider, params: { group_id: group }

            expect(response).to redirect_to(sso_group_saml_providers_path(group))
          end

          it "lets the user know their account isn't linked yet" do
            post provider, params: { group_id: group }

            expect(flash[:notice]).to eq 'Request to link SAML account must be authorized'
          end
        end

        context 'with enforced_group_managed_accounts enabled' do
          let!(:saml_provider) { create(:saml_provider, :enforced_group_managed_accounts, group: group) }

          it 'redirects to group sign up' do
            post provider, params: { group_id: group }

            expect(response).to redirect_to(group_sign_up_path(group))
          end
        end
      end
    end

    context "when not signed in" do
      context "and identity hasn't been linked" do
        let!(:saml_provider) { create(:saml_provider, :enforced_group_managed_accounts, group: group) }

        context 'when sign_up_on_sso feature flag is disabled' do
          before do
            stub_feature_flags(sign_up_on_sso: false)
          end

          it "redirects to sign in page with flash notice" do
            post provider, params: { group_id: group }

            expect(response).to redirect_to(new_user_session_path)
            expect(flash[:notice]).to start_with("Login to a GitLab account to link with your SAML identity")
          end
        end

        it 'redirects to group sign up page' do
          post provider, params: { group_id: group }

          expect(response).to redirect_to(group_sign_up_path(group))
        end
      end

      it_behaves_like "and identity already linked"
    end
  end

  describe "#failure" do
    include RoutesHelpers

    def fake_error_callback_route
      fake_routes do
        post '/groups/:group_id/-/saml/callback', to: 'groups/omniauth_callbacks#failure'
      end
    end

    def stub_certificate_error
      strategy = OmniAuth::Strategies::GroupSaml.new(nil)
      exception = OneLogin::RubySaml::ValidationError.new("Fingerprint mismatch")
      stub_omniauth_failure(strategy, :invalid_ticket, exception)
    end

    before do
      fake_error_callback_route
      stub_certificate_error
      set_devise_mapping(context: @request)
    end

    context "not signed in" do
      it "doesn't disclose group existence" do
        expect do
          post :failure, params: { group_id: group }
        end.to raise_error(ActionController::RoutingError)
      end

      context "group doesn't exist" do
        it "doesn't disclose group non-existence" do
          expect do
            post :failure, params: { group_id: 'not-a-group' }
          end.to raise_error(ActionController::RoutingError)
        end
      end
    end

    context "with access" do
      before do
        sign_in(user)
      end

      it "has descriptive error flash" do
        post :failure, params: { group_id: group }

        expect(flash[:alert]).to start_with("Unable to sign you in to the group with SAML due to")
        expect(flash[:alert]).to include("Fingerprint mismatch")
      end

      it "redirects back go the SSO page" do
        post :failure, params: { group_id: group }

        expect(response).to redirect_to(sso_group_saml_providers_path)
      end
    end

    context "with access to SAML settings for the group" do
      let(:user) { create_linked_user }

      before do
        group.add_owner(user)
        sign_in(user)
      end

      it "redirects to the settings page" do
        post :failure, params: { group_id: group }

        expect(response).to redirect_to(group_saml_providers_path)
      end
    end
  end
end
