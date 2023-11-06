# frozen_string_literal: true

class EpicIssue < ApplicationRecord
  include EpicTreeSorting
  include EachBatch
  include AfterCommitQueue

  validates :epic, :issue, presence: true
  validates :issue, uniqueness: true

  belongs_to :epic
  belongs_to :issue

  alias_attribute :parent_ids, :epic_id
  alias_attribute :parent, :epic

  scope :in_epic, ->(epic_id) { where(epic_id: epic_id) }

  validate :validate_confidential_epic

  def epic_tree_root?
    false
  end

  def self.epic_tree_node_query(node)
    selection = <<~SELECT_LIST
      id, relative_position, epic_id as parent_id, epic_id, '#{underscore}' as object_type
    SELECT_LIST

    select(selection).in_epic(node.parent_ids)
  end

  # TODO add this method to validate records (see https://gitlab.com/gitlab-org/gitlab/-/issues/339514)
  def epic_and_issue_at_same_group_hierarchy?
    epic.group.self_and_hierarchy.include?(issue.project.group)
  end

  private

  def validate_confidential_epic
    return unless epic && issue

    if epic.confidential? && !issue.confidential?
      errors.add :issue, _('Cannot assign a confidential epic to a non-confidential issue. Make the issue confidential and try again')
    end
  end
end
