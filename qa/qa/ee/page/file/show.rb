# frozen_string_literal: true

module QA
  module EE
    module Page
      module File
        module Show
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              view 'ee/app/views/projects/blob/_owners.html.haml' do
                element :file_owner_content
                element :link_file_owner
              end

              view 'ee/app/helpers/ee/lock_helper.rb' do
                element :lock_button
                element :disabled_lock_button
              end
            end
          end

          def lock
            accept_confirm do
              click_element :lock_button
            end

            begin
              has_element? :lock_button, text: 'Unlock'
            rescue StandardError
              raise QA::Page::Base::ElementNotFound, %q(Button did not show expected state)
            end
          end

          def unlock
            accept_confirm do
              click_element :lock_button
            end

            begin
              has_element? :lock_button, text: 'Lock'
            rescue StandardError
              raise QA::Page::Base::ElementNotFound, %q(Button did not show expected state)
            end
          end

          def has_lock_button_disabled?
            has_element? :disabled_lock_button
          end
        end
      end
    end
  end
end
