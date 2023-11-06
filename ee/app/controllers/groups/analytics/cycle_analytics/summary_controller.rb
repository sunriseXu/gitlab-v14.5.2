# frozen_string_literal: true

module Groups
  module Analytics
    module CycleAnalytics
      class SummaryController < Groups::Analytics::ApplicationController
        include CycleAnalyticsParams

        before_action :load_group
        before_action :authorize_access
        before_action :validate_params

        def show
          render json: group_level.summary
        end

        def time_summary
          render json: group_level.time_summary
        end

        private

        def group_level
          @group_level ||= ::Analytics::CycleAnalytics::GroupLevel.new(group: @group, options: options(request_params.to_data_collector_params))
        end

        def authorize_access
          return render_403 unless can?(current_user, :read_group_cycle_analytics, @group)
        end
      end
    end
  end
end
