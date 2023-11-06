# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GroupLinks::CreateService, '#execute' do
  include ProjectForksHelper

  let(:user) { create :user }
  let(:project) { create :project }
  let(:group) { create(:group, visibility_level: 0) }
  let(:opts) do
    {
      link_group_access: '30',
      expires_at: nil
    }
  end

  context 'audit events' do
    include_examples 'audit event logging' do
      let_it_be(:user) { create :user }
      let_it_be(:project) { create :project }
      let(:operation) { create_group_link(user, project, group, opts) }
      let(:fail_condition!) do
        create(:project_group_link, project: project, group: group)
      end

      let(:attributes) do
        {
           author_id: user.id,
           entity_id: group.id,
           entity_type: 'Group',
           details: {
             add: 'project_access',
             as: 'Developer',
             author_name: user.name,
             target_id: project.id,
             target_type: 'Project',
             target_details: project.full_path
           }
         }
      end
    end
  end

  context 'when project is in sso enforced group' do
    let(:saml_provider) { create(:saml_provider, enforced_sso: true) }
    let(:root_group) { saml_provider.group }
    let(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
    let(:user) { identity.user }
    let(:project) { create(:project, :private, group: root_group) }
    let(:subject) { described_class.new(project, user, opts) }

    before do
      group_to_invite.add_developer(user)
      stub_licensed_features(group_saml: true)
    end

    context 'when invited group is outside top group' do
      let(:group_to_invite) { create(:group) }

      it 'does not add group to project' do
        expect { subject.execute(group_to_invite) }.not_to change { project.project_group_links.count }
      end
    end

    context 'when invited group is in the top group' do
      let(:group_to_invite) { create(:group, parent: root_group) }

      it 'adds group to project' do
        expect { subject.execute(group_to_invite) }.to change { project.project_group_links.count }.from(0).to(1)
      end
    end

    context 'when project is deeper in the hierarchy and group is in the top group' do
      let(:group_to_invite) { create(:group, parent: root_group) }
      let(:nested_group) { create(:group, parent: root_group) }
      let(:nested_group_2) { create(:group, parent: nested_group_2) }
      let(:project) { create(:project, :private, group: nested_group) }

      it 'adds group to project' do
        expect { subject.execute(group_to_invite) }.to change { project.project_group_links.count }.from(0).to(1)
      end

      context 'when invited group is outside top group' do
        let(:group_to_invite) { create(:group) }

        it 'does not add group to project' do
          expect { subject.execute(group_to_invite) }.not_to change { project.project_group_links.count }
        end
      end
    end

    context 'when project is forked from group with enforced SSO' do
      let(:forked_project) { create(:project) }

      before do
        root_group.add_developer(user)

        fork_project(project, user, target_project: forked_project)
      end

      context 'when invited group is outside top group' do
        let(:group_to_invite) { create(:group) }

        it 'does not add group to project' do
          expect { described_class.new(forked_project, user, opts).execute(group_to_invite) }.not_to change { forked_project.project_group_links.count }
        end

        it 'returns error status and message' do
          result = described_class.new(forked_project, user, opts).execute(group_to_invite)

          expect(result[:message]).to eq('This group cannot be invited to a project inside a group with enforced SSO')
          expect(result[:status]).to eq(:error)
        end
      end

      context 'when invited group is in the top group' do
        let(:group_to_invite) { create(:group, parent: root_group) }

        it 'adds group to project' do
          expect { described_class.new(forked_project, user, opts).execute(group_to_invite) }.to change { forked_project.project_group_links.count }.from(0).to(1)

          group_link = forked_project.project_group_links.first

          expect(group_link.group_id).to eq(group_to_invite.id)
          expect(group_link.project_id).to eq(forked_project.id)
        end
      end
    end

    context 'when project is forked to group with enforced sso' do
      let(:source_project) { create(:project) }

      before do
        source_project.add_developer(user)

        fork_project(source_project, user, target_project: project)
      end

      context 'when invited group is outside top group' do
        let(:group_to_invite) { create(:group) }

        it 'does not add group to project' do
          expect { subject.execute(group_to_invite) }.not_to change { project.project_group_links.count }
        end
      end

      context 'when invited group is in the top group' do
        let(:group_to_invite) { create(:group, parent: root_group) }

        it 'adds group to project' do
          expect { subject.execute(group_to_invite) }.to change { project.project_group_links.count }.from(0).to(1)

          group_link = project.project_group_links.first

          expect(group_link.group_id).to eq(group_to_invite.id)
          expect(group_link.project_id).to eq(project.id)
        end
      end
    end
  end

  def create_group_link(user, project, group, opts)
    group.add_developer(user)
    described_class.new(project, user, opts).execute(group)
  end
end
