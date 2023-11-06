# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Welcome screen', :js do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  let(:params) { {} }

  describe 'on GitLab.com' do
    before do
      group.add_owner(user)
      gitlab_sign_in(user)
      stub_request(:get, "#{EE::SUBSCRIPTIONS_GITLAB_PLANS_URL}?plan=free&namespace_id=")
        .to_return(status: 200, body: '{}', headers: {})

      visit edit_subscriptions_group_path(group.path, params)
    end

    it 'shows the group edit page without a progress bar' do
      expect(page).to have_content('Create your group')
      expect(page).not_to have_content('Your profile')
    end

    context 'when showing for a new user' do
      let(:params) { { new_user: true } }

      it 'shows the progress bar with the correct steps' do
        expect(page).to have_content('Your profile Checkout Your GitLab group')
      end
    end
  end
end
