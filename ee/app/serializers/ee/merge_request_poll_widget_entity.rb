# frozen_string_literal: true

module EE
  module MergeRequestPollWidgetEntity
    include ::API::Helpers::RelatedResourcesHelpers
    extend ActiveSupport::Concern

    prepended do
      expose :merge_pipelines_enabled?, as: :merge_pipelines_enabled do |merge_request|
        merge_request.target_project.merge_pipelines_enabled?
      end

      expose :merge_trains_count, if: -> (merge_request) { merge_request.target_project.merge_trains_enabled? } do |merge_request|
        MergeTrain.total_count_in_train(merge_request)
      end

      expose :merge_train_index, if: -> (merge_request) { merge_request.on_train? } do |merge_request|
        merge_request.merge_train.index
      end
    end
  end
end
