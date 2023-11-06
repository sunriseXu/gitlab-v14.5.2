# frozen_string_literal: true

module Types
  class InstanceSecurityDashboardType < BaseObject
    graphql_name 'InstanceSecurityDashboard'

    authorize :read_instance_security_dashboard

    field :projects,
          Types::ProjectType.connection_type,
          null: false,
          description: 'Projects selected in Instance Security Dashboard.',
          resolver: ::Resolvers::InstanceSecurityDashboard::ProjectsResolver

    field :vulnerability_scanners,
          ::Types::VulnerabilityScannerType.connection_type,
          null: true,
          description: 'Vulnerability scanners reported on the vulnerabilities from projects selected in Instance Security Dashboard.',
          resolver: ::Resolvers::Vulnerabilities::ScannersResolver

    field :vulnerability_severities_count, ::Types::VulnerabilitySeveritiesCountType, null: true,
          description: 'Counts for each vulnerability severity from projects selected in Instance Security Dashboard.',
          resolver: ::Resolvers::VulnerabilitySeveritiesCountResolver

    field :vulnerability_grades,
          [Types::VulnerableProjectsByGradeType],
          null: false,
          description: 'Represents vulnerable project counts for each grade.'

    def vulnerability_grades
      ::Gitlab::Graphql::Aggregations::VulnerabilityStatistics::LazyAggregate.new(
        context,
        ::InstanceSecurityDashboard.new(context[:current_user])
      )
    end
  end
end
