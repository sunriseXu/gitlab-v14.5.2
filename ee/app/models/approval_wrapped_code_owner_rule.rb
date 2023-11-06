# frozen_string_literal: true

# A common state computation interface to wrap around code owner rule
class ApprovalWrappedCodeOwnerRule < ApprovalWrappedRule
  REQUIRED_APPROVALS_PER_CODE_OWNER_RULE = 1

  def approvals_required
    strong_memoize(:code_owner_approvals_required) do
      next 0 unless branch_requires_code_owner_approval?

      approvers.any? ? REQUIRED_APPROVALS_PER_CODE_OWNER_RULE : 0
    end
  end

  private

  def branch_requires_code_owner_approval?
    return false unless project.code_owner_approval_required_available?
    return false if section_optional?

    ProtectedBranch.branch_requires_code_owner_approval?(project, merge_request.target_branch)
  end

  def section_optional?
    Gitlab::CodeOwners.optional_section?(project, merge_request.target_branch, section)
  end
end
