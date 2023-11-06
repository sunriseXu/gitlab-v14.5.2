# frozen_string_literal: true

module ExternalStatusChecks
  class DestroyService < BaseContainerService
    def execute(rule)
      return unauthorized_error_response unless current_user.can?(:admin_project, container)

      if rule.destroy
        ServiceResponse.success
      else
        ServiceResponse.error(message: 'Failed to destroy rule',
                              payload: { errors: rule.errors.full_messages },
                              http_status: :unprocessable_entity)
      end
    end

    private

    def unauthorized_error_response
      ServiceResponse.error(
        message: 'Failed to destroy rule',
        payload: { errors: ['Not allowed'] },
        http_status: :unauthorized
      )
    end
  end
end
