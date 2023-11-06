# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Project'] do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:vulnerability) { create(:vulnerability, project: project, severity: :high) }

  before do
    stub_licensed_features(security_dashboard: true)

    project.add_developer(user)
  end

  it 'includes the ee specific fields' do
    expected_fields = %w[
      vulnerabilities vulnerability_scanners requirement_states_count
      vulnerability_severities_count packages compliance_frameworks vulnerabilities_count_by_day
      security_dashboard_path iterations iteration_cadences repository_size_excess actual_repository_size_limit
      code_coverage_summary api_fuzzing_ci_configuration corpuses path_locks incident_management_escalation_policies
      incident_management_escalation_policy scan_execution_policies network_policies
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'security_scanners' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, sha: project.commit.id, ref: project.default_branch) }
    let_it_be(:user) { create(:user) }

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            securityScanners {
              enabled
              available
              pipelineRun
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      create(:ci_build, :success, :sast, pipeline: pipeline)
      create(:ci_build, :success, :dast, pipeline: pipeline)
      create(:ci_build, :success, :license_scanning, pipeline: pipeline)
      create(:ci_build, :pending, :secret_detection, pipeline: pipeline)
    end

    it 'returns a list of analyzers enabled for the project' do
      query_result = subject.dig('data', 'project', 'securityScanners', 'enabled')
      expect(query_result).to match_array(%w[SAST DAST SECRET_DETECTION])
    end

    it 'returns a list of analyzers which were run in the last pipeline for the project' do
      query_result = subject.dig('data', 'project', 'securityScanners', 'pipelineRun')
      expect(query_result).to match_array(%w[DAST SAST])
    end
  end

  describe 'vulnerabilities' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let_it_be(:vulnerability) do
      create(:vulnerability, :detected, :critical, project: project, title: 'A terrible one!')
    end

    let_it_be(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            vulnerabilities {
              nodes {
                title
                severity
                state
              }
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    it "returns the project's vulnerabilities" do
      vulnerabilities = subject.dig('data', 'project', 'vulnerabilities', 'nodes')

      expect(vulnerabilities.count).to be(1)
      expect(vulnerabilities.first['title']).to eq('A terrible one!')
      expect(vulnerabilities.first['state']).to eq('DETECTED')
      expect(vulnerabilities.first['severity']).to eq('CRITICAL')
    end
  end

  describe 'code coverage summary field' do
    subject { described_class.fields['codeCoverageSummary'] }

    it { is_expected.to have_graphql_type(Types::Ci::CodeCoverageSummaryType) }
  end

  describe 'compliance_frameworks' do
    it 'queries in batches', :request_store, :use_clean_rails_memory_store_caching do
      projects = create_list(:project, 2, :with_compliance_framework)

      projects.each do |p|
        p.add_maintainer(user)
        # Cache warm up: runs authorization for each user.
        resolve_field(:id, p, current_user: user)
      end

      results = batch_sync(max_queries: 1) do
        projects.flat_map do |p|
          resolve_field(:compliance_frameworks, p, current_user: user)
        end
      end
      frameworks = results.flat_map(&:to_a)

      expect(frameworks).to match_array(projects.flat_map(&:compliance_management_framework))
    end
  end

  describe 'push rules field' do
    subject { described_class.fields['pushRules'] }

    it { is_expected.to have_graphql_type(Types::PushRulesType) }
  end

  describe 'scan_execution_policies' do
    let(:security_policy_management_project) { create(:project) }
    let(:policy_configuration) { create(:security_orchestration_policy_configuration, project: project, security_policy_management_project: security_policy_management_project) }
    let(:policy_yaml) { Gitlab::Config::Loader::Yaml.new(fixture_file('security_orchestration.yml', dir: 'ee')).load! }
    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            scanExecutionPolicies {
              nodes {
                name
                description
                enabled
                yaml
                updatedAt
              }
            }
          }
        }
      )
    end

    subject { GitlabSchema.execute(query, context: { current_user: user }).as_json }

    before do
      allow_next_found_instance_of(Security::OrchestrationPolicyConfiguration) do |policy|
        allow(policy).to receive(:policy_configuration_valid?).and_return(true)
        allow(policy).to receive(:policy_hash).and_return(policy_yaml)
        allow(policy).to receive(:policy_last_updated_at).and_return(Time.now)
      end

      stub_licensed_features(security_orchestration_policies: true)
      policy_configuration.security_policy_management_project.add_maintainer(user)
    end

    it 'returns associated scan execution policies' do
      policies = subject.dig('data', 'project', 'scanExecutionPolicies', 'nodes')

      expect(policies.count).to be(8)
    end
  end

  describe 'dora field' do
    subject { described_class.fields['dora'] }

    it { is_expected.to have_graphql_type(Types::DoraType) }
  end

  private

  def query_for_project(project)
    graphql_query_for(
      :projects, { ids: [global_id_of(project)] }, "nodes { #{query_nodes(:compliance_frameworks)} }"
    )
  end
end
