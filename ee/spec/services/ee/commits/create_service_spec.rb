# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Commits::CreateService do
  let(:project) { create(:project) }
  let(:user) { create(:user) }
  let(:branch_name) { 'master' }
  let(:extra_params) { {} }

  before do
    project.add_maintainer(user)
  end

  subject(:service) do
    described_class.new(project, user, start_branch: branch_name, branch_name: branch_name, **extra_params)
  end

  describe '#execute' do
    before do
      stub_licensed_features(repository_size_limit: true)
      project.update!(repository_size_limit: 1)
      allow(project.repository_size_checker).to receive(:current_size).and_return(2)
    end

    subject(:result) { service.execute }

    it 'raises an error if the repositoy exceeds the size limit' do
      expect(Gitlab::ErrorTracking).to receive(:log_exception)
        .with(instance_of(Commits::CreateService::ValidationError)).and_call_original
      expect(result[:status]).to be(:error)
      expect(result[:message]).to eq('Your changes could not be committed, because this repository has exceeded its size limit of 1 Byte by 1 Byte')
    end

    context 'when validating codeowners' do
      let(:extra_params) { { file_path: 'path', actions: [{ file_path: 'a', previous_path: 'b' }] } }

      context 'when the paths are empty' do
        let(:extra_params) { {} }

        it 'does not validate' do
          expect(::Gitlab::CodeOwners::Validator).not_to receive(:new)
          result
        end
      end

      it 'does not validate when the push_rules_supersede_code_owners flag is true' do
        expect(::Gitlab::CodeOwners::Validator).not_to receive(:new)
        result
      end

      it 'validates the code owners file when the push_rules_supersede_code_owners flag is false' do
        stub_feature_flags(push_rules_supersede_code_owners: false)
        expect(::Gitlab::CodeOwners::Validator).to receive(:new).with(project, branch_name, %w[path a b]).and_call_original

        result
      end
    end
  end
end
