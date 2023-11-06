# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DORA Metrics (JavaScript fixtures)' do
  include ApiHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:reporter) { create(:user).tap { |u| project.add_reporter(u) } }
  let_it_be(:environment) { create(:environment, project: project, name: 'production') }
  let_it_be(:seconds_in_1_day) { 60 * 60 * 24 }

  before_all do
    [
      { date: '2015-06-01', deployment_frequency: 1, lead_time_for_changes_in_seconds: nil },
      { date: '2015-06-25', deployment_frequency: 1, lead_time_for_changes_in_seconds: nil },
      { date: '2015-06-30', deployment_frequency: 3, lead_time_for_changes_in_seconds: seconds_in_1_day },
      { date: '2015-07-01', deployment_frequency: 1, lead_time_for_changes_in_seconds: seconds_in_1_day * 5 },
      { date: '2015-07-03', deployment_frequency: 1, lead_time_for_changes_in_seconds: seconds_in_1_day * 7 }
    ].each do |data_point|
      create(:dora_daily_metrics,
             deployment_frequency: data_point[:deployment_frequency],
             lead_time_for_changes_in_seconds: data_point[:lead_time_for_changes_in_seconds],
             environment: environment,
             date: data_point[:date])
    end
  end

  before do
    stub_licensed_features(dora4_analytics: true)
    sign_in(reporter)
  end

  after(:all) do
    remove_repository(project)
  end

  describe API::Dora::Metrics, type: :request do
    let(:shared_params) do
      {
        end_date: Date.tomorrow.beginning_of_day,
        interval: 'daily'
      }
    end

    def make_request(additional_query_params:)
      params = shared_params.merge(additional_query_params)
      get api("/projects/#{project.id}/dora/metrics?#{params.to_query}", reporter)
    end

    shared_examples 'dora metric fixtures' do |metric_name|
      it "api/dora/metrics/daily_#{metric_name}_for_last_week.json" do
        make_request(additional_query_params: { metric: metric_name, start_date: 1.week.ago })
        expect(response).to be_successful
      end

      it "api/dora/metrics/daily_#{metric_name}_for_last_month.json" do
        make_request(additional_query_params: { metric: metric_name, start_date: 1.month.ago })
        expect(response).to be_successful
      end

      it "api/dora/metrics/daily_#{metric_name}_for_last_90_days.json" do
        make_request(additional_query_params: { metric: metric_name, start_date: 90.days.ago })
        expect(response).to be_successful
      end
    end

    describe 'deployment frequency' do
      it_behaves_like 'dora metric fixtures', 'deployment_frequency'
    end

    describe 'lead time' do
      it_behaves_like 'dora metric fixtures', 'lead_time_for_changes'
    end
  end
end
