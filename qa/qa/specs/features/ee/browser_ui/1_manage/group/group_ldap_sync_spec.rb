# frozen_string_literal: true

module QA
  RSpec.describe 'Manage', :orchestrated, :ldap_tls, :ldap_no_tls, :requires_admin do
    describe 'LDAP Group sync' do
      include Support::API

      let(:root_group) do
        Resource::Sandbox.fabricate_via_api! do |resource|
          resource.path = "group_sync_root_group-#{SecureRandom.hex(4)}"
        end
      end

      let(:group) do
        Resource::Group.fabricate_via_api! do |resource|
          resource.sandbox = root_group
          resource.path = "#{group_name}-#{SecureRandom.hex(4)}"
        end
      end

      after do |example|
        # If a test fails leave the groups so we can investigate them
        unless example.exception
          root_group.remove_via_api!
        end
      end

      context 'using group cn method' do
        let(:ldap_users) do
          [
            {
              name: 'ENG User 1',
              username: 'enguser1',
              email: 'enguser1@example.org',
              provider: 'ldapmain',
              extern_uid: 'uid=enguser1,ou=people,ou=global groups,dc=example,dc=org'
            },
            {
              name: 'ENG User 2',
              username: 'enguser2',
              email: 'enguser2@example.org',
              provider: 'ldapmain',
              extern_uid: 'uid=enguser2,ou=people,ou=global groups,dc=example,dc=org'
            },
            {
              name: 'ENG User 3',
              username: 'enguser3',
              email: 'enguser3@example.org',
              provider: 'ldapmain',
              extern_uid: 'uid=enguser3,ou=people,ou=global groups,dc=example,dc=org'
            }
          ]
        end

        let(:owner_user) { 'enguser1' }
        let(:sync_users) { ['ENG User 2', 'ENG User 3'] }

        let(:group_name) { 'Synched-engineering-group' }

        before do
          created_users = create_users_via_api(ldap_users)

          group.add_member(created_users[owner_user], Resource::Members::AccessLevel::OWNER)

          signin_as_user(owner_user)

          group.visit!

          Page::Group::Menu.perform(&:go_to_ldap_sync_settings)

          EE::Page::Group::Settings::LDAPSync.perform do |settings|
            settings.set_ldap_group_sync_method
            settings.set_group_cn('Engineering')
            settings.click_add_sync_button
          end

          Page::Group::Menu.perform(&:click_subgroup_members_item)
        end

        it 'has LDAP users synced', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1454' do
          verify_users_synced(sync_users)
        end
      end

      context 'user filter method' do
        let(:ldap_users) do
          [
            {
              name: 'HR User 1',
              username: 'hruser1',
              email: 'hruser1@example.org',
              provider: 'ldapmain',
              extern_uid: 'uid=hruser1,ou=people,ou=global groups,dc=example,dc=org'
            },
            {
              name: 'HR User 2',
              username: 'hruser2',
              email: 'hruser2@example.org',
              provider: 'ldapmain',
              extern_uid: 'uid=hruser2,ou=people,ou=global groups,dc=example,dc=org'
            },
            {
              name: 'HR User 3',
              username: 'hruser3',
              email: 'hruser3@example.org',
              provider: 'ldapmain',
              extern_uid: 'uid=hruser3,ou=people,ou=global groups,dc=example,dc=org'
            }
          ]
        end

        let(:owner_user) { 'hruser1' }
        let(:sync_users) { ['HR User 2', 'HR User 3'] }

        let(:group_name) { 'Synched-human-resources-group' }

        before do
          created_users = create_users_via_api(ldap_users)

          group.add_member(created_users[owner_user], Resource::Members::AccessLevel::OWNER)

          signin_as_user(owner_user)

          group.visit!

          Page::Group::Menu.perform(&:go_to_ldap_sync_settings)

          EE::Page::Group::Settings::LDAPSync.perform do |settings|
            settings.set_user_filter('(&(objectClass=person)(cn=HR*))')
            settings.click_add_sync_button
          end

          Page::Group::Menu.perform(&:click_subgroup_members_item)
        end

        it 'has LDAP users synced', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/quality/test_cases/1455' do
          verify_users_synced(sync_users)
        end
      end

      def create_users_via_api(users)
        created_users = {}

        users.each do |user|
          created_users[user[:username]] = Resource::User.fabricate_via_api! do |resource|
            resource.username = user[:username]
            resource.name = user[:name]
            resource.email = user[:email]
            resource.extern_uid = user[:extern_uid]
            resource.provider = user[:provider]
            resource.api_client = Runtime::API::Client.as_admin
          end
        end
        created_users
      end

      def create_group_and_add_user_via_api(user_name, group_name, role)
        group = Resource::Group.fabricate_via_api! do |resource|
          resource.path = "#{group_name}-#{SecureRandom.hex(4)}"
        end

        group.add_member(@created_users[user_name], role)

        group
      end

      def signin_as_user(user_name)
        user = Struct.new(:ldap_username, :ldap_password).new(user_name, 'password')

        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform do |login_page|
          login_page.sign_in_using_ldap_credentials(user: user)
        end
      end

      def verify_users_synced(expected_users)
        EE::Page::Group::Members.perform do |members|
          members.click_sync_now

          users_synchronised = members.retry_until(reload: true) do
            expected_users.map { |user| members.has_content?(user) }.all?
          end

          expect(users_synchronised).to be_truthy
        end
      end
    end
  end
end
