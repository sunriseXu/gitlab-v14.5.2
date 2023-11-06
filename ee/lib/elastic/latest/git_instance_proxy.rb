# frozen_string_literal: true

module Elastic
  module Latest
    module GitInstanceProxy
      extend ActiveSupport::Concern

      class_methods do
        def methods_for_all_write_targets
          super + [:delete_index_for_commits_and_blobs]
        end
      end

      def es_parent
        "project_#{project_id}"
      end

      def elastic_search(query, type: 'all', page: 1, per: 20, options: {})
        options = repository_specific_options(options)

        self.class.elastic_search(query, type: type, page: page, per: per, options: options)
      end

      # @return [Kaminari::PaginatableArray]
      def elastic_search_as_found_blob(query, page: 1, per: 20, options: {}, preload_method: nil)
        options = repository_specific_options(options)

        self.class.elastic_search_as_found_blob(query, page: page, per: per, options: options, preload_method: preload_method)
      end

      def blob_aggregations
        self.class.blob_aggregations
      end

      def delete_index_for_commits_and_blobs(wiki: false)
        types =
          if wiki
            %w[wiki_blob]
          else
            %w[commit blob]
          end

        client.delete_by_query(
          index: index_name,
          routing: es_parent,
          body: {
            query: {
              bool: {
                filter: [
                  {
                    terms: {
                      type: types
                    }
                  },
                  {
                    has_parent: {
                      parent_type: 'project',
                      query: {
                        term: {
                          id: project_id
                        }
                      }
                    }
                  }
                ]
              }
            }
          }
        )
      end

      private

      def repository_id
        raise NotImplementedError
      end

      def repository_specific_options(options)
        if options[:repository_id].nil?
          options = options.merge(repository_id: repository_id)
        end

        options
      end
    end
  end
end
