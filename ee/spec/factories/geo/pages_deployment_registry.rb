# frozen_string_literal: true

FactoryBot.define do
  factory :geo_pages_deployment_registry, class: 'Geo::PagesDeploymentRegistry' do
    pages_deployment # This association should have data, like a file or repository
    state { Geo::PagesDeploymentRegistry.state_value(:pending) }

    trait :synced do
      state { Geo::PagesDeploymentRegistry.state_value(:synced) }
      last_synced_at { 5.days.ago }
    end

    trait :failed do
      state { Geo::PagesDeploymentRegistry.state_value(:failed) }
      last_synced_at { 1.day.ago }
      retry_count { 2 }
      last_sync_failure { 'Random error' }
    end

    trait :started do
      state { Geo::PagesDeploymentRegistry.state_value(:started) }
      last_synced_at { 1.day.ago }
      retry_count { 0 }
    end
  end
end
