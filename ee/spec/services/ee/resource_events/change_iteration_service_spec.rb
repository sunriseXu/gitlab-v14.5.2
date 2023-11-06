# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceEvents::ChangeIterationService do
  let_it_be(:timebox) { create(:iteration) }

  let(:created_at_time) { Time.utc(2019, 12, 30) }
  let(:add_timebox_args) { { old_iteration_id: nil } }
  let(:remove_timebox_args) { { old_iteration_id: timebox.id } }

  [:issue, :merge_request].each do |issuable|
    it_behaves_like 'timebox(milestone or iteration) resource events creator', ResourceIterationEvent do
      let_it_be(:resource) { create(issuable) } # rubocop:disable Rails/SaveBang
    end
  end
end
