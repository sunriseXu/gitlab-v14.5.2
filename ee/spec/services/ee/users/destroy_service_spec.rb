# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::DestroyService do
  let_it_be(:current_user) { create(:admin) }

  subject(:service) { described_class.new(current_user) }

  describe '#execute' do
    let!(:user) { create(:user) }

    subject(:operation) { service.execute(user) }

    context 'when admin mode is disabled' do
      it 'raises access denied' do
        expect { operation }.to raise_error(::Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when admin mode is enabled', :enable_admin_mode do
      it 'returns result' do
        allow(user).to receive(:destroy).and_return(user)

        expect(operation).to eq(user)
      end

      context 'when project is a mirror' do
        let(:project) { create(:project, :mirror, mirror_user_id: user.id) }

        it 'disables mirror and does not assign a new mirror_user' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)

          allow_next_instance_of(::NotificationService) do |notification|
            expect(notification).to receive(:mirror_was_disabled)
              .with(project, user.name)
              .and_call_original
          end

          expect { operation }.to change { project.reload.mirror_user }.from(user).to(nil)
            .and change { project.reload.mirror }.from(true).to(false)
        end
      end

      context 'when user has oncall rotations' do
        let(:schedule) { create(:incident_management_oncall_schedule, project: project) }
        let(:rotation) { create(:incident_management_oncall_rotation, schedule: schedule) }
        let!(:participant) { create(:incident_management_oncall_participant, rotation: rotation, user: user) }
        let!(:other_participant) { create(:incident_management_oncall_participant, rotation: rotation) }

        context 'in their own project' do
          let(:project) { create(:project, namespace: user.namespace) }

          it 'deletes the project and the schedule' do
            operation

            expect { project.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { schedule.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context 'in a group project' do
          let(:group) { create(:group) }
          let(:project) { create(:project, namespace: group) }

          before do
            project.add_developer(user)
          end

          it 'deletes the participant from the rotation' do
            expect(rotation.participants.reload).to include(participant)

            operation

            expect(rotation.participants.reload).not_to include(participant)
          end

          it 'sends an email about the user being removed from the rotation' do
            expect { operation }.to change(ActionMailer::Base.deliveries, :size).by(1)
          end
        end
      end

      describe 'audit events' do
        include_examples 'audit event logging' do
          let(:fail_condition!) do
            expect_any_instance_of(User)
              .to receive(:destroy).and_return(false)
          end

          let(:attributes) do
            {
              author_id: current_user.id,
              entity_id: @resource.id,
              entity_type: 'User',
              details: {
                remove: 'user',
                author_name: current_user.name,
                target_id: @resource.id,
                target_type: 'User',
                target_details: @resource.full_path
              }
            }
          end
        end
      end
    end
  end
end
