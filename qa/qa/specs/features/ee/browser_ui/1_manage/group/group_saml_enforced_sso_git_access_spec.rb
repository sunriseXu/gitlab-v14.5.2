# frozen_string_literal: true

module QA
  # TODO: Remove :requires_admin meta when the `Runtime::Feature.enable` method call is removed
  RSpec.describe 'Manage', :group_saml, :orchestrated, :requires_admin do
    describe 'Group SAML SSO - Enforced SSO' do
      include Support::API

      let!(:group) do
        Resource::Sandbox.fabricate_via_api! do |sandbox_group|
          sandbox_group.path = "saml_sso_group_#{SecureRandom.hex(8)}"
        end
      end

      let!(:saml_idp_service) { Flow::Saml.run_saml_idp_service(group.path) }

      let!(:developer_user) { Resource::User.fabricate_via_api! }

      let!(:project) do
        Resource::Project.fabricate! do |project|
          project.name = 'project-in-saml-enforced-group'
          project.description = 'project in SAML enforced group for git clone test'
          project.group = group
          project.initialize_with_readme = true
        end
      end

      before do
        Runtime::Feature.enable(:invite_members_group_modal, group: group)

        group.add_member(developer_user)

        Flow::Saml.enable_saml_sso(group, saml_idp_service, enforce_sso: true)

        Flow::Saml.logout_from_idp(saml_idp_service)

        page.visit Runtime::Scenario.gitlab_address
        Page::Main::Menu.perform(&:sign_out_if_signed_in)
      end

      it 'user clones and pushes to project within a group using Git HTTP', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1449' do
        expect do
          Resource::Repository::ProjectPush.fabricate! do |project_push|
            project_push.project = project
            project_push.branch_name = "new_branch"
            project_push.user = developer_user
          end
        end.not_to raise_error
      end

      after do
        page.visit Runtime::Scenario.gitlab_address
        Runtime::Feature.remove(:group_administration_nav_item)

        group.remove_via_api!

        Page::Main::Menu.perform(&:sign_out_if_signed_in)

        Flow::Saml.remove_saml_idp_service(saml_idp_service)
      end
    end
  end
end
