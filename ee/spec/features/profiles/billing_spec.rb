# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Profiles > Billing', :js do
  include StubRequests
  include SubscriptionPortalHelpers

  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:user) { create(:user, namespace: namespace) }
  let_it_be(:bronze_plan) { create(:bronze_plan) }

  def formatted_date(date)
    date.strftime("%B %-d, %Y")
  end

  def subscription_table
    '.subscription-table'
  end

  before do
    allow(Gitlab).to receive(:com?).and_return(true)
    stub_application_setting(check_namespace_plan: true)

    sign_in(user)
  end

  context 'when CustomersDot is available' do
    let(:plan) { 'free' }

    before do
      stub_billing_plans(user.namespace.id, plan)
    end

    context 'with a free plan' do
      let!(:subscription) do
        create(:gitlab_subscription, namespace: user.namespace, hosted_plan: nil)
      end

      it 'does not have search settings field' do
        visit profile_billings_path

        expect(page).not_to have_field(placeholder: SearchHelpers::INPUT_PLACEHOLDER)
      end
    end
  end
end
