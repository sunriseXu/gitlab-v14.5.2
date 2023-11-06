# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a Milestone' do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:milestone) { create(:milestone, project: project, start_date: '2020-01-01', due_date: '2020-01-15') }

  let(:query) do
    graphql_query_for('milestone', { id: milestone.to_global_id.to_s }, fields)
  end

  subject { graphql_data['milestone'] }

  before_all do
    project.add_guest(current_user)
  end

  context 'burnupTimeSeries' do
    let(:fields) do
      <<~FIELDS
      report {
        burnupTimeSeries {
          date
          scopeCount
          scopeWeight
          completedCount
          completedWeight
        }
      }
      FIELDS
    end

    let_it_be(:issue) { create(:issue, project: project) }

    before_all do
      create(:resource_milestone_event, issue: issue, milestone: milestone, action: :add, created_at: '2020-01-05')
    end

    context 'with insufficient license' do
      before do
        stub_licensed_features(milestone_charts: false)
      end

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to include(a_hash_including('message' => 'Milestone does not support burnup charts'))
      end
    end

    context 'with correct license' do
      before do
        stub_licensed_features(milestone_charts: true, issue_weights: true)
      end

      it 'returns burnup chart data' do
        post_graphql(query, current_user: current_user)

        expect(subject).to eq({
          'report' => {
            'burnupTimeSeries' => [
              {
                'date' => '2020-01-05',
                'scopeCount' => 1,
                'scopeWeight' => 0,
                'completedCount' => 0,
                'completedWeight' => 0
              }
            ]
          }
        })
      end
    end
  end

  shared_examples 'milestones queried by timeframe' do
    describe 'query for milestones by timeframe' do
      context 'without start' do
        it 'returns error' do
          post_graphql(milestones_query(parent, "timeframe: { end: \"#{3.days.ago.to_date}\" }"), current_user: current_user)

          expect(graphql_errors).to include(a_hash_including('message' => "Argument 'start' on InputObject 'Timeframe' is required. Expected type Date!"))
        end
      end

      context 'without end date' do
        it 'returns error' do
          post_graphql(milestones_query(parent, "timeframe: { start: \"#{3.days.ago.to_date}\" }"), current_user: current_user)

          expect(graphql_errors).to include(a_hash_including('message' => "Argument 'end' on InputObject 'Timeframe' is required. Expected type Date!"))
        end
      end

      context 'with start and end date' do
        it 'does not have errors' do
          post_graphql(milestones_query(parent, "timeframe: { start: \"#{3.days.ago.to_date}\", end: \"#{3.days.from_now.to_date}\" }"), current_user: current_user)

          expect(graphql_errors).to be_nil
        end
      end
    end
  end

  context 'group milestones' do
    it_behaves_like 'milestones queried by timeframe' do
      let(:parent) { group }
    end
  end

  context 'project milestones' do
    it_behaves_like 'milestones queried by timeframe' do
      let(:parent) { project }
    end
  end

  def project_milestones_query(project, milestone_query)
    <<~QUERY
      query {
        project(fullPath: "#{project.full_path}") {
          id,
          #{milestone_query}
        }
      }
    QUERY
  end

  def group_milestones_query(group, milestone_query)
    <<~QUERY
      query {
        group(fullPath: "#{group.full_path}") {
          id,
          #{milestone_query}
        }
      }
    QUERY
  end

  def milestones_query(parent, field_queries)
    query = <<~Q
      milestones(#{field_queries}) {
        nodes {
          id
        }
      }
    Q

    if parent.is_a?(Group)
      group_milestones_query(parent, query)
    else
      project_milestones_query(parent, query)
    end
  end
end
