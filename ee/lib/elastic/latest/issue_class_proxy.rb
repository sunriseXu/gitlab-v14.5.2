# frozen_string_literal: true

module Elastic
  module Latest
    class IssueClassProxy < ApplicationClassProxy
      include StateFilter

      def elastic_search(query, options: {})
        options[:features] = 'issues'
        options[:no_join_project] = true

        query_hash =
          if query =~ /#(\d+)\z/
            iid_query_hash(Regexp.last_match(1))
          else
            # iid field can be added here as lenient option will
            # pardon format errors, like integer out of range.
            fields = %w[iid^3 title^2 description]
            basic_query_hash(fields, query, options)
          end

        context.name(:issue) do
          query_hash = context.name(:authorized) { authorization_filter(query_hash, options) }
          query_hash = context.name(:confidentiality) { confidentiality_filter(query_hash, options) }
          query_hash = context.name(:match) { state_filter(query_hash, options) }
        end
        query_hash = apply_sort(query_hash, options)

        search(query_hash, options)
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def preload_indexing_data(relation)
        relation.includes(:issue_assignees, project: [:project_feature, :namespace])
      end
      # rubocop: enable CodeReuse/ActiveRecord

      private

      # override
      def apply_sort(query_hash, options)
        case ::Gitlab::Search::SortOptions.sort_and_direction(options[:order_by], options[:sort])
        when :popularity_asc
          query_hash.merge(sort: {
            upvotes: {
              order: 'asc'
            }
          })
        when :popularity_desc
          query_hash.merge(sort: {
            upvotes: {
              order: 'desc'
            }
          })
        else
          super
        end
      end

      def should_use_project_ids_filter?(options)
        options[:project_ids] == :any ||
        options[:group_ids].blank? ||
        Feature.disabled?(:elasticsearch_use_group_level_optimization) ||
        !Elastic::DataMigrationService.migration_has_finished?(:redo_backfill_namespace_ancestry_ids_for_issues)
      end

      def authorization_filter(query_hash, options)
        return project_ids_filter(query_hash, options) if should_use_project_ids_filter?(options)

        current_user = options[:current_user]
        namespace_ancestry = Namespace.find(authorized_namespace_ids(current_user, options))
                                      .map(&:elastic_namespace_ancestry)

        return project_ids_filter(query_hash, options) if namespace_ancestry.blank?

        context.name(:namespace) do
          query_hash[:query][:bool][:filter] ||= []
          query_hash[:query][:bool][:filter] << ancestry_filter(current_user, namespace_ancestry)
        end

        query_hash
      end

      # Builds an elasticsearch query that will select documents from a
      # set of projects for Group and Project searches, taking user access
      # rules for issues into account. Relies upon super for Global searches
      def project_ids_filter(query_hash, options)
        return super if options[:public_and_internal_projects]

        current_user = options[:current_user]
        scoped_project_ids = scoped_project_ids(current_user, options[:project_ids])
        return super if scoped_project_ids == :any

        context.name(:project) do
          query_hash[:query][:bool][:filter] ||= []
          query_hash[:query][:bool][:filter] << {
            terms: {
              _name: context.name,
              project_id: filter_ids_by_feature(scoped_project_ids, current_user, 'issues')
            }
          }
        end

        query_hash
      end

      def confidentiality_filter(query_hash, options)
        current_user = options[:current_user]
        project_ids = options[:project_ids]

        if [true, false].include?(options[:confidential])
          query_hash[:query][:bool][:filter] << { term: { confidential: options[:confidential] } }
        end

        return query_hash if current_user&.can_read_all_resources?

        scoped_project_ids = scoped_project_ids(current_user, project_ids)
        authorized_project_ids = authorized_project_ids(current_user, options)

        # we can shortcut the filter if the user is authorized to see
        # all the projects for which this query is scoped on
        unless scoped_project_ids == :any || scoped_project_ids.empty?
          return query_hash if authorized_project_ids.to_set == scoped_project_ids.to_set
        end

        filter = { term: { confidential: { _name: context.name(:non_confidential), value: false } } }

        if current_user
          filter = {
              bool: {
                should: [
                  { term: { confidential: { _name: context.name(:non_confidential), value: false } } },
                  {
                    bool: {
                      must: [
                        { term: { confidential: true } },
                        {
                          bool: {
                            should: [
                              { term: { author_id: { _name: context.name(:as_author), value: current_user.id } } },
                              { term: { assignee_id: { _name: context.name(:as_assignee), value: current_user.id } } },
                              { terms: { _name: context.name(:project, :membership, :id), project_id: authorized_project_ids } }
                            ]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
            }
        end

        query_hash[:query][:bool][:filter] << filter
        query_hash
      end
    end
  end
end
