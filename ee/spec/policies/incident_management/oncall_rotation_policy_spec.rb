# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IncidentManagement::OncallRotationPolicy do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be(:oncall_schedule) { create(:incident_management_oncall_schedule, project: project) }
  let_it_be_with_refind(:oncall_rotation) { create(:incident_management_oncall_rotation, schedule: oncall_schedule) }

  subject(:policy) { described_class.new(user, oncall_rotation) }

  before do
    stub_licensed_features(oncall_schedules: true)
  end

  describe 'rules' do
    it { is_expected.to be_disallowed :read_incident_management_oncall_schedule }

    context 'when reporter' do
      before do
        project.add_reporter(user)
      end

      it { is_expected.to be_allowed :read_incident_management_oncall_schedule }

      context 'licensed feature disabled' do
        before do
          stub_licensed_features(oncall_schedules: false)
        end

        it { is_expected.to be_disallowed :read_incident_management_oncall_schedule }
      end
    end
  end
end
