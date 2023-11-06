# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Mutations::Vulnerabilities::Dismiss do
  include GraphqlHelpers

  let(:mutation) { described_class.new(object: nil, context: { current_user: user }, field: nil) }

  describe '#resolve' do
    let_it_be(:vulnerability) { create(:vulnerability, :with_findings) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability_id) { GitlabSchema.id_from_object(vulnerability).to_s }

    let(:comment) { 'Dismissal Feedback' }
    let(:mutated_vulnerability) { subject[:vulnerability] }

    subject { mutation.resolve(id: vulnerability_id, comment: comment, dismissal_reason: 'used_in_tests') }

    context 'when the user can dismiss the vulnerability' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when user does not have access to the project' do
        it 'raises an error' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'with invalid params' do
        let(:vulnerability_id) { global_id_of(user) }

        it 'raises an error' do
          expect { subject }.to raise_error(::GraphQL::CoercionError)
        end
      end

      context 'when user has access to the project' do
        before do
          vulnerability.project.add_developer(user)
        end

        it 'returns the dismissed vulnerability' do
          expect(mutated_vulnerability).to eq(vulnerability)
          expect(mutated_vulnerability).to be_dismissed
          expect(subject[:errors]).to be_empty
        end
      end
    end
  end
end
