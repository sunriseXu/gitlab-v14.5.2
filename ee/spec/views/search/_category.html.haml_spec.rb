# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'search/_category' do
  let_it_be(:group) { create(:group) }

  context 'feature flags' do
    using RSpec::Parameterized::TableSyntax

    before do
      stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    end

    where(:feature_flag, :tab_name) do
      :global_search_code_tab           | 'Code'
      :global_search_issues_tab         | 'Issues'
      :global_search_merge_requests_tab | 'Merge requests'
      :global_search_wiki_tab           | 'Wiki'
      :global_search_commits_tab        | 'Commits'
    end

    with_them do
      context 'global search' do
        it 'shows the tab if FF is enabled' do
          stub_feature_flags(feature_flag => true)

          render

          expect(rendered).to have_selector('.search-filter li', text: tab_name)
        end

        it 'hides the tab if FF is disabled' do
          stub_feature_flags(feature_flag => false)

          render

          expect(rendered).not_to have_selector('.search-filter li', text: tab_name)
        end
      end

      context 'group search' do
        before do
          assign(:group, group)
        end

        it 'shows the tab even if FF is disabled for group search' do
          stub_feature_flags(feature_flag => false)

          render

          expect(rendered).to have_selector('.search-filter li', text: tab_name)
        end
      end
    end
  end
end
