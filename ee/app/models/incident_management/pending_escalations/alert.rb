# frozen_string_literal: true

module IncidentManagement
  module PendingEscalations
    class Alert < ApplicationRecord
      include ::IncidentManagement::BasePendingEscalation

      self.table_name = 'incident_management_pending_alert_escalations'

      alias_attribute :target, :alert

      belongs_to :alert, class_name: 'AlertManagement::Alert', foreign_key: 'alert_id', inverse_of: :pending_escalations

      validates :rule_id, uniqueness: { scope: [:alert_id] }
    end
  end
end
