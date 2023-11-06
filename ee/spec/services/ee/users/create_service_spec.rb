# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CreateService do
  let_it_be(:current_user) { create(:admin) }

  let(:params) do
    {
      name: 'John Doe',
      username: 'jduser',
      email: 'jd@example.com',
      password: 'mydummypass'
    }
  end

  subject(:service) { described_class.new(current_user, params) }

  describe '#execute' do
    let(:operation) { service.execute }

    context 'audit events' do
      include_examples 'audit event logging' do
        let(:fail_condition!) do
          expect_any_instance_of(User)
            .to receive(:save).and_return(false)
        end

        let(:attributes) do
          {
            author_id: current_user.id,
            entity_id: @resource.id,
            entity_type: 'User',
            details: {
              add: 'user',
              author_name: current_user.name,
              target_id: @resource.id,
              target_type: 'User',
              target_details: @resource.full_path
            }
          }
        end
      end

      context 'when audit is not required' do
        let(:current_user) { nil }

        it 'does not log any audit event' do
          expect { operation }.not_to change(AuditEvent, :count)
        end
      end
    end
  end
end
