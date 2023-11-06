# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::CreateService do
  let_it_be(:user) { create(:user) }
  let_it_be(:root_ancestor) { create(:group) }
  let_it_be(:project, reload: true) { create(:project, group: root_ancestor) }
  let_it_be(:subgroup) { create(:group, parent: root_ancestor) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }
  let_it_be(:project_users) { create_list(:user, 2) }

  let(:params) do
    {
      user_ids: project_users.map(&:id).join(','),
      access_level: Gitlab::Access::GUEST,
      invite_source: '_invite_source_'
    }
  end

  subject { described_class.new(user, params.merge({ source: project })).execute }

  before_all do
    project.add_maintainer(user)

    create(:project_member, :invited, project: subgroup_project, created_at: 2.days.ago)
    create(:project_member, :invited, project: subgroup_project)
    create(:group_member, :invited, group: subgroup, created_at: 2.days.ago)
    create(:group_member, :invited, group: subgroup)
  end

  context 'with group plan', :saas do
    let(:plan_limits) { create(:plan_limits, daily_invites: daily_invites) }
    let(:plan) { create(:plan, limits: plan_limits) }
    let!(:subscription) do
      create(
        :gitlab_subscription,
        namespace: root_ancestor,
        hosted_plan: plan
      )
    end

    shared_examples 'quota limit exceeded' do |limit|
      it { expect(subject).to include(status: :error, message: "Invite limit of #{limit} per day exceeded") }
      it { expect { subject }.not_to change { Member.count } }
    end

    context 'already exceeded invite quota limit' do
      let(:daily_invites) { 2 }

      it_behaves_like 'quota limit exceeded', 2
    end

    context 'will exceed invite quota limit' do
      let(:daily_invites) { 3 }

      it_behaves_like 'quota limit exceeded', 3
    end

    context 'within invite quota limit' do
      let(:daily_invites) { 5 }

      it { expect(subject).to eq({ status: :success }) }
      it do
        subject
        expect(project.users).to include(*project_users)
      end
    end

    context 'infinite invite quota limit' do
      let(:daily_invites) { 0 }

      it { expect(subject).to eq({ status: :success }) }
      it do
        subject
        expect(project.users).to include(*project_users)
      end
    end
  end

  context 'without a plan' do
    let(:plan) { nil }

    it { expect(subject).to eq({ status: :success }) }
    it do
      subject
      expect(project.users).to include(*project_users)
    end
  end

  context 'when assigning tasks to be done' do
    let(:params) do
      {
        user_ids: project_users.map(&:id).join(','),
        access_level: Gitlab::Access::DEVELOPER,
        tasks_to_be_done: %w(ci code),
        tasks_project_id: project.id,
        invite_source: '_invite_source_'
      }
    end

    before do
      stub_experiments(invite_members_for_task: true)
    end

    context 'when passing many user ids' do
      it 'creates 2 task issues', :aggregate_failures, :sidekiq_inline do
        expect(TasksToBeDone::CreateWorker)
          .to receive(:perform_async)
          .with(anything, user.id, array_including(*project_users.map(&:id)))
          .once
          .and_call_original

        expect { subject }.to change { project.issues.reload.count }.by(2)

        expect(project.issues).to all have_attributes(
          project: project,
          author: user,
          assignees: match_array(project_users)
        )
      end
    end
  end
end
