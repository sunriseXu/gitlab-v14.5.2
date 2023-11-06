# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PaidFeatureCalloutHelper do
  describe '#run_highlight_paid_features_during_active_trial_experiment', :experiment do
    let_it_be(:group) { create(:group) }
    let_it_be(:user) { create(:user) }
    let_it_be(:candidate_block) { proc { 'in candidate' } }

    let(:trials_available) { true }
    let(:user_can_admin_group) { true }
    let(:group_has_active_trial) { true }

    before do
      stub_application_setting(check_namespace_plan: trials_available)
      stub_experiments(highlight_paid_features_during_active_trial: variant)
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).with(user, :admin_namespace, group).and_return(user_can_admin_group)
      allow(group).to receive(:trial_active?).and_return(group_has_active_trial)
    end

    subject { helper.run_highlight_paid_features_during_active_trial_experiment(group, &candidate_block).run }

    shared_examples 'records an ExperimentSubject' do
      it 'records the group as an ExperimentSubject' do
        expect { subject }.to change { ExperimentSubject.count }
      end
    end

    shared_examples 'does not record an ExperimentSubject' do
      it 'does not record the group as an ExperimentSubject' do
        expect { subject }.not_to change { ExperimentSubject.count }
      end
    end

    shared_examples 'user receives control experience' do
      it { is_expected.to be_nil }
    end

    context 'when the user is in the candidate' do
      let(:variant) { :candidate }

      it { is_expected.to eq('in candidate') }

      include_examples 'records an ExperimentSubject'
    end

    context 'when the user is in the control' do
      let(:variant) { :control }

      include_examples 'user receives control experience'
      include_examples 'records an ExperimentSubject'
    end

    context 'when the user would be in the candidate' do
      let(:variant) { :candidate }

      context 'but trials are not available' do
        let(:trials_available) { false }

        include_examples 'user receives control experience'
        include_examples 'does not record an ExperimentSubject'
      end

      context 'but the group is not in an active trial' do
        let(:group_has_active_trial) { false }

        include_examples 'user receives control experience'
        include_examples 'does not record an ExperimentSubject'
      end

      context 'but the user is not an admin of the group' do
        let(:user_can_admin_group) { false }

        include_examples 'user receives control experience'
        include_examples 'does not record an ExperimentSubject'
      end
    end
  end

  describe '#paid_feature_badge_data_attrs' do
    subject { helper.paid_feature_badge_data_attrs('some feature') }

    it 'returns the set of data attributes needed to bootstrap the PaidFeatureCalloutBadge component' do
      is_expected.to eq({ id: 'some-feature-callout', feature_name: 'some feature' })
    end
  end

  describe '#paid_feature_popover_data_attrs' do
    let(:subscription) { instance_double(GitlabSubscription, plan_title: 'Ultimate') }
    let(:group) { instance_double(Group, id: 123, to_param: 'test-group', trial_days_remaining: 12, gitlab_subscription: subscription) }

    before do
      allow_next_instance_of(GitlabSubscriptions::FetchSubscriptionPlansService, plan: :free) do |instance|
        allow(instance).to receive(:execute).and_return([
          { 'code' => 'premium', 'id' => 'premium-plan-id' }
        ])
      end
    end

    subject { helper.paid_feature_popover_data_attrs(group: group, feature_name: 'first feature') }

    it 'returns the set of data attributes needed to bootstrap the PaidFeatureCalloutPopover component' do
      expected_attrs = {
        container_id: 'first-feature-callout',
        days_remaining: 12,
        feature_name: 'first feature',
        href_compare_plans: '/groups/test-group/-/billings',
        href_upgrade_to_paid: '/-/subscriptions/new?namespace_id=123&plan_id=premium-plan-id',
        plan_name_for_trial: 'Ultimate',
        plan_name_for_upgrade: 'Premium',
        target_id: 'first-feature-callout'
      }

      is_expected.to eq(expected_attrs)
    end
  end
end
