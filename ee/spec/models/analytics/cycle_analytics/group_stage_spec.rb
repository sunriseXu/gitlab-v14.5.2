# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::GroupStage do
  describe 'uniqueness validation on name' do
    subject { build(:cycle_analytics_group_stage) }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to([:group_id, :group_value_stream_id]) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:value_stream) }
  end

  it_behaves_like 'value stream analytics stage' do
    let(:factory) { :cycle_analytics_group_stage }
    let(:parent) { create(:group) }
    let(:parent_name) { :group }
  end

  include_examples 'value stream analytics label based stage' do
    let_it_be(:parent) { create(:group) }
    let_it_be(:parent_in_subgroup) { create(:group, parent: parent) }
    let_it_be(:group_label) { create(:group_label, group: parent) }
    let_it_be(:parent_outside_of_group_label_scope) { create(:group) }
  end

  context 'relative positioning' do
    it_behaves_like 'a class that supports relative positioning' do
      let(:parent) { create(:group) }
      let(:factory) { :cycle_analytics_group_stage }
      let(:default_params) { { group: parent } }
    end
  end

  describe '.distinct_stages_within_hierarchy' do
    let_it_be(:group) { create(:group) }
    let_it_be(:sub_group) { create(:group, parent: group) }

    before do
      # event identifiers are the same
      create(:cycle_analytics_group_stage, name: 'Stage A1', group: group, start_event_identifier: :merge_request_created, end_event_identifier: :merge_request_merged)
      create(:cycle_analytics_group_stage, name: 'Stage A2', group: sub_group, start_event_identifier: :merge_request_created, end_event_identifier: :merge_request_merged)
      create(:cycle_analytics_group_stage, name: 'Stage A3', group: sub_group, start_event_identifier: :merge_request_created, end_event_identifier: :merge_request_merged)

      create(:cycle_analytics_group_stage, name: 'Stage B1', group: group, start_event_identifier: :merge_request_created, end_event_identifier: :merge_request_closed)
    end

    it 'returns distinct stages by the event identifiers' do
      stages = described_class.distinct_stages_within_hierarchy(group).to_a

      expected_event_pairs = [
        %w[merge_request_created merge_request_merged],
        %w[merge_request_created merge_request_closed]
      ]

      current_event_pairs = stages.map do |stage|
        [stage.start_event_identifier, stage.end_event_identifier]
      end

      expect(current_event_pairs).to eq(expected_event_pairs)
    end
  end
end
