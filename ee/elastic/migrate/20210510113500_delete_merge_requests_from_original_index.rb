# frozen_string_literal: true

class DeleteMergeRequestsFromOriginalIndex < Elastic::Migration
  batched!
  throttle_delay 3.minutes

  MAX_ATTEMPTS = 30

  QUERY_BODY = {
    query: {
      term: {
        type: 'merge_request'
      }
    }
  }.freeze

  def migrate
    retry_attempt = migration_state[:retry_attempt].to_i
    task_id = migration_state[:task_id]

    if retry_attempt >= MAX_ATTEMPTS
      fail_migration_halt_error!(retry_attempt: retry_attempt)
      return
    end

    if task_id
      log "Checking task status with task_id:#{task_id}"
      check_task(task_id, retry_attempt)
      return
    end

    if completed?
      log "Skipping removing merge requests from the original index since it is already applied"
      return
    end

    log "Launching delete by query"
    response = client.delete_by_query(index: helper.target_name, body: QUERY_BODY, conflicts: 'proceed', wait_for_completion: false)

    log_raise "Failed to delete merge requests with task_id:#{task_id} - #{response['failures']}" if response['failures'].present?

    task_id = response['task']
    log "Removing merge requests from the original index is started with task_id:#{task_id}"

    set_migration_state(
      retry_attempt: retry_attempt,
      task_id: task_id
    )
  rescue StandardError => e
    log "migrate failed, increasing migration_state retry_attempt: #{retry_attempt} error:#{e.class}:#{e.message}"

    set_migration_state(
      retry_attempt: retry_attempt + 1,
      task_id: nil
    )

    raise e
  end

  def completed?
    helper.refresh_index

    results = client.count(index: helper.target_index_name, body: QUERY_BODY)
    total_remaining = results.dig('count')
    log "Checking to see if migration is completed based on index counts remaining:#{total_remaining}"

    total_remaining == 0
  end

  private

  def check_task(task_id, retry_attempt)
    response = helper.task_status(task_id: task_id)

    if response['completed']
      log "Removing merge requests from the original index is completed for task_id:#{task_id}"

      set_migration_state(
        retry_attempt: retry_attempt,
        task_id: nil
      )

      # since delete_by_query is using wait_for_completion = false, the task must be cleaned up
      # in Elasticsearch system .tasks index
      helper.client.delete(index: '.tasks', type: 'task', id: task_id)
    else
      log "Removing merge requests from the original index is still in progress for task_id:#{task_id}"
    end

    log_raise "Failed to delete merge requests: #{response['failures']}" if response['failures'].present?
  end
end
