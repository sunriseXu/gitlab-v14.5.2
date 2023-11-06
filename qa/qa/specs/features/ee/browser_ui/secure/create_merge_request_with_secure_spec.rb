# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', :runner do
    describe 'Security Reports in a Merge Request' do
      let(:sast_vuln_count) { 5 }
      let(:dependency_scan_vuln_count) { 4 }
      let(:container_scan_vuln_count) { 8 }
      let(:vuln_name) { "Regular Expression Denial of Service in debug" }
      let(:remediable_vuln_name) { "Authentication bypass via incorrect DOM traversal and canonicalization in saml2-js" }

      after do
        @runner.remove_via_api! if @runner
      end

      before do
        @executor = "qa-runner-#{Time.now.to_i}"

        Flow::Login.sign_in

        @project = Resource::Project.fabricate_via_api! do |p|
          p.name = Runtime::Env.auto_devops_project_name || 'project-with-secure'
          p.description = 'Project with Secure'
          p.auto_devops_enabled = false
          p.initialize_with_readme = true
        end

        @runner = Resource::Runner.fabricate! do |runner|
          runner.project = @project
          runner.name = @executor
          runner.tags = ['secure_report']
        end

        # Push fixture to generate Secure reports
        @source = Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = @project
          push.directory = Pathname
            .new(__dir__)
            .join('../../../../../ee/fixtures/secure_premade_reports')
          push.commit_message = 'Create Secure compatible application to serve premade reports'
          push.branch_name = 'secure-mr'
        end

        merge_request = Resource::MergeRequest.fabricate_via_api! do |mr|
          mr.project = @project
          mr.source_branch = 'secure-mr'
          mr.target_branch = @project.default_branch
          mr.source = @source
          mr.target = @project.default_branch
          mr.target_new_branch = false
        end

        @project.visit!
        Flow::Pipeline.wait_for_latest_pipeline(pipeline_condition: 'succeeded')

        merge_request.visit!
      end

      it 'displays the Security reports in the merge request', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1533' do
        Page::MergeRequest::Show.perform do |merge_request|
          expect(merge_request).to have_vulnerability_report
          expect(merge_request).to have_vulnerability_count

          merge_request.expand_vulnerability_report

          expect(merge_request).to have_sast_vulnerability_count_of(sast_vuln_count)
          expect(merge_request).to have_dependency_vulnerability_count_of(dependency_scan_vuln_count)
          expect(merge_request).to have_container_vulnerability_count_of(container_scan_vuln_count)
          expect(merge_request).to have_dast_vulnerability_count
        end
      end
    end
  end
end
