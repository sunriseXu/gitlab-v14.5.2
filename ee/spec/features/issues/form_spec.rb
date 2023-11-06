# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'New/edit issue', :js do
  include GitlabRoutingHelper
  include ActionView::Helpers::JavaScriptHelper
  include FormHelper

  let!(:project)   { create(:project) }
  let!(:user)      { create(:user)}
  let!(:user2)     { create(:user)}
  let!(:milestone) { create(:milestone, project: project) }
  let!(:label)     { create(:label, project: project) }
  let!(:label2)    { create(:label, project: project) }
  let!(:issue)     { create(:issue, project: project, assignees: [user], milestone: milestone) }

  before do
    project.add_maintainer(user)
    project.add_maintainer(user2)

    allow_any_instance_of(ApplicationHelper).to receive(:collapsed_sidebar?).and_return(true)

    stub_licensed_features(multiple_issue_assignees: true)
    gitlab_sign_in(user)
  end

  context 'new issue' do
    before do
      visit new_project_issue_path(project)
    end

    describe 'shorten users API pagination limit' do
      before do
        # Using `allow_any_instance_of`/`and_wrap_original`, `original` would
        # somehow refer to the very block we defined to _wrap_ that method, instead of
        # the original method, resulting in infinite recursion when called.
        # This is likely a bug with helper modules included into dynamically generated view classes.
        # To work around this, we have to hold on to and call to the original implementation manually.
        original_issue_dropdown_options = FormHelper.instance_method(:assignees_dropdown_options)
        allow_any_instance_of(FormHelper).to receive(:assignees_dropdown_options).and_wrap_original do |original, *args|
          options = original_issue_dropdown_options.bind(original.receiver).call(*args)
          options[:data][:per_page] = 2

          options
        end

        visit new_project_issue_path(project)

        click_button 'Unassigned'

        wait_for_requests
      end

      it 'displays selected users even if they are not part of the original API call', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/28634' do
        find('.dropdown-input-field').native.send_keys user2.name

        page.within '.dropdown-menu-user' do
          expect(page).to have_content user2.name
          click_link user2.name
        end

        find('.js-dropdown-input-clear').click

        page.within '.dropdown-menu-user' do
          expect(page).to have_content user.name
          expect(find('.dropdown-menu-user a.is-active').first(:xpath, '..')['data-user-id']).to eq(user2.id.to_s)
        end
      end
    end

    describe 'multiple assignees' do
      before do
        click_button 'Unassigned'

        wait_for_requests
      end

      it 'unselects other assignees when unassigned is selected' do
        page.within '.dropdown-menu-user' do
          click_link user2.name
        end

        page.within '.dropdown-menu-user' do
          click_link 'Unassigned'
        end

        expect(find('input[name="issue[assignee_ids][]"]', visible: false).value).to match('0')
      end

      it 'toggles assign to me when current user is selected and unselected' do
        page.within '.dropdown-menu-user' do
          click_link user.name
        end

        expect(find('a', text: 'Assign to me', visible: false)).not_to be_visible

        page.within('.dropdown-menu-user') do
          click_link user.name
        end

        expect(find('a', text: 'Assign to me')).to be_visible
      end
    end

    it 'allows user to create new issue' do
      fill_in 'issue_title', with: 'title'
      fill_in 'issue_description', with: 'title'

      expect(find('a', text: 'Assign to me')).to be_visible
      click_button 'Unassigned'

      wait_for_requests

      page.within '.dropdown-menu-user' do
        click_link user2.name
      end
      expect(find('input[name="issue[assignee_ids][]"]', visible: false).value).to match(user2.id.to_s)
      page.within '.js-assignee-search' do
        expect(page).to have_content user2.name
      end
      find('.dropdown-menu-user .dropdown-menu-close').click

      find('a', text: 'Assign to me').click
      assignee_ids = page.all('input[name="issue[assignee_ids][]"]', visible: false)

      expect(assignee_ids[0].value).to match(user2.id.to_s)
      expect(assignee_ids[1].value).to match(user.id.to_s)

      page.within '.js-assignee-search' do
        expect(page).to have_content "#{user2.name} + 1 more"
      end
      expect(find('a', text: 'Assign to me', visible: false)).not_to be_visible

      click_button 'Milestone'
      page.within '.issue-milestone' do
        click_link milestone.title
      end
      expect(find('input[name="issue[milestone_id]"]', visible: false).value).to match(milestone.id.to_s)
      page.within '.js-milestone-select' do
        expect(page).to have_content milestone.title
      end

      click_button 'Labels'
      page.within '.dropdown-menu-labels' do
        click_link label.title
        click_link label2.title

        find('.dropdown-menu-close').click
      end
      page.within '.js-label-select' do
        expect(page).to have_content label.title
      end
      expect(page.all('input[name="issue[label_ids][]"]', visible: false)[1].value).to match(label.id.to_s)
      expect(page.all('input[name="issue[label_ids][]"]', visible: false)[2].value).to match(label2.id.to_s)

      fill_in 'issue_weight', with: '1'

      click_button 'Create issue'

      page.within '.issuable-sidebar' do
        page.within '.assignee' do
          expect(page).to have_content "2 Assignees"
        end

        page.within '.milestone' do
          expect(page).to have_content milestone.title
        end

        page.within '.labels' do
          expect(page).to have_content label.title
          expect(page).to have_content label2.title
        end

        page.within '.weight' do
          expect(page).to have_content '1'
        end
      end

      page.within '.breadcrumbs' do
        issue = Issue.find_by(title: 'title')

        expect(page).to have_text("Issues #{issue.to_reference}")
      end
    end

    it 'correctly updates the selected user when changing assignee' do
      click_button 'Unassigned'

      wait_for_requests

      page.within '.dropdown-menu-user' do
        click_link user.name
      end

      expect(find('.js-assignee-search')).to have_content(user.name)

      page.within '.dropdown-menu-user' do
        click_link user2.name
      end

      expect(page.all('input[name="issue[assignee_ids][]"]', visible: false)[0].value).to match(user.id.to_s)
      expect(page.all('input[name="issue[assignee_ids][]"]', visible: false)[1].value).to match(user2.id.to_s)

      expect(page.all('.dropdown-menu-user a.is-active').length).to eq(2)

      expect(page.all('.dropdown-menu-user a.is-active')[0].first(:xpath, '..')['data-user-id']).to eq(user.id.to_s)
      expect(page.all('.dropdown-menu-user a.is-active')[1].first(:xpath, '..')['data-user-id']).to eq(user2.id.to_s)
    end
  end

  def before_for_selector(selector)
    js = <<-JS.strip_heredoc
      (function(selector) {
        var el = document.querySelector(selector);
        return window.getComputedStyle(el, '::before').getPropertyValue('content');
      })("#{escape_javascript(selector)}")
    JS
    page.evaluate_script(js)
  end
end
