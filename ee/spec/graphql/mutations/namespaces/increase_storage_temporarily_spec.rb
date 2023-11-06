# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Namespaces::IncreaseStorageTemporarily do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { user.namespace }

  subject(:mutation) { described_class.new(object: nil, context: { current_user: user }, field: nil) }

  describe '#resolve' do
    subject { mutation.resolve(id: namespace.to_global_id.to_s) }

    before do
      allow_next_instance_of(EE::Namespace::RootStorageSize, namespace) do |root_storage|
        allow(root_storage).to receive(:usage_ratio).and_return(0.5)
      end
    end

    context 'when user is not the admin of the namespace' do
      let(:user) { create(:user) }

      it 'raises a not accessible error' do
        expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
      end
    end

    context 'when the user can admin the namespace' do
      it 'sets temporary_storage_increase_ends_on' do
        expect(namespace.temporary_storage_increase_ends_on).to be_nil

        subject

        expect(subject[:namespace]).to be_present
        expect(subject[:errors]).to be_empty
        expect(namespace.reload.temporary_storage_increase_ends_on).to be_present
      end
    end

    context 'with invalid params' do
      let_it_be(:namespace) { user }

      it 'raises an error' do
        expect { subject }.to raise_error(::GraphQL::CoercionError)
      end
    end
  end
end
