# frozen_string_literal: true

module Vulnerabilities
  module HistoricalStatistics
    class DeletionWorker # rubocop:disable Scalability/IdempotentWorker
      include ApplicationWorker

      data_consistency :always

      # rubocop:disable Scalability/CronWorkerContext
      # This worker does not perform work scoped to a context
      include CronjobQueue
      # rubocop:enable Scalability/CronWorkerContext

      feature_category :vulnerability_management

      def perform
        DeletionService.execute
      end
    end
  end
end
