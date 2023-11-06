# frozen_string_literal: true

module EE
  module SearchService
    include ::Gitlab::Utils::StrongMemoize
    extend ::Gitlab::Utils::Override

    # This is a proper method instead of a `delegate` in order to
    # avoid adding unnecessary methods to Search::SnippetService
    def use_elasticsearch?
      search_service.use_elasticsearch?
    end

    def valid_query_length?
      return true if use_elasticsearch?

      super
    end

    def valid_terms_count?
      return true if use_elasticsearch?

      super
    end

    def show_epics?
      search_service.allowed_scopes.include?('epics')
    end

    def show_elasticsearch_tabs?
      ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: search_service.elasticsearchable_scope)
    end

    # rubocop: disable CodeReuse/ActiveRecord
    # rubocop: disable Gitlab/ModuleWithInstanceVariables
    override :projects
    def projects
      strong_memoize(:projects) do
        next unless params[:project_ids].present? && params[:project_ids].is_a?(String)
        next unless ::Feature.enabled?(:advanced_search_multi_project_select, current_user, default_enabled: :yaml)

        project_ids = params[:project_ids].split(',')
        the_projects = ::Project.where(id: project_ids)
        allowed_projects = the_projects.find_all { |p| can?(current_user, :read_project, p) }
        allowed_projects.presence
      end
    end
    # rubocop: enable Gitlab/ModuleWithInstanceVariables
    # rubocop: enable CodeReuse/ActiveRecord

    private

    override :search_service
    def search_service
      return super unless projects

      @search_service ||= ::Search::ProjectService.new(projects, current_user, params) # rubocop: disable Gitlab/ModuleWithInstanceVariables
    end
  end
end
