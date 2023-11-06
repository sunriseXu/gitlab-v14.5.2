# frozen_string_literal: true

module EE
  module TrialRegistrationHelper
    def social_signin_enabled?
      ::Gitlab.dev_env_or_com? &&
        omniauth_enabled? &&
        devise_mapping.omniauthable? &&
        button_based_providers_enabled?
    end
  end
end
