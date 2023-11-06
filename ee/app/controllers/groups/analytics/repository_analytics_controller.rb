# frozen_string_literal: true

class Groups::Analytics::RepositoryAnalyticsController < Groups::Analytics::ApplicationController
  layout 'group'

  before_action :load_group
  before_action -> { authorize_view_by_action!(:read_group_repository_analytics) }

  def show
    Gitlab::Tracking.event(self.class.name, 'show', **pageview_tracker_params)
  end

  private

  def pageview_tracker_params
    {
      label: 'group_id',
      value: @group.id,
      user: current_user,
      namespace: @group
    }
  end
end
