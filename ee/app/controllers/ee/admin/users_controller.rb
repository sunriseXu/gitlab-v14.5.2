# frozen_string_literal: true

# rubocop:disable Gitlab/ModuleWithInstanceVariables
module EE
  module Admin
    module UsersController
      extend ::Gitlab::Utils::Override

      def reset_runners_minutes
        user

        if ::Ci::Minutes::ResetUsageService.new(@user.namespace).execute
          redirect_to [:admin, @user], notice: _('User pipeline minutes were successfully reset.')
        else
          flash.now[:error] = _('There was an error resetting user pipeline minutes.')
          render "edit"
        end
      end

      def card_match
        return render_404 unless ::Gitlab.com?

        credit_card_validation = user.credit_card_validation

        if credit_card_validation&.holder_name
          @similar_credit_card_validations = credit_card_validation.similar_records.page(params[:page]).per(100)
        else
          redirect_to [:admin, @user], notice: _('No credit card data for matching')
        end
      end

      private

      override :users_with_included_associations
      def users_with_included_associations(users)
        super.includes(:oncall_schedules, :escalation_policies) # rubocop: disable CodeReuse/ActiveRecord
      end

      override :log_impersonation_event
      def log_impersonation_event
        super

        log_audit_event
      end

      def log_audit_event
        AuditEvents::ImpersonationAuditEventService.new(current_user, request.remote_ip, 'Started Impersonation')
          .for_user(full_path: user.username, entity_id: user.id).security_event
      end

      def allowed_user_params
        super + [
          namespace_attributes: [
            :id,
            :shared_runners_minutes_limit,
            gitlab_subscription_attributes: [:hosted_plan_id]
          ]
        ]
      end
    end
  end
end
