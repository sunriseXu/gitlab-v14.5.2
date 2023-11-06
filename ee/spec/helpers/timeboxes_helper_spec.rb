# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TimeboxesHelper do
  describe '#can_generate_chart?' do
    using RSpec::Parameterized::TableSyntax

    where(:supports_milestone_charts, :start_date, :due_date, :can_generate_chart) do
      false | nil        | nil        | false
      true  | Date.today | Date.today | true
      true  | Date.today | nil        | false
      true  | nil        | Date.today | false
      true  | nil        | nil        | false
    end

    subject { helper.can_generate_chart?(milestone) }

    let(:milestone) { double('Milestone', supports_milestone_charts?: supports_milestone_charts, start_date: start_date, due_date: due_date) }

    with_them do
      it { is_expected.to eq(can_generate_chart) }
    end
  end

  describe '#timebox_date_range' do
    let(:yesterday) { Date.yesterday }
    let(:tomorrow) { yesterday + 2 }
    let(:format) { '%b %-d, %Y' }
    let(:yesterday_formatted) { yesterday.strftime(format) }
    let(:tomorrow_formatted) { tomorrow.strftime(format) }

    context 'iteration' do
      # Iterations always have start and due dates, so only A-B format is expected
      it 'formats properly' do
        iteration = build(:iteration, start_date: yesterday, due_date: tomorrow)

        expect(timebox_date_range(iteration)).to eq("#{yesterday_formatted}–#{tomorrow_formatted}")
      end
    end
  end

  describe '#show_burndown_placeholder?' do
    let_it_be(:user) { build(:user) }

    subject { helper.show_burndown_placeholder?(milestone) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    describe('milestone does not support burndown charts') do
      let(:milestone) { double('Milestone', supports_milestone_charts?: false) }

      it { is_expected.to be false }
    end

    describe('user without permission') do
      let(:milestone) { double('Milestone', supports_milestone_charts?: true, resource_parent: 'board') }

      before do
        stub_can_admin_milestone(false)
      end

      it { is_expected.to be false }
    end

    describe('user with permission') do
      let(:milestone) { double('Milestone', supports_milestone_charts?: true, resource_parent: 'board') }

      before do
        stub_can_admin_milestone(true)
      end

      it { is_expected.to be true }
    end
  end

  describe '#legacy_milestone?' do
    subject { legacy_milestone?(milestone) }

    describe 'without any ResourceStateEvents' do
      let(:milestone) { double('Milestone', created_at: Date.current) }

      it { is_expected.to be_nil }
    end

    describe 'with ResourceStateEvent created before milestone' do
      let(:milestone) { double('Milestone', created_at: Date.current) }

      before do
        create_resource_state_event(Date.yesterday)
      end

      it { is_expected.to eq(false) }
    end

    describe 'with ResourceStateEvent created same day as milestone' do
      let(:milestone) { double('Milestone', created_at: Date.current) }

      before do
        create_resource_state_event
      end

      it { is_expected.to eq(false) }
    end

    describe 'with ResourceStateEvent created after milestone' do
      let(:milestone) { double('Milestone', created_at: Date.yesterday) }

      before do
        create_resource_state_event
      end

      it { is_expected.to eq(true) }
    end
  end

  def create_resource_state_event(created_at = Date.current)
    create(:resource_state_event, created_at: created_at)
  end

  def stub_can_admin_milestone(ability)
    allow(helper).to receive(:can?).with(user, :admin_milestone, milestone.resource_parent).and_return(ability)
  end
end
