# frozen_string_literal: true

module IncidentManagement
  class EscalationRule < ApplicationRecord
    self.table_name = 'incident_management_escalation_rules'

    belongs_to :policy, class_name: 'EscalationPolicy', inverse_of: 'rules', foreign_key: 'policy_id'
    belongs_to :oncall_schedule, class_name: 'OncallSchedule', foreign_key: 'oncall_schedule_id', optional: true
    belongs_to :user, optional: true

    enum status: ::IncidentManagement::Escalatable::STATUSES.slice(:acknowledged, :resolved)

    validates :status, presence: true
    validates :elapsed_time_seconds,
              presence: true,
              numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 24.hours }

    validate :schedule_or_rule_present
    validates :oncall_schedule_id,
              uniqueness: { scope: [:policy_id, :status, :elapsed_time_seconds],
              message: _('must be unique by status and elapsed time within a policy') },
              allow_nil: true
    validates :user_id,
              uniqueness: { scope: [:policy_id, :status, :elapsed_time_seconds],
              message: _('must be unique by status and elapsed time within a policy') },
              allow_nil: true

    scope :not_removed, -> { where(is_removed: false) }
    scope :removed, -> { where(is_removed: true) }

    private

    def schedule_or_rule_present
      unless oncall_schedule.present? ^ user.present?
        errors.add(:base, 'must have either an on-call schedule or user')
      end
    end
  end
end
