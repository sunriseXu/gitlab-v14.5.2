# frozen_string_literal: true

module EE
  module MergeRequestPollCachedWidgetEntity
    extend ActiveSupport::Concern

    prepended do
      expose :merge_train_when_pipeline_succeeds_docs_path do |merge_request|
        presenter(merge_request).merge_train_when_pipeline_succeeds_docs_path
      end

      expose :policy_violation do |merge_request|
        presenter(merge_request).has_denied_policies?
      end

      expose :missing_security_scan_types do |merge_request|
        presenter(merge_request).missing_security_scan_types
      end

      expose :api_status_checks_path do |merge_request|
        presenter(merge_request).api_status_checks_path
      end

      expose :jira_associations, if: -> (mr) { mr.project.jira_issue_association_required_to_merge_enabled? } do
        expose :enforced do |merge_request|
          presenter(merge_request).project.prevent_merge_without_jira_issue
        end

        expose :issue_keys do |merge_request|
          presenter(merge_request).issue_keys
        end
      end
    end
  end
end
