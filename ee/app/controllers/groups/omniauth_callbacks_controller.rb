# frozen_string_literal: true

class Groups::OmniauthCallbacksController < OmniauthCallbacksController
  extend ::Gitlab::Utils::Override

  skip_before_action :verify_authenticity_token, only: [:failure, :group_saml]

  feature_category :authentication_and_authorization

  def group_saml
    @unauthenticated_group = Group.find_by_full_path(params[:group_id])
    @saml_provider = @unauthenticated_group.saml_provider

    identity_linker = Gitlab::Auth::GroupSaml::IdentityLinker.new(current_user, oauth, session, @saml_provider)

    store_location_for(:redirect, saml_redirect_path)
    omniauth_flow(Gitlab::Auth::GroupSaml, identity_linker: identity_linker)
  rescue Gitlab::Auth::Saml::IdentityLinker::UnverifiedRequest
    redirect_unverified_saml_initiation
  end

  private

  override :link_identity
  def link_identity(identity_linker)
    super.tap do
      store_active_saml_session unless identity_linker.failed?
    end
  end

  override :redirect_identity_linked
  def redirect_identity_linked
    flash[:notice] = "SAML for #{@unauthenticated_group.name} was added to your connected accounts"

    redirect_to after_sign_in_path_for(current_user)
  end

  override :redirect_identity_exists
  def redirect_identity_exists
    flash[:notice] = "Already signed in with SAML for #{@unauthenticated_group.name}"

    redirect_to after_sign_in_path_for(current_user)
  end

  override :redirect_identity_link_failed
  def redirect_identity_link_failed(error_message)
    flash[:notice] = "SAML authentication failed: #{error_message}"

    if ::Feature.enabled?(:sign_up_on_sso, @unauthenticated_group) && @saml_provider.enforced_group_managed_accounts?
      redirect_to_group_sign_up
    else
      redirect_to after_sign_in_path_for(current_user)
    end
  end

  override :sign_in_and_redirect
  def sign_in_and_redirect(user, *args)
    super.tap { flash[:notice] = "Signed in with SAML for #{@unauthenticated_group.name}" }
  end

  override :sign_in
  def sign_in(resource_or_scope, *args)
    store_active_saml_session

    super
  end

  override :prompt_for_two_factor
  def prompt_for_two_factor(user)
    store_active_saml_session

    super
  end

  override :locked_user_redirect
  def locked_user_redirect(user)
    flash[:alert] = locked_user_redirect_alert(user)

    redirect_to sso_group_saml_providers_path(@unauthenticated_group, token: @unauthenticated_group.saml_discovery_token)
  end

  def store_active_saml_session
    Gitlab::Auth::GroupSaml::SsoEnforcer.new(@saml_provider).update_session
  end

  def redirect_unverified_saml_initiation
    flash[:notice] = "Request to link SAML account must be authorized"

    redirect_to sso_group_saml_providers_path(@unauthenticated_group)
  end

  override :after_sign_in_path_for
  def after_sign_in_path_for(resource)
    saml_redirect_path || super
  end

  override :build_auth_user
  def build_auth_user(auth_user_class)
    super.tap do |auth_user|
      auth_user.saml_provider = @saml_provider
    end
  end

  override :fail_login
  def fail_login(user)
    if user
      super
    else
      if ::Feature.enabled?(:sign_up_on_sso, @unauthenticated_group) && @saml_provider.enforced_group_managed_accounts?
        redirect_to_group_sign_up
      else
        redirect_to_login_or_register
      end
    end
  end

  def redirect_to_login_or_register
    notice = "Login to a GitLab account to link with your SAML identity"

    after_gitlab_sign_in = sso_group_saml_providers_path(@unauthenticated_group)

    store_location_for(:redirect, after_gitlab_sign_in)

    redirect_to new_user_session_path, notice: notice
  end

  def redirect_to_group_sign_up
    session['oauth_data'] = oauth
    session['oauth_group_id'] = @unauthenticated_group.id

    redirect_to group_sign_up_path(@unauthenticated_group)
  end

  def saml_redirect_path
    params['RelayState'].presence
  end

  override :find_message
  def find_message(kind, options = {})
    _('Unable to sign you in to the group with SAML due to "%{reason}"') % options
  end

  override :after_omniauth_failure_path_for
  def after_omniauth_failure_path_for(scope)
    group_saml_failure_path(scope)
  end

  def group_saml_failure_path(scope)
    group = Gitlab::Auth::GroupSaml::GroupLookup.new(request.env).group

    unless can?(current_user, :sign_in_with_saml_provider, group&.saml_provider)
      OmniAuth::Strategies::GroupSaml.invalid_group!(group&.path)
    end

    if can?(current_user, :admin_group_saml, group)
      group_saml_providers_path(group)
    else
      sso_group_saml_providers_path(group)
    end
  end

  override :log_audit_event
  def log_audit_event(user, options = {})
    AuditEventService.new(user, @unauthenticated_group, options)
      .for_authentication.security_event
  end
end
