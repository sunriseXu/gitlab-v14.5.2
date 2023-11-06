# frozen_string_literal: true

module EE
  module AutocompleteController
    extend ::ActiveSupport::Concern

    prepended do
      feature_category :subgroups, [:project_groups, :namespace_routes]
      feature_category :projects, [:project_routes]
    end

    def project_groups
      groups = ::Autocomplete::ProjectInvitedGroupsFinder
        .new(current_user, params)
        .execute

      render json: InvitedGroupSerializer.new.represent(groups)
    end

    def project_routes
      routes = ::Autocomplete::RoutesFinder::ProjectsOnly
                 .new(current_user, params)
                 .execute

      render json: RouteSerializer.new.represent(routes)
    end

    def namespace_routes
      routes = ::Autocomplete::RoutesFinder::NamespacesOnly
                 .new(current_user, params)
                 .execute

      render json: RouteSerializer.new.represent(routes)
    end
  end
end
