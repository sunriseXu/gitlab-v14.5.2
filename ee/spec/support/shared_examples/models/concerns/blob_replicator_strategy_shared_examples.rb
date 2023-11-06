# frozen_string_literal: true

# Include these shared examples in specs of Replicators that include
# BlobReplicatorStrategy.
#
# Required let variables:
#
# - model_record: A valid, unpersisted instance of the model class. Or a valid,
#                 persisted instance of the model class in a not-yet loaded let
#                 variable (so we can trigger creation).
#
RSpec.shared_examples 'a blob replicator' do
  include EE::GeoHelpers

  let_it_be(:primary) { create(:geo_node, :primary) }
  let_it_be(:secondary) { create(:geo_node) }

  subject(:replicator) { model_record.replicator }

  before do
    stub_current_geo_node(primary)
  end

  it_behaves_like 'a replicator'

  # This could be included in each model's spec, but including it here is DRYer.
  include_examples 'a replicable model' do
    let(:replicator_class) { described_class }
  end

  describe '#handle_after_create_commit' do
    it 'creates a Geo::Event' do
      model_record.save!

      expect do
        replicator.handle_after_create_commit
      end.to change { ::Geo::Event.count }.by(1)

      expect(::Geo::Event.last.attributes).to include(
        "replicable_name" => replicator.replicable_name, "event_name" => "created", "payload" => { "model_record_id" => replicator.model_record.id })
    end

    it 'calls #after_verifiable_update' do
      expect(replicator).to receive(:after_verifiable_update)

      replicator.handle_after_create_commit
    end

    context 'when replication feature flag is disabled' do
      before do
        stub_feature_flags(replicator.replication_enabled_feature_key => false)
      end

      it 'does not call #after_verifiable_update' do
        expect(replicator).not_to receive(:after_verifiable_update)

        replicator.handle_after_create_commit
      end

      it 'does not publish' do
        expect(replicator).not_to receive(:publish)

        replicator.handle_after_create_commit
      end
    end
  end

  describe '#handle_after_destroy' do
    it 'creates a Geo::Event' do
      model_record

      expect do
        replicator.handle_after_destroy
      end.to change { ::Geo::Event.count }.by(1)

      expect(::Geo::Event.last.attributes).to include(
        "replicable_name" => replicator.replicable_name,
        "event_name" => "deleted",
        "payload" => {
          "model_record_id" => replicator.model_record.id,
          "uploader_class" => replicator.carrierwave_uploader.class.to_s,
          "blob_path" => replicator.carrierwave_uploader.relative_path.to_s
        }
      )
    end

    context 'when replication feature flag is disabled' do
      before do
        stub_feature_flags(replicator.replication_enabled_feature_key => false)
      end

      it 'does not publish' do
        expect(replicator).not_to receive(:publish)

        replicator.handle_after_create_commit
      end
    end
  end

  describe 'created event consumption' do
    context "when the blob's project is in replicables for this geo node" do
      it 'invokes Geo::BlobDownloadService' do
        expect(replicator).to receive(:in_replicables_for_current_secondary?).and_return(true)
        service = double(:service)

        expect(service).to receive(:execute)
        expect(::Geo::BlobDownloadService).to receive(:new).with(replicator: replicator).and_return(service)

        replicator.consume(:created)
      end
    end

    context "when the blob's project is not in replicables for this geo node" do
      it 'does not invoke Geo::BlobDownloadService' do
        expect(replicator).to receive(:in_replicables_for_current_secondary?).and_return(false)

        expect(::Geo::BlobDownloadService).not_to receive(:new)

        replicator.consume(:created)
      end
    end
  end

  describe 'deleted event consumption' do
    before do
      model_record.save!
    end

    let!(:model_record_id) { replicator.model_record_id }
    let!(:blob_path) { replicator.carrierwave_uploader.relative_path.to_s }
    let!(:uploader_class) { replicator.carrierwave_uploader.class.to_s }
    let!(:deleted_params) { { model_record_id: model_record_id, uploader_class: uploader_class, blob_path: blob_path } }

    context 'when model_record was deleted from the DB and the replicator only has its ID' do
      before do
        model_record.delete
      end

      # The replicator is instantiated by Geo::EventService on the secondary
      # side, after the model_record no longer exists. This line ensures the
      # replicator does not hold an instance of ActiveRecord::Base, which helps
      # avoid a regression of
      # https://gitlab.com/gitlab-org/gitlab/-/issues/233040
      let(:secondary_side_replicator) { replicator.class.new(model_record_id: model_record_id) }

      it 'invokes Geo::FileRegistryRemovalService' do
        service = double(:service)

        secondary_blob_path = File.join(uploader_class.constantize.root, blob_path)

        expect(service).to receive(:execute)
        expect(::Geo::FileRegistryRemovalService)
          .to receive(:new).with(secondary_side_replicator.replicable_name, model_record_id, secondary_blob_path).and_return(service)

        secondary_side_replicator.consume(:deleted, **deleted_params)
      end

      context 'backward compatibility' do
        let!(:deprecated_deleted_params) { { model_record_id: model_record_id, blob_path: blob_path } }

        it 'invokes Geo::FileRegistryRemovalService when delete event is in deprecated format' do
          service = double(:service)

          expect(service).to receive(:execute)
          expect(::Geo::FileRegistryRemovalService)
            .to receive(:new).with(secondary_side_replicator.replicable_name, model_record_id, blob_path).and_return(service)

          secondary_side_replicator.consume(:deleted, **deprecated_deleted_params)
        end
      end
    end
  end

  describe '#carrierwave_uploader' do
    it 'is implemented' do
      expect do
        replicator.carrierwave_uploader
      end.not_to raise_error
    end
  end

  describe '#model' do
    let(:invoke_model) { replicator.class.model }

    it 'is implemented' do
      expect do
        invoke_model
      end.not_to raise_error
    end

    it 'is a Class' do
      expect(invoke_model).to be_a(Class)
    end
  end

  describe '#blob_path' do
    context 'when the file is locally stored' do
      it 'returns a valid path to a file' do
        file_exist = File.exist?(replicator.blob_path)

        expect(file_exist).to be_truthy
      end
    end
  end

  describe '#calculate_checksum' do
    context 'when the file is locally stored' do
      context 'when the file exists' do
        it 'returns hexdigest of the file' do
          expected = described_class.model.sha256_hexdigest(subject.blob_path)

          expect(subject.calculate_checksum).to eq(expected)
        end
      end

      context 'when the file does not exist' do
        it 'raises an error' do
          allow(subject).to receive(:file_exists?).and_return(false)

          expect { subject.calculate_checksum }.to raise_error('File is not checksummable')
        end
      end
    end

    context 'when the file is remotely stored' do
      it 'raises an error' do
        carrierwave_uploader = double(file_storage?: false)
        allow(subject).to receive(:carrierwave_uploader).and_return(carrierwave_uploader)

        expect { subject.calculate_checksum }.to raise_error('File is not checksummable')
      end
    end
  end
end
