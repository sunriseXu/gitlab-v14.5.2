# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::EventLog, type: :model do
  describe 'relationships' do
    it { is_expected.to belong_to(:cache_invalidation_event).class_name('Geo::CacheInvalidationEvent').with_foreign_key('cache_invalidation_event_id') }
    it { is_expected.to belong_to(:repositories_changed_event).class_name('Geo::RepositoriesChangedEvent').with_foreign_key('repositories_changed_event_id') }
    it { is_expected.to belong_to(:repository_created_event).class_name('Geo::RepositoryCreatedEvent').with_foreign_key('repository_created_event_id') }
    it { is_expected.to belong_to(:repository_deleted_event).class_name('Geo::RepositoryDeletedEvent').with_foreign_key('repository_deleted_event_id') }
    it { is_expected.to belong_to(:repository_renamed_event).class_name('Geo::RepositoryRenamedEvent').with_foreign_key('repository_renamed_event_id') }
    it { is_expected.to belong_to(:repository_updated_event).class_name('Geo::RepositoryUpdatedEvent').with_foreign_key('repository_updated_event_id') }
    it { is_expected.to belong_to(:reset_checksum_event).class_name('Geo::ResetChecksumEvent').with_foreign_key('reset_checksum_event_id') }
    it { is_expected.to belong_to(:hashed_storage_migrated_event).class_name('Geo::HashedStorageMigratedEvent').with_foreign_key('hashed_storage_migrated_event_id') }
    it { is_expected.to belong_to(:hashed_storage_attachments_event).class_name('Geo::HashedStorageAttachmentsEvent').with_foreign_key('hashed_storage_attachments_event_id') }
    it { is_expected.to belong_to(:job_artifact_deleted_event).class_name('Geo::JobArtifactDeletedEvent').with_foreign_key('job_artifact_deleted_event_id') }
    it { is_expected.to belong_to(:container_repository_updated_event).class_name('Geo::ContainerRepositoryUpdatedEvent').with_foreign_key('container_repository_updated_event_id') }
  end

  describe '.next_unprocessed_event' do
    it 'returns next unprocessed event' do
      processed_event = create(:geo_event_log)
      unprocessed_event = create(:geo_event_log)
      create(:geo_event_log_state, event_id: processed_event.id)

      expect(described_class.next_unprocessed_event).to eq unprocessed_event
    end

    it 'returns the oldest event when there are no processed events yet' do
      oldest_event = create(:geo_event_log)
      create(:geo_event_log)

      expect(described_class.next_unprocessed_event).to eq oldest_event
    end

    it 'returns nil when there are no events yet' do
      expect(described_class.next_unprocessed_event).to be_nil
    end
  end

  describe '.event_classes' do
    it 'returns all event class reflections' do
      reflections = described_class.reflections.map { |_k, v| v.class_name.constantize }

      expect(described_class.event_classes).to contain_exactly(*reflections)
    end
  end

  describe '#event' do
    it 'returns nil when having no event associated' do
      expect(subject.event).to be_nil
    end

    it 'returns repository_created_event when set' do
      repository_created_event = build_stubbed(:geo_repository_created_event)
      subject.repository_created_event = repository_created_event

      expect(subject.event).to eq repository_created_event
    end

    it 'returns repository_updated_event when set' do
      repository_updated_event = build(:geo_repository_updated_event)
      subject.repository_updated_event = repository_updated_event

      expect(subject.event).to eq repository_updated_event
    end

    it 'returns repository_deleted_event when set' do
      repository_deleted_event = build(:geo_repository_deleted_event)
      subject.repository_deleted_event = repository_deleted_event

      expect(subject.event).to eq repository_deleted_event
    end

    it 'returns repository_renamed_event when set' do
      repository_renamed_event = build(:geo_repository_renamed_event)
      subject.repository_renamed_event = repository_renamed_event

      expect(subject.event).to eq repository_renamed_event
    end

    it 'returns repositories_changed_event when set' do
      repositories_changed_event = build(:geo_repositories_changed_event)
      subject.repositories_changed_event = repositories_changed_event

      expect(subject.event).to eq repositories_changed_event
    end

    it 'returns hashed_storage_migrated_event when set' do
      hashed_storage_migrated_event = build(:geo_hashed_storage_migrated_event)
      subject.hashed_storage_migrated_event = hashed_storage_migrated_event

      expect(subject.event).to eq hashed_storage_migrated_event
    end

    it 'returns hashed_storage_attachments_event when set' do
      hashed_storage_attachments_event = build(:geo_hashed_storage_attachments_event)
      subject.hashed_storage_attachments_event = hashed_storage_attachments_event

      expect(subject.event).to eq hashed_storage_attachments_event
    end

    it 'returns job_artifact_deleted_event when set' do
      job_artifact_deleted_event = build(:geo_job_artifact_deleted_event)
      subject.job_artifact_deleted_event = job_artifact_deleted_event

      expect(subject.event).to eq job_artifact_deleted_event
    end

    it 'returns reset_checksum_event when set' do
      reset_checksum_event = build(:geo_reset_checksum_event)
      subject.reset_checksum_event = reset_checksum_event

      expect(subject.event).to eq reset_checksum_event
    end

    it 'returns cache_invalidation_event when set' do
      cache_invalidation_event = build(:geo_cache_invalidation_event)
      subject.cache_invalidation_event = cache_invalidation_event

      expect(subject.event).to eq cache_invalidation_event
    end
  end

  describe '#project_id' do
    it 'returns nil when having no event associated' do
      expect(subject.project_id).to be_nil
    end

    it 'returns nil when an event does not respond to project_id' do
      repositories_changed_event = build(:geo_repositories_changed_event)
      subject.repositories_changed_event = repositories_changed_event

      expect(subject.project_id).to be_nil
    end

    it 'returns event#project_id when an event respond to project_id' do
      repository_updated_event = build(:geo_repository_updated_event)
      subject.repository_updated_event = repository_updated_event

      expect(subject.project_id).to eq repository_updated_event.project_id
    end
  end
end
