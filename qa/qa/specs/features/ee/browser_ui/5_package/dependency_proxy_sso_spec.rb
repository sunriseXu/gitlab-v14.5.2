# frozen_string_literal: true

module QA
  RSpec.describe 'Package', :orchestrated, :group_saml, :requires_admin, except: { subdomain: :staging } do
    describe 'Dependency Proxy Group SSO' do
      include Support::API

      let!(:group) do
        Resource::Sandbox.fabricate! do |sandbox_group|
          sandbox_group.path = "saml_sso_group_with_dependency_proxy_#{SecureRandom.hex(8)}"
        end
      end

      let(:idp_user) { Struct.new(:username, :password).new('user3', 'user3pass') }

      let(:user) do
        QA::Resource::User.init do |user|
          user.username = 'user_3'
          user.email = 'user_3@example.com'
          user.name = 'User Three'
        end
      end

      # starts a docker Docker container with a plug and play SAML 2.0 Identity Provider (IdP)
      let!(:saml_idp_service) { Flow::Saml.run_saml_idp_service(group.path) }

      let!(:group_sso_url) { Flow::Saml.enable_saml_sso(group, saml_idp_service, enforce_sso: true) }

      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'dependency-proxy-sso-project'
          project.group = group
        end
      end

      let!(:runner) do
        Resource::Runner.fabricate! do |runner|
          runner.name = "qa-runner-#{Time.now.to_i}"
          runner.tags = ["runner-for-#{project.name}"]
          runner.executor = :docker
          runner.project = project
        end
      end

      let(:uri) { URI.parse(Runtime::Scenario.gitlab_address) }
      let(:gitlab_host_with_port) { "#{uri.host}:#{uri.port}" }
      let(:dependency_proxy_url) { "#{gitlab_host_with_port}/#{project.group.full_path}/dependency_proxy/containers" }

      before do
        Page::Main::Menu.perform(&:sign_out_if_signed_in)
        Flow::Saml.logout_from_idp(saml_idp_service)

        visit_group_sso_url

        EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)
        Flow::Saml.login_to_idp_if_required(idp_user.username, idp_user.password)
        QA::Flow::User.confirm_user(user)

        visit_group_sso_url

        EE::Page::Group::SamlSSOSignIn.perform(&:click_sign_in)
      end

      after do
        Flow::Saml.remove_saml_idp_service(saml_idp_service)

        Runtime::Feature.remove(:group_administration_nav_item)

        user.remove_via_api!
        group.remove_via_api!
        runner.remove_via_api!
      end

      it "pulls an image using the dependency proxy on a group enforced SSO", testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/2291' do
        project.group.visit!

        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = project
          commit.commit_message = 'Add .gitlab-ci.yml'
          commit.add_files([{
                             file_path: '.gitlab-ci.yml',
                             content:
                                  <<~YAML
                                    dependency-proxy-pull-test:
                                      image: "docker:stable"
                                      services:
                                      - name: "docker:stable-dind"
                                        command: ["--insecure-registry=#{gitlab_host_with_port}"]
                                      before_script:
                                        - apk add curl jq grep
                                        - docker login -u "$CI_DEPENDENCY_PROXY_USER" -p "$CI_DEPENDENCY_PROXY_PASSWORD" "$CI_DEPENDENCY_PROXY_SERVER"
                                      script:
                                        - docker pull #{dependency_proxy_url}/alpine:latest
                                        - TOKEN=$(curl "https://auth.docker.io/token?service=registry.docker.io&scope=repository:ratelimitpreview/test:pull" | jq --raw-output .token)
                                        - 'curl --head --header "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest" 2>&1'
                                        - docker pull #{dependency_proxy_url}/alpine:latest
                                        - 'curl --head --header "Authorization: Bearer $TOKEN" "https://registry-1.docker.io/v2/ratelimitpreview/test/manifests/latest" 2>&1'
                                      tags:
                                      - "runner-for-#{project.name}"
                                  YAML
                           }])
        end

        project.visit!
        Flow::Pipeline.visit_latest_pipeline

        Page::Project::Pipeline::Show.perform do |pipeline|
          pipeline.click_job('dependency-proxy-pull-test')
        end

        Page::Project::Job::Show.perform do |job|
          expect(job).to be_successful(timeout: 800)
        end

        Flow::Login.sign_in

        project.group.visit!

        Page::Group::Menu.perform(&:go_to_dependency_proxy)

        Page::Group::DependencyProxy.perform do |index|
          expect(index).to have_blob_count("Contains 1 blobs of images")
        end
      end

      def visit_group_sso_url
        Runtime::Logger.debug(%(Visiting managed_group_url at "#{group_sso_url}"))

        page.visit group_sso_url
        Support::Waiter.wait_until { current_url == group_sso_url }
      end
    end
  end
end
