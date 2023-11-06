# frozen_string_literal: true

module Registrations
  class GroupsController < ApplicationController
    include Registrations::CreateGroup
    include ::Gitlab::Utils::StrongMemoize

    layout 'minimal'

    feature_category :onboarding

    def new
      experiment(:trial_registration_with_reassurance, actor: current_user)
        .track(:render, label: 'registrations:groups:new', user: current_user)
      @group = Group.new(visibility_level: helpers.default_group_visibility)
      experiment(:combined_registration, user: current_user).track(:view_new_group_action)
    end

    def create
      @group = Groups::CreateService.new(current_user, group_params.merge(create_event: true)).execute

      if @group.persisted?
        experiment(:combined_registration, user: current_user).track(:create_group, namespace: @group)

        force_company_trial_experiment.track(:create_group, namespace: @group, user: current_user)

        create_successful_flow
      else
        render action: :new
      end
    end

    private

    def force_company_trial_experiment
      @force_company_trial_experiment ||=
        experiment(:force_company_trial, user: current_user)
    end

    def create_successful_flow
      if helpers.in_trial_onboarding_flow?
        apply_trial_for_trial_onboarding_flow
      else
        registration_onboarding_flow
      end
    end

    def apply_trial_for_trial_onboarding_flow
      if apply_trial
        record_experiment_user(:remove_known_trial_form_fields_welcoming, namespace_id: @group.id)
        record_experiment_conversion_event(:remove_known_trial_form_fields_welcoming)

        experiment(:trial_registration_with_reassurance, actor: current_user).track(
          :apply_trial,
          label: 'registrations:groups:create',
          namespace: @group,
          user: current_user
        )

        redirect_to new_users_sign_up_project_path(namespace_id: @group.id, trial: helpers.in_trial_during_signup_flow?, trial_onboarding_flow: true)
      else
        render action: :new
      end
    end

    def registration_onboarding_flow
      if helpers.in_trial_during_signup_flow?
        create_lead_and_apply_trial_flow
      else
        redirect_to new_users_sign_up_project_path(namespace_id: @group.id, trial: false)
      end
    end

    def create_lead_and_apply_trial_flow
      if create_lead && apply_trial
        redirect_to new_users_sign_up_project_path(namespace_id: @group.id, trial: true)
      else
        render action: :new
      end
    end

    def create_lead
      trial_params = {
        trial_user: params.permit(
          :company_name,
          :company_size,
          :phone_number,
          :number_of_users,
          :country
        ).merge(
          work_email: current_user.email,
          first_name: current_user.first_name,
          last_name: current_user.last_name,
          uid: current_user.id,
          setup_for_company: current_user.setup_for_company,
          skip_email_confirmation: true,
          gitlab_com_trial: true,
          provider: 'gitlab',
          newsletter_segment: current_user.email_opted_in
        )
      }
      result = GitlabSubscriptions::CreateLeadService.new.execute(trial_params)
      flash[:alert] = result&.dig(:errors) unless result&.dig(:success)

      result&.dig(:success)
    end

    def apply_trial
      apply_trial_params = {
        uid: current_user.id,
        trial_user: params.permit(:glm_source, :glm_content).merge({
                                                                     namespace_id: @group.id,
                                                                     gitlab_com_trial: true,
                                                                     sync_to_gl: true
                                                                   })
      }

      result = GitlabSubscriptions::ApplyTrialService.new.execute(apply_trial_params)
      flash[:alert] = result&.dig(:errors) unless result&.dig(:success)

      success = result&.dig(:success)

      force_company_trial_experiment.track(:create_trial, namespace: @group, user: current_user, label: 'registrations_groups_controller') if success

      success
    end
  end
end
