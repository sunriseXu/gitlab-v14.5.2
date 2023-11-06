# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Groups do
  include GroupAPIHelpers

  let_it_be(:group, reload: true) { create(:group) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  before do
    group.add_owner(user)
    group.ldap_group_links.create! cn: 'ldap-group', group_access: Gitlab::Access::MAINTAINER, provider: 'ldap'
  end

  shared_examples 'inaccessable by reporter role and lower' do
    context 'for reporter' do
      before do
        reporter = create(:user)
        group.add_reporter(reporter)

        get api(path, reporter)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'for guest' do
      before do
        guest = create(:user)
        group.add_guest(guest)

        get api(path, guest)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'for anonymous' do
      before do
        anonymous = create(:user)

        get api(path, anonymous)
      end

      it 'returns 403 response' do
        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "GET /groups" do
    context "when authenticated as user" do
      it "returns ldap details" do
        get api("/groups", user)

        expect(json_response).to(
          satisfy_one { |group_json| group_json['ldap_cn'] == group.ldap_cn })
        expect(json_response).to(
          satisfy_one do |group_json|
            group_json['ldap_access'] == group.ldap_access
          end
        )

        expect(json_response).to(
          satisfy_one do |group_json|
            ldap_group_link = group_json['ldap_group_links'].first

            ldap_group_link['cn'] == group.ldap_cn &&
              ldap_group_link['group_access'] == group.ldap_access &&
              ldap_group_link['provider'] == 'ldap'
          end
        )
      end
    end
  end

  describe 'GET /groups/:id' do
    context 'group_ip_restriction' do
      before do
        create(:ip_restriction, group: private_group)
        private_group.add_maintainer(user)
      end

      context 'when the group_ip_restriction feature is not available' do
        before do
          stub_licensed_features(group_ip_restriction: false)
        end

        it 'returns 200' do
          get api("/groups/#{private_group.id}", user)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the group_ip_restriction feature is available' do
        before do
          stub_licensed_features(group_ip_restriction: true)
        end

        it 'returns 404 for request from ip not in the range' do
          get api("/groups/#{private_group.id}", user)

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns 200 for request from ip in the range' do
          get api("/groups/#{private_group.id}", user), headers: { 'REMOTE_ADDR' => '192.168.0.0' }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'marked_for_deletion_on attribute' do
      context 'when feature is available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
        end

        it 'is exposed' do
          get api("/groups/#{group.id}", user)

          expect(json_response).to have_key 'marked_for_deletion_on'
        end
      end

      context 'when feature is not available' do
        before do
          stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
        end

        it 'is not exposed' do
          get api("/groups/#{group.id}", user)

          expect(json_response).not_to have_key 'marked_for_deletion_on'
        end
      end
    end

    context 'file_template_project_id is a private project' do
      let_it_be(:private_project) { create(:project, :private, group: group) }

      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
        group.update_attribute(:file_template_project_id, private_project.id)
      end

      context 'user has permission to private project' do
        it 'returns file_template_project_id' do
          private_project.add_maintainer(user)

          get api("/groups/#{group.id}", user)

          expect(json_response).to have_key 'file_template_project_id'
        end
      end

      context 'user does not have permission to private project' do
        it 'does not return file_template_project_id' do
          get api("/groups/#{group.id}", another_user)

          expect(json_response).not_to have_key 'file_template_project_id'
        end
      end

      context 'user is not logged in' do
        it 'does not return file_template_project_id' do
          get api("/groups/#{group.id}")

          expect(json_response).not_to have_key 'file_template_project_id'
        end
      end
    end
  end

  describe 'PUT /groups/:id' do
    subject { put api("/groups/#{group.id}", user), params: params }

    context 'file_template_project_id' do
      let(:params) { { file_template_project_id: project.id } }

      it 'does not update file_template_project_id if unlicensed' do
        stub_licensed_features(custom_file_templates_for_namespace: false)

        expect { subject }.not_to change { group.reload.file_template_project_id }
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).not_to have_key('file_template_project_id')
      end

      it 'updates file_template_project_id if licensed' do
        stub_licensed_features(custom_file_templates_for_namespace: true)

        expect { subject }.to change { group.reload.file_template_project_id }.to(project.id)
        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['file_template_project_id']).to eq(project.id)
      end
    end

    context 'shared_runners_minutes_limit' do
      let(:params) { { shared_runners_minutes_limit: 133 } }

      context 'when authenticated as the group owner' do
        it 'returns 200 if shared_runners_minutes_limit is not changing' do
          group.update!(shared_runners_minutes_limit: 133)

          expect do
            put api("/groups/#{group.id}", user), params: { shared_runners_minutes_limit: 133 }
          end.not_to change { group.shared_runners_minutes_limit }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when authenticated as the admin' do
        let(:user) { create(:admin) }

        it 'updates the group for shared_runners_minutes_limit' do
          expect { subject }.to(
            change { group.reload.shared_runners_minutes_limit }.from(nil).to(133))

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['shared_runners_minutes_limit']).to eq(133)
        end
      end
    end

    context 'default_branch_protection' do
      using RSpec::Parameterized::TableSyntax

      let(:params) { { default_branch_protection: Gitlab::Access::PROTECTION_NONE } }

      context 'authenticated as an admin' do
        let(:user) { admin }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end

      context 'authenticated a normal user' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end
    end

    context 'prevent_forking_outside_group' do
      using RSpec::Parameterized::TableSyntax

      context 'authenticated as group owner' do
        where(:feature_enabled, :prevent_forking_outside_group, :result) do
          false | false | nil
          false | true  | nil
          true  | false | false
          true  | true  | true
        end

        with_them do
          let(:params) { { prevent_forking_outside_group: prevent_forking_outside_group } }

          before do
            group.add_owner(user)

            stub_licensed_features(group_forking_protection: feature_enabled)
          end

          it 'updates the attribute as expected' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['prevent_forking_outside_group']).to eq(result)
          end
        end
      end
    end
  end

  describe "POST /groups" do
    context "when authenticated as user with group permissions" do
      it "creates an ldap_group_link if ldap_cn and ldap_access are supplied" do
        group_attributes = attributes_for_group_api ldap_cn: 'ldap-group', ldap_access: Gitlab::Access::DEVELOPER
        expect { post api("/groups", admin), params: group_attributes }.to change { LdapGroupLink.count }.by(1)
      end

      context 'when shared_runners_minutes_limit is given' do
        context 'when the current user is not an admin' do
          it "does not create a group with shared_runners_minutes_limit" do
            group = attributes_for_group_api shared_runners_minutes_limit: 133

            expect do
              post api("/groups", another_user), params: group
            end.not_to change { Group.count }

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context 'when the current user is an admin' do
          it "creates a group with shared_runners_minutes_limit" do
            group = attributes_for_group_api shared_runners_minutes_limit: 133

            expect do
              post api("/groups", admin), params: group
            end.to change { Group.count }.by(1)

            created_group = Group.find(json_response['id'])

            expect(created_group.shared_runners_minutes_limit).to eq(133)
            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['shared_runners_minutes_limit']).to eq(133)
          end
        end
      end
    end

    context 'when creating a group with `default_branch_protection` attribute' do
      using RSpec::Parameterized::TableSyntax

      let(:params) { attributes_for_group_api(default_branch_protection: Gitlab::Access::PROTECTION_NONE) }

      subject do
        post api("/groups", user), params: params
      end

      context 'authenticated as an admin' do
        let(:user) { admin }

        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_NONE
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'creates the group with the expected `default_branch_protection` value' do
            subject

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end

      context 'authenticated a normal user' do
        where(:feature_enabled, :setting_enabled, :default_branch_protection) do
          true  | true  | Gitlab::Access::PROTECTION_NONE
          false | true  | Gitlab::Access::PROTECTION_NONE
          true  | false | Gitlab::Access::PROTECTION_FULL
          false | false | Gitlab::Access::PROTECTION_NONE
        end

        with_them do
          before do
            stub_licensed_features(default_branch_protection_restriction_in_groups: feature_enabled)
            stub_ee_application_setting(group_owners_can_manage_default_branch_protection: setting_enabled)
          end

          it 'creates the group with the expected `default_branch_protection` value' do
            subject

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['default_branch_protection']).to eq(default_branch_protection)
          end
        end
      end
    end

    context 'when creating group on .com' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(true)
      end

      context 'when top_level_group_creation_enabled feature flag is disabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: false)
        end

        it 'does not create a top-level group' do
          group = attributes_for_group_api

          expect do
            post api("/groups", admin), params: group
          end.not_to change { Group.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end

        it 'creates a subgroup' do
          parent = create(:group)
          parent.add_owner(admin)

          expect do
            post api("/groups", admin), params: { parent_id: parent.id, name: 'foo', path: 'foo' }
          end.to change { Group.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when top_level_group_creation_enabled feature flag is enabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: true)
        end

        it 'creates a top-level group' do
          group = attributes_for_group_api

          expect do
            post api("/groups", admin), params: group
          end.to change { Group.count }

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end

    context 'when creating group on self-managed' do
      context 'when top_level_group_creation_enabled feature flag is disabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: false)
        end

        it 'creates a top-level group' do
          group = attributes_for_group_api

          expect do
            post api("/groups", admin), params: group
          end.to change { Group.count }

          expect(response).to have_gitlab_http_status(:created)
        end

        it 'creates a subgroup' do
          parent = create(:group)
          parent.add_owner(admin)

          expect do
            post api("/groups", admin), params: { parent_id: parent.id, name: 'foo', path: 'foo' }
          end.to change { Group.count }.by(1)

          expect(response).to have_gitlab_http_status(:created)
        end
      end

      context 'when top_level_group_creation_enabled feature flag is enabled' do
        before do
          stub_feature_flags(top_level_group_creation_enabled: true)
        end

        it 'creates a top-level group' do
          group = attributes_for_group_api

          expect do
            post api("/groups", admin), params: group
          end.to change { Group.count }

          expect(response).to have_gitlab_http_status(:created)
        end
      end
    end
  end

  describe 'POST /groups/:id/ldap_sync' do
    before do
      allow(Gitlab::Auth::Ldap::Config).to receive(:enabled?).and_return(true)
    end

    context 'when the ldap_group_sync feature is available' do
      before do
        stub_licensed_features(ldap_group_sync: true)
      end

      context 'when authenticated as the group owner' do
        context 'when the group is ready to sync' do
          it 'returns 202 Accepted' do
            ldap_sync(group.id, user, :disable!)
            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'queues a sync job' do
            expect { ldap_sync(group.id, user, :fake!) }.to change(LdapGroupSyncWorker.jobs, :size).by(1)
          end

          it 'sets the ldap_sync state to pending' do
            ldap_sync(group.id, user, :disable!)
            expect(group.reload.ldap_sync_pending?).to be_truthy
          end
        end

        context 'when the group is already pending a sync' do
          before do
            group.pending_ldap_sync!
          end

          it 'returns 202 Accepted' do
            ldap_sync(group.id, user, :disable!)
            expect(response).to have_gitlab_http_status(:accepted)
          end

          it 'does not queue a sync job' do
            expect { ldap_sync(group.id, user, :fake!) }.not_to change(LdapGroupSyncWorker.jobs, :size)
          end

          it 'does not change the ldap_sync state' do
            expect do
              ldap_sync(group.id, user, :disable!)
            end.not_to change { group.reload.ldap_sync_status }
          end
        end

        it 'returns 404 for a non existing group' do
          ldap_sync(non_existing_record_id, user, :disable!)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when authenticated as the admin' do
        it 'returns 202 Accepted' do
          ldap_sync(group.id, admin, :disable!)
          expect(response).to have_gitlab_http_status(:accepted)
        end
      end

      context 'when authenticated as a non-owner user that can see the group' do
        it 'returns 403' do
          ldap_sync(group.id, another_user, :disable!)
          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an user that cannot see the group' do
        it 'returns 404' do
          ldap_sync(private_group.id, user, :disable!)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when the ldap_group_sync feature is not available' do
      before do
        stub_licensed_features(ldap_group_sync: false)
      end

      it 'returns 404 (same as CE would)' do
        ldap_sync(group.id, admin, :disable!)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe "GET /groups/:id/projects" do
    context "when authenticated as user" do
      let!(:project_with_security_scans) { create(:project, :with_security_scans, :public, group: group) }
      let!(:project_without_security_scans) { create(:project, :public, group: group) }

      subject { get api("/groups/#{group.id}/projects", user), params: { with_security_reports: true } }

      context 'when security dashboard is enabled for a group', :saas do
        let(:group) { create(:group_with_plan, plan: :ultimate_plan) } # overriding group from parent context

        before do
          stub_licensed_features(security_dashboard: true)
          enable_namespace_license_check!
        end

        it "returns only projects with security scans" do
          subject

          expect(json_response.map { |p| p['id'] }).to contain_exactly(project_with_security_scans.id)
        end
      end

      context 'when security dashboard is disabled for a group' do
        it "returns all projects regardless of the security scans" do
          subject

          # using `include` since other projects may be added to this group from different contexts
          expect(json_response.map { |p| p['id'] }).to include(project_with_security_scans.id, project_without_security_scans.id)
        end
      end
    end
  end

  describe 'GET group/:id/audit_events' do
    let(:path) { "/groups/#{group.id}/audit_events" }

    it_behaves_like 'inaccessable by reporter role and lower'

    context 'when authenticated, as a member' do
      before do
        stub_licensed_features(audit_events: true)
        group.add_developer(user)
      end

      it 'returns only events authored by current user' do
        group_audit_event = create(:group_audit_event, entity_id: group.id, author_id: user.id)
        create(:group_audit_event, entity_id: group.id, author_id: another_user.id)

        get api(path, user)

        expect_response_contain_exactly(group_audit_event.id)
      end
    end

    context 'when authenticated, as a group owner' do
      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        let_it_be(:group_audit_event_1) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: group.id) }
        let_it_be(:group_audit_event_2) { create(:group_audit_event, created_at: Date.new(2000, 1, 15), entity_id: group.id) }
        let_it_be(:group_audit_event_3) { create(:group_audit_event, created_at: Date.new(2000, 1, 20), entity_id: group.id) }

        before do
          stub_licensed_features(audit_events: true)
        end

        it 'returns 200 response' do
          get api(path, user)

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'includes the correct pagination headers' do
          audit_events_counts = 3

          get api(path, user)

          expect(response).to include_pagination_headers
          expect(response.headers['X-Total']).to eq(audit_events_counts.to_s)
          expect(response.headers['X-Page']).to eq('1')
        end

        it 'does not include audit events of a different group' do
          group = create(:group)
          audit_event = create(:group_audit_event, created_at: Date.new(2000, 1, 20), entity_id: group.id)

          get api(path, user)

          audit_event_ids = json_response.map { |audit_event| audit_event['id'] }

          expect(audit_event_ids).not_to include(audit_event.id)
        end

        context 'parameters' do
          context 'created_before parameter' do
            it "returns audit events created before the given parameter" do
              created_before = '2000-01-20T00:00:00.060Z'

              get api(path, user), params: { created_before: created_before }

              expect(json_response.size).to eq 3
              expect(json_response.first["id"]).to eq(group_audit_event_3.id)
              expect(json_response.last["id"]).to eq(group_audit_event_1.id)
            end
          end

          context 'created_after parameter' do
            it "returns audit events created after the given parameter" do
              created_after = '2000-01-12T00:00:00.060Z'

              get api(path, user), params: { created_after: created_after }

              expect(json_response.size).to eq 2
              expect(json_response.first["id"]).to eq(group_audit_event_3.id)
              expect(json_response.last["id"]).to eq(group_audit_event_2.id)
            end
          end
        end

        context 'response schema' do
          it 'matches the response schema' do
            get api(path, user)

            expect(response).to match_response_schema('public_api/v4/audit_events', dir: 'ee')
          end
        end
      end
    end
  end

  describe 'GET group/:id/audit_events/:audit_event_id' do
    let(:path) { "/groups/#{group.id}/audit_events/#{group_audit_event.id}" }

    let_it_be(:group_audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: group.id) }

    it_behaves_like 'inaccessable by reporter role and lower'

    context 'when authenticated, as a member' do
      let_it_be(:developer) { create(:user) }

      before do
        stub_licensed_features(audit_events: true)
        group.add_developer(developer)
      end

      it 'returns 200 response' do
        audit_event = create(:group_audit_event, entity_id: group.id, author_id: developer.id)
        path = "/groups/#{group.id}/audit_events/#{audit_event.id}"

        get api(path, developer)

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'existing audit event of a different user' do
        let_it_be(:audit_event) { create(:group_audit_event, entity_id: group.id, author_id: another_user.id) }

        let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

        it_behaves_like '404 response' do
          let(:request) { get api(path, developer) }
        end
      end
    end

    context 'when authenticated, as a group owner' do
      context 'audit events feature is not available' do
        before do
          stub_licensed_features(audit_events: false)
        end

        it_behaves_like '403 response' do
          let(:request) { get api(path, user) }
        end
      end

      context 'audit events feature is available' do
        before do
          stub_licensed_features(audit_events: true)
        end

        context 'existent audit event' do
          it 'returns 200 response' do
            get api(path, user)

            expect(response).to have_gitlab_http_status(:ok)
          end

          context 'response schema' do
            it 'matches the response schema' do
              get api(path, user)

              expect(response).to match_response_schema('public_api/v4/audit_event', dir: 'ee')
            end
          end

          context 'invalid audit_event_id' do
            let(:path) { "/groups/#{group.id}/audit_events/an-invalid-id" }

            it_behaves_like '400 response' do
              let(:request) { get api(path, user) }
            end
          end

          context 'non existent audit event' do
            context 'non existent audit event of a group' do
              let(:path) { "/groups/#{group.id}/audit_events/666777" }

              it_behaves_like '404 response' do
                let(:request) { get api(path, user) }
              end
            end

            context 'existing audit event of a different group' do
              let(:new_group) { create(:group) }
              let(:audit_event) { create(:group_audit_event, created_at: Date.new(2000, 1, 10), entity_id: new_group.id) }

              let(:path) { "/groups/#{group.id}/audit_events/#{audit_event.id}" }

              it_behaves_like '404 response' do
                let(:request) { get api(path, user) }
              end
            end
          end
        end
      end
    end
  end

  describe "DELETE /groups/:id" do
    subject { delete api("/groups/#{group.id}", user) }

    shared_examples_for 'immediately enqueues the job to delete the group' do
      specify do
        Sidekiq::Testing.fake! do
          expect { subject }.to change(GroupDestroyWorker.jobs, :size).by(1)
        end

        expect(response).to have_gitlab_http_status(:accepted)
      end
    end

    context 'feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      context 'period for delayed deletion is greater than 0' do
        before do
          stub_application_setting(deletion_adjourned_period: 1)
        end

        context 'success' do
          it 'marks the group for delayed deletion' do
            subject
            group.reload

            expect(response).to have_gitlab_http_status(:accepted)
            expect(group.marked_for_deletion_on).to eq(Date.today)
            expect(group.deleting_user).to eq(user)
          end

          it 'does not immediately enqueue the job to delete the group' do
            expect { subject }.not_to change(GroupDestroyWorker.jobs, :size)
          end
        end

        context 'failure' do
          before do
            allow(::Groups::MarkForDeletionService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: 'error' })
          end

          it 'returns error' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('error')
          end
        end

        it 'does not mark the group for deletion when the group has a paid gitlab.com subscription', :saas do
          create(:gitlab_subscription, :ultimate, namespace: group)

          subject

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq("This group can't be removed because it is linked to a subscription.")
          expect(group.marked_for_deletion_on).to be_nil
          expect(group.deleting_user).to be_nil
        end

        it 'marks for deletion a subgroup of a group with a paid gitlab.com subscription', :saas do
          create(:gitlab_subscription, :ultimate, namespace: group)
          subgroup = create(:group, parent: group)

          delete api("/groups/#{subgroup.id}", user)

          expect(response).to have_gitlab_http_status(:accepted)
          expect(subgroup.marked_for_deletion_on).to eq(Date.today)
          expect(subgroup.deleting_user).to eq(user)
        end
      end

      context 'period of delayed deletion is set to 0' do
        before do
          stub_application_setting(deletion_adjourned_period: 0)
        end

        it_behaves_like 'immediately enqueues the job to delete the group'
      end
    end

    context 'feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it_behaves_like 'immediately enqueues the job to delete the group'

      it 'does not delete the group when the group has a paid gitlab.com subscription', :saas do
        create(:gitlab_subscription, :ultimate, namespace: group)

        expect { subject }.not_to change(GroupDestroyWorker.jobs, :size)
        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to eq("This group can't be removed because it is linked to a subscription.")
      end

      it 'deletes a subgroup of a group with a paid gitlab.com subscription', :saas do
        create(:gitlab_subscription, :ultimate, namespace: group)
        subgroup = create(:group, parent: group)

        expect { delete api("/groups/#{subgroup.id}", user) }.to change(GroupDestroyWorker.jobs, :size).by(1)
        expect(response).to have_gitlab_http_status(:accepted)
      end
    end
  end

  describe "POST /groups/:id/restore" do
    let(:group) do
      create(:group_with_deletion_schedule,
      marked_for_deletion_on: 1.day.ago,
      deleting_user: user)
    end

    subject { post api("/groups/#{group.id}/restore", user) }

    context 'feature is available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      end

      context 'authenticated as owner' do
        context 'restoring is successful' do
          it 'restores the group to original state' do
            subject

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['marked_for_deletion_on']).to be_falsey
          end
        end

        context 'restoring fails' do
          before do
            allow(::Groups::RestoreService).to receive_message_chain(:new, :execute).and_return({ status: :error, message: 'error' })
          end

          it 'returns error' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq('error')
          end
        end
      end

      context 'authenticated as user without access to the group' do
        subject { post api("/groups/#{group.id}/restore", another_user) }

        it 'returns 403' do
          subject

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end

    context 'feature is not available' do
      before do
        stub_licensed_features(adjourned_deletion_for_projects_and_groups: false)
      end

      it 'returns 404' do
        subject

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  def ldap_sync(group_id, user, sidekiq_testing_method)
    Sidekiq::Testing.send(sidekiq_testing_method) do
      post api("/groups/#{group_id}/ldap_sync", user)
    end
  end
end
