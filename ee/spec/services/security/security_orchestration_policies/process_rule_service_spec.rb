# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ProcessRuleService do
  describe '#execute' do
    let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }
    let_it_be(:owner) { create(:user) }
    let_it_be(:schedule) do
      travel_to(1.day.ago) do
        create(:security_orchestration_policy_rule_schedule, security_orchestration_policy_configuration: policy_configuration)
      end
    end

    let(:policy) do
      rules = [
        { type: 'pipeline', branches: %w[production] },
        { type: 'schedule', branches: %w[production], cadence: '*/15 * * * *' }
      ]

      build(:scan_execution_policy, rules: rules)
    end

    subject(:service) { described_class.new(policy_configuration: policy_configuration, policy_index: 0, policy: policy) }

    before do
      allow(policy_configuration).to receive(:policy_last_updated_by).and_return(owner)
    end

    context 'when security_orchestration_policies_configuration policy is scheduled' do
      it 'creates new schedule' do
        service.execute

        new_schedule = Security::OrchestrationPolicyRuleSchedule.first
        expect(Security::OrchestrationPolicyRuleSchedule.count).to eq(1)
        expect(new_schedule.id).not_to eq(schedule.id)
        expect(new_schedule.rule_index).to eq(1)
        expect(new_schedule.next_run_at).to be > schedule.next_run_at
      end
    end

    context 'when policy is not of type scheduled' do
      let(:policy) { build(:scan_execution_policy) }

      it 'deletes schedules' do
        expect { service.execute }.to change(Security::OrchestrationPolicyRuleSchedule, :count).by(-1)
      end
    end
  end
end
