# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::HashedStorageMigratedEventStore do
  include EE::GeoHelpers

  let_it_be(:secondary_node) { create(:geo_node) }

  let(:project) { create(:project, :design_repo, path: 'bar') }
  let(:old_disk_path) { "#{project.namespace.full_path}/foo" }
  let(:old_wiki_disk_path) { "#{old_disk_path}.wiki" }
  let(:old_design_disk_path) { "#{old_disk_path}.design" }

  subject do
    described_class.new(
      project,
      old_storage_version: nil,
      old_disk_path: old_disk_path,
      old_wiki_disk_path: old_wiki_disk_path,
      old_design_disk_path: old_design_disk_path
    )
  end

  before do
    TestEnv.clean_test_path
  end

  describe '#create!' do
    it_behaves_like 'a Geo event store', Geo::HashedStorageMigratedEvent

    context 'when running on a primary node' do
      before do
        stub_primary_node
      end

      it 'tracks project attributes' do
        subject.create!

        expect(Geo::HashedStorageMigratedEvent.last).to have_attributes(
          repository_storage_name: project.repository_storage,
          old_storage_version: nil,
          new_storage_version: project.storage_version,
          old_disk_path: old_disk_path,
          new_disk_path: project.disk_path,
          old_wiki_disk_path: old_wiki_disk_path,
          new_wiki_disk_path: project.wiki.disk_path,
          old_design_disk_path: old_design_disk_path,
          new_design_disk_path: project.design_repository.disk_path
        )
      end
    end
  end
end
