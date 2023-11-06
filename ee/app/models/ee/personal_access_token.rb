# frozen_string_literal: true

module EE
  # PersonalAccessToken EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `PersonalAccessToken` model
  module PersonalAccessToken
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include ::Gitlab::Utils::StrongMemoize
      include FromUnion

      after_create :clear_rotation_notification_cache

      scope :with_no_expires_at, -> { where(revoked: false, expires_at: nil) }
      scope :with_expires_at_after, ->(max_lifetime) { where(revoked: false).where('expires_at > ?', max_lifetime) }
      scope :expires_in, ->(within) { not_revoked.where('expires_at > CURRENT_DATE AND expires_at <= ?', within) }
      scope :created_on_or_after, ->(date) { active.where('created_at >= ?', date) }

      with_options if: :expiration_policy_enabled? do
        validates :expires_at, presence: true
        validate :expires_at_before_max_expiry_date
      end
    end

    class_methods do
      def pluck_names
        pluck(:name)
      end

      def with_invalid_expires_at(max_lifetime, limit = 1_000)
        from_union(
          [
            with_no_expires_at.limit(limit),
            with_expires_at_after(max_lifetime).limit(limit)
          ]
        )
      end

      def expiration_enforced?
        return true unless enforce_pat_expiration_feature_available?

        ::Gitlab::CurrentSettings.enforce_pat_expiration?
      end

      def enforce_pat_expiration_feature_available?
        License.feature_available?(:enforce_personal_access_token_expiration)
      end
    end

    override :expired?
    def expired?
      return super if self.class.expiration_enforced?

      # The user is notified about the expired-yet-active status of the token through an in-app banner: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/34101
      false
    end

    override :expired_but_not_enforced?
    def expired_but_not_enforced?
      expired_original? && !self.class.expiration_enforced?
    end

    override :revoke!
    def revoke!
      clear_rotation_notification_cache

      super
    end

    private

    def expiration_policy_enabled?
      return group_level_expiration_policy_enabled? if user.group_managed_account?

      instance_level_expiration_policy_enabled?
    end

    def instance_level_expiration_policy_enabled?
      expiration_policy_licensed? && instance_level_max_expiry_date
    end

    def max_expiry_date
      return group_level_max_expiry_date if user.group_managed_account?

      instance_level_max_expiry_date
    end

    def instance_level_max_expiry_date
      ::Gitlab::CurrentSettings.max_personal_access_token_lifetime_from_now
    end

    def expires_at_before_max_expiry_date
      return if expires_at.blank?

      errors.add(:expires_at, :invalid) if expires_at > max_expiry_date
    end

    def expiration_policy_licensed?
      License.feature_available?(:personal_access_token_expiration_policy)
    end

    def group_level_expiration_policy_enabled?
      expiration_policy_licensed? && group_level_max_expiry_date
    end

    def group_level_max_expiry_date
      user.managing_group.max_personal_access_token_lifetime_from_now
    end

    def clear_rotation_notification_cache
      ::PersonalAccessTokens::RotationVerifierService.new(user).clear_cache
    end
  end
end
