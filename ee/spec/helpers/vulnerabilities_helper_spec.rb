# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VulnerabilitiesHelper do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, :public) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project) }
  let_it_be(:finding) { create(:vulnerabilities_finding, :with_pipeline, project: project, severity: :high) }

  let(:vulnerability) { create(:vulnerability, title: "My vulnerability", project: project, findings: [finding]) }

  before do
    allow(helper).to receive(:current_user).and_return(user)
  end

  RSpec.shared_examples 'vulnerability properties' do
    let(:vulnerability_serializer_hash) do
      vulnerability.slice(
        :id,
        :title,
        :state,
        :severity,
        :confidence,
        :report_type,
        :resolved_on_default_branch,
        :project_default_branch,
        :resolved_by_id,
        :dismissed_by_id,
        :confirmed_by_id)
    end

    let(:finding_serializer_hash) do
      finding.slice(:description,
                    :identifiers,
                    :links,
                    :location,
                    :name,
                    :issue_feedback,
                    :project,
                    :remediations,
                    :solution,
                    :uuid,
                    :details)
    end

    let(:desired_serializer_fields) { %i[metadata identifiers name issue_feedback merge_request_feedback project project_fingerprint scanner uuid details dismissal_feedback false_positive] }

    before do
      vulnerability_serializer_stub = instance_double("VulnerabilitySerializer")
      expect(VulnerabilitySerializer).to receive(:new).and_return(vulnerability_serializer_stub)
      expect(vulnerability_serializer_stub).to receive(:represent).with(vulnerability).and_return(vulnerability_serializer_hash)

      finding_serializer_stub = instance_double("Vulnerabilities::FindingSerializer")
      expect(Vulnerabilities::FindingSerializer).to receive(:new).and_return(finding_serializer_stub)
      expect(finding_serializer_stub).to receive(:represent).with(finding, only: desired_serializer_fields).and_return(finding_serializer_hash)
    end

    around do |example|
      freeze_time { example.run }
    end

    it 'has expected vulnerability properties' do
      expect(subject).to include(
        timestamp: Time.now.to_i,
        new_issue_url: "/#{project.full_path}/-/issues/new?vulnerability_id=#{vulnerability.id}",
        create_jira_issue_url: nil,
        related_jira_issues_path: "/#{project.full_path}/-/integrations/jira/issues?vulnerability_ids%5B%5D=#{vulnerability.id}",
        jira_integration_settings_path: "/#{project.full_path}/-/services/jira/edit",
        has_mr: anything,
        create_mr_url: "/#{project.full_path}/-/vulnerability_feedback",
        discussions_url: "/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}/discussions",
        notes_url: "/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}/notes",
        related_issues_help_path: kind_of(String),
        pipeline: anything,
        can_modify_related_issues: false
      )
    end

    context 'when the issues are disabled for the project' do
      before do
        allow(project).to receive(:issues_enabled?).and_return(false)
      end

      it 'has `new_issue_url` set as nil' do
        expect(subject).to include(new_issue_url: nil)
      end
    end
  end

  describe '#vulnerability_details' do
    before do
      allow(helper).to receive(:can?).and_return(true)
    end

    subject { helper.vulnerability_details(vulnerability, pipeline) }

    describe '[:can_modify_related_issues]' do
      context 'with security dashboard feature enabled' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        context 'when user can manage related issues' do
          before do
            project.add_developer(user)
          end

          it { is_expected.to include(can_modify_related_issues: true) }
        end

        context 'when user cannot manage related issues' do
          it { is_expected.to include(can_modify_related_issues: false) }
        end
      end

      context 'with security dashboard feature disabled' do
        before do
          stub_licensed_features(security_dashboard: false)
          project.add_developer(user)
        end

        it { is_expected.to include(can_modify_related_issues: false) }
      end
    end

    context 'when pipeline exists' do
      subject { helper.vulnerability_details(vulnerability, pipeline) }

      include_examples 'vulnerability properties'

      it 'returns expected pipeline data' do
        expect(subject[:pipeline]).to include(
          id: pipeline.id,
          created_at: pipeline.created_at.iso8601,
          url: be_present
        )
      end
    end

    context 'when pipeline is nil' do
      subject { helper.vulnerability_details(vulnerability, nil) }

      include_examples 'vulnerability properties'

      it 'returns no pipeline data' do
        expect(subject[:pipeline]).to be_nil
      end
    end

    describe '[:has_mr]' do
      subject { helper.vulnerability_details(vulnerability, pipeline)[:has_mr] }

      context 'with existing merge request feedback' do
        before do
          create(:vulnerability_feedback, :merge_request, project: project, pipeline: pipeline, project_fingerprint: finding.project_fingerprint)
        end

        it { is_expected.to be_truthy }
      end

      context 'without feedback' do
        it { is_expected.to be_falsey }
      end
    end

    context 'dismissal descriptions' do
      let(:expected_descriptions) do
        {
          acceptable_risk: "The vulnerability is known, and has not been remediated or mitigated, but is considered to be an acceptable business risk.",
          false_positive: "An error in reporting in which a test result incorrectly indicates the presence of a vulnerability in a system when the vulnerability is not present.",
          mitigating_control: "A management, operational, or technical control (that is, safeguard or countermeasure) employed by an organization that provides equivalent or comparable protection for an information system.",
          used_in_tests: "The finding is not a vulnerability because it is part of a test or is test data.",
          not_applicable: "The vulnerability is known, and has not been remediated or mitigated, but is considered to be in a part of the application that will not be updated."
        }
      end

      let(:translated_descriptions) do
        # Use dynamic translations via N_(...)
        expected_descriptions.values.map { |description| _(description) }
      end

      it 'includes translated dismissal descriptions' do
        Gitlab::I18n.with_locale(:en) do
          # Force loading of the class and configured translations
          Vulnerabilities::DismissalReasonEnum.translated_descriptions
        end

        Gitlab::I18n.with_locale(:zh_CN) do
          expect(subject[:dismissal_descriptions].keys).to eq(expected_descriptions.keys)
          expect(subject[:dismissal_descriptions].values).to eq(translated_descriptions)
        end
      end
    end
  end

  describe '#create_jira_issue_url_for' do
    subject { helper.vulnerability_details(vulnerability, pipeline) }

    let(:jira_integration) { double('Integrations::Jira', new_issue_url_with_predefined_fields: 'https://jira.example.com/new') }

    before do
      allow(helper).to receive(:can?).and_return(true)
      allow(vulnerability.project).to receive(:jira_integration).and_return(jira_integration)
    end

    context 'with jira vulnerabilities integration enabled' do
      before do
        allow(project).to receive(:jira_vulnerabilities_integration_enabled?).and_return(true)
        allow(project).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(true)
      end

      let(:expected_jira_issue_description) do
        <<-JIRA.strip_heredoc
          Issue created from vulnerability [#{vulnerability.id}|http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}]

          h3. Description:

          Description of My vulnerability

          * Severity: high
          * Confidence: medium
          * Location: [maven/src/main/java/com/gitlab/security_products/tests/App.java:29|http://localhost/#{project.full_path}/-/blob/b83d6e391c22777fca1ed3012fce84f633d7fed0/maven/src/main/java/com/gitlab/security_products/tests/App.java#L29]

          ### Solution:

          See vulnerability [#{vulnerability.id}|http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}] for any Solution details.


          h3. Links:

          * [Cipher does not check for integrity first?|https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first]


          h3. Scanner:

          * Name: Find Security Bugs
        JIRA
      end

      it 'delegates rendering URL to Integrations::Jira' do
        expect(jira_integration).to receive(:new_issue_url_with_predefined_fields).with("Investigate vulnerability: #{vulnerability.title}", expected_jira_issue_description)

        subject
      end

      it 'generates url to create issue in Jira' do
        expect(subject[:create_jira_issue_url]).to eq('https://jira.example.com/new')
      end

      context 'when scan property is empty' do
        before do
          vulnerability.finding.scan = nil
        end

        it 'renders description using dedicated template without raising error' do
          expect(jira_integration).to receive(:new_issue_url_with_predefined_fields).with("Investigate vulnerability: #{vulnerability.title}", expected_jira_issue_description)

          subject
        end
      end
    end

    context 'with jira vulnerabilities integration disabled' do
      before do
        allow(project).to receive(:jira_vulnerabilities_integration_enabled?).and_return(false)
        allow(project).to receive(:configured_to_create_issues_from_vulnerabilities?).and_return(false)
      end

      it { expect(subject[:create_jira_issue_url]).to be_nil }
    end
  end

  describe '#vulnerability_finding_data' do
    subject { helper.vulnerability_finding_data(vulnerability) }

    it 'returns finding information' do
      expect(subject.to_h).to match(
        description: finding.description,
        identifiers: kind_of(Array),
        issue_feedback: anything,
        links: finding.links,
        location: finding.location,
        name: finding.name,
        merge_request_feedback: anything,
        project: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        project_fingerprint: finding.project_fingerprint,
        remediations: finding.remediations,
        solution: kind_of(String),
        evidence: kind_of(String),
        scanner: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        request: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        response: kind_of(Grape::Entity::Exposure::NestingExposure::OutputBuilder),
        evidence_source: anything,
        assets: kind_of(Array),
        supporting_messages: kind_of(Array),
        uuid: kind_of(String),
        details: kind_of(Hash),
        dismissal_feedback: anything
      )

      expect(subject[:location]['blob_path']).to match(kind_of(String))
    end

    context 'when there is no file' do
      before do
        vulnerability.finding.location['file'] = nil
        vulnerability.finding.location.delete('blob_path')
      end

      it 'does not have a blob_path if there is no file' do
        expect(subject[:location]).not_to have_key('blob_path')
      end
    end

    context 'with existing dismissal feedback' do
      let_it_be(:feedback) { create(:vulnerability_feedback, :comment, :dismissal, project: project, pipeline: pipeline, project_fingerprint: finding.project_fingerprint) }

      it 'returns dismissal feedback information', :aggregate_failures do
        dismissal_feedback = subject[:dismissal_feedback]
        expect(dismissal_feedback[:dismissal_reason]).to eq(feedback.dismissal_reason)
        expect(dismissal_feedback[:comment_details][:comment]).to eq(feedback.comment)
      end
    end
  end

  describe '#vulnerability_scan_data?' do
    subject { helper.vulnerability_scan_data?(vulnerability) }

    context 'scanner present' do
      before do
        allow(vulnerability).to receive(:scanner).and_return(true)
      end

      it { is_expected.to be_truthy }
    end

    context 'scan present' do
      before do
        allow(vulnerability).to receive(:scanner).and_return(false)
        allow(vulnerability).to receive(:scan).and_return(true)
      end

      it { is_expected.to be_truthy }
    end

    context 'neither scan nor scanner being present' do
      before do
        allow(vulnerability).to receive(:scanner).and_return(false)
        allow(vulnerability).to receive(:scan).and_return(false)
      end

      it { is_expected.to be_falsey }
    end
  end
end
