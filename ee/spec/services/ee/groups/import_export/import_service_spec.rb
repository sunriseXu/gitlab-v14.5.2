# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::ImportExport::ImportService do
  let_it_be(:import_file) { fixture_file_upload('ee/spec/fixtures/group_export_with_wikis.tar.gz') }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) do
    create(:group).tap do |g|
      g.add_owner(user)
    end
  end

  subject(:import_service) { described_class.new(group: group, user: user) }

  before do
    ImportExportUpload.create!(group: group, import_file: import_file)
  end

  context 'when group_wikis feature is enabled' do
    it 'imports group and descendant wiki repositories', :aggregate_failures do
      stub_licensed_features(group_wikis: true)

      expect_next_instance_of(
        Gitlab::ImportExport::Group::GroupAndDescendantsRepoRestorer,
        group: group,
        shared: instance_of(Gitlab::ImportExport::Shared),
        tree_restorer: instance_of(Gitlab::ImportExport::Group::TreeRestorer)
      ) do |restorer|
        expect(restorer).to receive(:restore).and_call_original
      end

      import_service.execute

      expect(group.wiki.repository_exists?).to be true
      expect(group.wiki.list_pages.first.title).to eq 'home'

      group.descendants.each do |subgroup|
        expect(subgroup.wiki.repository_exists?).to be true
        expect(subgroup.wiki.list_pages.first.title).to eq "home_#{subgroup.path}"
      end
    end

    context 'when export file not in ndjson format' do
      let(:import_file) { fixture_file_upload('spec/fixtures/legacy_group_export.tar.gz') }

      it 'does not export group wiki repositories' do
        expect(::Gitlab::ImportExport::Group::GroupAndDescendantsRepoRestorer).not_to receive(:new)

        import_service.execute
      end
    end
  end

  context 'when group_wikis feature is not enabled' do
    it 'does not call the group wiki restorer' do
      expect(::Gitlab::ImportExport::RepoRestorer).not_to receive(:new)

      expect { import_service.execute }.not_to raise_error(Gitlab::ImportExport::Error)
    end
  end
end
