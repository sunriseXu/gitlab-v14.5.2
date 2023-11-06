# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module ProtectedBranches
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/views/projects/protected_branches/ee/_code_owner_approval_table.html.haml' do
                  element :code_owner_toggle_button
                end

                view 'ee/app/views/projects/protected_branches/ee/_create_protected_branch.html.haml' do
                  element :allowed_to_push_select
                  element :allowed_to_push_dropdown
                  element :allowed_to_merge_select
                  element :allowed_to_merge_dropdown
                end

                view 'ee/app/views/projects/protected_branches/ee/_protected_branch_access_summary.html.haml' do
                  element :allowed_to_merge
                end
              end
            end

            def require_code_owner_approval(branch)
              toggle = find_element(:code_owner_toggle_button, branch_name: branch)
              toggle.click unless toggle[:class].include?('is-checked')
            end

            private

            def select_allowed(action, allowed)
              super

              # Click the select element again to close the dropdown
              click_element(:"allowed_to_#{action}_select")
            end
          end
        end
      end
    end
  end
end
