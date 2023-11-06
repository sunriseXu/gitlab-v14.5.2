# frozen_string_literal: true

module Mutations
  module DastSiteProfiles
    class Create < BaseMutation
      include FindsProject
      include Mutations::AppSec::Dast::SiteProfiles::SharedArguments

      graphql_name 'DastSiteProfileCreate'

      field :id, SiteProfileID,
            null: true,
            description: 'ID of the site profile.'

      argument :full_path, GraphQL::Types::ID,
               required: true,
               description: 'Project the site profile belongs to.'

      argument :excluded_urls, [GraphQL::Types::String],
               required: false,
               default_value: [],
               description: 'URLs to skip during an authenticated scan. Defaults to `[]`.'

      authorize :create_on_demand_dast_scan

      def resolve(full_path:, profile_name:, target_url: nil, **params)
        project = authorized_find!(full_path)

        auth_params = params[:auth] || {}

        dast_site_profile_params = {
          name: profile_name,
          target_url: target_url,
          target_type: params[:target_type],
          excluded_urls: params[:excluded_urls],
          request_headers: params[:request_headers],
          auth_enabled: auth_params[:enabled],
          auth_url: auth_params[:url],
          auth_username_field: auth_params[:username_field],
          auth_password_field: auth_params[:password_field],
          auth_username: auth_params[:username],
          auth_password: auth_params[:password]
        }.compact

        result = ::AppSec::Dast::SiteProfiles::CreateService.new(project, current_user).execute(**dast_site_profile_params)

        { id: result.payload.try(:to_global_id), errors: result.errors }
      end
    end
  end
end
