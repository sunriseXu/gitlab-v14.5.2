# frozen_string_literal: true

module Analytics
  module CycleAnalytics
    class DataLoaderService
      MAX_UPSERT_COUNT = 10_000
      UPSERT_LIMIT = 1000
      BATCH_LIMIT = 500
      EVENTS_LIMIT = 25

      CONFIG_MAPPING = {
        Issue => { event_model: IssueStageEvent, project_column: :project_id }.freeze,
        MergeRequest => { event_model: MergeRequestStageEvent, project_column: :target_project_id }.freeze
      }.freeze

      def initialize(group:, model:, cursor: nil, updated_at_before: Time.current)
        @group = group
        @model = model
        @cursor = cursor
        @updated_at_before = updated_at_before
        @upsert_count = 0
      end

      def execute
        unless model == Issue || model == MergeRequest
          return error(:invalid_model)
        end

        unless group.licensed_feature_available?(:cycle_analytics_for_groups)
          return error(:missing_license)
        end

        unless group.root_ancestor == group
          return error(:requires_top_level_group)
        end

        response = success(:model_processed)

        iterator.each_batch(of: BATCH_LIMIT) do |records|
          loaded_records = records.to_a

          break if records.empty?

          load_timestamp_data_into_value_stream_analytics(loaded_records)

          if upsert_count >= MAX_UPSERT_COUNT
            response = success(:limit_reached, cursor: cursor_for_node(loaded_records.last))
            break
          end
        end

        response
      end

      private

      attr_reader :group, :model, :cursor, :updated_at_before, :upsert_count

      def error(error_reason)
        ServiceResponse.error(
          message: "DataLoader error for group: #{group.id} (#{error_reason})",
          payload: { reason: error_reason }
        )
      end

      def success(success_reason, cursor: {})
        ServiceResponse.success(payload: { reason: success_reason, cursor: cursor })
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def iterator_base_scope
        model.updated_before(updated_at_before).order(:updated_at, :id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def iterator
        opts = {
          in_operator_optimization_options: {
            array_scope: group.all_projects.select(:id),
            array_mapping_scope: -> (id_expression) { model.where(model.arel_table[project_column].eq(id_expression)) }
          }
        }

        Gitlab::Pagination::Keyset::Iterator.new(scope: iterator_base_scope, cursor: cursor, **opts)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      # rubocop: disable CodeReuse/ActiveRecord
      def load_timestamp_data_into_value_stream_analytics(loaded_records)
        records_by_id = {}

        events.each_slice(EVENTS_LIMIT) do |event_slice|
          scope = model.join_project.id_in(loaded_records.pluck(:id))

          current_select_columns = select_columns # default SELECT columns
          # Add the stage timestamp columns to the SELECT
          event_slice.each do |event|
            scope = event.include_in(scope)
            current_select_columns << event.timestamp_projection.as(event_column_name(event))
          end

          record_attributes = scope
            .reselect(*current_select_columns)
            .to_a
            .map(&:attributes)

          records_by_id.deep_merge!(record_attributes.index_by { |attr| attr['id'] }.compact)
        end

        upsert_data(records_by_id)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def upsert_data(records)
        data = []

        records.each_value do |record|
          stages.each do |stage|
            next if record[event_column_name(stage.start_event)].nil?

            data << {
              stage_event_hash_id: stage.stage_event_hash_id,
              issuable_id: record['id'],
              group_id: record['group_id'],
              project_id: record['project_id'],
              author_id: record['author_id'],
              milestone_id: record['milestone_id'],
              state_id: record['state_id'],
              start_event_timestamp: record[event_column_name(stage.start_event)],
              end_event_timestamp: record[event_column_name(stage.end_event)]
            }

            if data.size == UPSERT_LIMIT
              @upsert_count += event_model.upsert_data(data)
              data.clear
            end
          end
        end

        @upsert_count += event_model.upsert_data(data) if data.any?
      end

      def select_columns
        [
          model.arel_table[:id],
          model.arel_table[project_column].as('project_id'),
          model.arel_table[:milestone_id],
          model.arel_table[:author_id],
          model.arel_table[:state_id],
          Project.arel_table[:parent_id].as('group_id')
        ]
      end

      # rubocop: disable CodeReuse/ActiveRecord
      def cursor_for_node(record)
        scope, _ = Gitlab::Pagination::Keyset::SimpleOrderBuilder.build(iterator_base_scope)
        order = Gitlab::Pagination::Keyset::Order.extract_keyset_order_object(scope)
        order.cursor_attributes_for_node(record)
      end
      # rubocop: enable CodeReuse/ActiveRecord

      def project_column
        CONFIG_MAPPING.fetch(model).fetch(:project_column)
      end

      def event_model
        CONFIG_MAPPING.fetch(model).fetch(:event_model)
      end

      def event_column_name(event)
        "column_" + event.hash_code[0...10]
      end

      def stages
        @stages ||= Analytics::CycleAnalytics::GroupStage
          .distinct_stages_within_hierarchy(group)
          .select { |stage| stage.start_event.object_type == model }
      end

      def events
        @events ||= stages
          .flat_map { |stage| [stage.start_event, stage.end_event] }
          .uniq { |event| event.hash_code }
      end
    end
  end
end
