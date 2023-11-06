# frozen_string_literal: true

module Elastic
  module Latest
    class ProjectWikiClassProxy < ApplicationClassProxy
      include GitClassProxy

      def es_type
        'wiki_blob'
      end

      def elastic_search_as_wiki_page(*args)
        elastic_search_as_found_blob(*args).map! do |blob|
          Gitlab::Search::FoundWikiPage.new(blob)
        end
      end
    end
  end
end
