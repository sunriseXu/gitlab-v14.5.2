# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Usage Quotas > Seat Usage', :js do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:user_from_sub_group) { create(:user) }
  let_it_be(:shared_group) { create(:group) }
  let_it_be(:shared_group_developer) { create(:user) }

  before do
    allow(Gitlab).to receive(:com?).and_return(true)
    stub_application_setting(check_namespace_plan: true)

    group.add_owner(user)
    group.add_maintainer(maintainer)

    sub_group.add_maintainer(user_from_sub_group)

    shared_group.add_developer(shared_group_developer)
    create(:group_group_link, { shared_with_group: shared_group, shared_group: group })

    sign_in(user)

    visit group_seat_usage_path(group)
    wait_for_requests
  end

  context 'seat usage table' do
    it 'displays correct number of users' do
      within '[data-testid="table"]' do
        expect(all('tbody tr').count).to eq(4)
      end
    end

    context 'seat usage details table' do
      it 'expands the details on click' do
        first('[data-testid="toggle-seat-usage-details"]').click

        wait_for_requests

        expect(page).to have_selector('[data-testid="seat-usage-details"]')
      end

      it 'hides the details table on click' do
        # expand the details table first
        first('[data-testid="toggle-seat-usage-details"]').click

        wait_for_requests

        # and collapse it
        first('[data-testid="toggle-seat-usage-details"]').click

        expect(page).not_to have_selector('[data-testid="seat-usage-details"]')
      end
    end
  end

  context 'when removing user' do
    let(:user_to_remove_row) do
      within '[data-testid="table"]' do
        find('tr', text: maintainer.name)
      end
    end

    context 'with a modal to confirm removal' do
      before do
        within user_to_remove_row do
          find('[data-testid="user-actions"]').click
          click_button 'Remove user'
        end
      end

      it 'has disabled the remove button' do
        within '[data-qa-selector="remove_billable_member_modal"]' do # rubocop:disable QA/SelectorUsage
          expect(page).to have_button('Remove user', disabled: true)
        end
      end

      it 'enables the remove button when user enters valid username' do
        within '[data-qa-selector="remove_billable_member_modal"]' do # rubocop:disable QA/SelectorUsage
          find('input').fill_in(with: maintainer.username)
          find('input').send_keys(:tab)

          expect(page).to have_button('Remove user', disabled: false)
        end
      end

      it 'does not enable button when user enters invalid username' do
        within '[data-qa-selector="remove_billable_member_modal"]' do # rubocop:disable QA/SelectorUsage
          find('input').fill_in(with: 'invalid username')
          find('input').send_keys(:tab)

          expect(page).to have_button('Remove user', disabled: true)
        end
      end

      it 'does not display the error modal' do
        expect(page).not_to have_content('Cannot remove user')
      end
    end

    context 'removing the user' do
      before do
        within user_to_remove_row do
          find('[data-testid="user-actions"]').click
          click_button 'Remove user'
        end
      end

      it 'shows a flash message' do
        within '[data-qa-selector="remove_billable_member_modal"]' do # rubocop:disable QA/SelectorUsage
          find('input').fill_in(with: maintainer.username)
          find('input').send_keys(:tab)

          click_button('Remove user')
        end

        wait_for_all_requests

        within '[data-testid="table"]' do
          expect(all('tbody tr').count).to eq(3)
        end

        expect(page.find('.flash-container')).to have_content('User was successfully removed')
      end

      context 'removing the user from a sub-group' do
        it 'updates the seat table of the parent group' do
          within '[data-testid="table"]' do
            expect(all('tbody tr').count).to eq(4)
          end

          visit group_group_members_path(sub_group)

          click_button('Remove member')

          within '[data-qa-selector="remove_member_modal_content"]' do # rubocop:disable QA/SelectorUsage
            click_button('Remove member')
          end

          wait_for_all_requests

          visit group_seat_usage_path(group)

          wait_for_all_requests

          within '[data-testid="table"]' do
            expect(all('tbody tr').count).to eq(3)
          end
        end
      end
    end

    context 'when cannot remove the user' do
      let(:shared_user_row) do
        within '[data-testid="table"]' do
          find('tr', text: shared_group_developer.name)
        end
      end

      it 'displays an error modal' do
        within shared_user_row do
          find('[data-testid="user-actions"]').click
          click_button 'Remove user'
        end

        expect(page).to have_content('Cannot remove user')
      end
    end
  end
end
