# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Audit::GroupChangesAuditor do
  describe '.audit_changes' do
    let!(:user) { create(:user) }
    let!(:group) { create(:group, visibility_level: 0) }
    let(:foo_instance) { described_class.new(user, group) }

    before do
      stub_licensed_features(extended_audit_events: true)
    end

    describe 'non audit changes' do
      it 'does not call the audit event service' do
        group.update!(runners_token: 'new token')

        expect { foo_instance.execute }.not_to change { AuditEvent.count }
      end
    end

    describe 'audit changes' do
      it 'creates and event when the visibility change' do
        group.update!(visibility_level: 20)

        expect { foo_instance.execute }.to change { AuditEvent.count }.by(1)
        expect(AuditEvent.last.details[:change]).to eq 'visibility'
      end

      it 'creates an event for project creation level change' do
        group.update!(project_creation_level: 0)

        expect { foo_instance.execute }.to change { AuditEvent.count }.by(1)

        event = AuditEvent.last
        expect(event.details[:from]).to eq 'Maintainers'
        expect(event.details[:to]).to eq 'No one'
        expect(event.details[:change]).to eq 'project_creation_level'
      end

      it 'creates an event when attributes change' do
        # Exclude special cases covered from above
        columns = described_class::COLUMNS - described_class::COLUMN_HUMAN_NAME.keys - [:project_creation_level]

        columns.each do |column|
          data = group.attributes[column.to_s]

          value =
            case Group.type_for_attribute(column.to_s).type
            when :integer
              data.present? ? data + 1 : 0
            when :boolean
              !data
            else
              "#{data}-next"
            end

          group.update_attribute(column, value)

          expect { foo_instance.execute }.to change { AuditEvent.count }.by(1)

          event = AuditEvent.last
          expect(event.details[:from]).to eq data
          expect(event.details[:to]).to eq value
          expect(event.details[:change]).to eq column.to_s
        end
      end
    end
  end
end
