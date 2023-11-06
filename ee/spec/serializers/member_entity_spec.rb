# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberEntity do
  let_it_be(:current_user) { create(:user) }

  let(:entity) { described_class.new(member, { current_user: current_user, group: group }) }
  let(:entity_hash) { entity.as_json }

  shared_examples 'member.json' do
    it 'matches json schema' do
      expect(entity.to_json).to match_schema('entities/member', dir: 'ee')
    end

    it 'correctly exposes `using_license`' do
      allow(entity).to receive(:can?).with(current_user, :owner_access, group).and_return(true)
      allow(member.user).to receive(:using_gitlab_com_seat?).with(group).and_return(true)

      expect(entity_hash[:using_license]).to be(true)
    end

    it 'correctly exposes `group_sso`' do
      allow(member).to receive(:group_sso?).and_return(true)

      expect(entity_hash[:group_sso]).to be(true)
    end

    it 'correctly exposes `group_managed_account`' do
      allow(member).to receive(:group_managed_account?).and_return(true)

      expect(entity_hash[:group_managed_account]).to be(true)
    end

    it 'correctly exposes `can_override`' do
      allow(member).to receive(:can_override?).and_return(true)

      expect(entity_hash[:can_override]).to be(true)
    end

    it 'correctly exposes `provisioned_by_this_group`' do
      allow(member).to receive(:provisioned_by_this_group?).and_return(true)

      expect(entity_hash[:provisioned_by_this_group]).to be(true)
    end
  end

  context 'group member' do
    let(:group) { create(:group) }
    let(:member) { GroupMemberPresenter.new(create(:group_member, group: group, created_by: current_user), current_user: current_user) }

    it_behaves_like 'member.json'
  end

  context 'project member' do
    let(:project) { create(:project) }
    let(:group) { project.group }
    let(:member) { ProjectMemberPresenter.new(create(:project_member, project: project), current_user: current_user) }

    it_behaves_like 'member.json'
  end
end
