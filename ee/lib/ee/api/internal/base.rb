# frozen_string_literal: true

module EE
  module API
    module Internal
      module Base
        extend ActiveSupport::Concern

        prepended do
          helpers do
            extend ::Gitlab::Utils::Override

            override :lfs_authentication_url
            def lfs_authentication_url(container)
              container.lfs_http_url_to_repo(params[:operation])
            end

            override :check_allowed
            def check_allowed(params)
              ip = params.fetch(:check_ip, nil)
              ::Gitlab::IpAddressState.with(ip) do # rubocop: disable CodeReuse/ActiveRecord
                super
              end
            end

            override :two_factor_otp_check
            def two_factor_otp_check
              return { success: false, message: 'Feature is not available' } unless ::License.feature_available?(:git_two_factor_enforcement)
              return { success: false, message: 'Feature flag is disabled' } unless ::Feature.enabled?(:two_factor_for_cli)

              actor.update_last_used_at!
              user = actor.user

              error_message = validate_actor(actor)

              return { success: false, message: error_message } if error_message

              return { success: false, message: 'Deploy keys cannot be used for Two Factor' } if actor.key.is_a?(DeployKey)

              return { success: false, message: 'Two-factor authentication is not enabled for this user' } unless user.two_factor_enabled?

              otp_validation_result = ::Users::ValidateOtpService.new(user).execute(params.fetch(:otp_attempt))

              if otp_validation_result[:status] == :success
                ::Gitlab::Auth::Otp::SessionEnforcer.new(actor.key).update_session

                { success: true }
              else
                { success: false, message: 'Invalid OTP' }
              end
            end
          end
        end
      end
    end
  end
end
