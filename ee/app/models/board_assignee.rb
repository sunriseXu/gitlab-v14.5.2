# frozen_string_literal: true

class BoardAssignee < ApplicationRecord
  belongs_to :board
  belongs_to :assignee, class_name: 'User'

  validates :board, presence: true
  validates :assignee, presence: true
end
