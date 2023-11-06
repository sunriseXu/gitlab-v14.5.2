# frozen_string_literal: true

module Geo
  class MergeRequestDiffReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy
    extend ::Gitlab::Utils::Override

    def self.model
      ::MergeRequestDiff
    end

    def self.primary_total_count
      model.has_external_diffs.count
    end

    def carrierwave_uploader
      model_record.external_diff
    end

    private

    # Only external diffs can be checksummed
    override :checksummable?
    def checksummable?
      model_record.stored_externally? && super
    end

    override :verification_feature_flag_enabled?
    def self.verification_feature_flag_enabled?
      Feature.enabled?(:geo_merge_request_diff_verification, default_enabled: :yaml)
    end
  end
end
