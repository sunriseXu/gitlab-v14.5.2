# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::IngestReportSliceService do
  let(:service_object) { described_class.new(pipeline, finding_maps) }
  let(:pipeline) { create(:ci_pipeline) }
  let(:finding_maps) { [create(:finding_map)] }

  describe '#execute' do
    subject(:ingest_report_slice) { service_object.execute }

    before do
      described_class::TASKS.each do |task_name|
        task = Object.const_get("Security::Ingestion::Tasks::#{task_name}", false)

        allow(task).to receive(:execute)
      end
    end

    it 'runs the series of tasks in correct order' do
      ingest_report_slice

      expect(Security::Ingestion::Tasks::IngestIdentifiers).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestFindings).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestVulnerabilities).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::AttachFindingsToVulnerabilities).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestFindingPipelines).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestFindingIdentifiers).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestFindingLinks).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestFindingSignatures).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestVulnerabilityFlags).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestIssueLinks).to have_received(:execute).ordered.with(pipeline, finding_maps)
      expect(Security::Ingestion::Tasks::IngestRemediations).to have_received(:execute).ordered.with(pipeline, finding_maps)
    end

    context 'when an exception happens' do
      let(:mock_task_1) { double(:task) }
      let(:mock_task_2) { double(:task) }

      before do
        allow(mock_task_1).to receive(:execute) { |pipeline, *| pipeline.update_column(:updated_at, 3.months.from_now) }
        allow(mock_task_2).to receive(:execute) { raise 'foo' }

        allow(Security::Ingestion::Tasks).to receive(:const_get).with(:IngestIdentifiers, false).and_return(mock_task_1)
        allow(Security::Ingestion::Tasks).to receive(:const_get).with(:IngestFindings, false).and_return(mock_task_2)
      end

      it 'rollsback the recent changes to not to leave the database in an inconsistent state' do
        expect { ingest_report_slice }.to raise_error('foo')
                                      .and not_change { pipeline.reload.updated_at }
      end
    end
  end
end
