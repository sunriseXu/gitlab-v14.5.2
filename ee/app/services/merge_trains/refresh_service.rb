# frozen_string_literal: true
module MergeTrains
  # This class is to refresh all merge requests on the merge train that
  # the given merge request belongs to.
  #
  # It performs a sequential update on all merge requests on the train.
  # In order to prevent multiple sidekiq jobs from updating concurrently,
  # the process attempts to obtain an exclusive lock at first.
  # If the process successfully obtains the lock, the sequential refresh will be executed in this sidekiq job.
  # If the process failed to obtain the lock, the refresh request is pushed to the queue in Redis.
  # The queued refresh requests will be poped at once when the current process has finished.
  class RefreshService < BaseService
    include ::Gitlab::ExclusiveLeaseHelpers
    include ::Gitlab::Utils::StrongMemoize

    DEFAULT_CONCURRENCY = 20
    TRAIN_PROCESSING_LOCK_TIMEOUT = 15.minutes.freeze
    SIGNAL_FOR_REFRESH_REQUEST = 1

    def execute(target_project_id, target_branch)
      @target_project_id = target_project_id
      @target_branch = target_branch

      queue = Gitlab::BatchPopQueueing.new('merge_trains', queue_id)
      result = queue.safe_execute([SIGNAL_FOR_REFRESH_REQUEST], lock_timeout: TRAIN_PROCESSING_LOCK_TIMEOUT) do |items|
        unsafe_refresh
      end

      if result[:status] == :finished && result[:new_items].present?
        MergeTrains::RefreshWorker.perform_async(target_project_id, target_branch)
      end
    end

    private

    attr_reader :target_project_id, :target_branch

    def unsafe_refresh
      require_next_recreate = false

      MergeTrain.all_cars(target_project_id, target_branch, limit: DEFAULT_CONCURRENCY).each do |car|
        result = MergeTrains::RefreshMergeRequestService
          .new(car.target_project, car.user, require_recreate: require_next_recreate)
          .execute(car.merge_request)

        require_next_recreate = (result[:status] == :error || result[:pipeline_created])
      end
    end

    def queue_id
      "#{target_project_id}:#{target_branch}"
    end
  end
end
