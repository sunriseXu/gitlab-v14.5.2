# frozen_string_literal: true

module Types
  module MergeRequests
    class ApprovalStateType < BaseObject
      graphql_name 'MergeRequestApprovalState'
      description 'Information relating to rules that must be satisfied to merge this merge request.'
      authorize :read_merge_request

      field :approval_rules_overwritten, GraphQL::Types::Boolean, method: :approval_rules_overwritten?,
            description: 'Indicates if the merge request approval rules are overwritten for the merge request.', null: true

      field :rules, [::Types::ApprovalRuleType], method: :wrapped_approval_rules,
            description: 'List of approval rules associated with the merge request.', null: true, complexity: 5
    end
  end
end
