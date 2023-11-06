# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class LDAPSync < ::QA::Page::Base
            include QA::Page::Component::Select2

            view 'ee/app/views/ldap_group_links/_form.html.haml' do
              element :add_sync_button
              element :ldap_group_cn_select
              element :ldap_sync_group_radio
              element :ldap_user_filter_field
            end

            def set_ldap_group_sync_method
              choose_element(:ldap_sync_group_radio)
            end

            def set_group_cn(group_cn)
              click_element(:ldap_group_cn_select)
              search_and_select(group_cn)
            end

            def set_user_filter(user_filter)
              fill_element(:ldap_user_filter_field, user_filter)
            end

            def click_add_sync_button
              click_element(:add_sync_button)
            end
          end
        end
      end
    end
  end
end
