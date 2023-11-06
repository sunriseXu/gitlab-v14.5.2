# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User creates On-demand Scan' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
  let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }

  let(:profile_library_path) { project_security_configuration_dast_scans_path(project) }

  before_all do
    project.add_developer(user)
  end

  before do
    sign_in(user)
  end

  context 'when feature is available' do
    before do
      stub_licensed_features(security_on_demand_scans: true)
      visit(new_project_on_demand_scan_path(project))
    end

    it 'shows new scan page', :aggregate_failures, :js do
      expect(page).to have_content 'New on-demand DAST scan'
      expect(page).to have_link 'Manage DAST scans'
      expect(page).to have_button 'Save and run scan'
      expect(page).to have_button 'Save scan'
    end

    it 'on save', :js do
      fill_in_form

      click_button 'Save scan'
      wait_for_requests

      expect(current_path).to eq(profile_library_path)
    end

    it 'on cancel', :js do
      click_button 'Cancel'
      expect(current_path).to eq(profile_library_path)
    end
  end

  context 'when feature is not available' do
    before do
      visit(new_project_on_demand_scan_path(project))
    end

    it 'renders a 404' do
      expect(page).to have_gitlab_http_status(:not_found)
    end
  end

  def fill_in_form
    fill_in 'name', with: "My scan"
    fill_in 'description', with: "This is the description"
  end
end
