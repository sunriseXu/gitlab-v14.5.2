# frozen_string_literal: true

module EE
  module Commits
    module CreateService
      extend ::Gitlab::Utils::Override

      private

      override :validate!
      def validate!
        super

        validate_against_codeowner_rules!
        validate_repository_size!
      end

      def validate_repository_size!
        size_checker = project.repository_size_checker

        if size_checker.above_size_limit?
          raise_error(size_checker.error_message.commit_error)
        end
      end

      def validate_against_codeowner_rules!
        codeowners_error = check_against_codeowners(project, params[:branch_name], extracted_paths)

        if codeowners_error.present?
          raise_error(codeowners_error.tr("\n", " "))
        end
      end

      def check_against_codeowners(project, branch, paths)
        return if paths.empty?
        return if ::Feature.enabled?(:push_rules_supersede_code_owners, project, default_enabled: true)

        ::Gitlab::CodeOwners::Validator.new(project, branch, paths).execute
      end

      def extracted_paths
        paths = []

        paths << params[:file_path].presence
        paths << paths_from_actions
        paths << paths_from_start_sha
        paths << paths_from_commit(params[:commit])

        paths.flatten.compact.uniq
      end

      def paths_from_actions
        return unless params[:actions].present?

        params[:actions].flat_map do |entry|
          [entry[:file_path], entry[:previous_path]]
        end
      end

      def paths_from_start_sha
        return unless params[:start_sha].present?

        commit = project.commit(params[:start_sha])
        return unless commit

        paths_from_commit(commit)
      end

      def paths_from_commit(commit)
        return unless commit.present?

        commit.raw_deltas.flat_map { |diff| [diff.new_path, diff.old_path] }
      end
    end
  end
end
