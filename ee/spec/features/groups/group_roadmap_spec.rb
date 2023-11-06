# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'group epic roadmap', :js do
  include FilteredSearchHelpers
  include MobileHelpers

  let(:user) { create(:user) }
  let(:user_dev) { create(:user) }
  let(:group) { create(:group) }
  let(:milestone) { create(:milestone, group: group) }
  let(:state_dropdown) { find('.dropdown-epics-state') }

  let!(:bug_label) { create(:group_label, group: group, title: 'Bug') }
  let!(:critical_label) { create(:group_label, group: group, title: 'Critical') }

  def search_for_label(label)
    page.within('.vue-filtered-search-bar-container .gl-search-box-by-click') do
      page.find('input.gl-filtered-search-term-input').click
      click_link 'Label'
      page.first('.gl-filtered-search-suggestion-list .gl-filtered-search-suggestion').click # Select `=` operator
      wait_for_requests
      page.find('.gl-filtered-search-suggestion-list .gl-filtered-search-suggestion', text: bug_label.title).click
    end
    page.find('.gl-search-box-by-click-search-button').click
  end

  before do
    stub_licensed_features(epics: true)
    stub_feature_flags(unfiltered_epic_aggregates: false)

    sign_in(user)
  end

  context 'when epics exist for the group' do
    available_tokens = %w[Author Label Milestone Epic My-Reaction]

    let!(:epic_with_bug) { create(:labeled_epic, group: group, start_date: 10.days.ago, end_date: 1.day.ago, labels: [bug_label]) }
    let!(:epic_with_critical) { create(:labeled_epic, group: group, start_date: 20.days.ago, end_date: 2.days.ago, labels: [critical_label]) }
    let!(:closed_epic) { create(:epic, :closed, group: group, start_date: 20.days.ago, end_date: 2.days.ago) }

    before do
      visit group_roadmap_path(group)
      wait_for_requests
    end

    describe 'roadmap page' do
      context 'roadmap daterange filtering' do
        def select_date_range(range_type)
          page.within('.epics-roadmap-filters') do
            page.find('[data-testid="daterange-dropdown"] button.dropdown-toggle').click
            click_button(range_type)
          end
        end

        it 'renders daterange filtering dropdown with "This quarter" selected by default no layout presets available', :aggregate_failures do
          page.within('.epics-roadmap-filters') do
            expect(page).to have_selector('[data-testid="daterange-dropdown"]')
            expect(page).not_to have_selector('.gl-segmented-control')
            expect(page.find('[data-testid="daterange-dropdown"] button.dropdown-toggle')).to have_content('This quarter')
          end
        end

        it 'selecting "This year" as daterange shows `Months` and `Weeks` layout presets', :aggregate_failures do
          select_date_range('This year')

          page.within('.epics-roadmap-filters') do
            expect(page).to have_selector('.gl-segmented-control')
            expect(page).to have_selector('input[value="MONTHS"]')
            expect(page).to have_selector('input[value="WEEKS"]')
          end
        end

        it 'selecting "Within 3 years" as daterange shows `Quarters`, `Months` and `Weeks` layout presets', :aggregate_failures do
          select_date_range('Within 3 years')

          page.within('.epics-roadmap-filters') do
            expect(page).to have_selector('.gl-segmented-control')
            expect(page).to have_selector('input[value="QUARTERS"]')
            expect(page).to have_selector('input[value="MONTHS"]')
            expect(page).to have_selector('input[value="WEEKS"]')
          end
        end
      end

      it 'renders the epics state dropdown' do
        page.within('.content-wrapper .content .epics-filters') do
          expect(page).to have_css('.dropdown-epics-state')
        end
      end

      it 'renders the filtered search bar correctly' do
        page.within('.content-wrapper .content .epics-filters') do
          expect(page).to have_css('.vue-filtered-search-bar-container')
        end
      end

      it 'renders the sort dropdown correctly' do
        page.within('.vue-filtered-search-bar-container') do
          expect(page).to have_css('.sort-dropdown-container')
          find('.sort-dropdown-container .dropdown-toggle').click
          page.within('.sort-dropdown-container .dropdown-menu') do
            expect(page).to have_selector('li button', count: 2)
            expect(page).to have_content('Start date')
            expect(page).to have_content('Due date')
          end
        end
      end

      it 'renders roadmap view' do
        page.within('.content-wrapper .content') do
          expect(page).to have_css('.roadmap-container')
        end
      end

      it 'renders all group epics within roadmap' do
        page.within('.roadmap-container .epics-list-section') do
          expect(page).to have_selector('.epics-list-item .epic-title', count: 3)
        end
      end
    end

    describe 'roadmap page with epics state filter' do
      before do
        state_dropdown.find('.dropdown-toggle').click
      end

      it 'renders open epics only' do
        state_dropdown.find('button', text: 'Open epics').click

        page.within('.roadmap-container .epics-list-section') do
          expect(page).to have_selector('.epics-list-item .epic-title', count: 2)
        end
      end

      it 'renders closed epics only' do
        state_dropdown.find('button', text: 'Closed epics').click

        page.within('.roadmap-container .epics-list-section') do
          expect(page).to have_selector('.epics-list-item .epic-title', count: 1)
        end
      end

      it 'saves last selected epic state', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/341827' do
        state_dropdown.find('button', text: 'Open epics').click

        wait_for_all_requests
        visit group_roadmap_path(group)
        wait_for_requests

        expect(state_dropdown.find('.dropdown-toggle')).to have_text("Open epics")
        page.within('.roadmap-container .epics-list-section') do
          expect(page).to have_selector('.epics-list-item .epic-title', count: 2)
        end
      end
    end

    describe 'roadmap page with filter applied' do
      before do
        search_for_label(bug_label)
      end

      it 'renders filtered search bar with applied filter token' do
        expect_vue_tokens([label_token(bug_label.title)])
      end

      it 'renders roadmap view with matching epic' do
        page.within('.roadmap-container .epics-list-section') do
          expect(page).to have_selector('.epics-list-item .epic-title', count: 1)
          expect(page).to have_content(epic_with_bug.title)
        end
      end

      it 'keeps label filter when filtering by state' do
        state_dropdown.find('.dropdown-toggle').click
        state_dropdown.find('button', text: 'Open epics').click

        page.within('.roadmap-container .epics-list-section') do
          expect(page).to have_selector('.epics-list-item .epic-title', count: 1)
          expect(page).to have_content(epic_with_bug.title)
        end
      end
    end

    describe 'filtered search tokens' do
      let!(:epic1) { create(:epic, group: group, end_date: 10.days.ago) }
      let!(:epic2) { create(:epic, group: group, start_date: 2.days.ago) }
      let!(:award_emoji_star) { create(:award_emoji, name: 'star', user: user, awardable: epic1) }

      before do
        group.add_developer(user_dev)
        visit group_roadmap_path(group)
        wait_for_requests
      end

      it_behaves_like 'filtered search bar', available_tokens
    end

    describe 'that is a sub-group' do
      let!(:subgroup) { create(:group, parent: group, name: 'subgroup') }
      let!(:sub_epic1) { create(:epic, group: subgroup, end_date: 10.days.ago) }
      let!(:sub_epic2) { create(:epic, group: subgroup, start_date: 2.days.ago) }
      let!(:award_emoji_star) { create(:award_emoji, name: 'star', user: user, awardable: sub_epic1) }

      before do
        subgroup.add_developer(user_dev)
        visit group_roadmap_path(subgroup)
        wait_for_requests
      end

      it_behaves_like 'filtered search bar', available_tokens
    end
  end

  context 'when no epics exist for the group' do
    before do
      visit group_roadmap_path(group)
      wait_for_requests
    end

    describe 'roadmap page' do
      it 'shows empty state page' do
        page.within('.empty-state') do
          expect(page).to have_content('The roadmap shows the progress of your epics along a timeline')
        end
      end
    end
  end
end
