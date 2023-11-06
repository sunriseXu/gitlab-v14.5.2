# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Security::Common do
  describe '#parse!' do
    where(vulnerability_finding_signatures_enabled: [true, false])
    with_them do
      let_it_be(:pipeline) { create(:ci_pipeline) }

      let(:artifact) { build(:ci_job_artifact, :common_security_report) }
      let(:report) { Gitlab::Ci::Reports::Security::Report.new(artifact.file_type, pipeline, 2.weeks.ago) }
      let(:location) { ::Gitlab::Ci::Reports::Security::Locations::DependencyScanning.new(file_path: 'yarn/yarn.lock', package_version: 'v2', package_name: 'saml2') }
      let(:tracking_data) { nil }

      before do
        allow_next_instance_of(described_class) do |parser|
          allow(parser).to receive(:create_location).and_return(location)
          allow(parser).to receive(:tracking_data).and_return(tracking_data)
        end

        artifact.each_blob { |blob| described_class.parse!(blob, report, vulnerability_finding_signatures_enabled) }
      end

      describe 'schema validation' do
        let(:validator_class) { Gitlab::Ci::Parsers::Security::Validators::SchemaValidator }
        let(:parser) { described_class.new('{}', report, vulnerability_finding_signatures_enabled, validate: validate) }

        subject(:parse_report) { parser.parse! }

        before do
          allow(validator_class).to receive(:new).and_call_original
        end

        context 'when the validate flag is set as `true`' do
          let(:validate) { true }
          let(:valid?) { false }

          before do
            allow_next_instance_of(validator_class) do |instance|
              allow(instance).to receive(:valid?).and_return(valid?)
              allow(instance).to receive(:errors).and_return(['foo'])
            end

            allow(parser).to receive_messages(create_scanner: true, create_scan: true, collate_remediations: [])
          end

          context 'when the report data is not valid according to the schema' do
            it 'does not try to create report entities' do
              parse_report

              expect(parser).not_to have_received(:create_scanner)
              expect(parser).not_to have_received(:create_scan)
              expect(parser).not_to have_received(:collate_remediations)
            end
          end

          context 'when the report data is valid according to the schema' do
            let(:valid?) { true }

            it 'keeps the execution flow as normal' do
              parse_report

              expect(parser).to have_received(:create_scanner)
              expect(parser).to have_received(:create_scan)
              expect(parser).to have_received(:collate_remediations)
            end
          end
        end
      end

      describe 'parsing remediations' do
        let(:expected_remediation) { create(:ci_reports_security_remediation, diff: '') }

        it 'finds remediation with same cve' do
          finding = report.findings.find { |x| x.compare_key == "CVE-1020" }
          remediation = { 'fixes' => [{ 'cve' => 'CVE-1020' }], 'summary' => '', 'diff' => '' }

          expect(Gitlab::Json.parse(finding.raw_metadata).dig('remediations').first).to include remediation
          expect(finding.remediations.first.checksum).to eq(expected_remediation.checksum)
        end

        it 'finds remediation with same id' do
          finding = report.findings.find { |x| x.compare_key == "CVE-1030" }
          remediation = { 'fixes' => [{ 'cve' => 'CVE', 'id' => 'bb2fbeb1b71ea360ce3f86f001d4e84823c3ffe1a1f7d41ba7466b14cfa953d3' }], 'summary' => '', 'diff' => '' }

          expect(Gitlab::Json.parse(finding.raw_metadata).dig('remediations').first).to include remediation
          expect(finding.remediations.first.checksum).to eq(expected_remediation.checksum)
        end

        it 'does not assign any remediation to the finding if there exists no related remediation' do
          finding = report.findings.find { |x| x.compare_key == 'yarn/yarn.lock:saml2-js:gemnasium:9952e574-7b5b-46fa-a270-aeb694198a98' }

          expect(Gitlab::Json.parse(finding.raw_metadata).dig('remediations').first).to be_nil
          expect(finding.remediations).to match([])
        end

        it 'does not find remediation with different id' do
          fix_with_id = {
            "fixes": [
              {
               "id": "2134",
               "cve": "CVE-1"
              }
            ],
            "summary": "",
            "diff": ""
          }

          report.findings.map do |finding|
            expect(Gitlab::Json.parse(finding.raw_metadata).dig('remediations')).not_to include(fix_with_id)
          end
        end
      end

      describe 'parsing scan' do
        it 'returns scan object for each finding' do
          scans = report.findings.map(&:scan)

          expect(scans.map(&:status).all?('success')).to be(true)
          expect(scans.map(&:type).all?('dependency_scanning')).to be(true)
          expect(scans.map(&:start_time).all?('placeholder-value')).to be(true)
          expect(scans.map(&:end_time).all?('placeholder-value')).to be(true)
          expect(scans.size).to eq(3)
          expect(scans.first).to be_a(::Gitlab::Ci::Reports::Security::Scan)
        end
      end
    end
  end
end
