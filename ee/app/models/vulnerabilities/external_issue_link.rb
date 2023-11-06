# frozen_string_literal: true

module Vulnerabilities
  class ExternalIssueLink < ApplicationRecord
    self.table_name = 'vulnerability_external_issue_links'

    belongs_to :author, class_name: 'User'
    belongs_to :vulnerability

    enum link_type: { created: 1 }
    enum external_type: { jira: 1 }

    validates :vulnerability, :external_issue_key, :external_type, :external_project_key, presence: true
    validates :external_issue_key, uniqueness: { scope: [:vulnerability_id, :external_type, :external_project_key], message: N_('has already been linked to another vulnerability') }
    validates :vulnerability_id,
              uniqueness: {
                conditions: -> { where(link_type: 'created') },
                message: N_('already has a "created" issue link')
              },
              if: :created?
  end
end
