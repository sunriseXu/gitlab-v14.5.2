# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::VulnerabilitiesFinder do
  let_it_be(:project) { create(:project) }

  let_it_be(:vulnerability1) do
    create(:vulnerability, :with_findings, :with_issue_links, severity: :low, report_type: :sast, state: :detected, project: project)
  end

  let_it_be(:vulnerability2) do
    create(:vulnerability, :with_findings, resolved_on_default_branch: true, severity: :high, report_type: :dependency_scanning, state: :confirmed, project: project)
  end

  let_it_be(:vulnerability3) do
    create(:vulnerability, :with_findings, severity: :medium, report_type: :dast, state: :dismissed, project: project)
  end

  let(:filters) { {} }
  let(:vulnerable) { project }

  subject { described_class.new(vulnerable, filters).execute }

  it 'returns vulnerabilities of a project' do
    expect(subject).to match_array(project.vulnerabilities)
  end

  context 'when not given a second argument' do
    subject { described_class.new(project).execute }

    it 'does not filter the vulnerability list' do
      expect(subject).to match_array(project.vulnerabilities)
    end
  end

  context 'when filtered by report type' do
    let(:filters) { { report_type: %w[sast dast] } }

    it 'only returns vulnerabilities matching the given report types' do
      is_expected.to contain_exactly(vulnerability1, vulnerability3)
    end
  end

  context 'when filtered by severity' do
    let(:filters) { { severity: %w[medium high] } }

    it 'only returns vulnerabilities matching the given severities' do
      is_expected.to contain_exactly(vulnerability3, vulnerability2)
    end
  end

  context 'when filtered by state' do
    let(:filters) { { state: %w[detected confirmed] } }

    it 'only returns vulnerabilities matching the given states' do
      is_expected.to contain_exactly(vulnerability1, vulnerability2)
    end
  end

  context 'when filtered by scanner external ID' do
    let(:filters) { { scanner: [vulnerability1.finding_scanner_external_id, vulnerability2.finding_scanner_external_id] } }

    it 'only returns vulnerabilities matching the given scanner IDs' do
      is_expected.to contain_exactly(vulnerability1, vulnerability2)
    end
  end

  context 'when filtered by scanner_id' do
    let(:filters) { { scanner_id: [vulnerability1.finding_scanner_id, vulnerability3.finding_scanner_id] } }

    it 'only returns vulnerabilities matching the given scanner IDs' do
      is_expected.to contain_exactly(vulnerability1, vulnerability3)
    end
  end

  context 'when filtered by project' do
    let(:group) { create(:group) }
    let(:another_project) { create(:project, namespace: group) }
    let!(:another_vulnerability) { create(:vulnerability, project: another_project) }
    let(:filters) { { project_id: [another_project.id] } }
    let(:vulnerable) { group }

    before do
      project.update!(namespace: group)
    end

    it 'only returns vulnerabilities matching the given projects' do
      is_expected.to contain_exactly(another_vulnerability)
    end
  end

  context 'when sorted' do
    let(:filters) { { sort: method } }

    context 'ascending by severity' do
      let(:method) { :severity_asc }

      it { is_expected.to eq([vulnerability1, vulnerability3, vulnerability2]) }
    end

    context 'descending by severity' do
      let(:method) { :severity_desc }

      it { is_expected.to eq([vulnerability2, vulnerability3, vulnerability1]) }
    end
  end

  context 'when filtered by has_issues argument' do
    let(:filters) { { has_issues: has_issues } }

    context 'when has_issues is set to true' do
      let(:has_issues) { true }

      it 'only returns vulnerabilities that have issues' do
        is_expected.to contain_exactly(vulnerability1)
      end
    end

    context 'when has_issues is set to false' do
      let(:has_issues) { false }

      it 'only returns vulnerabilities that does not have issues' do
        is_expected.to contain_exactly(vulnerability2, vulnerability3)
      end
    end
  end

  context 'when filtered by has_resolution argument' do
    let(:filters) { { has_resolution: has_resolution } }

    context 'when has_resolution is set to true' do
      let(:has_resolution) { true }

      it 'only returns vulnerabilities that have resolution' do
        is_expected.to contain_exactly(vulnerability2)
      end
    end

    context 'when has_resolution is set to false' do
      let(:has_resolution) { false }

      it 'only returns vulnerabilities that do not have resolution' do
        is_expected.to contain_exactly(vulnerability1, vulnerability3)
      end
    end
  end

  context 'when filtered by more than one property' do
    let_it_be(:vulnerability4) do
      create(:vulnerability, severity: :medium, report_type: :sast, state: :detected, project: project)
    end

    let(:filters) { { report_type: %w[sast], severity: %w[medium] } }

    it 'only returns vulnerabilities matching all of the given filters' do
      is_expected.to contain_exactly(vulnerability4)
    end
  end

  context 'when filtered by image' do
    let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, vulnerability: cluster_vulnerability) }

    let(:filters) { { image: [finding.location['image']] } }
    let(:feature_enabled) { true }

    before do
      stub_feature_flags(vulnerability_location_image_filter: feature_enabled)
    end

    context 'when vulnerability_location_image_filter is disabled' do
      let(:feature_enabled) { false }

      it 'does not include cluster vulnerability' do
        is_expected.not_to contain_exactly(cluster_vulnerability)
      end
    end

    context 'when vulnerability_location_image_filter is enabled' do
      it 'only returns vulnerabilities matching the given image' do
        is_expected.to contain_exactly(cluster_vulnerability)
      end

      context 'when different report_type is passed' do
        let(:filters) { { report_type: %w[dast], image: [finding.location['image']] }}

        it 'returns empty list' do
          is_expected.to be_empty
        end
      end
    end

    context 'when vulnerable is InstanceSecurityDashboard' do
      let(:vulnerable) { InstanceSecurityDashboard.new(project.users.first) }

      it 'does not include cluster vulnerability' do
        is_expected.not_to contain_exactly(cluster_vulnerability)
      end
    end
  end

  context 'when filtered by cluster_id' do
    let_it_be(:cluster_vulnerability) { create(:vulnerability, :cluster_image_scanning, project: project) }
    let_it_be(:finding) { create(:vulnerabilities_finding, :with_cluster_image_scanning_scanning_metadata, vulnerability: cluster_vulnerability) }

    let(:filters) { { cluster_id: [finding.location['cluster_id']] } }

    it 'only returns vulnerabilities matching the given cluster_id' do
      is_expected.to contain_exactly(cluster_vulnerability)
    end

    context 'when different report_type is passed' do
      let(:filters) { { report_type: %w[dast], cluster_id: [finding.location['cluster_id']] }}

      it 'returns empty list' do
        is_expected.to be_empty
      end
    end
  end
end
