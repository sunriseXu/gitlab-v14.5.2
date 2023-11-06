# frozen_string_literal: true

module Security
  class ReportFetchService
    include Gitlab::Utils::StrongMemoize

    def initialize(project, artifact)
      @project = project
      @artifact = artifact
    end

    def pipeline
      strong_memoize(:pipeline) do
        project.latest_pipeline_with_reports(artifact)
      end
    end

    def build
      return unless pipeline

      @build ||= pipeline.builds.latest
                   .with_reports(artifact)
                   .last
    end

    def able_to_fetch?
      build&.success?
    end

    private

    attr_reader :project, :artifact
  end
end
