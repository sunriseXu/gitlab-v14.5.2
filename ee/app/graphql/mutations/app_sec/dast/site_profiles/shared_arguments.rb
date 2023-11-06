# frozen_string_literal: true

module Mutations
  module AppSec
    module Dast
      module SiteProfiles
        module SharedArguments
          extend ActiveSupport::Concern

          SiteProfileID = ::Types::GlobalIDType[::DastSiteProfile]

          included do
            argument :profile_name, GraphQL::Types::String,
                     required: true,
                     description: 'Name of the site profile.'

            argument :target_url, GraphQL::Types::String,
                     required: false,
                     description: 'URL of the target to be scanned.'

            argument :target_type, Types::DastTargetTypeEnum,
                     required: false,
                     description: 'Type of target to be scanned.'

            argument :request_headers, GraphQL::Types::String,
                     required: false,
                     description: 'Comma-separated list of request header names and values to be ' \
                                  'added to every request made by DAST.'

            argument :auth, ::Types::Dast::SiteProfileAuthInputType,
                     required: false,
                     description: 'Parameters for authentication.'
          end
        end
      end
    end
  end
end
