# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PagesDeployment do
  using RSpec::Parameterized::TableSyntax
  include EE::GeoHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  describe '.replicables_for_current_secondary' do
    where(:selective_sync_enabled, :object_storage_sync_enabled, :pages_object_storage_enabled, :synced_pages) do
      true  | true  | true  | 5
      true  | true  | false | 5
      true  | false | true  | 0
      true  | false | false | 5
      false | true  | true  | 10
      false | true  | false | 10
      false | false | true  | 0
      false | false | false | 10
    end

    with_them do
      let(:secondary) do
        node = build(:geo_node, sync_object_storage: object_storage_sync_enabled)

        if selective_sync_enabled
          node.selective_sync_type = 'namespaces'
          node.namespaces = [group]
        end

        node.save!
        node
      end

      before do
        stub_current_geo_node(secondary)
        stub_pages_object_storage(::Pages::DeploymentUploader) if pages_object_storage_enabled

        create_list(:pages_deployment, 5, project: project)
        create_list(:pages_deployment, 5, project: create(:project))
      end

      it 'returns the proper number of pages deployments' do
        expect(described_class.replicables_for_current_secondary(1..described_class.last.id).count).to eq(synced_pages)
      end
    end
  end
end
