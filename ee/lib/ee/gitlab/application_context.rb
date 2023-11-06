# frozen_string_literal: true

module EE
  module Gitlab
    module ApplicationContext
      extend ::Gitlab::Utils::Override

      override :to_lazy_hash
      def to_lazy_hash
        super.tap do |hash|
          hash[:subscription_plan] = -> { subcription_plan_name } if include_namespace?
        end
      end

      def subcription_plan_name
        object = namespace
        # Avoid loading the project's namespace if it wasn't loaded
        object ||= project.namespace if project&.association(:namespace)&.loaded?
        # Avoid loading or creating a plan if it wasn't already.
        return unless object&.strong_memoized?(:actual_plan)

        object&.actual_plan_name
      end
    end
  end
end
