# frozen_string_literal: true

FactoryBot.define do
  factory :geo_project_registry, class: 'Geo::ProjectRegistry' do
    project
    last_repository_synced_at { nil }
    last_repository_successful_sync_at { nil }
    last_wiki_synced_at { nil }
    last_wiki_successful_sync_at { nil }
    resync_repository { true }
    resync_wiki { true }
    primary_repository_checksummed { true }
    primary_wiki_checksummed { true }

    trait :dirty do
      resync_repository { true }
      resync_wiki { true }
    end

    trait :repository_dirty do
      resync_repository { true }
      resync_wiki { false }
    end

    trait :wiki_dirty do
      resync_repository { false }
      resync_wiki { true }
    end

    trait :synced do
      last_repository_synced_at { 5.days.ago }
      last_repository_successful_sync_at { 5.days.ago }
      last_wiki_synced_at { 5.days.ago }
      last_wiki_successful_sync_at { 5.days.ago }
      resync_repository { false }
      resync_wiki { false }
    end

    trait :sync_failed do
      last_repository_synced_at { 5.days.ago }
      last_repository_successful_sync_at { nil }
      last_wiki_synced_at { 5.days.ago }
      last_wiki_successful_sync_at { nil }
      resync_repository { true }
      resync_wiki { true }
      repository_retry_count { 1 }
      wiki_retry_count { 1 }
    end

    trait :repository_sync_failed do
      sync_failed

      last_wiki_successful_sync_at { 5.days.ago }
      resync_wiki { false }
      wiki_retry_count { nil }
    end

    trait :existing_repository_sync_failed do
      repository_sync_failed

      last_repository_successful_sync_at { 5.days.ago }
    end

    trait :repository_syncing do
      repository_sync_failed
      repository_retry_count { 0 }
    end

    trait :wiki_sync_failed do
      sync_failed

      last_repository_successful_sync_at { 5.days.ago }
      resync_repository { false }
      repository_retry_count { nil }
    end

    trait :wiki_syncing do
      wiki_sync_failed
      wiki_retry_count { 0 }
    end

    trait :repository_verified do
      repository_verification_checksum_sha { 'f079a831cab27bcda7d81cd9b48296d0c3dd92ee' }
      last_repository_verification_failure { nil }
    end

    trait :repository_verification_failed do
      repository_verification_checksum_sha { nil }
      last_repository_verification_failure { 'Repository checksum did not match' }
    end

    trait :repository_checksum_mismatch do
      last_repository_verification_failure { 'Repository checksum mismatch' }
      repository_checksum_mismatch { true }
    end

    trait :repository_verification_outdated do
      repository_verification_checksum_sha { nil }
      last_repository_verification_failure { nil }
    end

    trait :repository_retrying_verification do
      repository_verification_retry_count { 1 }
      resync_repository { true }
    end

    trait :wiki_verified do
      wiki_verification_checksum_sha { 'e079a831cab27bcda7d81cd9b48296d0c3dd92ef' }
      last_wiki_verification_failure { nil }
    end

    trait :wiki_verification_failed do
      wiki_verification_checksum_sha { nil }
      last_wiki_verification_failure { 'Wiki checksum did not match' }
    end

    trait :wiki_checksum_mismatch do
      last_wiki_verification_failure { 'Wiki checksum mismatch' }
      wiki_checksum_mismatch { true }
    end

    trait :wiki_verification_outdated do
      wiki_verification_checksum_sha { nil }
      last_wiki_verification_failure { nil }
    end

    trait :wiki_retrying_verification do
      wiki_verification_retry_count { 1 }
      resync_wiki { true }
    end
  end
end
