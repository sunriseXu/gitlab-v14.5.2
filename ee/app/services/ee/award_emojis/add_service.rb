# frozen_string_literal: true

module EE
  module AwardEmojis
    module AddService
      extend ::Gitlab::Utils::Override

      private

      override :after_create
      def after_create(award)
        super

        ::Gitlab::StatusPage.trigger_publish(project, current_user, award)
        track_epic_emoji_awarded if awardable.is_a?(Epic)
      end

      def track_epic_emoji_awarded
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_emoji_awarded_action(author: current_user)
      end
    end
  end
end
