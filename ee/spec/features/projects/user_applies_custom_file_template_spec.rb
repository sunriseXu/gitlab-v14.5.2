# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project', :js do
  let(:template_text) { 'Custom license template content' }
  let(:group) { create(:group) }
  let(:template_project) { create(:project, :custom_repo, namespace: group, files: { 'LICENSE/custom.txt' => template_text }) }
  let(:project) { create(:project, :empty_repo, namespace: group) }
  let(:developer) { create(:user) }

  describe 'Custom file templates' do
    before do
      project.add_developer(developer)
      gitlab_sign_in(developer)
    end

    it 'allows file creation from an instance template' do
      stub_licensed_features(custom_file_templates: true)
      stub_ee_application_setting(file_template_project: template_project)

      visit project_new_blob_path(project, 'master', file_name: 'LICENSE.txt')

      select_template_type('LICENSE')
      select_template('license', 'custom')

      wait_for_requests

      expect(page).to have_content(template_text)
    end

    it 'allows file creation from a group template' do
      stub_licensed_features(custom_file_templates_for_namespace: true)
      group.update_columns(file_template_project_id: template_project.id)

      visit project_new_blob_path(project, 'master', file_name: 'LICENSE.txt')

      select_template_type('LICENSE')
      select_template('license', 'custom')

      wait_for_requests

      expect(page).to have_content(template_text)
    end
  end

  def select_template_type(template_type)
    find('.js-template-type-selector').click
    find('.dropdown-content li', text: template_type).click
  end

  def select_template(type, name)
    find(".js-#{type}-selector").click
    find('.dropdown-content li', text: name).click
  end
end
