# frozen_string_literal: true

module QA
  # Do not run on staging since another top level group has to be created which doesn't have premium license
  RSpec.describe 'Manage', :requires_admin, except: { subdomain: :staging } do
    describe 'Bulk group import' do
      let(:admin_api_client) { Runtime::API::Client.as_admin }
      let(:api_client) { Runtime::API::Client.new(user: user) }
      # validate different epic author is migrated correctly
      let(:author_api_client) { Runtime::API::Client.new(user: author) }

      let(:user) do
        Resource::User.fabricate_via_api! do |usr|
          usr.api_client = admin_api_client
          usr.hard_delete_on_api_removal = true
        end
      end

      let(:author) do
        Resource::User.fabricate_via_api! do |usr|
          usr.api_client = admin_api_client
          usr.hard_delete_on_api_removal = true
        end
      end

      let(:sandbox) do
        Resource::Sandbox.fabricate_via_api! do |group|
          group.api_client = admin_api_client
        end
      end

      let(:source_group) do
        Resource::Sandbox.fabricate_via_api! do |group|
          group.api_client = api_client
          group.path = "source-group-for-import-#{SecureRandom.hex(4)}"
        end
      end

      let(:imported_group) do
        Resource::BulkImportGroup.fabricate_via_api! do |group|
          group.api_client = api_client
          group.sandbox = sandbox
          group.source_group_path = source_group.path
        end
      end

      let(:source_epics) { source_group.epics }
      let(:imported_epics) { imported_group.epics }

      let(:source_iteration) do
        EE::Resource::GroupIteration.fabricate_via_api! do |iteration|
          iteration.api_client = api_client
          iteration.group = source_group
        end
      end

      # Find epic by title
      #
      # @param [Array] epics
      # @param [String] title
      # @return [EE::Resource::Epic]
      def find_epic(epics, title)
        epics.find { |epic| epic.title == title }
      end

      before do
        sandbox.add_member(user, Resource::Members::AccessLevel::MAINTAINER)
        source_group.add_member(author, Resource::Members::AccessLevel::MAINTAINER)
        author.set_public_email

        parent_epic = EE::Resource::Epic.fabricate_via_api! do |epic|
          epic.api_client = author_api_client
          epic.group = source_group
          epic.title = 'Parent epic'
        end
        child_epic = EE::Resource::Epic.fabricate_via_api! do |child_epic|
          child_epic.api_client = api_client
          child_epic.group = source_group
          child_epic.title = 'Child epic'
          child_epic.confidential = true
          child_epic.labels = 'label1,label2'
          child_epic.parent_id = parent_epic.id
        end

        child_epic.award_emoji('thumbsup')
        child_epic.award_emoji('thumbsdown')

        source_iteration
      end

      after do
        user.remove_via_api!
        author.remove_via_api!
      end

      it(
        'imports group epics and iterations',
        testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1921'
      ) do
        expect { imported_group.import_status }.to(
          eventually_eq('finished').within(max_duration: 300, sleep_interval: 2)
        )

        source_parent_epic = find_epic(source_epics, 'Parent epic')
        imported_parent_epic = find_epic(imported_epics, 'Parent epic')
        imported_child_epic = find_epic(imported_epics, 'Child epic')
        imported_iteration = imported_group.reload!.iterations.find { |ml| ml.title == source_iteration.title }

        aggregate_failures do
          expect(imported_epics).to eq(source_epics)
          expect(imported_child_epic.parent_id).to eq(imported_parent_epic.id)
          expect(imported_parent_epic.author).to eq(source_parent_epic.author)

          expect(imported_iteration).to eq(source_iteration)
          expect(imported_iteration.iid).to eq(source_iteration.iid)
          expect(imported_iteration.created_at).to eq(source_iteration.created_at)
          expect(imported_iteration.updated_at).to eq(source_iteration.updated_at)
        end
      end
    end
  end
end
