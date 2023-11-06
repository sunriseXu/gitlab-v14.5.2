# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Milestones::UpdateService do
  describe '#execute' do
    context 'refresh related epic dates' do
      it 'updates milestone sourced dates' do
        project = create(:project)
        user = build(:user)
        milestone = create(:milestone, project: project)
        epic = create(:epic)
        create(:issue, milestone: milestone, epic: epic, project: project)
        due_date = 3.days.from_now.to_date

        described_class.new(project, user, { due_date: due_date }).execute(milestone)

        expect(epic.reload).to have_attributes(
          start_date: nil,
          start_date_sourcing_milestone: nil,
          due_date: due_date,
          due_date_sourcing_milestone: milestone
        )
      end
    end
  end
end
