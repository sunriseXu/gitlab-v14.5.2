# frozen_string_literal: true

module EE
  module Projects
    module MergeRequestsController
      extend ActiveSupport::Concern

      prepended do
        include DescriptionDiffActions

        before_action only: [:show] do
          if can_run_sast_experiments_on?(@project)
            experiment(:security_reports_mr_widget_prompt, namespace: @project.namespace).publish
          end

          push_frontend_feature_flag(:anonymous_visual_review_feedback)
          push_frontend_feature_flag(:missing_mr_security_scan_types, @project)
          push_frontend_feature_flag(:refactor_mr_widgets_extensions, @project, default_enabled: :yaml)
          push_frontend_feature_flag(:refactor_mr_widgets_extensions_user, current_user, default_enabled: :yaml)
        end

        before_action :authorize_read_pipeline!, only: [:container_scanning_reports, :dependency_scanning_reports,
                                                        :sast_reports, :secret_detection_reports,
                                                        :dast_reports, :coverage_fuzzing_reports, :api_fuzzing_reports,
                                                        :metrics_reports]
        before_action :authorize_read_licenses!, only: [:license_scanning_reports]

        feature_category :vulnerability_management, [:container_scanning_reports, :dependency_scanning_reports,
                                                     :sast_reports, :secret_detection_reports,
                                                     :dast_reports, :coverage_fuzzing_reports, :api_fuzzing_reports]
        feature_category :metrics, [:metrics_reports]
        feature_category :license_compliance, [:license_scanning_reports]
        feature_category :code_review, [:delete_description_version, :description_diff]
      end

      def can_run_sast_experiments_on?(project)
        project.licensed_feature_available?(:sast) &&
          project.feature_available?(:security_and_compliance, current_user)
      end

      def license_scanning_reports
        reports_response(merge_request.compare_license_scanning_reports(current_user))
      end

      def container_scanning_reports
        reports_response(merge_request.compare_container_scanning_reports(current_user), head_pipeline)
      end

      def dependency_scanning_reports
        reports_response(merge_request.compare_dependency_scanning_reports(current_user), head_pipeline)
      end

      def dast_reports
        reports_response(merge_request.compare_dast_reports(current_user), head_pipeline)
      end

      def metrics_reports
        reports_response(merge_request.compare_metrics_reports)
      end

      def coverage_fuzzing_reports
        reports_response(merge_request.compare_coverage_fuzzing_reports(current_user), head_pipeline)
      end

      def api_fuzzing_reports
        reports_response(merge_request.compare_api_fuzzing_reports(current_user), head_pipeline)
      end
    end
  end
end
