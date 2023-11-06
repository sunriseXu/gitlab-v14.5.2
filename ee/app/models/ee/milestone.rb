# frozen_string_literal: true

module EE
  module Milestone
    extend ActiveSupport::Concern

    prepended do
      include Elastic::ApplicationVersionedSearch

      has_many :boards
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      override :with_web_entity_associations
      def with_web_entity_associations
        super.preload(project: [group: [:saml_provider]])
      end
    end

    def supports_milestone_charts?
      resource_parent&.feature_available?(:milestone_charts) && weight_available?
    end

    alias_method :supports_timebox_charts?, :supports_milestone_charts?
  end
end
