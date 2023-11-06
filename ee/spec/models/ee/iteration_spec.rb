# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Iteration do
  include ActiveSupport::Testing::TimeHelpers

  let(:set_cadence) { nil }

  let_it_be(:group) { create(:group) }
  let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:project) { create(:project, group: group) }

  describe "#iid" do
    it "is properly scoped on project and group" do
      iteration1 = create(:iteration, :skip_project_validation, project: project)
      iteration2 = create(:iteration, :skip_project_validation, project: project)
      iteration3 = create(:iteration, group: group)
      iteration4 = create(:iteration, group: group)
      iteration5 = create(:iteration, :skip_project_validation, project: project)

      want = {
        iteration1: 1,
        iteration2: 2,
        iteration3: 1,
        iteration4: 2,
        iteration5: 3
      }
      got = {
        iteration1: iteration1.iid,
        iteration2: iteration2.iid,
        iteration3: iteration3.iid,
        iteration4: iteration4.iid,
        iteration5: iteration5.iid
      }
      expect(got).to eq(want)
    end
  end

  describe '.reference_pattern' do
    subject { described_class.reference_pattern }

    let(:captures) { subject.match(reference).named_captures }

    context 'when iteration id is provided' do
      let(:reference) { 'gitlab-org/gitlab-ce*iteration:123' }

      it 'correctly detects the iteration' do
        expect(captures).to eq(
          'namespace' => 'gitlab-org',
          'project' => 'gitlab-ce',
          'iteration_id' => '123',
          'iteration_name' => nil
        )
      end
    end

    context 'when iteration name is provided' do
      let(:reference) { 'gitlab-org/gitlab-ce*iteration:my-iteration' }

      it 'correctly detects the iteration' do
        expect(captures).to eq(
          'namespace' => 'gitlab-org',
          'project' => 'gitlab-ce',
          'iteration_id' => nil,
          'iteration_name' => 'my-iteration'
        )
      end
    end

    context 'when reference includes tags' do
      let(:reference) { '<p>gitlab-org/gitlab-ce*iteration:my-iteration</p>' }

      it 'correctly detects the iteration' do
        expect(captures).to eq(
          'namespace' => 'gitlab-org',
          'project' => 'gitlab-ce',
          'iteration_id' => nil,
          'iteration_name' => 'my-iteration'
        )
      end
    end
  end

  describe '.filter_by_state' do
    let_it_be(:closed_iteration) { create(:iteration, :closed, :skip_future_date_validation, group: group, start_date: 8.days.ago, due_date: 2.days.ago) }
    let_it_be(:current_iteration) { create(:iteration, :current, :skip_future_date_validation, group: group, start_date: 1.day.ago, due_date: 6.days.from_now) }
    let_it_be(:upcoming_iteration) { create(:iteration, :upcoming, group: group, start_date: 1.week.from_now, due_date: 2.weeks.from_now) }

    shared_examples_for 'filter_by_state' do
      it 'filters by the given state' do
        expect(described_class.filter_by_state(Iteration.all, state)).to match(expected_iterations)
      end
    end

    context 'filtering by closed iterations' do
      it_behaves_like 'filter_by_state' do
        let(:state) { 'closed' }
        let(:expected_iterations) { [closed_iteration] }
      end
    end

    context 'filtering by started iterations' do
      it_behaves_like 'filter_by_state' do
        let(:state) { 'current' }
        let(:expected_iterations) { [current_iteration] }
      end
    end

    context 'filtering by opened iterations' do
      it_behaves_like 'filter_by_state' do
        let(:state) { 'opened' }
        let(:expected_iterations) { [current_iteration, upcoming_iteration] }
      end
    end

    context 'filtering by upcoming iterations' do
      it_behaves_like 'filter_by_state' do
        let(:state) { 'upcoming' }
        let(:expected_iterations) { [upcoming_iteration] }
      end
    end

    context 'filtering by "all"' do
      it_behaves_like 'filter_by_state' do
        let(:state) { 'all' }
        let(:expected_iterations) { [closed_iteration, current_iteration, upcoming_iteration] }
      end
    end

    context 'filtering by nonexistent filter' do
      it 'raises ArgumentError' do
        expect { described_class.filter_by_state(Iteration.none, 'unknown') }.to raise_error(ArgumentError, 'Unknown state filter: unknown')
      end
    end
  end

  context 'Validations' do
    subject { build(:iteration, group: group, iterations_cadence: iteration_cadence, start_date: start_date, due_date: due_date) }

    describe 'when iteration belongs to project' do
      subject { build(:iteration, project: project, start_date: Time.current, due_date: 1.day.from_now) }

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors[:project_id]).to include('is not allowed. We do not currently support project-level iterations')
      end
    end

    describe '#dates_do_not_overlap' do
      let_it_be(:existing_iteration) { create(:iteration, group: group, iterations_cadence: iteration_cadence, start_date: 4.days.from_now, due_date: 1.week.from_now) }

      context 'when no Iteration dates overlap' do
        let(:start_date) { 2.weeks.from_now }
        let(:due_date) { 3.weeks.from_now }

        it { is_expected.to be_valid }
      end

      context 'when updated iteration dates overlap with its own dates' do
        it 'is valid' do
          existing_iteration.start_date = 5.days.from_now

          expect(existing_iteration).to be_valid
        end
      end

      context 'when dates overlap' do
        let(:start_date) { 5.days.from_now }
        let(:due_date) { 6.days.from_now }

        shared_examples_for 'overlapping dates' do
          shared_examples_for 'invalid dates' do
            context 'with iterations_cadences FF disabled' do
              before do
                stub_feature_flags(iteration_cadences: false)
              end

              it 'is not valid' do
                expect(subject).not_to be_valid
                expect(subject.errors[:base]).to include('Dates cannot overlap with other existing Iterations within this group')
              end
            end

            it 'is not valid even if forced' do
              subject.validate # to generate iid/etc
              expect { subject.save!(validate: false) }.to raise_exception(ActiveRecord::StatementInvalid, /#{constraint_name}/)
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:base]).to include('Dates cannot overlap with other existing Iterations within this iterations cadence')
            end
          end

          context 'when start_date overlaps' do
            let(:start_date) { 5.days.from_now }
            let(:due_date) { 3.weeks.from_now }

            it_behaves_like 'invalid dates'
          end

          context 'when due_date overlaps' do
            let(:start_date) { Time.current }
            let(:due_date) { 6.days.from_now }

            it_behaves_like 'invalid dates'
          end

          context 'when both overlap' do
            it_behaves_like 'invalid dates'
          end
        end

        context 'group' do
          it_behaves_like 'overlapping dates' do
            let(:constraint_name) { 'iteration_start_and_due_date_iterations_cadence_id_constraint' }
          end

          context 'different group' do
            let(:group) { create(:group) }
            let(:iteration_cadence) { create(:iterations_cadence, group: group) }

            it { is_expected.to be_valid }

            it 'does not trigger exclusion constraints' do
              expect { subject.save! }.not_to raise_exception
            end
          end

          context 'sub-group' do
            let(:subgroup) { create(:group, parent: group) }
            let(:subgroup_ic) { create(:iterations_cadence, group: subgroup) }

            subject { build(:iteration, group: subgroup, iterations_cadence: subgroup_ic, start_date: start_date, due_date: due_date) }

            it { is_expected.to be_valid }
          end
        end

        # Skipped. Pending https://gitlab.com/gitlab-org/gitlab/-/issues/299864
        xcontext 'project' do
          let_it_be(:existing_iteration) { create(:iteration, :skip_project_validation, project: project, start_date: 4.days.from_now, due_date: 1.week.from_now) }

          subject { build(:iteration, :skip_project_validation, project: project, start_date: start_date, due_date: due_date) }

          it_behaves_like 'overlapping dates' do
            let(:constraint_name) { 'iteration_start_and_due_daterange_project_id_constraint' }
          end

          context 'different project' do
            let(:project) { create(:project) }

            it { is_expected.to be_valid }

            it 'does not trigger exclusion constraints' do
              expect { subject.save! }.not_to raise_exception
            end
          end

          context 'in a group' do
            let(:group) { create(:group) }

            subject { build(:iteration, group: group, start_date: start_date, due_date: due_date) }

            it { is_expected.to be_valid }

            it 'does not trigger exclusion constraints' do
              expect { subject.save! }.not_to raise_exception
            end
          end

          context 'project in a group' do
            let_it_be(:project) { create(:project, group: create(:group)) }
            let_it_be(:existing_iteration) { create(:iteration, :skip_project_validation, project: project, start_date: 4.days.from_now, due_date: 1.week.from_now) }

            subject { build(:iteration, :skip_project_validation, project: project, start_date: start_date, due_date: due_date) }

            it_behaves_like 'overlapping dates' do
              let(:constraint_name) { 'iteration_start_and_due_daterange_project_id_constraint' }
            end
          end
        end
      end
    end

    describe '#future_date' do
      context 'when dates are in the future' do
        let(:start_date) { Time.current }
        let(:due_date) { 1.week.from_now }

        it { is_expected.to be_valid }
      end

      context 'when start_date is in the past' do
        let(:start_date) { 1.week.ago }
        let(:due_date) { 1.week.from_now }

        it { is_expected.to be_valid }
      end

      context 'when due_date is in the past' do
        let(:start_date) { 2.weeks.ago }
        let(:due_date) { 1.week.ago }

        it { is_expected.to be_valid }
      end

      context 'when due_date is before start date' do
        let(:start_date) { Time.current }
        let(:due_date) { 1.week.ago }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:due_date]).to include('must be greater than start date')
        end
      end

      context 'when start_date is over 500 years in the future' do
        let(:start_date) { 501.years.from_now }
        let(:due_date) { Time.current }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:start_date]).to include('cannot be more than 500 years in the future')
        end
      end

      context 'when due_date is over 500 years in the future' do
        let(:start_date) { Time.current }
        let(:due_date) { 501.years.from_now }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:due_date]).to include('cannot be more than 500 years in the future')
        end
      end
    end
  end

  context 'time scopes' do
    let_it_be(:project) { create(:project, :empty_repo) }
    let_it_be(:iteration_1) { create(:iteration, :skip_future_date_validation, :skip_project_validation, project: project, start_date: 3.days.ago, due_date: 1.day.from_now) }
    let_it_be(:iteration_2) { create(:iteration, :skip_future_date_validation, :skip_project_validation, project: project, start_date: 10.days.ago, due_date: 4.days.ago) }
    let_it_be(:iteration_3) { create(:iteration, :skip_project_validation, project: project, start_date: 4.days.from_now, due_date: 1.week.from_now) }

    describe 'start_date_passed' do
      it 'returns iterations where start_date is in the past but due_date is in the future' do
        expect(described_class.start_date_passed).to contain_exactly(iteration_1)
      end
    end

    describe 'due_date_passed' do
      it 'returns iterations where due date is in the past' do
        expect(described_class.due_date_passed).to contain_exactly(iteration_2)
      end
    end
  end

  describe '#validate_group' do
    let_it_be(:iterations_cadence) { create(:iterations_cadence, group: group) }

    context 'when the iteration and iteration cadence groups are same' do
      it 'is valid' do
        iteration = build(:iteration, group: group, iterations_cadence: iterations_cadence)

        expect(iteration).to be_valid
      end
    end

    context 'when the iteration and iteration cadence groups are different' do
      it 'is invalid' do
        other_group = create(:group)
        iteration = build(:iteration, group: other_group, iterations_cadence: iterations_cadence)

        expect(iteration).not_to be_valid
      end
    end

    context 'when the iteration belongs to a project and the iteration cadence is set' do
      it 'is invalid' do
        iteration = build(:iteration, project: project, iterations_cadence: iterations_cadence, skip_project_validation: true)

        expect(iteration).to be_invalid
      end
    end

    context 'when the iteration belongs to a project and the iteration cadence is not set' do
      it 'is valid' do
        iteration = build(:iteration, project: project, skip_project_validation: true)

        expect(iteration).to be_valid
      end
    end
  end

  describe '.within_timeframe' do
    let_it_be(:now) { Time.current }
    let_it_be(:project) { create(:project, :empty_repo) }
    let_it_be(:iteration_1) { create(:iteration, :skip_project_validation, project: project, start_date: now, due_date: 1.day.from_now) }
    let_it_be(:iteration_2) { create(:iteration, :skip_project_validation, project: project, start_date: 2.days.from_now, due_date: 3.days.from_now) }
    let_it_be(:iteration_3) { create(:iteration, :skip_project_validation, project: project, start_date: 4.days.from_now, due_date: 1.week.from_now) }

    it 'returns iterations with start_date and/or end_date between timeframe' do
      iterations = described_class.within_timeframe(2.days.from_now, 3.days.from_now)

      expect(iterations).to match_array([iteration_2])
    end

    it 'returns iterations which starts before the timeframe' do
      iterations = described_class.within_timeframe(1.day.from_now, 3.days.from_now)

      expect(iterations).to match_array([iteration_1, iteration_2])
    end

    it 'returns iterations which ends after the timeframe' do
      iterations = described_class.within_timeframe(3.days.from_now, 5.days.from_now)

      expect(iterations).to match_array([iteration_2, iteration_3])
    end
  end

  describe '.by_iteration_cadence_ids' do
    let_it_be(:iterations_cadence1) { create(:iterations_cadence, group: group, start_date: 10.days.ago) }
    let_it_be(:iterations_cadence2) { create(:iterations_cadence, group: group, start_date: 10.days.ago) }
    let_it_be(:closed_iteration) { create(:iteration, :closed, :skip_future_date_validation, iterations_cadence: iterations_cadence1, group: group, start_date: 8.days.ago, due_date: 2.days.ago) }
    let_it_be(:current_iteration) { create(:iteration, :current, :skip_future_date_validation, iterations_cadence: iterations_cadence2, group: group, start_date: 1.day.ago, due_date: 6.days.from_now) }
    let_it_be(:upcoming_iteration) { create(:iteration, :upcoming, iterations_cadence: iterations_cadence2, group: group, start_date: 1.week.from_now, due_date: 2.weeks.from_now) }

    it 'returns iterations by cadence' do
      iterations = described_class.by_iteration_cadence_ids(iterations_cadence1)

      expect(iterations).to match_array([closed_iteration])
    end

    it 'returns iterations by multiple cadences' do
      iterations = described_class.by_iteration_cadence_ids([iterations_cadence1, iterations_cadence2])

      expect(iterations).to match_array([closed_iteration, current_iteration, upcoming_iteration])
    end
  end

  context 'sets correct state based on iteration dates' do
    around do |example|
      travel_to(Time.utc(2019, 12, 30)) { example.run }
    end

    let_it_be(:iterations_cadence) { create(:iterations_cadence, group: group, start_date: 10.days.ago.utc.to_date) }

    let(:iteration) { build(:iteration, group: iterations_cadence.group, iterations_cadence: iterations_cadence, start_date: start_date, due_date: 2.weeks.after(start_date).to_date) }

    context 'start_date is in the future' do
      let(:start_date) { 1.day.from_now.utc.to_date }

      it 'sets state to started' do
        iteration.save!

        expect(iteration.state).to eq('upcoming')
      end
    end

    context 'start_date is today' do
      let(:start_date) { Time.now.utc.to_date }

      it 'sets state to started' do
        iteration.save!

        expect(iteration.state).to eq('current')
      end
    end

    context 'start_date is in the past and due date is still in the future' do
      let(:start_date) { 1.week.ago.utc.to_date }

      it 'sets state to started' do
        iteration.save!

        expect(iteration.state).to eq('current')
      end
    end

    context 'start_date is in the past and due date is also in the past' do
      let(:start_date) { 3.weeks.ago.utc.to_date }

      it 'sets state to started' do
        iteration.save!

        expect(iteration.state).to eq('closed')
      end
    end

    context 'when dates for an existing iteration change' do
      context 'when iteration dates go from future to past' do
        let(:iteration) { create(:iteration, group: iterations_cadence.group, iterations_cadence: iterations_cadence, start_date: 2.weeks.from_now.utc.to_date, due_date: 3.weeks.from_now.utc.to_date)}

        it 'sets state to closed' do
          expect(iteration.state).to eq('upcoming')

          iteration.start_date -= 4.weeks
          iteration.due_date -= 4.weeks
          iteration.save!

          expect(iteration.state).to eq('closed')
        end
      end

      context 'when iteration dates go from past to future' do
        let(:iteration) { create(:iteration, group: iterations_cadence.group, iterations_cadence: iterations_cadence, start_date: 2.weeks.ago.utc.to_date, due_date: 1.week.ago.utc.to_date)}

        it 'sets state to upcoming' do
          expect(iteration.state).to eq('closed')

          iteration.start_date += 3.weeks
          iteration.due_date += 3.weeks
          iteration.save!

          expect(iteration.state).to eq('upcoming')
        end

        context 'and today is between iteration start and due dates' do
          it 'sets state to started' do
            expect(iteration.state).to eq('closed')

            iteration.start_date += 2.weeks
            iteration.due_date += 2.weeks
            iteration.save!

            expect(iteration.state).to eq('current')
          end
        end
      end
    end
  end

  it_behaves_like 'a timebox', :iteration do
    let(:cadence) { create(:iterations_cadence, group: group) }
    let(:timebox_args) { [:skip_project_validation] }
    let(:timebox_table_name) { described_class.table_name.to_sym }

    # Overrides used during .within_timeframe
    let(:mid_point) { 1.year.from_now.to_date }
    let(:open_on_left) { min_date - 100.days }
    let(:open_on_right) { max_date + 100.days }

    describe "#uniqueness_of_title" do
      context "per group" do
        let(:timebox) { create(:iteration, *timebox_args, iterations_cadence: cadence, group: group) }

        before do
          project.update!(group: group)
        end

        it "accepts the same title in the same group with different cadence" do
          new_cadence = create(:iterations_cadence, group: group)
          new_timebox = create(:iteration, iterations_cadence: new_cadence, group: group, title: timebox.title)

          expect(new_timebox.iterations_cadence).not_to eq(timebox.iterations_cadence)
          expect(new_timebox).to be_valid
        end

        it "does not accept the same title when in same cadence" do
          new_timebox = described_class.new(group: group, iterations_cadence: cadence, title: timebox.title)

          expect(new_timebox).not_to be_valid
        end
      end
    end
  end

  context 'when closing iteration' do
    let_it_be_with_reload(:iteration) { create(:iteration, group: group, start_date: 4.days.from_now, due_date: 1.week.from_now) }

    context 'when cadence roll-over flag enabled' do
      before do
        iteration.iterations_cadence.update!(automatic: true, active: true, roll_over: true)
      end

      it 'triggers roll-over issues worker' do
        expect(Iterations::RollOverIssuesWorker).to receive(:perform_async).with([iteration.id])

        iteration.close!
      end
    end

    context 'when cadence roll-over flag disabled' do
      before do
        iteration.iterations_cadence.update!(automatic: true, active: true, roll_over: false)
      end

      it 'triggers roll-over issues worker' do
        expect(Iterations::RollOverIssuesWorker).not_to receive(:perform_async)

        iteration.close!
      end
    end
  end
end
