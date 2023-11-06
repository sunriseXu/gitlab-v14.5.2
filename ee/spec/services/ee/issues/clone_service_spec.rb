# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issues::CloneService do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:old_project) { create(:project, group: group) }
  let_it_be(:new_project) { create(:project, group: group) }
  let_it_be(:old_issue, reload: true) { create(:issue, project: old_project, author: user) }

  let(:clone_service) { described_class.new(project: old_project, current_user: user) }

  subject { clone_service.execute(old_issue, new_project) }

  before do
    group.add_reporter(user)
  end

  describe '#execute' do
    context 'group issue hooks' do
      let_it_be(:hook) { create(:group_hook, group: group, issues_events: true) }

      it 'executes group issue hooks' do
        allow_next_instance_of(WebHookService) do |instance|
          allow(instance).to receive(:execute)
        end

        # Ideally, we'd test that `WebHookWorker.jobs.size` increased by 1,
        # but since the entire spec run takes place in a transaction, we never
        # actually get to the `after_commit` hook that queues these jobs.
        expect { subject }
        .not_to raise_error # Sidekiq::Worker::EnqueueFromTransactionError
      end
    end

    context 'resource weight events' do
      let_it_be(:old_issue) { create(:issue, project: old_project, author: user, weight: 5) }
      let_it_be(:event1) { create(:resource_weight_event, issue: old_issue, weight: 1) }
      let_it_be(:event2) { create(:resource_weight_event, issue: old_issue, weight: 42) }
      let_it_be(:event3) { create(:resource_weight_event, issue: old_issue, weight: 5) }

      let_it_be(:another_old_issue) { create(:issue, project: new_project, author: user) }
      let_it_be(:event4) { create(:resource_weight_event, issue: another_old_issue, weight: 2) }

      it 'creates expected resource weight events' do
        expect(subject.resource_weight_events.map(&:weight)).to contain_exactly(1, 42, 5)
      end
    end

    context 'when it is not allowed to clone issues of given type' do
      it 'throws error' do
        requirement_issue = create(:issue, issue_type: :requirement, project: old_project)

        expect { clone_service.execute(requirement_issue, new_project) }
          .to raise_error(StandardError, 'Cannot clone issues of \'requirement\' type.')
      end
    end

    context 'epics' do
      context 'issue assigned to epic' do
        let_it_be(:epic) { create(:epic, group: group) }

        before do
          stub_licensed_features(epics: true)
          create(:epic_issue, issue: old_issue, epic: epic)
        end

        it 'creates epic reference' do
          expect(subject.epic).to eq(epic)
        end

        it 'tracks usage data for changed epic action' do
          expect(Gitlab::UsageDataCounters::IssueActivityUniqueCounter).to receive(:track_issue_changed_epic_action).with(author: user)

          subject
        end

        context 'user can not update the epic' do
          before do
            group.group_member(user).destroy!
            old_project.add_reporter(user)
            new_project.add_reporter(user)
          end

          it 'ignores epic reference' do
            expect(subject.epic).to be_nil
          end

          it 'does not send usage data for changed epic action' do
            expect(Gitlab::UsageDataCounters::IssueActivityUniqueCounter).not_to receive(:track_issue_changed_epic_action)

            subject
          end
        end

        context 'epic update fails' do
          it 'does not send usage data for changed epic action' do
            allow_next_instance_of(::Issues::UpdateService) do |update_service|
              allow(update_service).to receive(:execute).and_return(false)
            end

            expect(Gitlab::UsageDataCounters::IssueActivityUniqueCounter).not_to receive(:track_issue_changed_epic_action)

            subject
          end
        end
      end
    end
  end
end
