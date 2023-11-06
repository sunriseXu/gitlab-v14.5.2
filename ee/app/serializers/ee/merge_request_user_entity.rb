# frozen_string_literal: true

module EE
  module MergeRequestUserEntity
    extend ActiveSupport::Concern

    prepended do
      expose :gitlab_employee?, as: :is_gitlab_employee, if: proc { ::Gitlab.com? && ::Feature.enabled?(:gitlab_employee_badge) }
      expose :applicable_approval_rules, if: proc { |_, options| options[:project]&.feature_available?(:merge_request_approvers) && options[:approval_rules] }, using: ::EE::API::Entities::ApprovalRuleShort do |user, options|
        options[:merge_request]&.applicable_approval_rules_for_user(user.id)
      end
    end
  end
end
