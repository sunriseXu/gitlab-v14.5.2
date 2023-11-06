# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Edit group settings', :js do
  include Select2Helper

  let(:user) { create(:user) }
  let(:group) { create(:group, path: 'foo') }

  before do
    group.add_owner(user)
    sign_in(user)
  end

  context 'LDAP sync method' do
    before do
      allow(Gitlab.config.ldap).to receive(:enabled).and_return(true)
    end

    context 'when the LDAP group sync filter feature is available' do
      before do
        stub_licensed_features(ldap_group_sync_filter: true)

        visit group_ldap_group_links_path(group)
      end

      it 'adds new LDAP synchronization', :js do
        page.within('form#new_ldap_group_link') do
          choose('sync_method_group')

          select2 'my-group-cn', from: '#ldap_group_link_cn'
          select 'Developer', from: 'ldap_group_link_group_access'

          click_button 'Add synchronization'
        end

        expect(page).not_to have_content('No LDAP synchronizations')
        expect(page).to have_content('As Developer on ldap server')
      end

      it 'shows the LDAP filter section' do
        choose('sync_method_filter')

        expect(page).to have_content('This query must use valid LDAP Search Filter Syntax')
        expect(page).not_to have_content("Synchronize #{group.name}'s members with this LDAP group")
      end

      it 'shows the LDAP group section' do
        choose('sync_method_group')

        expect(page).to have_content("Synchronize #{group.name}'s members with this LDAP group")
        expect(page).not_to have_content('This query must use valid LDAP Search Filter Syntax')
      end
    end

    context 'when the LDAP group sync filter feature is not available' do
      before do
        stub_licensed_features(ldap_group_sync_filter: false)

        visit group_ldap_group_links_path(group)
      end

      it 'does not show the LDAP search method switcher' do
        expect(page).not_to have_field('sync_method_filter')
      end

      it 'shows the LDAP group section' do
        expect(page).to have_content("Synchronize #{group.name}'s members with this LDAP group")
      end

      it 'does not shows the LDAP filter section' do
        expect(page).not_to have_content('This query must use valid LDAP Search Filter Syntax')
      end
    end
  end
end
