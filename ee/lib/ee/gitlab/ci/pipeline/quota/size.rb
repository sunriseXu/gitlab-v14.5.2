# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Quota
          class Size < ::Gitlab::Ci::Limit
            include ::Gitlab::Utils::StrongMemoize
            include ActionView::Helpers::TextHelper

            LOGGABLE_JOBS_COUNT = 2000  # log large pipelines to determine a future global pipeline size limit

            def initialize(namespace, pipeline, command)
              @namespace = namespace
              @pipeline = pipeline
              @command = command
            end

            def enabled?
              ci_pipeline_size_limit > 0
            end

            def exceeded?
              return false unless enabled?

              seeds_size > ci_pipeline_size_limit
            end

            def log_exceeded_limit?
              seeds_size > LOGGABLE_JOBS_COUNT
            end

            def message
              "Pipeline has too many jobs! Requested #{seeds_size}, but the limit is #{ci_pipeline_size_limit}."
            end

            private

            def ci_pipeline_size_limit
              strong_memoize(:ci_pipeline_size_limit) do
                @namespace.actual_limits.ci_pipeline_size
              end
            end

            def seeds_size
              @command.pipeline_seed.size
            end
          end
        end
      end
    end
  end
end
