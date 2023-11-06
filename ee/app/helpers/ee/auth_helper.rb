# frozen_string_literal: true

module EE
  module AuthHelper
    extend ::Gitlab::Utils::Override

    GROUP_LEVEL_PROVIDERS = %i(group_saml).freeze

    delegate :slack_app_id, to: :'Gitlab::CurrentSettings.current_application_settings'

    override :display_providers_on_profile?
    def display_providers_on_profile?
      super || group_saml_enabled?
    end

    override :button_based_providers
    def button_based_providers
      super - GROUP_LEVEL_PROVIDERS
    end

    override :providers_for_base_controller
    def providers_for_base_controller
      super - GROUP_LEVEL_PROVIDERS
    end

    override :form_based_provider_priority
    def form_based_provider_priority
      super << 'smartcard'
    end

    override :form_based_provider?
    def form_based_provider?(name)
      super || name.to_s == 'kerberos'
    end

    override :form_based_providers
    def form_based_providers
      providers = super

      providers << :smartcard if smartcard_enabled?

      providers
    end

    def kerberos_enabled?
      auth_providers.include?(:kerberos)
    end

    def smartcard_enabled?
      ::Gitlab::Auth::Smartcard.enabled?
    end

    def smartcard_enabled_for_ldap?(provider_name, required: false)
      return false unless smartcard_enabled?

      server = ::Gitlab::Auth::Ldap::Config.servers.find do |server|
        server['provider_name'] == provider_name
      end

      return false unless server

      truthy_values = ['required']
      truthy_values << 'optional' unless required

      truthy_values.include? server['smartcard_auth']
    end

    def smartcard_login_button_classes(provider_name)
      css_classes = %w[btn btn-success]
      css_classes << 'btn-inverted' unless smartcard_enabled_for_ldap?(provider_name, required: true)
      css_classes.join(' ')
    end

    def group_saml_enabled?
      auth_providers.include?(:group_saml)
    end

    def slack_redirect_uri(project)
      slack_auth_project_settings_slack_url(project)
    end
  end
end
