# frozen_string_literal: true

RSpec.shared_examples 'a Geo framework registry' do
  let(:registry_class_factory) { described_class.underscore.tr('/', '_').to_sym }

  context 'scopes' do
    describe 'sync_timed_out' do
      it 'return correct records' do
        record = create(registry_class_factory, :started, last_synced_at: 9.hours.ago)
        create(registry_class_factory, :started, last_synced_at: 1.hour.ago)
        create(registry_class_factory, :failed, last_synced_at: 9.hours.ago)

        expect(described_class.sync_timed_out).to eq [record]
      end
    end
  end

  context 'finders' do
    let!(:failed_item1) { create(registry_class_factory, :failed) }
    let!(:failed_item2) { create(registry_class_factory, :failed) }
    let!(:unsynced_item1) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang
    let!(:unsynced_item2) { create(registry_class_factory) } # rubocop:disable Rails/SaveBang

    describe '.find_registries_never_attempted_sync' do
      it 'returns unsynced items' do
        result = described_class.find_registries_never_attempted_sync(batch_size: 10)

        expect(result).to include(unsynced_item1, unsynced_item2)
      end

      it 'returns items that never have an attempt to sync except some specific item ID' do
        except_id = unsynced_item1.model_record_id

        result = described_class.find_registries_never_attempted_sync(batch_size: 10, except_ids: [except_id])

        expect(result).to include(unsynced_item2)
        expect(result).not_to include(unsynced_item1)
      end
    end

    describe '.find_registries_needs_sync_again' do
      it 'returns failed items' do
        result = described_class.find_registries_needs_sync_again(batch_size: 10)

        expect(result).to include(failed_item1, failed_item2)
      end

      it 'returns failed items except some specific item ID' do
        except_id = failed_item1.model_record_id

        result = described_class.find_registries_needs_sync_again(batch_size: 10, except_ids: [except_id])

        expect(result).to include(failed_item2)
        expect(result).not_to include(failed_item1)
      end

      it 'orders records according to retry_at' do
        failed_item1.update!(retry_at: 2.days.ago)
        failed_item2.update!(retry_at: 4.days.ago)

        result = described_class.find_registries_needs_sync_again(batch_size: 10)

        expect(result.first).to eq failed_item2
      end
    end
  end

  describe '.fail_sync_timeouts' do
    it 'marks started records as failed if they are expired' do
      record1 = create(registry_class_factory, :started, last_synced_at: 9.hours.ago)
      record2 = create(registry_class_factory, :started, last_synced_at: 1.hour.ago) # not yet expired

      described_class.fail_sync_timeouts

      expect(record1.reload.state).to eq described_class::STATE_VALUES[:failed]
      expect(record2.reload.state).to eq described_class::STATE_VALUES[:started]
    end
  end
end
