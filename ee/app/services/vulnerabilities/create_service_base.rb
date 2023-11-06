# frozen_string_literal: true

module Vulnerabilities
  class CreateServiceBase
    include Gitlab::Allowable

    GENERIC_REPORT_TYPE = ::Enums::Vulnerability.report_types[:generic]

    def initialize(project, author, params:)
      @project = project
      @author = author
      @params = params
    end

    private

    def authorized?
      can?(@author, :create_vulnerability, @project)
    end

    def location_fingerprint(_location_hash)
      raise NotImplmentedError, "location_fingerprint should be implemented by subclass"
    end

    def metadata_version
      raise NotImplmentedError, "metadata_version should be implemented by subclass"
    end

    def report_type
      GENERIC_REPORT_TYPE
    end

    def initialize_vulnerability(vulnerability_hash)
      attributes = vulnerability_hash
        .slice(*%i[
          description
          state
          severity
          confidence
          detected_at
          confirmed_at
          resolved_at
          dismissed_at
        ])
        .merge(
          project: @project,
          author: @author,
          # Our security report schema has name
          # https://gitlab.com/gitlab-org/security-products/security-report-schemas/-/blob/master/src/security-report-format.json#L369
          # Our database has title
          # https://gitlab.com/gitlab-org/gitlab/blob/master/db/structure.sql#L20164
          # We want the GraphQL mutation arguments to reflect the security scanner schema
          title: vulnerability_hash[:name]&.truncate(::Issuable::TITLE_LENGTH_MAX),
          report_type: report_type
        )

      vulnerability = Vulnerability.new(**attributes)

      vulnerability.confirmed_by = @author if vulnerability.confirmed?
      vulnerability.resolved_by = @author if vulnerability.resolved?
      vulnerability.dismissed_by = @author if vulnerability.dismissed?

      vulnerability
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def initialize_identifiers(identifier_hashes)
      identifier_hashes.map do |identifier|
        name = identifier[:name]
        external_type = identifier[:external_type] || map_external_type_from_name(name)
        external_id = identifier[:external_id] || name
        fingerprint = Digest::SHA1.hexdigest("#{external_type}:#{external_id}")
        url = identifier[:url]

        Vulnerabilities::Identifier.find_or_initialize_by(name: name) do |i|
          i.fingerprint = fingerprint
          i.project = @project
          i.external_type = external_type
          i.external_id = external_id
          i.url = url
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def map_external_type_from_name(name)
      return 'cve' if name.match?(/CVE/i)
      return 'cwe' if name.match?(/CWE/i)

      'other'
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def initialize_scanner(scanner_hash)
      name = scanner_hash[:name]

      Vulnerabilities::Scanner.find_or_initialize_by(name: name) do |s|
        s.project = @project
        s.external_id = scanner_hash[:id]
        s.vendor = scanner_hash.dig(:vendor, :name)
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def initialize_finding(vulnerability:, identifiers:, scanner:, message:, description:, solution:)
      location = @params[:vulnerability][:location]
      loc_fingerprint = location_fingerprint(location)
      uuid = ::Security::VulnerabilityUUID.generate(
        report_type: report_type,
        primary_identifier_fingerprint: identifiers.first.fingerprint,
        location_fingerprint: loc_fingerprint,
        project_id: @project.id
      )

      Vulnerabilities::Finding.new(
        project: @project,
        identifiers: identifiers,
        primary_identifier: identifiers.first,
        vulnerability: vulnerability,
        name: vulnerability.title,
        severity: vulnerability.severity,
        confidence: vulnerability.confidence,
        report_type: vulnerability.report_type,
        project_fingerprint: Digest::SHA1.hexdigest(identifiers.first.name),
        location_fingerprint: loc_fingerprint,
        metadata_version: metadata_version,
        raw_metadata: {
          location: location
        },
        scanner: scanner,
        uuid: uuid,
        message: message,
        description: description,
        solution: solution
      )
    end
  end
end
