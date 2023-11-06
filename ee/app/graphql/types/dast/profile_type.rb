# frozen_string_literal: true

module Types
  module Dast
    class ProfileType < BaseObject
      graphql_name 'DastProfile'
      description 'Represents a DAST Profile'

      authorize :read_on_demand_dast_scan

      field :id, ::Types::GlobalIDType[::Dast::Profile], null: false,
            description: 'ID of the profile.'

      field :name, GraphQL::Types::String, null: true,
            description: 'Name of the profile.'

      field :description, GraphQL::Types::String, null: true,
            description: 'Description of the scan.'

      field :dast_site_profile, DastSiteProfileType, null: true,
            description: 'Associated site profile.'

      field :dast_scanner_profile, DastScannerProfileType, null: true,
            description: 'Associated scanner profile.'

      field :dast_profile_schedule, ::Types::Dast::ProfileScheduleType, null: true,
            description: 'Associated profile schedule.'

      field :branch, Dast::ProfileBranchType, null: true,
            description: 'Associated branch.',
            calls_gitaly: true

      field :edit_path, GraphQL::Types::String, null: true,
            description: 'Relative web path to the edit page of a profile.'

      def edit_path
        Gitlab::Routing.url_helpers.edit_project_on_demand_scan_path(object.project, object)
      end

      def dast_profile_schedule
        object.dast_profile_schedule
      end
    end
  end
end
