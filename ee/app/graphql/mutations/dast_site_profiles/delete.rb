# frozen_string_literal: true

module Mutations
  module DastSiteProfiles
    class Delete < BaseMutation
      graphql_name 'DastSiteProfileDelete'

      ProfileID = ::Types::GlobalIDType[::DastSiteProfile]

      argument :full_path, GraphQL::Types::ID,
               required: false,
               deprecated: { reason: 'Full path not required to qualify Global ID', milestone: '14.5' },
               description: 'Project the site profile belongs to.'

      argument :id, ProfileID,
               required: true,
               description: 'ID of the site profile to be deleted.'

      authorize :create_on_demand_dast_scan

      def resolve(id:, full_path: nil)
        dast_site_profile = authorized_find!(id)

        service = ::AppSec::Dast::SiteProfiles::DestroyService.new(dast_site_profile.project, current_user)
        result = service.execute(id: dast_site_profile.id)

        return { errors: result.errors } unless result.success?

        { errors: [] }
      end

      private

      def find_object(id)
        # TODO: remove this line when the compatibility layer is removed
        # See: https://gitlab.com/gitlab-org/gitlab/-/issues/257883
        id = ProfileID.coerce_isolated_input(id)

        GitlabSchema.find_by_gid(id)
      end
    end
  end
end
