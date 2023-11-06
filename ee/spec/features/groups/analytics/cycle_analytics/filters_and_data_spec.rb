# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group value stream analytics filters and data', :js do
  include CycleAnalyticsHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository, namespace: group, group: group, name: 'Cool fun project') }
  let_it_be(:sub_group) { create(:group, name: 'CA-sub-group', parent: group) }
  let_it_be(:sub_group_project) { create(:project, :repository, namespace: group, group: sub_group, name: 'Cool sub group project') }
  let_it_be(:group_label1) { create(:group_label, group: group) }
  let_it_be(:group_label2) { create(:group_label, group: group) }

  let(:milestone) { create(:milestone, project: project) }
  let(:mr) { create_merge_request_closing_issue(user, project, issue, commit_message: "References #{issue.to_reference}") }
  let(:pipeline) { create(:ci_empty_pipeline, status: 'created', project: project, ref: mr.source_branch, sha: mr.source_branch_sha, head_pipeline_of: mr) }

  path_nav_selector = '[data-testid="vsa-path-navigation"]'
  filter_bar_selector = '[data-testid="vsa-filter-bar"]'
  card_metric_selector = '[data-testid="vsa-time-metrics"] .gl-single-stat'
  new_issues_count = 3

  new_issues_count.times do |i|
    let_it_be("issue_#{i}".to_sym) { create(:issue, title: "New Issue #{i}", project: sub_group_project, created_at: 2.days.ago) }
  end

  def select_stage(name)
    string_id = "CycleAnalyticsStage|#{name}"
    within '[data-testid="vsa-path-navigation"]' do
      page.find('li', text: s_(string_id), match: :prefer_exact).click
    end

    wait_for_requests
  end

  def create_merge_request(id, extra_params = {})
    params = {
      id: id,
      target_branch: 'master',
      source_project: project2,
      source_branch: "feature-branch-#{id}",
      title: "mr name#{id}",
      created_at: 2.days.ago
    }.merge(extra_params)

    create(:merge_request, params)
  end

  before do
    stub_licensed_features(cycle_analytics_for_groups: true, type_of_work_analytics: true, dora4_analytics: true)

    group.add_owner(user)
    project.add_maintainer(user)

    sign_in(user)
  end

  shared_examples 'empty state' do
    it 'displays an empty state' do
      element = page.find('.row.empty-state')

      expect(element).to have_content(_("We don't have enough data to show this stage."))
      expect(element.find('.svg-content img')['src']).to have_content('illustrations/analytics/cycle-analytics-empty-chart')
    end
  end

  shared_examples 'no group available' do
    it 'displays empty text' do
      [
        'Value Stream Analytics can help you determine your team’s velocity',
        'Filter parameters are not valid. Make sure that the end date is after the start date.'
      ].each do |content|
        expect(page).to have_content(content)
      end
    end
  end

  shared_examples 'has overview metrics' do
    before do
      wait_for_requests
    end

    it 'displays the recent activity' do
      deploys_count = page.all(card_metric_selector)[4]

      expect(deploys_count).to have_content(n_('Deploy', 'Deploys', 0))
      expect(deploys_count).to have_content('-')

      deployment_frequency = page.all(card_metric_selector).last

      expect(deployment_frequency).to have_content(_('Deployment Frequency'))
      expect(deployment_frequency).to have_content('-')

      issue_count = page.all(card_metric_selector)[3]

      expect(issue_count).to have_content(n_('New Issue', 'New Issues', 3))
      expect(issue_count).to have_content(new_issues_count)
    end

    it 'displays time metrics' do
      lead_time = page.all(card_metric_selector).first

      expect(lead_time).to have_content(_('Lead Time'))
      expect(lead_time).to have_content('-')

      cycle_time = page.all(card_metric_selector)[1]

      expect(cycle_time).to have_content(_('Cycle Time'))
      expect(cycle_time).to have_content('-')

      median_lead_time_for_changes = page.all(card_metric_selector)[2]

      expect(median_lead_time_for_changes).to have_content(s_('CycleAnalytics|Lead Time for Changes'))
      expect(median_lead_time_for_changes).to have_content('-')
    end
  end

  shared_examples 'group value stream analytics' do
    context 'stage table' do
      before do
        select_stage("Issue")
      end

      it 'displays the stage table' do
        expect(page).to have_selector('[data-testid="vsa-stage-table"]')
      end
    end

    context 'navigation' do
      before do
        select_group(selected_group)
      end

      it 'shows the path navigation' do
        expect(page).to have_selector(path_nav_selector)
      end

      it 'each stage will have median values' do
        stage_medians = page.all('.gl-path-button span').collect(&:text)

        expect(stage_medians).to eq(["-"] * 7)
      end

      it 'displays the default list of stages' do
        path_nav = page.find(path_nav_selector)

        expect(path_nav).to have_content(_("Overview"))

        %w[Issue Plan Code Test Review Staging].each do |item|
          string_id = "CycleAnalytics|#{item}"
          expect(path_nav).to have_content(s_(string_id))
        end
      end
    end
  end

  shared_examples 'has default filters' do
    it 'shows the projects filter' do
      expect(page).to have_selector('.dropdown-projects', visible: true)
    end

    it 'shows the date filter' do
      expect(page).to have_selector('.js-daterange-picker', visible: true)
    end

    it 'shows the filter bar' do
      expect(page).to have_selector(filter_bar_selector, visible: false)
    end
  end

  context 'without valid query parameters set' do
    context 'with created_after date > created_before date' do
      before do
        visit "#{group_analytics_cycle_analytics_path(group)}?created_after=2019-12-31&created_before=2019-11-01"
      end

      it_behaves_like 'no group available'
    end

    context 'with fake parameters' do
      before do
        visit "#{group_analytics_cycle_analytics_path(group)}?beans=not-cool"

        select_stage("Issue")
      end

      it_behaves_like 'empty state'
    end
  end

  context 'with valid query parameters set' do
    projects_dropdown = '.js-projects-dropdown-filter'

    context 'with project_ids set' do
      before do
        visit "#{group_analytics_cycle_analytics_path(group)}?project_ids[]=#{project.id}"
      end

      it 'has the projects dropdown prepopulated' do
        element = page.find(projects_dropdown)

        expect(element).to have_content project.name
      end
    end

    context 'with created_before and created_after set' do
      date_range = '.js-daterange-picker'

      before do
        visit "#{group_analytics_cycle_analytics_path(group)}?created_before=2019-12-31&created_after=2019-11-01"
      end

      it 'has the date range prepopulated' do
        element = page.find(date_range)

        expect(element.find('.js-daterange-picker-from input').value).to eq '2019-11-01'
        expect(element.find('.js-daterange-picker-to input').value).to eq '2019-12-31'
        expect(page.find('.js-tasks-by-type-chart')).to have_text(_("Showing data for group '%{group_name}' from Nov 1, 2019 to Dec 31, 2019") % { group_name: group.name })
      end
    end
  end

  context 'with a group' do
    let(:selected_group) { group }

    before do
      select_group(group)
    end

    it_behaves_like 'group value stream analytics'

    it_behaves_like 'has overview metrics'

    it_behaves_like 'has default filters'
  end

  context 'with a sub group' do
    let(:selected_group) { sub_group }

    before do
      select_group(sub_group)
    end

    it_behaves_like 'group value stream analytics'

    it_behaves_like 'has overview metrics'

    it_behaves_like 'has default filters'
  end

  context 'with lots of data', :js do
    let_it_be(:issue) { create(:issue, project: project) }

    around do |example|
      freeze_time { example.run }
    end

    before do
      stub_feature_flags(use_vsa_aggregated_tables: false)
      issue.update!(created_at: 5.days.ago)
      create_cycle(user, project, issue, mr, milestone, pipeline)
      create(:labeled_issue, created_at: 5.days.ago, project: create(:project, group: group), labels: [group_label1])
      create(:labeled_issue, created_at: 3.days.ago, project: create(:project, group: group), labels: [group_label2])

      issue.metrics.update!(first_mentioned_in_commit_at: mr.created_at - 5.hours)
      mr.metrics.update!(first_deployed_to_production_at: mr.created_at + 2.hours, merged_at: mr.created_at + 1.hour)

      deploy_master(user, project, environment: 'staging')
      deploy_master(user, project)

      select_group(group)
    end

    stages_with_data = [
      { title: 'Issue', description: 'Time before an issue gets scheduled', events_count: 1, time: '5d' },
      { title: 'Code', description: 'Time until first merge request', events_count: 1, time: '5h' },
      { title: 'Review', description: 'Time between merge request creation and merge/close', events_count: 1, time: '1h' },
      { title: 'Staging', description: 'From merge request merge until deploy to production', events_count: 1, time: '1h' }
    ]

    stages_without_data = [
      { title: 'Plan', description: 'Time before an issue starts implementation', events_count: 0, time: "-" },
      { title: 'Test', description: 'Total test time for all commits/merges', events_count: 0, time: "-" }
    ]

    it 'each stage with events will display the stage events list when selected', :sidekiq_might_not_need_inline do
      stages_without_data.each do |stage|
        select_stage(stage[:title])
        expect(page).not_to have_selector('[data-testid="vsa-stage-event"]')
      end

      stages_with_data.each do |stage|
        select_stage(stage[:title])
        expect(page).to have_selector('[data-testid="vsa-stage-table"]')
        expect(page.all('[data-testid="vsa-stage-event"]').length).to eq(stage[:events_count])
      end
    end

    it 'each stage will be selectable' do
      [].concat(stages_without_data, stages_with_data).each do |stage|
        select_stage(stage[:title])

        stage_name = page.find("#{path_nav_selector} .gl-path-active-item-indigo").text
        expect(stage_name).to include(stage[:title])
        expect(stage_name).to include(stage[:time])
      end
    end

    it 'will not display the stage table on the overview stage' do
      expect(page).not_to have_selector('[data-testid="vsa-stage-table"]')

      select_stage("Issue")
      expect(page).to have_selector('[data-testid="vsa-stage-table"]')
    end

    it 'will have data available' do
      duration_chart_content = page.find('[data-testid="vsa-duration-chart"]')
      expect(duration_chart_content).not_to have_text(_("There is no data available. Please change your selection."))
      expect(duration_chart_content).to have_text(s_('CycleAnalytics|Average days to completion'))

      tasks_by_type_chart_content = page.find('.js-tasks-by-type-chart')
      expect(tasks_by_type_chart_content).not_to have_text(_("There is no data available. Please change your selection."))
    end

    context 'with filters applied' do
      before do
        visit "#{group_analytics_cycle_analytics_path(group)}?created_before=2019-12-31&created_after=2019-11-01"

        wait_for_stages_to_load
      end

      it 'will filter the data' do
        duration_chart_content = page.find('[data-testid="vsa-duration-chart"]')
        expect(duration_chart_content).not_to have_text(s_('CycleAnalytics|Average days to completion'))
        expect(duration_chart_content).to have_text(_("There is no data available. Please change your selection."))

        tasks_by_type_chart_content = page.find('.js-tasks-by-type-chart')
        expect(tasks_by_type_chart_content).to have_text(_("There is no data available. Please change your selection."))
      end
    end
  end
end
