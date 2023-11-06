# frozen_string_literal: true

# NOTE: This is largely mimicking the structure created as part of the
# TrialStatusWidgetHelper (ee/app/helpers/trial_status_widget_helper.rb), & it
# is utilizing a few methods (including private ones) from that helper as well.
module PaidFeatureCalloutHelper
  def run_highlight_paid_features_during_active_trial_experiment(group, &block)
    experiment(:highlight_paid_features_during_active_trial, group: group) do |e|
      e.exclude! unless billing_plans_and_trials_available?
      e.exclude! unless group && eligible_for_trial_upgrade_callout?(group)
      e.use { nil } # control gets nothing new added to the existing UI
      e.try(&block)
      e.record!
    end
  end

  def paid_feature_badge_data_attrs(feature_name)
    base_attrs = base_paid_feature_data_attrs(feature_name)

    base_attrs.merge({
      id: feature_callout_container_id(feature_name)
    })
  end

  def paid_feature_popover_data_attrs(group:, feature_name:)
    base_attrs = base_paid_feature_data_attrs(feature_name)
    container_id = feature_callout_container_id(feature_name)

    base_attrs.merge({
      container_id: container_id,
      days_remaining: group.trial_days_remaining,
      href_compare_plans: group_billings_path(group),
      href_upgrade_to_paid: premium_subscription_path_for_group(group),
      plan_name_for_trial: group.gitlab_subscription&.plan_title,
      plan_name_for_upgrade: 'Premium',
      target_id: container_id
    })
  end

  private

  def feature_callout_container_id(feature_name)
    "#{feature_name.parameterize}-callout"
  end

  def base_paid_feature_data_attrs(feature_name)
    { feature_name: feature_name }
  end

  def premium_subscription_path_for_group(group)
    new_subscriptions_path(namespace_id: group.id, plan_id: premium_plan_id)
  end

  def premium_plan_id
    strong_memoize(:premium_plan_id) do
      plans = GitlabSubscriptions::FetchSubscriptionPlansService.new(plan: :free).execute

      next unless plans

      plans.find { |data| data['code'] == 'premium' }&.fetch('id', nil)
    end
  end
end
