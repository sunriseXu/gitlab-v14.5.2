# frozen_string_literal: true

module EE
  module GroupsController
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include PreventForkingHelper
    include GroupInviteMembers

    prepended do
      alias_method :ee_authorize_admin_group!, :authorize_admin_group!

      before_action :ee_authorize_admin_group!, only: [:restore]
      before_action :check_subscription!, only: [:destroy]

      feature_category :subgroups, [:restore]
    end

    override :render_show_html
    def render_show_html
      if redirect_show_path
        redirect_to redirect_show_path, status: :temporary_redirect
      else
        super
      end
    end

    def group_params_attributes
      super + group_params_ee
    end

    override :destroy
    def destroy
      return super unless group.adjourned_deletion?
      return super if group.marked_for_deletion? && ::Gitlab::Utils.to_boolean(params[:permanently_remove])

      result = ::Groups::MarkForDeletionService.new(group, current_user).execute

      if result[:status] == :success
        redirect_to group_path(group),
          status: :found,
          notice: "'#{group.name}' has been scheduled for removal on #{permanent_deletion_date(Time.current.utc)}."
      else
        redirect_to edit_group_path(group), status: :found, alert: result[:message]
      end
    end

    def restore
      return render_404 unless group.marked_for_deletion?

      result = ::Groups::RestoreService.new(group, current_user).execute

      if result[:status] == :success
        redirect_to edit_group_path(group),
        notice: "Group '#{group.name}' has been successfully restored."
      else
        redirect_to edit_group_path(group), alert: result[:message]
      end
    end

    private

    def check_subscription!
      if group.paid?
        redirect_to edit_group_path(group),
          status: :found,
          alert: _('This group is linked to a subscription')
      end
    end

    def group_params_ee
      [
        :membership_lock,
        :repository_size_limit,
        :new_user_signups_cap
      ].tap do |params_ee|
        params_ee << { insight_attributes: [:id, :project_id, :_destroy] } if current_group&.insights_available?
        params_ee << :file_template_project_id if current_group&.feature_available?(:custom_file_templates_for_namespace)
        params_ee << :custom_project_templates_group_id if current_group&.group_project_template_available?
        params_ee << :ip_restriction_ranges if current_group&.feature_available?(:group_ip_restriction)
        params_ee << :allowed_email_domains_list if current_group&.feature_available?(:group_allowed_email_domains)
        params_ee << :max_pages_size if can?(current_user, :update_max_pages_size)
        params_ee << :max_personal_access_token_lifetime if current_group&.personal_access_token_expiration_policy_available?
        params_ee << :prevent_forking_outside_group if can_change_prevent_forking?(current_user, current_group)

        if current_group&.feature_available?(:adjourned_deletion_for_projects_and_groups)
          params_ee << :delayed_project_removal
          params_ee << :lock_delayed_project_removal
        end
      end
    end

    def current_group
      @group
    end

    def redirect_show_path
      strong_memoize(:redirect_show_path) do
        case group_view
        when 'security_dashboard'
          helpers.group_security_dashboard_path(group)
        else
          nil
        end
      end
    end

    def group_view
      current_user&.group_view || default_group_view
    end

    def default_group_view
      EE::User::DEFAULT_GROUP_VIEW
    end

    override :successful_creation_hooks
    def successful_creation_hooks
      super

      invite_members(group, invite_source: 'group-creation-page')
    end
  end
end
