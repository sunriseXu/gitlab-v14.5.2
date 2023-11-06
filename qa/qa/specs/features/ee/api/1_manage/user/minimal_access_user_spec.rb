# frozen_string_literal: true

module QA
  RSpec.describe 'Manage' do
    describe 'User with minimal access to group', :requires_admin do
      before(:all) do
        admin_api_client = Runtime::API::Client.as_admin

        @user_with_minimal_access = Resource::User.fabricate_via_api! do |user|
          user.api_client = admin_api_client
        end

        @user_api_client = Runtime::API::Client.new(:gitlab, user: @user_with_minimal_access)

        @group = Resource::Group.fabricate_via_api!

        @group.sandbox.add_member(@user_with_minimal_access, Resource::Members::AccessLevel::MINIMAL_ACCESS)

        @project = Resource::Project.fabricate_via_api! do |project|
          project.group = @group
          project.name = "project-for-minimal-access"
          project.initialize_with_readme = true
        end
      end

      it 'is not allowed to push code via the CLI', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1626' do
        expect do
          Resource::Repository::Push.fabricate! do |push|
            push.repository_http_uri = @project.repository_http_location.uri
            push.file_name = 'test.txt'
            push.file_content = "# This is a test project named #{@project.name}"
            push.commit_message = 'Add test.txt'
            push.branch_name = 'new_branch'
            push.user = @user_with_minimal_access
          end
        end.to raise_error(QA::Support::Run::CommandError, /You are not allowed to push code to this project/)
      end

      it 'is not allowed to create a file via the API', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1625' do
        expect do
          Resource::File.fabricate_via_api! do |file|
            file.api_client = @user_api_client
            file.project = @project
            file.branch = 'new_branch'
            file.commit_message = 'Add new file'
            file.name = 'test.txt'
            file.content = "New file"
          end
        end.to raise_error(Resource::ApiFabricator::ResourceFabricationFailedError, /403 Forbidden/)
      end

      it 'is not allowed to commit via the API', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1901' do
        expect do
          Resource::Repository::Commit.fabricate_via_api! do |commit|
            commit.api_client = @user_api_client
            commit.project = @project
            commit.branch = 'new_branch'
            commit.start_branch = @project.default_branch
            commit.commit_message = 'Add new file'
            commit.add_files([
              { file_path: 'test.txt', content: 'new file' }
            ])
          end
        end.to raise_error(Resource::ApiFabricator::ResourceFabricationFailedError, /403 Forbidden - You are not allowed to push into this branch/)
      end

      after(:all) do
        @user_with_minimal_access.remove_via_api!
        @project.remove_via_api!
        begin
          @group.remove_via_api!
        rescue Resource::ApiFabricator::ResourceNotDeletedError
          # It is ok if the group is already marked for deletion by another test
        end
      end
    end
  end
end
