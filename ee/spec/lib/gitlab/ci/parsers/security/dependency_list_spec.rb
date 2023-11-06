# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Parsers::Security::DependencyList do
  let(:parser) { described_class.new(project, sha, pipeline) }
  let(:project) { create(:project) }
  let(:sha) { '4242424242424242' }
  let(:report) { Gitlab::Ci::Reports::DependencyList::Report.new }

  let_it_be(:pipeline) { create :ee_ci_pipeline, :with_dependency_list_report }

  describe '#parse!' do
    before do
      artifact.each_blob do |blob|
        parser.parse!(blob, report)
      end
    end

    context 'with dependency_list artifact' do
      let(:artifact) { pipeline.job_artifacts.last }

      before do
        artifact.each_blob do |blob|
          parser.parse!(blob, report)
        end
      end

      it 'parses all files' do
        blob_path = "/#{project.full_path}/-/blob/#{sha}/yarn/yarn.lock"

        expect(report.dependencies.size).to eq(21)
        expect(report.dependencies[0][:name]).to eq('mini_portile2')
        expect(report.dependencies[0][:version]).to eq('2.2.0')
        expect(report.dependencies[0][:packager]).to eq('Ruby (Bundler)')
        expect(report.dependencies[0][:location][:path]).to eq('rails/Gemfile.lock')

        expect(report.dependencies[12][:name]).to eq('xml-crypto')
        expect(report.dependencies[12][:version]).to eq('0.8.5')
        expect(report.dependencies[12][:packager]).to eq('JavaScript (Yarn)')
        expect(report.dependencies[12][:location][:blob_path]).to eq(blob_path)
        expect(report.dependencies[12][:location][:top_level]).to be_falsey
        expect(report.dependencies[12][:location][:ancestors]).to be_nil

        expect(report.dependencies[13][:name]).to eq('xml-encryption')
        expect(report.dependencies[13][:version]).to eq('0.7.4')
        expect(report.dependencies[13][:location][:top_level]).to be_truthy
        expect(report.dependencies[13][:location][:ancestors]).to be_nil
      end
    end

    context 'with vulnerabilities in the database' do
      let_it_be(:vulnerability) { create(:vulnerability, report_type: :dependency_scanning) }
      let_it_be(:finding) { create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vulnerability) }
      let_it_be(:finding_pipeline) { create(:vulnerabilities_finding_pipeline, finding: finding, pipeline: pipeline) }

      let(:artifact) { pipeline.job_artifacts.last }

      it 'does not causes N+1 query' do
        control_count = ActiveRecord::QueryRecorder.new do
          artifact.each_blob do |blob|
            parser.parse!(blob, report)
          end
        end

        vuln2 = create(:vulnerability, report_type: :dependency_scanning)
        finding2 = create(:vulnerabilities_finding, :with_dependency_scanning_metadata, package: 'mini_portile2', vulnerability: vuln2)
        create(:vulnerabilities_finding_pipeline, finding: finding2, pipeline: pipeline)

        expect do
          ActiveRecord::QueryRecorder.new do
            artifact.each_blob do |blob|
              parser.parse!(blob, report)
            end
          end
        end.not_to exceed_query_limit(control_count)
      end

      it 'merges vulnerability data' do
        vuln_nokogiri = report.dependencies[1][:vulnerabilities]

        expect(report.dependencies.size).to eq(21)
        expect(vuln_nokogiri.size).to eq(1)
        expect(vuln_nokogiri[0][:name]).to eq('Vulnerabilities in libxml2 in nokogiri')
      end

      context 'with newfound dependency' do
        let_it_be(:other_finding) { create(:vulnerabilities_finding, :with_dependency_scanning_metadata, vulnerability: vulnerability, package: 'giri') }
        let_it_be(:finding_pipeline) { create(:vulnerabilities_finding_pipeline, finding: other_finding, pipeline: pipeline) }

        it 'adds new dependency and vulnerability to the report' do
          giri = report.dependencies.detect { |dep| dep[:name] == 'giri' }

          expect(report.dependencies.size).to eq(22)
          expect(giri[:vulnerabilities].size).to eq(1)
        end
      end
    end
  end

  describe '#parse_licenses!' do
    let(:artifact) { create(:ee_ci_job_artifact, :license_scanning) }
    let(:dependency_info) { build(:dependency, :nokogiri, :with_vulnerabilities) }

    before do
      report.add_dependency(dependency)

      artifact.each_blob do |blob|
        parser.parse_licenses!(blob, report)
      end
    end

    context 'with existing license' do
      let(:dependency) { dependency_info }

      it 'apply license to dependency' do
        licenses = report.dependencies.last[:licenses]

        expect(licenses.count).to eq(1)
        expect(licenses[0][:name]).to eq('MIT')
        expect(licenses[0][:url]).to eq('http://opensource.org/licenses/mit-license')
      end
    end

    context 'without existing license' do
      let(:dependency) { dependency_info.merge(name: 'irigokon') }

      it 'does not apply any license if name mismatch' do
        expect(report.dependencies.first[:licenses]).to be_empty
      end
    end
  end
end
