# frozen_string_literal: true

module EE
  module WikiPages
    # BaseService EE mixin
    #
    # This module is intended to encapsulate EE-specific service logic
    # and be included in the `WikiPages::BaseService` service
    module BaseService
      extend ActiveSupport::Concern

      private

      def execute_hooks(page)
        super
        process_wiki_repository_update
      end

      def create_wiki_event(_page)
        # TODO: group hooks https://gitlab.com/gitlab-org/gitlab/-/issues/216904
        return if container.is_a?(Group)

        super
      end

      def process_wiki_repository_update
        # TODO: Geo support for group wiki
        # https://gitlab.com/gitlab-org/gitlab/-/issues/208147
        if ::Gitlab::Geo.primary? && container.is_a?(Project)
          ::Geo::RepositoryUpdatedService.new(container.wiki.repository).execute
        end
      end
    end
  end
end
