# frozen_string_literal: true

module Security
  module Ingestion
    # This entity is used in ingestion services to
    # map security_finding - report_finding - vulnerability_id - finding_id
    #
    # You can think this as the Message object in the pipeline design pattern
    # which is passed between tasks.
    class FindingMap
      FINDING_ATTRIBUTES = %i[confidence metadata_version name raw_metadata report_type severity details description message cve solution].freeze

      attr_reader :security_finding, :report_finding
      attr_accessor :finding_id, :vulnerability_id, :new_record, :identifier_ids

      delegate :uuid, :scanner_id, to: :security_finding
      delegate :scan, to: :security_finding, private: true
      delegate :project, to: :scan, private: true
      delegate :project_fingerprint, to: :report_finding, private: true

      def initialize(security_finding, report_finding)
        @security_finding = security_finding
        @report_finding = report_finding
        @identifier_ids = []
      end

      def identifiers
        @identifiers ||= report_finding.identifiers.first(Vulnerabilities::Finding::MAX_NUMBER_OF_IDENTIFIERS)
      end

      def set_identifier_ids_by(fingerprint_id_map)
        @identifier_ids = identifiers.map { |identifier| fingerprint_id_map[identifier.fingerprint] }
      end

      def issue_feedback
        BatchLoader.for([project.id, project_fingerprint]).batch do |tuples, loader|
          Vulnerabilities::Feedback.for_issue
                                   .by_project(tuples.first.first)
                                   .by_project_fingerprints(tuples.map(&:second))
                                   .each { |feedback| loader.call([feedback.project_id, feedback.project_fingerprint], feedback) }
        end
      end

      def to_hash
        report_finding.to_hash
                      .slice(*FINDING_ATTRIBUTES)
                      .merge!(
                        uuid: uuid,
                        scanner_id: scanner_id,
                        project_fingerprint: project_fingerprint,
                        primary_identifier_id: identifier_ids.first,
                        location: report_finding.location_data,
                        location_fingerprint: report_finding.location.fingerprint
                      )
      end
    end
  end
end
