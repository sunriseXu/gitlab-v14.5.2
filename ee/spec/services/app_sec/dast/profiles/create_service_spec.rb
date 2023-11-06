# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::Dast::Profiles::CreateService do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_projects: [project] ) }
  let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
  let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }
  let_it_be(:time_zone) { Time.zone.tzinfo.name }
  let_it_be(:default_params) do
    {
      name: SecureRandom.hex,
      description: :description,
      branch_name: 'orphaned-branch',
      dast_site_profile: dast_site_profile,
      dast_scanner_profile: dast_scanner_profile,
      run_after_create: false
    }
  end

  let(:params) { default_params }

  subject { described_class.new(container: project, current_user: developer, params: params).execute }

  describe 'execute' do
    context 'when on demand scan licensed feature is not available' do
      it 'communicates failure' do
        stub_licensed_features(security_on_demand_scans: false)

        aggregate_failures do
          expect(subject.status).to eq(:error)
          expect(subject.message).to eq('Insufficient permissions')
        end
      end
    end

    context 'when the feature is enabled' do
      before do
        stub_licensed_features(security_on_demand_scans: true)
      end

      it 'communicates success' do
        expect(subject.status).to eq(:success)
      end

      it 'creates a dast_profile' do
        expect { subject }.to change { Dast::Profile.count }.by(1)
      end

      it 'audits the creation' do
        profile = subject.payload[:dast_profile]

        audit_event = AuditEvent.find_by(author_id: developer.id)

        aggregate_failures do
          expect(audit_event.author).to eq(developer)
          expect(audit_event.entity).to eq(project)
          expect(audit_event.target_id).to eq(profile.id)
          expect(audit_event.target_type).to eq('Dast::Profile')
          expect(audit_event.target_details).to eq(profile.name)
          expect(audit_event.details).to eq({
            author_name: developer.name,
            custom_message: 'Added DAST profile',
            target_id: profile.id,
            target_type: 'Dast::Profile',
            target_details: profile.name
          })
        end
      end

      context 'when param run_after_create: true' do
        let(:params) { default_params.merge(run_after_create: true) }

        it_behaves_like 'it delegates scan creation to another service' do
          let(:delegated_params) { hash_including(dast_profile: instance_of(Dast::Profile)) }
        end

        it 'creates a ci_pipeline' do
          expect { subject }.to change { Ci::Pipeline.count }.by(1)
        end
      end

      context 'when param dast_profile_schedule is present' do
        let(:params) do
          default_params.merge(
            dast_profile_schedule: {
              active: true,
              starts_at: Time.zone.now,
              timezone: time_zone,
              cadence: { unit: 'day', duration: 1 }
            }
          )
        end

        it 'creates the dast_profile_schedule' do
          expect { subject }.to change { ::Dast::ProfileSchedule.count }.by(1)
        end

        it 'responds with dast_profile_schedule' do
          expect(subject.payload[:dast_profile_schedule]).to be_a ::Dast::ProfileSchedule
        end

        it 'audits the creation' do
          schedule = subject.payload[:dast_profile_schedule]

          audit_event = AuditEvent.find_by(target_id: schedule.id)

          aggregate_failures do
            expect(audit_event.author).to eq(developer)
            expect(audit_event.entity).to eq(project)
            expect(audit_event.target_id).to eq(schedule.id)
            expect(audit_event.target_type).to eq('Dast::ProfileSchedule')
            expect(audit_event.details).to eq({
              author_name: developer.name,
              custom_message: 'Added DAST profile schedule',
              target_id: schedule.id,
              target_type: 'Dast::ProfileSchedule',
              target_details: developer.name
            })
          end
        end

        context 'when invalid schedule it present' do
          let(:bad_time_zone) { 'BadZone' }

          let(:params) do
            default_params.merge(
              dast_profile_schedule: {
                active: true,
                starts_at: Time.zone.now,
                timezone: bad_time_zone,
                cadence: { unit: 'bad_day', duration: 100 }
              }
            )
          end

          it 'rollback the transaction' do
            expect { subject }.to change { ::Dast::ProfileSchedule.count }.by(0)
            .and change { ::Dast::Profile.count }.by(0)
          end

          it 'returns the error service response' do
            expect(subject.error?).to be true
          end
        end
      end

      context 'when a param is missing' do
        let(:params) { default_params.except(:run_after_create) }

        it 'communicates failure' do
          aggregate_failures do
            expect(subject.status).to eq(:error)
            expect(subject.message).to eq('Key not found: :run_after_create')
          end
        end
      end
    end
  end
end
