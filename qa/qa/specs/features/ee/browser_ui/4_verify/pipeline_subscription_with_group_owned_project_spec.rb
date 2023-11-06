# frozen_string_literal: true

module QA
  RSpec.describe 'Verify' do
    describe 'Pipeline subscription with a group owned project', :runner do
      let(:executor) { "qa-runner-#{SecureRandom.hex(3)}" }
      let(:tag_name) { "awesome-tag-#{SecureRandom.hex(3)}" }

      let(:upstream_project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'upstream-project-for-subscription'
          project.description = 'Project with CI subscription'
        end
      end

      let(:downstream_project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'project-with-pipeline-subscription'
          project.description = 'Project with CI subscription'
        end
      end

      let!(:runner) do
        Resource::Runner.fabricate! do |runner|
          runner.project = upstream_project
          runner.token = upstream_project.group.sandbox.runners_token
          runner.name = executor
          runner.tags = [executor]
        end
      end

      before do
        [downstream_project, upstream_project].each do |project|
          add_ci_file(project)
        end

        Flow::Login.sign_in
        downstream_project.visit!

        EE::Resource::PipelineSubscriptions.fabricate_via_browser_ui! do |subscription|
          subscription.project_path = upstream_project.path_with_namespace
        end
      end

      after do
        [runner, upstream_project, downstream_project].each do |item|
          item.remove_via_api!
        end
      end

      context 'when upstream project new tag pipeline finishes' do
        it 'triggers pipeline in downstream project', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1826' do
          # Downstream project should have one pipeline at this time
          unless downstream_project.pipelines.size == 1
            raise "[ERROR] Downstream project should have 1 pipeline - pipelines count #{downstream_project.pipelines.size}"
          end

          Resource::Tag.fabricate_via_api! do |tag|
            tag.project = upstream_project
            tag.ref = upstream_project.default_branch
            tag.name = tag_name
          end

          downstream_project.visit!

          Support::Waiter.wait_until(sleep_interval: 3) do
            QA::Runtime::Logger.info 'Waiting for upstream pipeline to succeed.'
            new_pipeline = upstream_project.pipelines.find { |pipeline| pipeline[:ref] == tag_name }
            new_pipeline&.dig(:status) == 'success'
          end

          Page::Project::Menu.perform(&:click_ci_cd_pipelines)

          # Downstream project must have 2 pipelines at this time
          expect(downstream_project.pipelines.size).to eq(2), "There are currently #{downstream_project.pipelines.size} pipelines in downstream project."

          # expect new downstream pipeline to also succeed
          Page::Project::Pipeline::Index.perform do |index|
            expect(index.wait_for_latest_pipeline_succeeded).to be_truthy, 'Downstream pipeline did not succeed as expected.'
          end
        end
      end

      private

      def add_ci_file(project)
        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = project
          commit.commit_message = 'Add .gitlab-ci.yml'
          commit.add_files(
            [
              {
                file_path: '.gitlab-ci.yml',
                content: <<~YAML
                  job:
                    tags:
                      - #{executor}
                    script:
                      - echo DONE!
                YAML
              }
            ]
          )
        end
      end
    end
  end
end
