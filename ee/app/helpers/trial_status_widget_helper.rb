# frozen_string_literal: true

# NOTE: The patterns first introduced in this helper for doing trial-related
# callouts are mimicked by the PaidFeatureCalloutHelper. A third reuse of these
# patterns (especially as these experiments finish & become permanent parts of
# the codebase) could trigger the need to extract these patterns into a single,
# reusable, sharable helper.
module TrialStatusWidgetHelper
  D14_CALLOUT_RANGE = (7..14).freeze # between 14 & 7 days remaining
  D3_CALLOUT_RANGE = (0..3).freeze # between 3 & 0 days remaining
  D14_CALLOUT_ID = 'trial_status_reminder_d14'
  D3_CALLOUT_ID = 'trial_status_reminder_d3'

  def trial_status_popover_data_attrs(group)
    base_attrs = trial_status_common_data_attrs(group)
    base_attrs.merge(
      days_remaining: group.trial_days_remaining, # for experiment tracking
      group_name: group.name,
      purchase_href: ultimate_subscription_path_for_group(group),
      start_initially_shown: force_popover_to_be_shown?(group),
      target_id: base_attrs[:container_id],
      trial_end_date: group.trial_ends_on,
      user_callouts_path: user_callouts_path,
      user_callouts_feature_id: current_user_callout_feature_id(group.trial_days_remaining)
    )
  end

  def trial_status_widget_data_attrs(group)
    trial_status_common_data_attrs(group).merge(
      days_remaining: group.trial_days_remaining,
      nav_icon_image_path: image_path('illustrations/golden_tanuki.svg'),
      percentage_complete: group.trial_percentage_complete
    )
  end

  def show_trial_status_widget?(group)
    billing_plans_and_trials_available? && eligible_for_trial_upgrade_callout?(group)
  end

  private

  def billing_plans_and_trials_available?
    ::Gitlab::CurrentSettings.should_check_namespace_plan?
  end

  def eligible_for_trial_upgrade_callout?(group)
    group.trial_active? && can?(current_user, :admin_namespace, group)
  end

  def force_popover_to_be_shown?(group)
    force_popover = false

    experiment(:forcibly_show_trial_status_popover, group: group) do |e|
      e.try do
        force_popover = !dismissed_feature_callout?(
          current_user_callout_feature_id(group.trial_days_remaining)
        )
      end
      e.record!
    end

    force_popover
  end

  def current_user_callout_feature_id(days_remaining)
    return D14_CALLOUT_ID if D14_CALLOUT_RANGE.cover?(days_remaining)
    return D3_CALLOUT_ID if D3_CALLOUT_RANGE.cover?(days_remaining)
  end

  def dismissed_feature_callout?(feature_name)
    return true if feature_name.blank?

    current_user.dismissed_callout?(feature_name: feature_name)
  end

  def trial_status_common_data_attrs(group)
    {
      container_id: 'trial-status-sidebar-widget',
      plan_name: group.gitlab_subscription&.plan_title,
      plans_href: group_billings_path(group)
    }
  end

  def ultimate_subscription_path_for_group(group)
    new_subscriptions_path(namespace_id: group.id, plan_id: ultimate_plan_id)
  end

  def ultimate_plan_id
    strong_memoize(:ultimate_plan_id) do
      plans = GitlabSubscriptions::FetchSubscriptionPlansService.new(plan: :free).execute

      next unless plans

      plans.find { |data| data['code'] == 'ultimate' }&.fetch('id', nil)
    end
  end
end
