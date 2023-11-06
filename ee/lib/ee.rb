# frozen_string_literal: true

module EE
  SUBSCRIPTIONS_URL = ::Gitlab::SubscriptionPortal::SUBSCRIPTIONS_URL
  SUBSCRIPTIONS_COMPARISON_URL = ::Gitlab::SubscriptionPortal.subscriptions_comparison_url.freeze
  SUBSCRIPTIONS_GRAPHQL_URL = ::Gitlab::SubscriptionPortal.subscriptions_graphql_url.freeze
  SUBSCRIPTIONS_MORE_MINUTES_URL = ::Gitlab::SubscriptionPortal.subscriptions_more_minutes_url.freeze
  SUBSCRIPTIONS_MORE_STORAGE_URL = ::Gitlab::SubscriptionPortal.subscriptions_more_storage_url.freeze
  SUBSCRIPTIONS_MANAGE_URL = ::Gitlab::SubscriptionPortal.subscriptions_manage_url.freeze
  SUBSCRIPTIONS_PLANS_URL = ::Gitlab::SubscriptionPortal.subscriptions_plans_url.freeze
  SUBSCRIPTIONS_GITLAB_PLANS_URL = ::Gitlab::SubscriptionPortal.subscriptions_gitlab_plans_url.freeze
  SUBSCRIPTION_PORTAL_ADMIN_EMAIL = ::Gitlab::SubscriptionPortal.subscription_portal_admin_email.freeze
  SUBSCRIPTION_PORTAL_ADMIN_TOKEN = ::Gitlab::SubscriptionPortal.subscription_portal_admin_token.freeze
  CUSTOMER_SUPPORT_URL = ::Gitlab::Saas.customer_support_url.freeze
  CUSTOMER_LICENSE_SUPPORT_URL = ::Gitlab::Saas.customer_license_support_url.freeze
  GITLAB_COM_STATUS_URL = ::Gitlab::Saas.gitlab_com_status_url.freeze
end
