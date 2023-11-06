# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::DestroyPipelineService do
  let(:project) { create(:project) }
  let!(:pipeline) { create(:ci_pipeline, project: project) }
  let(:user) { project.owner }

  subject { described_class.new(project, user).execute(pipeline) }

  context 'when audit events is enabled' do
    before do
      stub_licensed_features(extended_audit_events: true, admin_audit_log: true)
    end

    it 'does not log an audit event' do
      expect { subject }.not_to change { AuditEvent.count }
    end
  end
end
