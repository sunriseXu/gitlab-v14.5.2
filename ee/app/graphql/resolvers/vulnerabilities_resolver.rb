# frozen_string_literal: true

module Resolvers
  class VulnerabilitiesResolver < VulnerabilitiesBaseResolver
    include Gitlab::Utils::StrongMemoize
    include LooksAhead

    type Types::VulnerabilityType, null: true

    argument :project_id, [GraphQL::Types::ID],
             required: false,
             description: 'Filter vulnerabilities by project.'

    argument :report_type, [Types::VulnerabilityReportTypeEnum],
             required: false,
             description: 'Filter vulnerabilities by report type.'

    argument :severity, [Types::VulnerabilitySeverityEnum],
             required: false,
             description: 'Filter vulnerabilities by severity.'

    argument :state, [Types::VulnerabilityStateEnum],
             required: false,
             description: 'Filter vulnerabilities by state.'

    argument :scanner, [GraphQL::Types::String],
             required: false,
             description: 'Filter vulnerabilities by VulnerabilityScanner.externalId.'

    argument :scanner_id, [::Types::GlobalIDType[::Vulnerabilities::Scanner]],
             required: false,
             description: 'Filter vulnerabilities by scanner ID.'

    argument :sort, Types::VulnerabilitySortEnum,
             required: false,
             default_value: 'severity_desc',
             description: 'List vulnerabilities by sort order.'

    argument :has_resolution, GraphQL::Types::Boolean,
             required: false,
             description: 'Returns only the vulnerabilities which have been resolved on default branch.'

    argument :has_issues, GraphQL::Types::Boolean,
             required: false,
             description: 'Returns only the vulnerabilities which have linked issues.'

    argument :image, [GraphQL::Types::String],
             required: false,
             description: "Filter vulnerabilities by location image. When this filter is present, "\
                          "the response only matches entries for a `reportType` "\
                          "that includes #{::Vulnerabilities::Finding::REPORT_TYPES_WITH_LOCATION_IMAGE.map { |type| "`#{type}`" }.join(', ')}."

    argument :cluster_id, [::Types::GlobalIDType[::Clusters::Cluster]],
             prepare: ->(ids, _) { ids.map(&:model_id) },
             required: false,
             description: "Filter vulnerabilities by `cluster_id`. Vulnerabilities with a `reportType` "\
                          "of `cluster_image_scanning` are only included with this filter."

    def resolve_with_lookahead(**args)
      return Vulnerability.none unless vulnerable

      args[:scanner_id] = resolve_gids(args[:scanner_id], ::Vulnerabilities::Scanner) if args[:scanner_id]

      vulnerabilities(args)
        .with_findings_scanner_and_identifiers
        .with_created_issue_links_and_issues
    end

    def unconditional_includes
      [:findings]
    end

    def preloads
      {
        has_solutions: [{ findings: [:remediations] }]
      }
    end

    private

    def vulnerabilities(params)
      apply_lookahead(Security::VulnerabilitiesFinder.new(vulnerable, params).execute)
    end
  end
end
