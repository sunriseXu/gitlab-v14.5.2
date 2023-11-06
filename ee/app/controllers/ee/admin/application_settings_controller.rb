# frozen_string_literal: true

module EE
  module Admin
    module ApplicationSettingsController
      extend ::Gitlab::Utils::Override
      extend ActiveSupport::Concern

      prepended do
        before_action :elasticsearch_reindexing_task, only: [:advanced_search]
        before_action :elasticsearch_index_settings, only: [:advanced_search]
        before_action :elasticsearch_warn_if_not_using_aliases, only: [:advanced_search]

        feature_category :license, [:seat_link_payload]
        feature_category :source_code_management, [:templates]
        feature_category :global_search, [:advanced_search]

        def elasticsearch_reindexing_task
          @last_elasticsearch_reindexing_task = Elastic::ReindexingTask.last
          @elasticsearch_reindexing_task = Elastic::ReindexingTask.new
        end

        def elasticsearch_index_settings
          @elasticsearch_index_settings = Elastic::IndexSetting.order_by_name
        end

        def elasticsearch_warn_if_not_using_aliases
          @elasticsearch_warn_if_not_using_aliases = ::Gitlab::Elastic::Helper.default.alias_missing?
        rescue StandardError => e
          log_exception(e)
        end
      end

      EE_VALID_SETTING_PANELS = %w(advanced_search templates).freeze

      EE_VALID_SETTING_PANELS.each do |action|
        define_method(action) { perform_update if submitted? }
      end

      def visible_application_setting_attributes
        attrs = super

        if License.feature_available?(:repository_mirrors)
          attrs += EE::ApplicationSettingsHelper.repository_mirror_attributes
        end

        # License feature => attribute name
        {
          custom_project_templates: :custom_project_templates_group_id,
          email_additional_text: :email_additional_text,
          custom_file_templates: :file_template_project_id,
          pseudonymizer: :pseudonymizer_enabled,
          default_project_deletion_protection: :default_project_deletion_protection,
          adjourned_deletion_for_projects_and_groups: [:delayed_project_deletion, :deletion_adjourned_period],
          required_ci_templates: :required_instance_ci_template,
          disable_name_update_for_users: :updating_name_disabled_for_users,
          package_forwarding: [:npm_package_requests_forwarding, :pypi_package_requests_forwarding],
          default_branch_protection_restriction_in_groups: :group_owners_can_manage_default_branch_protection
        }.each do |license_feature, attribute_names|
          if License.feature_available?(license_feature)
            attrs += Array.wrap(attribute_names)
          end
        end

        if License.feature_available?(:git_two_factor_enforcement) && ::Feature.enabled?(:two_factor_for_cli)
          attrs << :git_two_factor_session_expiry
        end

        if License.feature_available?(:admin_merge_request_approvers_rules)
          attrs += EE::ApplicationSettingsHelper.merge_request_appovers_rules_attributes
        end

        if License.feature_available?(:elastic_search)
          attrs += [
            elasticsearch_shards: {},
            elasticsearch_replicas: {}
          ]
        end

        if ::Gitlab::Geo.license_allows?
          attrs << :maintenance_mode
          attrs << :maintenance_mode_message
        end

        attrs << :new_user_signups_cap

        attrs
      end

      def seat_link_payload
        data = ::Gitlab::SeatLinkData.new

        respond_to do |format|
          format.html do
            seat_link_json = ::Gitlab::Json.pretty_generate(data)

            render html: ::Gitlab::Highlight.highlight('payload.json', seat_link_json, language: 'json')
          end
          format.json { render json: data.to_json }
        end
      end

      private

      override :valid_setting_panels
      def valid_setting_panels
        super + EE_VALID_SETTING_PANELS
      end
    end
  end
end
