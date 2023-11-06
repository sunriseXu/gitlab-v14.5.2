# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          class LicenseCompliance < QA::Page::Base
            include QA::Page::Component::Select2

            view 'ee/app/assets/javascripts/license_compliance/components/app.vue' do
              element :license_compliance_empty_state_description_content
              element :policies_tab
            end

            view 'ee/app/assets/javascripts/vue_shared/license_compliance/license_management.vue' do
              element :license_add_button
            end
            view 'ee/app/assets/javascripts/vue_shared/license_compliance/components/add_license_form.vue' do
              element :license_radio, 'data-qa-selector="`${option.value}_license_radio`"' # rubocop:disable QA/ElementWithPattern
              element :add_license_submit_button
            end

            view 'ee/app/assets/javascripts/vue_shared/license_compliance/components/admin_license_management_row.vue' do
              element :admin_license_compliance_container
            end

            def has_empty_state_description?(text)
              within_element(:license_compliance_empty_state_description_content) do
                has_text?(text)
              end
            end

            def approve_license(license)
              click_element(:license_add_button)
              expand_select_list
              search_and_select_exact(license)
              choose_element(:approved_license_radio, true)
              click_element(:add_license_submit_button)

              has_approved_license?(license)
            end

            def has_approved_license?(name)
              has_element?(:admin_license_compliance_container, text: name)
              within_element(:admin_license_compliance_container, text: name) do
                has_element?(:status_success_icon)
              end
            end

            def deny_license(license)
              click_element(:license_add_button)
              expand_select_list
              search_and_select_exact(license)
              choose_element(:blacklisted_license_radio, true)
              click_element(:add_license_submit_button)

              has_denied_license?(license)
            end

            def has_denied_license?(name)
              has_element?(:admin_license_compliance_container, text: name)
              within_element(:admin_license_compliance_container, text: name) do
                has_element?(:status_failed_icon)
              end
            end

            def open_tab
              click_element(:policies_tab)
            end
          end
        end
      end
    end
  end
end
