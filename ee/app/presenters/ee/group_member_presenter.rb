# frozen_string_literal: true

module EE
  module GroupMemberPresenter
    extend ::Gitlab::Utils::Override

    def group_sso?
      return false unless member.user.present?

      member.user.group_sso?(source)
    end

    def group_managed_account?
      return false unless member.user.present?

      member.user.group_managed_account?
    end

    override :access_level_roles
    def access_level_roles
      member.source.access_level_roles
    end

    private

    def override_member_permission
      :override_group_member
    end
  end
end
