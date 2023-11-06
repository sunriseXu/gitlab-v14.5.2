# frozen_string_literal: true

module QA
  module EE
    module Page
      class OperationsDashboard < QA::Page::Base
        include QA::Page::Component::ProjectSelector
        include QA::Page::Component::CiBadgeLink

        view 'ee/app/assets/javascripts/operations/components/dashboard/dashboard.vue' do
          element :add_projects_button
          element :add_projects_modal
        end

        view 'ee/app/assets/javascripts/operations/components/dashboard/project.vue' do
          element :dashboard_project_card
        end

        def add_project(project_name)
          open_add_project_modal

          within_add_projects_modal do
            fill_project_search_input(project_name)
            select_project
            find('button.btn.btn-success').click
          end
        end

        def remove_all_projects
          project_cards.each do |card|
            card.find('button.btn.js-remove-button').click
          end
        end

        def has_project_card?
          has_element? :dashboard_project_card
        end

        def find_project_card_by_name(name)
          project_cards.each do |card|
            title = card.find('div.card-header').find('a.gl-link')[:title]
            return card if title.include? name
          end
        end

        def pipeline_status(project_card)
          project_card.find(element_selector_css(:status_badge)).text
        end

        private

        def project_cards
          all_elements(:dashboard_project_card, minimum: 1)
        end

        def within_add_projects_modal
          within_element(:add_projects_modal) do
            yield
          end
        end

        def open_add_project_modal
          click_element :add_projects_button
        end
      end
    end
  end
end
