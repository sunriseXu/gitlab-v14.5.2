# frozen_string_literal: true

module EE
  module Issuable
    module DestroyService
      extend ::Gitlab::Utils::Override

      private

      override :after_destroy
      def after_destroy(issuable)
        track_usage_ping_epic_destroyed if issuable.is_a?(Epic)

        super
      end

      override :group_for
      def group_for(issuable)
        return issuable.resource_parent if issuable.is_a?(Epic)

        super
      end

      def track_usage_ping_epic_destroyed
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_destroyed(author: current_user)
      end
    end
  end
end
