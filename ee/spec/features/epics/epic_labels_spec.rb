# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Assign labels to an epic', :js do
  let(:user) { create(:user) }
  let(:group) { create(:group, :public) }
  let(:label) { create(:group_label, group: group, title: 'bug') }
  let(:epic) { create(:epic, group: group) }

  before do
    group.add_developer(user)
    stub_licensed_features(epics: true)
    sign_in(user)

    set_cookie('collapsed_gutter', 'true')

    visit group_epic_path(group, epic)
  end

  context 'when label is referenced' do
    before do
      fill_in 'note[note]', with: "refer ~#{label.name}"
      click_button 'Comment'

      wait_for_requests
    end

    it 'creates new system note with label pointing to epics index page' do
      page.within('div#notes li.note div.note-text') do
        expect(page).to have_content("refer #{label.name}")
        expect(page.find('a')).to have_content(label.name)
        expect(page).to have_link(label.name, href: group_epics_path(group, label_name: label.name))
      end
    end
  end

  context 'when labels icon is clicked on collapsed sidebar' do
    before do
      page.within('aside.right-sidebar') do
        find('[data-testid="labels-icon"]').click
      end
      wait_for_requests
    end

    it 'expands sidebar' do
      page.within('.content-wrapper .content') do
        expect(page).to have_css('.right-sidebar-expanded')
      end
    end

    it 'opens labels dropdown' do
      page.within('aside.right-sidebar') do
        expect(page).to have_css('.js-labels-block [data-testid="labels-select-dropdown-contents"]')
      end
    end

    it 'collapses sidebar when clicked outside' do
      wait_for_requests
      page.within('.content-wrapper') do
        find('.epic-page-container').click

        expect(page).to have_css('.right-sidebar-collapsed')
      end
    end
  end
end
