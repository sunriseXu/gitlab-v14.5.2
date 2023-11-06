# frozen_string_literal: true

module Gitlab
  module Analytics
    module CycleAnalytics
      module Summary
        class CycleTime < BaseTime
          def title
            _('Cycle Time')
          end

          def start_event_identifier
            :issue_first_mentioned_in_commit
          end

          def end_event_identifier
            :issue_closed
          end
        end
      end
    end
  end
end
