# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPolicy do
  include ProjectForksHelper

  let_it_be(:guest) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }

  let_it_be(:fork_guest) { create(:user) }
  let_it_be(:fork_developer) { create(:user) }
  let_it_be(:fork_maintainer) { create(:user) }

  let(:project) { create(:project, :public) }
  let(:forked_project) { fork_project(project) }

  let(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let(:fork_merge_request) { create(:merge_request, author: fork_developer, source_project: forked_project, target_project: project) }

  before do
    project.add_guest(guest)
    project.add_developer(developer)
    project.add_maintainer(maintainer)

    forked_project.add_guest(fork_guest)
    forked_project.add_developer(fork_guest)
    forked_project.add_maintainer(fork_maintainer)
  end

  def policy_for(user)
    described_class.new(user, merge_request)
  end

  context 'for a merge request within the same project' do
    context 'when overwriting approvers is disabled on the project' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'does not allow anyone to update approvers' do
        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(developer)).to be_disallowed(:update_approvers)
        expect(policy_for(maintainer)).to be_disallowed(:update_approvers)

        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'when overwriting approvers is enabled on the project' do
      it 'allows only project developers and above to update the approvers' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'allows project developers and above' do
      it 'to approve the merge request' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end
  end

  context 'for a merge request from a fork' do
    let(:merge_request) { fork_merge_request }

    context 'when overwriting approvers is disabled on the target project' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'does not allow anyone to update approvers' do
        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(developer)).to be_disallowed(:update_approvers)
        expect(policy_for(maintainer)).to be_disallowed(:update_approvers)

        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'when overwriting approvers is disabled on the source project' do
      before do
        forked_project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it 'has no effect - project developers and above, as well as the author, can update the approvers' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'when overwriting approvers is enabled on the target project' do
      it 'allows project developers and above, as well as the author, to update the approvers' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end

    context 'allows project developers and above' do
      it 'to approve the merge requests' do
        expect(policy_for(developer)).to be_allowed(:update_approvers)
        expect(policy_for(maintainer)).to be_allowed(:update_approvers)
        expect(policy_for(fork_developer)).to be_allowed(:update_approvers)

        expect(policy_for(guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_guest)).to be_disallowed(:update_approvers)
        expect(policy_for(fork_maintainer)).to be_disallowed(:update_approvers)
      end
    end
  end

  context 'for a merge request on a protected branch' do
    let(:branch_name) { 'feature' }
    let_it_be(:user) { create :user }
    let(:protected_branch) { create(:protected_branch, project: project, name: branch_name) }
    let_it_be(:approver_group) { create(:group) }

    let(:merge_request) { create(:merge_request, source_project: project, target_project: project, target_branch: branch_name) }

    before do
      project.add_reporter(user)
    end

    subject { described_class.new(user, merge_request) }

    context 'when the reporter nor the group is added' do
      specify do
        expect(subject).not_to be_allowed(:approve_merge_request)
      end
    end

    context 'when a group-level approval rule exists' do
      let(:approval_project_rule) { create :approval_project_rule, project: project, approvals_required: 1 }

      context 'when the merge request targets the protected branch' do
        before do
          approval_project_rule.protected_branches << protected_branch
          approval_project_rule.groups << approver_group
        end

        context 'when the reporter is not a group member' do
          specify do
            expect(subject).not_to be_allowed(:approve_merge_request)
          end
        end

        context 'when the reporter is a group member' do
          before do
            approver_group.add_reporter(user)
          end

          specify do
            expect(subject).to be_allowed(:approve_merge_request)
          end
        end
      end

      context 'when the reporter has permission for a different protected branch' do
        let(:protected_branch2) { create(:protected_branch, project: project, name: branch_name, code_owner_approval_required: true) }

        before do
          approval_project_rule.protected_branches << protected_branch2
          approval_project_rule.groups << approver_group
        end

        it 'does not allow approval of the merge request' do
          expect(subject).not_to be_allowed(:approve_merge_request)
        end
      end

      context 'when the protected branch name is a wildcard' do
        let(:wildcard_protected_branch) { create(:protected_branch, project: project, name: '*-stable') }

        before do
          approval_project_rule.protected_branches << wildcard_protected_branch
          approval_project_rule.groups << approver_group
          approver_group.add_reporter(user)
        end

        context 'when the reporter has permission for the wildcarded branch' do
          let(:branch_name) { '13-4-stable' }

          it 'does allows approval of the merge request' do
            expect(subject).to be_allowed(:approve_merge_request)
          end
        end

        context 'when the reporter does not have permission for the wildcarded branch' do
          let(:branch_name) { '13-4-pre' }

          it 'does allows approval of the merge request' do
            expect(subject).not_to be_allowed(:approve_merge_request)
          end
        end
      end
    end
  end

  context 'when checking for namespace whether exceeding storage limit' do
    context 'when namespace does exceeds storage limit' do
      before do
        allow(merge_request.target_project.namespace).to receive(:over_storage_limit?).and_return(true)
      end

      it 'does not allow few policies for all users including maintainer' do
        expect(policy_for(maintainer)).to be_disallowed(:approve_merge_request,
                                                        :update_merge_request,
                                                        :reopen_merge_request,
                                                        :create_note,
                                                        :resolve_note)
      end
    end

    context 'when namespace does not exceeds storage limit' do
      before do
        allow(merge_request.target_project.namespace).to receive(:over_storage_limit?).and_return(false)
      end

      it 'does not lock basic policies for any user' do
        expect(policy_for(maintainer)).to be_allowed(:approve_merge_request,
                                                      :update_merge_request,
                                                      :reopen_merge_request,
                                                      :create_note,
                                                      :resolve_note)
      end
    end
  end
end
