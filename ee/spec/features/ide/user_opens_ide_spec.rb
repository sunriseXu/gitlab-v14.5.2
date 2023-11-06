# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'EE user opens IDE', :js do
  using RSpec::Parameterized::TableSyntax
  include WebIdeSpecHelpers

  let_it_be(:unsigned_commits_warning) { 'This project does not accept unsigned commits.' }

  let(:project) { create(:project, :repository) }
  let(:user) { project.owner }

  before do
    stub_licensed_features(push_rules: true)
    stub_licensed_features(reject_unsigned_commits: true)
    sign_in(user)
  end

  shared_examples 'no warning' do
    it 'does not show warning' do
      ide_visit(project)

      expect(page).not_to have_text(unsigned_commits_warning)
    end
  end

  shared_examples 'has warning' do
    it 'shows warning' do
      ide_visit(project)

      expect(page).to have_text(unsigned_commits_warning)
    end
  end

  context 'no push rules' do
    it_behaves_like 'no warning'
  end

  context 'when has reject_unsigned_commit push rule' do
    before do
      create(:push_rule, project: project, reject_unsigned_commits: true)
    end

    it_behaves_like 'has warning'

    context 'and feature flag off' do
      before do
        stub_feature_flags(reject_unsigned_commits_by_gitlab: false)
      end

      it_behaves_like 'no warning'
    end
  end
end
