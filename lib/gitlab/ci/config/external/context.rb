# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module External
        class Context
          include Gitlab::Utils::StrongMemoize

          TimeoutError = Class.new(StandardError)

          attr_reader :project, :sha, :user, :parent_pipeline, :variables
          attr_reader :expandset, :execution_deadline

          def initialize(project: nil, sha: nil, user: nil, parent_pipeline: nil, variables: [])
            @project = project
            @sha = sha
            @user = user
            @parent_pipeline = parent_pipeline
            @variables = variables
            @expandset = Set.new
            @execution_deadline = 0

            yield self if block_given?
          end

          def top_level_worktree_paths
            strong_memoize(:top_level_worktree_paths) do
              project.repository.tree(sha).blobs.map(&:path)
            end
          end

          def all_worktree_paths
            strong_memoize(:all_worktree_paths) do
              project.repository.ls_files(sha)
            end
          end

          def mutate(attrs = {})
            self.class.new(**attrs) do |ctx|
              ctx.expandset = expandset
              ctx.execution_deadline = execution_deadline
            end
          end

          def set_deadline(timeout_seconds)
            @execution_deadline = current_monotonic_time + timeout_seconds.to_f
          end

          def check_execution_time!
            raise TimeoutError if execution_expired?
          end

          def sentry_payload
            {
              user: user.inspect,
              project: project.inspect
            }
          end

          protected

          attr_writer :expandset, :execution_deadline

          private

          def current_monotonic_time
            Gitlab::Metrics::System.monotonic_time
          end

          def execution_expired?
            return false if execution_deadline == 0

            current_monotonic_time > execution_deadline
          end
        end
      end
    end
  end
end
