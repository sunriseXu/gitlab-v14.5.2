# frozen_string_literal: true

module EE::Groups::GroupMembersHelper
  extend ::Gitlab::Utils::Override

  override :group_member_select_options
  def group_member_select_options
    super.merge(skip_ldap: @group.ldap_synced?)
  end

  override :group_members_list_data
  def group_members_list_data(group, _members, _pagination = {})
    super.merge!({
      ldap_override_path: override_group_group_member_path(group, ':id')
    })
  end

  override :group_members_app_data
  def group_members_app_data(group, members:, invited:, access_requests:)
    super.merge!({
       can_export_members: can?(current_user, :export_group_memberships, group),
       export_csv_path: export_csv_group_group_members_path(group)
     })
  end
end
