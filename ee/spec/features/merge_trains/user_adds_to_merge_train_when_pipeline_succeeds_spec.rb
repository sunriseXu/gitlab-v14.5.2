# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User adds to merge train when pipeline succeeds', :js do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }

  let!(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let(:pipeline) { merge_request.all_pipelines.first }

  before do
    stub_feature_flags(disable_merge_trains: false)
    stub_licensed_features(merge_pipelines: true, merge_trains: true)
    project.add_maintainer(user)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)

    merge_request.update_head_pipeline

    sign_in(user)
  end

  it 'shows Start merge train when pipeline succeeds button and helper icon' do
    visit project_merge_request_path(project, merge_request)

    expect(page).to have_button('Start merge train when pipeline succeeds')

    find('[data-testid="merge-train-helper-icon"]').hover

    expect(page).to have_selector('[data-testid="merge-train-helper-content"]')
    expect(page).to have_link('Learn more', href: help_page_path('ci/pipelines/merge_trains.md', anchor: 'add-a-merge-request-to-a-merge-train'))
  end

  context 'when merge_trains EEP license is not available' do
    before do
      stub_licensed_features(merge_trains: false)
    end

    it 'does not show Start merge train when pipeline succeeds button' do
      visit project_merge_request_path(project, merge_request)

      expect(page).not_to have_button('Start merge train when pipeline succeeds')
      expect(page).not_to have_selector('[data-testid="merge-train-helper-icon"]')
    end
  end

  context "when user clicks 'Start merge train when pipeline succeeds' button" do
    before do
      visit project_merge_request_path(project, merge_request)
      click_button 'Start merge train when pipeline succeeds'
    end

    it 'informs merge request that auto merge is enabled' do
      within('.mr-widget-section') do
        expect(page).to have_content("Set by #{user.name} to start a merge train when the pipeline succeeds")
        expect(page).to have_content('Does not delete the source branch')
        expect(page).to have_button('Cancel auto-merge')
        expect(page).to have_button('Delete source branch')
      end
    end

    context "when user clicks 'Cancel' button" do
      before do
        click_button 'Cancel auto-merge'
      end

      it 'cancels automatic merge' do
        within('.mr-widget-section') do
          expect(page).not_to have_content("Set by #{user.name} to start a merge train when the pipeline succeeds")
          expect(page).to have_button('Start merge train when pipeline succeeds')
        end
      end
    end

    context "when user clicks 'Delete source branch" do
      before do
        wait_for_requests
        click_button 'Delete source branch'
      end

      it 'updates the merge option' do
        within('.mr-widget-section') do
          expect(page).to have_content('Deletes the source branch')
        end
      end
    end
  end

  context 'when the merge request is not the first queue on the train' do
    before do
      create(:merge_request, :on_train,
        source_project: project, source_branch: 'signed-commits',
        target_project: project, target_branch: 'master')
    end

    it 'shows Add to merge train when pipeline succeeds button' do
      visit project_merge_request_path(project, merge_request)

      expect(page).to have_button('Add to merge train when pipeline succeeds')
    end
  end
end
