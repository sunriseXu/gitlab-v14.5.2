# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Frameworks::DestroyService do
  let_it_be_with_refind(:namespace) { create(:user_namespace) }
  let_it_be_with_refind(:framework) { create(:compliance_framework, namespace: namespace) }

  context 'when feature is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    subject { described_class.new(framework: framework, current_user: namespace.owner) }

    it 'does not destroy the compliance framework' do
      expect { subject.execute }.not_to change { ComplianceManagement::Framework.count }
    end

    it 'is unsuccessful' do
      expect(subject.execute.success?).to be false
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when current user is namespace owner' do
      subject { described_class.new(framework: framework, current_user: namespace.owner) }

      it 'destroys the compliance framework' do
        expect { subject.execute }.to change { ComplianceManagement::Framework.count }.by(-1)
      end

      it 'is successful' do
        expect(subject.execute.success?).to be true
      end

      it 'audits the destruction' do
        expect { subject.execute }.to change { AuditEvent.count }.by(1)
      end
    end

    context 'when current user is not the namespace owner' do
      subject { described_class.new(framework: framework, current_user: create(:user)) }

      it 'does not destroy the compliance framework' do
        expect { subject.execute }.not_to change { ComplianceManagement::Framework.count }
      end

      it 'is unsuccessful' do
        expect(subject.execute.success?).to be false
      end
    end
  end
end
