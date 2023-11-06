# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User activates Jira', :js do
  include_context 'project service activation'
  include_context 'project service Jira context'

  describe 'user sets and activates Jira Service' do
    before do
      server_info = { key: 'value' }.to_json
      stub_request(:get, test_url).with(basic_auth: %w(username password)).to_return(body: server_info)
    end

    context 'when Jira connection test succeeds' do
      before do
        stub_licensed_features(jira_issues_integration: true)
        allow_next_instance_of(Integrations::Jira) do |instance|
          allow(instance).to receive(:issues_enabled) { true }
        end

        visit_project_integration('Jira')
        fill_form
        fill_in 'service_project_key', with: 'AB'
        click_test_then_save_integration(expect_test_to_fail: false)
      end

      it 'adds Jira links to sidebar menu' do
        page.within('.nav-sidebar') do
          expect(page).to have_link('Jira Issues', href: project_integrations_jira_issues_path(project))
          expect(page).to have_link('Issue List', href: project_integrations_jira_issues_path(project), visible: false)
          expect(page).to have_link('Open Jira', href: url, visible: false)
          expect(page).not_to have_link('Jira', href: url)
        end
      end
    end

    context 'when jira_issues_integration feature is not available' do
      before do
        stub_licensed_features(jira_issues_integration: false)

        visit_project_integration('Jira')
        fill_form
        click_save_integration
      end

      it 'does not show Jira links in sidebar menu' do
        page.within('.nav-sidebar') do
          expect(page).not_to have_link('Jira Issues', href: project_integrations_jira_issues_path(project))
          expect(page).not_to have_link('Issue List', href: project_integrations_jira_issues_path(project), visible: false)
          expect(page).not_to have_link('Open Jira', href: url, visible: false)
          expect(page).to have_link('Jira', href: url)
        end
      end
    end
  end
end
