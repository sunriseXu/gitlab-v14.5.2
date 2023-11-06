# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a Compliance Framework' do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:current_user) { namespace.owner }

  let(:mutation) do
    graphql_mutation(
      :create_compliance_framework,
      namespace_path: namespace.full_path,
      params: {
        name: 'GDPR',
        description: 'Example Description',
        color: '#ABC123',
        pipeline_configuration_full_path: '.compliance-gitlab-ci.yml@compliance/hipaa'
      }
    )
  end

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:create_compliance_framework)
  end

  shared_examples 'a mutation that creates a compliance framework' do
    it 'creates a new compliance framework' do
      expect { subject }.to change { namespace.compliance_management_frameworks.count }.by 1
    end

    it 'returns the newly created framework', :aggregate_failures do
      subject

      expect(mutation_response['framework']['color']).to eq '#ABC123'
      expect(mutation_response['framework']['name']).to eq 'GDPR'
      expect(mutation_response['framework']['description']).to eq 'Example Description'
      expect(mutation_response['framework']['pipelineConfigurationFullPath']).to eq '.compliance-gitlab-ci.yml@compliance/hipaa'
    end
  end

  context 'framework feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      post_graphql_mutation(mutation, current_user: current_user)
    end

    it_behaves_like 'a mutation that returns errors in the response', errors: ['Not permitted to create framework']
  end

  context 'pipeline configuration feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: false)
      post_graphql_mutation(mutation, current_user: current_user)
    end

    it_behaves_like 'a mutation that returns errors in the response', errors: ['Pipeline configuration full path feature is not available']
  end

  context 'feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    context 'current_user is namespace owner' do
      it_behaves_like 'a mutation that creates a compliance framework'
    end

    context 'current_user is group owner' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:current_user) { create(:user) }

      before do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'a mutation that creates a compliance framework'
    end

    context 'current_user is not namespace owner' do
      let_it_be(:current_user) { create(:user) }

      it 'does not create a new compliance framework' do
        expect { subject }.not_to change { namespace.compliance_management_frameworks.count }
      end

      it_behaves_like 'a mutation that returns errors in the response', errors: ['Not permitted to create framework']
    end
  end
end
