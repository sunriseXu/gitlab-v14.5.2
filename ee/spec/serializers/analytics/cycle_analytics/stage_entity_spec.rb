# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::StageEntity do
  subject(:entity_json) { described_class.new(Analytics::CycleAnalytics::StagePresenter.new(stage)).as_json }

  context 'when label based event is given' do
    let(:label) { create(:group_label, title: 'test label') }
    let(:stage) { build(:cycle_analytics_group_stage, group: label.group, start_event_label: label, start_event_identifier: :merge_request_label_added, end_event_identifier: :merge_request_merged) }

    it 'includes the label reference in the description' do
      expect(entity_json[:start_event_html_description]).to include(label.title)
    end
  end
end
