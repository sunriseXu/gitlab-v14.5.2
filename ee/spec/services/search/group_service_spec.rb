# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::GroupService do
  include SearchResultHelpers
  include ProjectHelpers
  using RSpec::Parameterized::TableSyntax

  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  it_behaves_like 'EE search service shared examples', ::Gitlab::GroupSearchResults, ::Gitlab::Elastic::GroupSearchResults do
    let(:scope) { create(:group) }
    let(:service) { described_class.new(user, scope, params) }
  end

  describe 'group search' do
    let(:term) { "RandomName" }
    let(:nested_group) { create(:group, :nested) }

    # These projects shouldn't be found
    let(:outside_project) { create(:project, :public, name: "Outside #{term}") }
    let(:private_project) { create(:project, :private, namespace: nested_group, name: "Private #{term}" )}
    let(:other_project)   { create(:project, :public, namespace: nested_group, name: 'OtherProject') }

    # These projects should be found
    let(:project1) { create(:project, :internal, namespace: nested_group, name: "Inner #{term} 1") }
    let(:project2) { create(:project, :internal, namespace: nested_group, name: "Inner #{term} 2") }
    let(:project3) { create(:project, :internal, namespace: nested_group.parent, name: "Outer #{term}") }

    let(:results) { described_class.new(user, search_group, search: term).execute }

    before do
      stub_ee_application_setting(
        elasticsearch_search: true,
        elasticsearch_indexing: true
      )

      # Ensure these are present when the index is refreshed
      _ = [
        outside_project, private_project, other_project,
        project1, project2, project3
      ]

      ensure_elasticsearch_index!
    end

    context 'finding projects by name', :elastic, :clean_gitlab_redis_shared_state, :sidekiq_might_not_need_inline do
      subject { results.objects('projects') }

      context 'in parent group' do
        let(:search_group) { nested_group.parent }

        it { is_expected.to match_array([project1, project2, project3]) }
      end

      context 'in subgroup' do
        let(:search_group) { nested_group }

        it { is_expected.to match_array([project1, project2]) }
      end
    end
  end

  context 'visibility', :elastic_delete_by_query, :clean_gitlab_redis_shared_state, :sidekiq_inline do
    include_context 'ProjectPolicyTable context'

    shared_examples 'search respects visibility' do
      it 'respects visibility' do
        enable_admin_mode!(user) if admin_mode
        projects.each do |project|
          update_feature_access_level(project, feature_access_level)
        end
        ensure_elasticsearch_index!

        expect_search_results(user, scope, expected_count: expected_count) do |user|
          described_class.new(user, group, search: search).execute
        end
      end
    end

    let_it_be(:group) { create(:group) }

    let!(:project) { create(:project, project_level, namespace: group) }
    let!(:project2) { create(:project, project_level) }
    let(:user) { create_user_from_membership(project, membership) }
    let(:projects) { [project, project2] }

    context 'merge request' do
      let!(:merge_request) { create :merge_request, target_project: project, source_project: project }
      let!(:merge_request2) { create :merge_request, target_project: project2, source_project: project2, title: merge_request.title }
      let(:scope) { 'merge_requests' }
      let(:search) { merge_request.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_reporter_feature_access
      end

      with_them do
        it_behaves_like 'search respects visibility'
      end
    end

    context 'blob and commit' do
      let!(:project) { create(:project, project_level, :repository, namespace: group ) }
      let!(:project2) { create(:project, project_level, :repository) }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access_and_non_private_project_only
      end

      with_them do
        before do
          project.repository.index_commits_and_blobs
          project2.repository.index_commits_and_blobs
        end

        it_behaves_like 'search respects visibility' do
          let(:scope) { 'commits' }
          let(:search) { 'initial' }
        end

        it_behaves_like 'search respects visibility' do
          let(:scope) { 'blobs' }
          let(:search) { '.gitmodules' }
        end
      end
    end

    context 'note' do
      let(:scope) { 'notes' }
      let(:search) { note.note }

      context 'on issues' do
        let!(:note) { create :note_on_issue, project: project }
        let!(:note2) { create :note_on_issue, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'on merge requests' do
        let!(:note) { create :note_on_merge_request, project: project }
        let!(:note2) { create :note_on_merge_request, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_reporter_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'on commits' do
        let!(:project) { create(:project, project_level, :repository, namespace: group ) }
        let!(:project2) { create(:project, project_level, :repository) }
        let!(:note) { create :note_on_commit, project: project }
        let!(:note2) { create :note_on_commit, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access_and_non_private_project_only
        end

        with_them do
          before do
            project.repository.index_commits_and_blobs
            project2.repository.index_commits_and_blobs
          end

          it_behaves_like 'search respects visibility'
        end
      end

      context 'on snippets' do
        let!(:note) { create :note_on_project_snippet, project: project }
        let!(:note2) { create :note_on_project_snippet, project: project2, note: note.note }

        where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
          permission_table_for_guest_feature_access
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end
    end

    context 'issue' do
      let!(:issue) { create :issue, project: project }
      let!(:issue2) { create :issue, project: project2, title: issue.title }
      let(:scope) { 'issues' }
      let(:search) { issue.title }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      context 'elasticsearch_use_group_level_optimization is enabled' do
        before do
          stub_feature_flags(elasticsearch_use_group_level_optimization: true)
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end

      context 'elasticsearch_use_group_level_optimization is disabled' do
        before do
          stub_feature_flags(elasticsearch_use_group_level_optimization: false)
        end

        with_them do
          it_behaves_like 'search respects visibility'
        end
      end
    end

    context 'wiki' do
      let!(:project) { create(:project, project_level, :wiki_repo) }
      let(:group) { project.namespace }
      let(:projects) { [project] }
      let(:scope) { 'wiki_blobs' }
      let(:search) { 'term' }

      where(:project_level, :feature_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_guest_feature_access
      end

      with_them do
        before do
          project.wiki.create_page('test.md', "# term")
          project.wiki.index_wiki_blobs
        end

        it_behaves_like 'search respects visibility'
      end
    end

    context 'milestone' do
      let!(:milestone) { create :milestone, project: project }

      where(:project_level, :issues_access_level, :merge_requests_access_level, :membership, :admin_mode, :expected_count) do
        permission_table_for_milestone_access
      end

      with_them do
        it "respects visibility" do
          enable_admin_mode!(user) if admin_mode
          project.update!(
            'issues_access_level' => issues_access_level,
            'merge_requests_access_level' => merge_requests_access_level
          )
          ensure_elasticsearch_index!

          expect_search_results(user, 'milestones', expected_count: expected_count) do |user|
            described_class.new(user, group, search: milestone.title).execute
          end
        end
      end
    end

    context 'project' do
      let(:project) { create(:project, project_level, namespace: group) }

      where(:project_level, :membership, :expected_count) do
        permission_table_for_project_access
      end

      with_them do
        it "respects visibility" do
          ElasticCommitIndexerWorker.new.perform(project.id)
          ensure_elasticsearch_index!

          expected_objects = expected_count == 1 ? [project] : []

          expect_search_results(
            user,
            'projects',
            expected_count: expected_count,
            expected_objects: expected_objects
          ) do |user|
            described_class.new(user, group, search: project.name).execute
          end
        end
      end
    end
  end

  context 'sorting', :elastic, :clean_gitlab_redis_shared_state do
    context 'issues' do
      let(:scope) { 'issues' }
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :public, group: group) }

      let!(:old_result) { create(:issue, project: project, title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:issue, project: project, title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:issue, project: project, title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:issue, project: project, title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:issue, project: project, title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:issue, project: project, title: 'updated very old', updated_at: 1.year.ago) }

      let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
      let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }

      before do
        ensure_elasticsearch_index!
      end

      context 'elasticsearch_use_group_level_optimization is enabled' do
        before do
          stub_feature_flags(elasticsearch_use_group_level_optimization: true)
        end

        include_examples 'search results sorted'
      end

      context 'elasticsearch_use_group_level_optimization is disabled' do
        before do
          stub_feature_flags(elasticsearch_use_group_level_optimization: false)
        end

        include_examples 'search results sorted'
      end
    end

    context 'merge requests' do
      let(:scope) { 'merge_requests' }
      let!(:project) { create(:project, :public, group: group) }

      let!(:old_result) { create(:merge_request, :opened, source_project: project, source_branch: 'old-1', title: 'sorted old', created_at: 1.month.ago) }
      let!(:new_result) { create(:merge_request, :opened, source_project: project, source_branch: 'new-1', title: 'sorted recent', created_at: 1.day.ago) }
      let!(:very_old_result) { create(:merge_request, :opened, source_project: project, source_branch: 'very-old-1', title: 'sorted very old', created_at: 1.year.ago) }

      let!(:old_updated) { create(:merge_request, :opened, source_project: project, source_branch: 'updated-old-1', title: 'updated old', updated_at: 1.month.ago) }
      let!(:new_updated) { create(:merge_request, :opened, source_project: project, source_branch: 'updated-new-1', title: 'updated recent', updated_at: 1.day.ago) }
      let!(:very_old_updated) { create(:merge_request, :opened, source_project: project, source_branch: 'updated-very-old-1', title: 'updated very old', updated_at: 1.year.ago) }

      before do
        ensure_elasticsearch_index!
      end

      include_examples 'search results sorted' do
        let(:results_created) { described_class.new(nil, group, search: 'sorted', sort: sort).execute }
        let(:results_updated) { described_class.new(nil, group, search: 'updated', sort: sort).execute }
      end
    end
  end

  describe '#allowed_scopes' do
    context 'epics scope' do
      let(:allowed_scopes) { described_class.new(user, group, {}).allowed_scopes }

      before do
        stub_licensed_features(epics: epics_available)
      end

      context 'epics available' do
        let(:epics_available) { true }

        it 'does include epics to allowed_scopes' do
          expect(allowed_scopes).to include('epics')
        end
      end

      context 'epics is no available' do
        let(:epics_available) { false }

        it 'does not include epics to allowed_scopes' do
          expect(allowed_scopes).not_to include('epics')
        end
      end
    end
  end
end
