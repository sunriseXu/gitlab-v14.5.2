# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::BuildService do
  describe '#execute' do
    let(:params) do
      { name: 'John Doe', username: 'jduser', email: 'jd@example.com', password: 'mydummypass' }
    end

    context 'with an admin user' do
      let_it_be(:admin_user) { create(:admin) }

      let(:service) { described_class.new(admin_user, ActionController::Parameters.new(params).permit!) }

      context 'allowed params' do
        let_it_be(:provider) { create(:saml_provider) }

        let(:identity_params) { { extern_uid: 'uid', provider: 'group_saml', saml_provider_id: provider.id } }

        before do
          params.merge!(identity_params)
        end

        context 'with identity' do
          it 'sets all allowed attributes' do
            expect(Identity).to receive(:new).with(hash_including(identity_params)).and_call_original
            expect(ScimIdentity).not_to receive(:new)

            service.execute
          end
        end

        context 'with scim identity' do
          let_it_be(:group) { create(:group) }
          let_it_be(:scim_identity_params) { { extern_uid: 'uid', provider: 'group_scim', group_id: group.id } }

          before do
            params.merge!(scim_identity_params)
          end

          it 'passes allowed attributes to both scim and saml identity' do
            scim_params = scim_identity_params.dup
            scim_params.delete(:provider)

            expect(ScimIdentity).to receive(:new).with(hash_including(scim_params)).and_call_original
            expect(Identity).to receive(:new).with(hash_including(identity_params)).and_call_original

            service.execute
          end

          it 'marks the user as provisioned by group' do
            expect(service.execute.provisioned_by_group_id).to eq(group.id)
          end
        end
      end

      context 'smartcard authentication enabled' do
        before do
          allow(Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(true)
        end

        context 'smartcard params' do
          let(:subject) { '/O=Random Corp Ltd/CN=gitlab-user/emailAddress=gitlab-user@random-corp.org' }
          let(:issuer) { '/O=Random Corp Ltd/CN=Random Corp' }
          let(:smartcard_identity_params) do
            { certificate_subject: subject, certificate_issuer: issuer }
          end

          before do
            params.merge!(smartcard_identity_params)
          end

          it 'sets smartcard identity attributes' do
            expect(SmartcardIdentity).to(
              receive(:new)
                .with(hash_including(issuer: issuer, subject: subject))
                .and_call_original)

            service.execute
          end
        end

        context 'missing smartcard params' do
          it 'works as expected' do
            expect { service.execute }.not_to raise_error
          end
        end
      end

      context 'user signup cap' do
        let(:new_user_signups_cap) { 10 }

        before do
          allow(Gitlab::CurrentSettings).to receive(:new_user_signups_cap).and_return(new_user_signups_cap)
        end

        context 'when user signup cap is set' do
          it 'sets the user state to blocked_pending_approval' do
            user = service.execute

            expect(user).to be_blocked_pending_approval
          end
        end

        context 'when user signup cap is not set' do
          let(:new_user_signups_cap) { nil }

          it 'does not set the user state to blocked_pending_approval' do
            user = service.execute

            expect(user).to be_active
          end
        end
      end
    end
  end
end
