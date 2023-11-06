# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Scan do
  describe 'associations' do
    it { is_expected.to belong_to(:build) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:pipeline) }
    it { is_expected.to have_many(:findings) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:build_id) }
    it { is_expected.to validate_presence_of(:scan_type) }

    describe 'info' do
      let(:scan) { build(:security_scan, info: info) }

      subject { scan.errors.details[:info] }

      before do
        scan.validate
      end

      context 'when the value for info field is valid' do
        let(:info) { { errors: [{ type: 'Foo', message: 'Message' }] } }

        it { is_expected.to be_empty }
      end

      context 'when the value for info field is invalid' do
        let(:info) { { errors: [{ type: 'Foo' }] } }

        it { is_expected.not_to be_empty }
      end
    end
  end

  describe '#name' do
    it { is_expected.to delegate_method(:name).to(:build) }
  end

  describe '#has_errors?' do
    let(:scan) { build(:security_scan, info: info) }

    subject { scan.has_errors? }

    context 'when the info attribute is nil' do
      let(:info) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when the info attribute presents' do
      let(:info) { { errors: errors } }

      context 'when there is no error' do
        let(:errors) { [] }

        it { is_expected.to be_falsey }
      end

      context 'when there are errors' do
        let(:errors) { [{ type: 'Foo', message: 'Bar' }] }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '.by_scan_types' do
    let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast) }
    let_it_be(:dast_scan) { create(:security_scan, scan_type: :dast) }

    let(:expected_scans) { [sast_scan] }

    subject { described_class.by_scan_types(:sast) }

    it { is_expected.to match_array(expected_scans) }

    context 'when an invalid enum value is given' do
      subject { described_class.by_scan_types([:sast, :generic]) }

      it { is_expected.to match_array(expected_scans) }
    end
  end

  describe '.latest_successful' do
    let!(:first_successful_scan) { create(:security_scan, latest: false, status: :succeeded) }
    let!(:second_successful_scan) { create(:security_scan, latest: true, status: :succeeded) }
    let!(:failed_scan) { create(:security_scan, latest: true, status: :failed) }

    subject { described_class.latest_successful }

    it { is_expected.to match_array([second_successful_scan]) }
  end

  describe '.by_build_ids' do
    let!(:sast_scan) { create(:security_scan, scan_type: :sast) }
    let!(:dast_scan) { create(:security_scan, scan_type: :dast, build: sast_scan.build) }
    let(:expected_scans) { [sast_scan, dast_scan] }

    subject { described_class.by_build_ids(expected_scans.map(&:build_id)) }

    it { with_cross_joins_prevented { is_expected.to match_array(expected_scans) } }
  end

  describe '.has_dismissal_feedback' do
    let(:project_1) { create(:project) }
    let(:project_2) { create(:project) }
    let(:scan_1) { create(:security_scan, project: project_1) }
    let(:scan_2) { create(:security_scan, project: project_2) }
    let(:expected_scans) { [scan_1] }

    subject { described_class.has_dismissal_feedback }

    before do
      create(:vulnerability_feedback, :dismissal, project: project_1, category: scan_1.scan_type)
      create(:vulnerability_feedback, :issue, project: project_2, category: scan_2.scan_type)
    end

    it { is_expected.to match_array(expected_scans) }
  end

  describe '.without_errors' do
    let(:scan_1) { create(:security_scan, :with_error) }
    let(:scan_2) { create(:security_scan) }

    subject { described_class.without_errors }

    it { is_expected.to contain_exactly(scan_2) }
  end

  describe '.latest' do
    let!(:latest_scan) { create(:security_scan, latest: true) }
    let!(:retried_scan) { create(:security_scan, latest: false) }

    subject { described_class.latest }

    it { is_expected.to match_array([latest_scan]) }
  end

  describe '#report_findings' do
    let(:artifact) { create(:ee_ci_job_artifact, :dast) }
    let(:scan) { create(:security_scan, build: artifact.job) }
    let(:artifact_finding_uuids) { artifact.security_report.findings.map(&:uuid) }

    subject { scan.report_findings.map(&:uuid) }

    it { is_expected.to match_array(artifact_finding_uuids) }
  end

  describe '#processing_errors' do
    let(:scan) { build(:security_scan, :with_error) }

    subject { scan.processing_errors }

    it { is_expected.to eq([{ 'type' => 'ParsingError', 'message' => 'Unknown error happened' }]) }
  end

  describe '#processing_errors=' do
    let(:scan) { create(:security_scan) }

    subject(:set_processing_errors) { scan.processing_errors = [:foo] }

    it 'sets the processing errors' do
      expect { set_processing_errors }.to change { scan.info['errors'] }.from(nil).to([:foo])
    end
  end

  describe '#add_processing_error!' do
    let(:error) { { type: 'foo', message: 'bar' } }

    subject(:add_processing_error) { scan.add_processing_error!(error) }

    context 'when the scan does not have any errors' do
      let(:scan) { create(:security_scan) }

      it 'persists the error' do
        expect { add_processing_error }.to change { scan.reload.info['errors'] }.from(nil).to([{ 'type' => 'foo', 'message' => 'bar' }])
      end
    end

    context 'when the scan already has some errors' do
      let(:scan) { create(:security_scan, :with_error) }

      it 'persists the new error with the existing ones' do
        expect { add_processing_error }.to change { scan.reload.info['errors'] }.from([{ 'type' => 'ParsingError', 'message' => 'Unknown error happened' }])
                                                                                .to([{ 'type' => 'ParsingError', 'message' => 'Unknown error happened' }, { 'type' => 'foo', 'message' => 'bar' }])
      end
    end
  end

  it_behaves_like 'having unique enum values'

  it 'sets `project_id` and `pipeline_id` before save' do
    scan = create(:security_scan)
    scan.update_columns(project_id: nil, pipeline_id: nil)

    scan.save!

    expect(scan.project_id).to eq(scan.build.project_id)
    expect(scan.pipeline_id).to eq(scan.build.commit_id)
  end
end
