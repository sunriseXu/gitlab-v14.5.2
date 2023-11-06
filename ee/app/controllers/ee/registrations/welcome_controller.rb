# frozen_string_literal: true

module EE
  module Registrations
    module WelcomeController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      TRIAL_ONBOARDING_BOARD_NAME = 'GitLab onboarding'

      prepended do
        before_action :authorized_for_trial_onboarding!,
                      only: [
                        :trial_getting_started,
                        :trial_onboarding_board
                      ]

        before_action only: :show do
          publish_combined_registration_experiment
          experiment(:trial_registration_with_reassurance, actor: current_user)
            .track(:render, label: 'registrations:welcome:show', user: current_user)
        end
      end

      def trial_getting_started
        render locals: { learn_gitlab_project: learn_gitlab_project }
      end

      def trial_onboarding_board
        board = learn_gitlab_project.boards.find_by_name(TRIAL_ONBOARDING_BOARD_NAME)
        path = board ? project_board_path(learn_gitlab_project, board) : project_boards_path(learn_gitlab_project)
        redirect_to path
      end

      def continuous_onboarding_getting_started
        project = ::Project.find(params[:project_id])
        return access_denied! unless can?(current_user, :owner_access, project)

        session[:confetti_post_signup] = true

        render locals: { project: project }
      end

      private

      override :update_params
      def update_params
        clean_params = super.merge(params.require(:user).permit(:email_opted_in, :registration_objective))

        return clean_params unless ::Gitlab.dev_env_or_com?

        clean_params[:email_opted_in] = '1' if clean_params[:setup_for_company] == 'true'

        if clean_params[:email_opted_in] == '1'
          clean_params[:email_opted_in_ip] = request.remote_ip
          clean_params[:email_opted_in_source_id] = User::EMAIL_OPT_IN_SOURCE_ID_GITLAB_COM
          clean_params[:email_opted_in_at] = Time.zone.now
        end

        clean_params
      end

      override :show_signup_onboarding?
      def show_signup_onboarding?
        !helpers.in_subscription_flow? &&
          !helpers.user_has_memberships? &&
          !helpers.in_oauth_flow? &&
          !helpers.in_trial_flow? &&
          helpers.signup_onboarding_enabled?
      end

      override :trial_params
      def trial_params
        return if combined_registration_experiment.variant.name == 'candidate'

        experiment(:force_company_trial, user: current_user) do |e|
          e.try { { trial: true } }
          e.run
        end
      end

      def authorized_for_trial_onboarding!
        access_denied! unless can?(current_user, :owner_access, learn_gitlab_project)
      end

      def learn_gitlab_project
        strong_memoize(:learn_gitlab_project) do
          ::Project.find(params[:learn_gitlab_project_id])
        end
      end

      def publish_combined_registration_experiment
        combined_registration_experiment.publish_to_client if show_signup_onboarding?
      end

      def combined_registration_experiment
        experiment(:combined_registration, user: current_user)
      end

      override :update_success_path
      def update_success_path
        if params[:joining_project] == 'true'
          bypass_registration_event(:joining_project)
          path_for_signed_in_user(current_user)
        else
          bypass_registration_event(:creating_project)
          experiment(:combined_registration, user: current_user).redirect_path(trial_params)
        end
      end

      def bypass_registration_event(event_name)
        experiment(:bypass_registration, user: current_user).track(event_name, user: current_user)
      end
    end
  end
end
