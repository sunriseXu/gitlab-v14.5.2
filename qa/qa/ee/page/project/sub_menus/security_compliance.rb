# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module SubMenus
          module SecurityCompliance
            extend QA::Page::PageConcern

            def click_on_security_dashboard
              within_sidebar do
                click_element(:sidebar_menu_item_link, menu_item: 'Security Dashboard')
              end
            end

            def click_on_dependency_list
              hover_security_compliance do
                within_submenu do
                  click_element(:sidebar_menu_item_link, menu_item: 'Dependency List')
                end
              end
            end

            def click_on_threat_monitoring
              hover_security_compliance do
                within_submenu do
                  click_element(:sidebar_menu_item_link, menu_item: 'Threat Monitoring')
                end
              end
            end

            def click_on_policies
              hover_security_compliance do
                within_submenu do
                  click_element(:sidebar_menu_item_link, menu_item: 'Policies')
                end
              end
            end

            def click_on_vulnerability_report
              hover_security_compliance do
                within_submenu do
                  click_element(:sidebar_menu_item_link, menu_item: 'Vulnerability Report')
                end
              end
            end

            def click_on_security_configuration_link
              hover_security_compliance do
                within_submenu do
                  click_element(:sidebar_menu_item_link, menu_item: 'Configuration')
                end
              end
            end

            def hover_security_compliance
              within_sidebar do
                find_element(:sidebar_menu_link, menu_item: 'Security & Compliance').hover

                yield
              end
            end

            def go_to_audit_events_settings
              hover_security_compliance do
                within_submenu do
                  click_element(:sidebar_menu_item_link, menu_item: 'Audit Events')
                end
              end
            end
          end
        end
      end
    end
  end
end
