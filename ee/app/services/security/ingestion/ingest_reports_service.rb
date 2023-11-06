# frozen_string_literal: true

module Security
  module Ingestion
    # Service for starting the ingestion of the security reports
    # into the database.
    class IngestReportsService
      def self.execute(pipeline)
        new(pipeline).execute
      end

      def initialize(pipeline)
        @pipeline = pipeline
      end

      def execute
        store_reports
        mark_project_as_vulnerable!
        set_latest_pipeline!
        schedule_auto_fix
      end

      private

      attr_reader :pipeline

      delegate :project, to: :pipeline, private: true

      def store_reports
        latest_security_scans.flat_map(&method(:ingest))
                             .then(&method(:mark_resolved_vulnerabilities))
      end

      def latest_security_scans
        @latest_security_scans ||= pipeline.security_scans.without_errors.latest
      end

      def ingest(security_scan)
        IngestReportService.execute(security_scan)
      end

      # This can cause issues if we have lots of existing ids
      # or, if we try to update lots of records at once.
      # Maybe we can extract this into a different service class
      # and update the records iteratively.
      def mark_resolved_vulnerabilities(existing_ids)
        project.vulnerabilities
               .id_not_in(existing_ids)
               .update_all(resolved_on_default_branch: true)
      end

      def mark_project_as_vulnerable!
        project.project_setting.update!(has_vulnerabilities: true)
      end

      def set_latest_pipeline!
        Vulnerabilities::Statistic.set_latest_pipeline_with(pipeline)
      end

      def schedule_auto_fix
        ::Security::AutoFixWorker.perform_async(pipeline.id) if auto_fix_enabled?
      end

      def auto_fix_enabled?
        project.security_setting&.auto_fix_enabled? && has_auto_fixable_report_type?
      end

      def has_auto_fixable_report_type?
        (project.security_setting.auto_fix_enabled_types & report_types).any?
      end

      def report_types
        latest_security_scans.map(&:scan_type).map(&:to_sym)
      end
    end
  end
end
