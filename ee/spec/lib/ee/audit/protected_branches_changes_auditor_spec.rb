# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Audit::ProtectedBranchesChangesAuditor, :request_store do
  let_it_be(:author) { create(:user, :with_sign_ins) }
  let_it_be(:user) { create(:user, :with_sign_ins) }
  let_it_be(:entity) { create(:project, creator: author) }

  let(:protected_branch) { create(:protected_branch, :no_one_can_push, :no_one_can_merge, allow_force_push: false, code_owner_approval_required: false, project: entity) }
  let(:ip_address) { '192.168.15.18' }

  before do
    stub_licensed_features(admin_audit_log: true, code_owner_approval_required: true)
    allow(Gitlab::RequestContext.instance).to receive(:client_ip).and_return(ip_address)
  end

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    let(:old_merge_access_levels) { protected_branch.merge_access_levels.map(&:clone) }
    let(:old_push_access_levels) { protected_branch.push_access_levels.map(&:clone) }
    let(:new_merge_access_levels) { protected_branch.merge_access_levels }
    let(:new_push_access_levels) { protected_branch.push_access_levels }

    subject(:service) { described_class.new(author, protected_branch, old_merge_access_levels, old_push_access_levels) }

    shared_examples 'settings' do |setting|
      context "when #{setting} changed" do
        it 'creates an event' do
          protected_branch.update_attribute(setting, true)
          expect { service.execute }.to change { AuditEvent.count }.by(1)

          event = AuditEvent.last
          expect(event.details).to eq({ change: "#{setting}".humanize(capitalize: false),
                                        author_name: author.name,
                                        target_id: protected_branch.id,
                                        entity_path: entity.full_path,
                                        target_type: 'ProtectedBranch',
                                        target_details: protected_branch.name,
                                        from: false,
                                        to: true,
                                        ip_address: ip_address })

          expect(event.author_id).to eq(author.id)
          expect(event.entity_id).to eq(entity.id)
          expect(event.entity_type).to eq('Project')
          expect(event.ip_address).to eq(ip_address)
        end
      end
    end

    include_examples 'settings', :allow_force_push
    include_examples 'settings', :code_owner_approval_required

    where(:type, :old_access_levels, :new_access_levels, :change_text) do
      :push  | ref(:old_push_access_levels)  | ref(:new_push_access_levels)  | 'allowed to push'
      :merge | ref(:old_merge_access_levels) | ref(:new_merge_access_levels) | 'allowed to merge'
    end

    with_them do
      context "when access levels changed" do
        it 'creates an event' do
          new_access_levels.new(user: user)
          expect { service.execute }.to change { AuditEvent.count }.by(1)

          event = AuditEvent.last
          expect(event.details).to eq({ change: change_text,
                                        from: old_access_levels.map(&:humanize),
                                        to: new_access_levels.map(&:humanize),
                                        target_id: protected_branch.id,
                                        target_type: "ProtectedBranch",
                                        target_details: protected_branch.name,
                                        ip_address: ip_address,
                                        entity_path: entity.full_path,
                                        author_name: author.name })

          expect(event.author_id).to eq(author.id)
          expect(event.entity_id).to eq(entity.id)
          expect(event.entity_type).to eq('Project')
          expect(event.ip_address).to eq(ip_address)
        end
      end
    end
  end
end
