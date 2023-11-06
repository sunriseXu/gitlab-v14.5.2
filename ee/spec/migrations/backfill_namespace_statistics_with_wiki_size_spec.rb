# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20210302074524_backfill_namespace_statistics_with_wiki_size.rb')

RSpec.describe BackfillNamespaceStatisticsWithWikiSize do
  let_it_be(:shards) { table(:shards) }
  let_it_be(:shard) { shards.create!(id: 1, name: 'default') }
  let_it_be(:groups) { table(:namespaces) }
  let_it_be(:group1) { groups.create!(id: 10, name: 'test1', path: 'test1', type: 'Group') }
  let_it_be(:group2) { groups.create!(id: 20, name: 'test2', path: 'test2', type: 'Group') }
  let_it_be(:group3) { groups.create!(id: 30, name: 'test3', path: 'test3', type: 'Group') }
  let_it_be(:group4) { groups.create!(id: 40, name: 'test4', path: 'test4', type: 'Group') }
  let_it_be(:group_wiki_repository) { table(:group_wiki_repositories) }
  let_it_be(:group1_repo) { group_wiki_repository.create!(shard_id: 1, group_id: 10, disk_path: 'foo1') }
  let_it_be(:group2_repo) { group_wiki_repository.create!(shard_id: 1, group_id: 20, disk_path: 'foo2') }
  let_it_be(:group3_repo) { group_wiki_repository.create!(shard_id: 1, group_id: 30, disk_path: 'foo3') }

  describe '#up' do
    it 'correctly schedules background migrations' do
      stub_const("#{described_class}::BATCH_SIZE", 2)

      Sidekiq::Testing.fake! do
        freeze_time do
          migrate!

          aggregate_failures do
            expect(described_class::MIGRATION)
              .to be_scheduled_migration([10, 20], ['wiki_size'])

            expect(described_class::MIGRATION)
              .to be_scheduled_delayed_migration(2.minutes, [30], ['wiki_size'])

            expect(BackgroundMigrationWorker.jobs.size).to eq(2)
          end
        end
      end
    end
  end
end
