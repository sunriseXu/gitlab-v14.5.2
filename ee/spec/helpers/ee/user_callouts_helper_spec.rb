# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::UserCalloutsHelper do
  include Devise::Test::ControllerHelpers
  using RSpec::Parameterized::TableSyntax

  describe '.render_enable_hashed_storage_warning' do
    context 'when we should show the enable warning' do
      it 'renders the enable warning' do
        expect(helper).to receive(:show_enable_hashed_storage_warning?).and_return(true)

        expect(helper).to receive(:render_flash_user_callout)
          .with(:warning,
            /Please enable and migrate to hashed/,
            EE::UserCalloutsHelper::GEO_ENABLE_HASHED_STORAGE)

        helper.render_enable_hashed_storage_warning
      end
    end

    context 'when we should not show the enable warning' do
      it 'does not render the enable warning' do
        expect(helper).to receive(:show_enable_hashed_storage_warning?).and_return(false)

        expect(helper).not_to receive(:render_flash_user_callout)

        helper.render_enable_hashed_storage_warning
      end
    end
  end

  describe '.render_migrate_hashed_storage_warning' do
    context 'when we should show the migrate warning' do
      it 'renders the migrate warning' do
        expect(helper).to receive(:show_migrate_hashed_storage_warning?).and_return(true)

        expect(helper).to receive(:render_flash_user_callout)
          .with(:warning,
            /Please migrate all existing projects/,
            EE::UserCalloutsHelper::GEO_MIGRATE_HASHED_STORAGE)

        helper.render_migrate_hashed_storage_warning
      end
    end

    context 'when we should not show the migrate warning' do
      it 'does not render the migrate warning' do
        expect(helper).to receive(:show_migrate_hashed_storage_warning?).and_return(false)

        expect(helper).not_to receive(:render_flash_user_callout)

        helper.render_migrate_hashed_storage_warning
      end
    end
  end

  describe '.show_enable_hashed_storage_warning?' do
    subject { helper.show_enable_hashed_storage_warning? }

    let(:user) { create(:user) }

    context 'when hashed storage is disabled' do
      before do
        stub_application_setting(hashed_storage_enabled: false)
        allow(helper).to receive(:current_user).and_return(user)
      end

      context 'when the enable warning has not been dismissed' do
        it { is_expected.to be_truthy }
      end

      context 'when the enable warning was dismissed' do
        before do
          create(:user_callout, user: user, feature_name: described_class::GEO_ENABLE_HASHED_STORAGE)
        end

        it { is_expected.to be_falsy }
      end
    end

    context 'when hashed storage is enabled' do
      before do
        stub_application_setting(hashed_storage_enabled: true)
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '.show_migrate_hashed_storage_warning?' do
    subject { helper.show_migrate_hashed_storage_warning? }

    let(:user) { create(:user) }

    context 'when hashed storage is disabled' do
      before do
        stub_application_setting(hashed_storage_enabled: false)
      end

      it { is_expected.to be_falsy }
    end

    context 'when hashed storage is enabled' do
      before do
        stub_application_setting(hashed_storage_enabled: true)
        allow(helper).to receive(:current_user).and_return(user)
      end

      context 'when the enable warning has not been dismissed' do
        context 'when there is a project in non-hashed-storage' do
          before do
            create(:project, :legacy_storage)
          end

          it { is_expected.to be_truthy }
        end

        context 'when there are NO projects in non-hashed-storage' do
          it { is_expected.to be_falsy }
        end
      end

      context 'when the enable warning was dismissed' do
        before do
          create(:user_callout, user: user, feature_name: described_class::GEO_MIGRATE_HASHED_STORAGE)
        end

        it { is_expected.to be_falsy }
      end
    end
  end

  describe '#render_dashboard_ultimate_trial', :saas do
    let_it_be(:namespace) { create(:namespace) }
    let_it_be(:ultimate_plan) { create(:ultimate_plan) }

    let(:user) { namespace.owner }

    where(:owns_group_without_trial?, :show_ultimate_trial?, :user_default_dashboard?, :has_no_trial_or_paid_plan?, :should_render?) do
      true  | true  | true  | true  | true
      true  | true  | true  | false | false
      true  | true  | false | true  | false
      true  | false | true  | true  | false
      true  | true  | false | false | false
      true  | false | false | true  | false
      true  | false | true  | false | false
      true  | false | false | false | false
      false | true  | true  | true  | false
      false | true  | true  | false | false
      false | true  | false | true  | false
      false | false | true  | true  | false
      false | true  | false | false | false
      false | false | false | true  | false
      false | false | true  | false | false
      false | false | false | false | false
    end

    with_them do
      before do
        allow(helper).to receive(:show_ultimate_trial?) { show_ultimate_trial? }
        allow(helper).to receive(:user_default_dashboard?) { user_default_dashboard? }
        allow(user).to receive(:owns_group_without_trial?) { owns_group_without_trial? }

        unless has_no_trial_or_paid_plan?
          create(:gitlab_subscription, hosted_plan: ultimate_plan, namespace: namespace)
        end
      end

      it do
        if should_render?
          expect(helper).to receive(:render).with('shared/ultimate_trial_callout_content')
        else
          expect(helper).not_to receive(:render)
        end

        helper.render_dashboard_ultimate_trial(user)
      end
    end
  end

  describe '#render_two_factor_auth_recovery_settings_check' do
    let(:user_two_factor_disabled) { create(:user) }
    let(:user_two_factor_enabled) { create(:user, :two_factor) }
    let(:anonymous) { nil }

    where(:kind_of_user, :is_gitlab_com?, :dismissed_callout?, :should_render?) do
      :anonymous                | false | false | false
      :anonymous                | true  | false | false
      :user_two_factor_disabled | false | false | false
      :user_two_factor_disabled | true  | false | false
      :user_two_factor_disabled | true  | true  | false
      :user_two_factor_enabled  | false | false | false
      :user_two_factor_enabled  | true  | false | true
      :user_two_factor_enabled  | true  | true  | false
    end

    with_them do
      before do
        user = send(kind_of_user)
        allow(helper).to receive(:current_user).and_return(user)
        allow(Gitlab).to receive(:com?).and_return(is_gitlab_com?)
        allow(user).to receive(:dismissed_callout?).and_return(dismissed_callout?) if user
      end

      it do
        if should_render?
          expect(helper).to receive(:render).with('shared/two_factor_auth_recovery_settings_check')
        else
          expect(helper).not_to receive(:render)
        end

        helper.render_two_factor_auth_recovery_settings_check
      end
    end
  end

  describe '.show_token_expiry_notification?' do
    subject { helper.show_token_expiry_notification? }

    let_it_be(:user) { create(:user) }

    where(:expiration_enforced?, :dismissed_callout?, :active?, :result) do
      true  | true  | true  | false
      true  | true  | false | false
      true  | false | true  | false
      false | true  | true  | false
      true  | false | false | false
      false | false | true  | true
      false | true  | false | false
      false | false | false | false
    end

    with_them do
      before do
        allow(helper).to receive(:current_user).and_return(user)
        allow(user).to receive(:active?).and_return(active?)
        allow(helper).to receive(:token_expiration_enforced?).and_return(expiration_enforced?)
        allow(user).to receive(:dismissed_callout?).and_return(dismissed_callout?)
      end

      it do
        expect(subject).to be result
      end

      context 'when user is nil' do
        before do
          allow(helper).to receive(:current_user).and_return(nil)
          allow(helper).to receive(:token_expiration_enforced?).and_return(false)
        end

        it do
          expect(subject).to be false
        end
      end
    end
  end

  describe '.show_profile_token_expiry_notification?' do
    subject { helper.show_profile_token_expiry_notification? }

    let_it_be(:user) { create(:user) }

    where(:expiration_enforced?, :dismissed_callout?, :result) do
      true  | true  | false
      true  | false | false
      false | true  | false
      false | false | true
    end

    with_them do
      before do
        allow(helper).to receive(:current_user).and_return(user)
        allow(helper).to receive(:token_expiration_enforced?).and_return(expiration_enforced?)
        allow(helper).to receive(:user_dismissed?).and_return(dismissed_callout?)
      end

      it { is_expected.to be result }
    end
  end

  describe '.show_new_user_signups_cap_reached?' do
    subject { helper.show_new_user_signups_cap_reached? }

    let(:user) { create(:user) }
    let(:admin) { create(:user, admin: true) }

    context 'when user is anonymous' do
      before do
        allow(helper).to receive(:current_user).and_return(nil)
      end

      it { is_expected.to eq(false) }
    end

    context 'when user is not an admin' do
      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      it { is_expected.to eq(false) }
    end

    context 'when feature flag is enabled' do
      where(:new_user_signups_cap, :active_user_count, :result) do
        nil | 10 | false
        10  | 9  | false
        0   | 10 | true
        1   | 1  | true
      end

      with_them do
        before do
          allow(helper).to receive(:current_user).and_return(admin)
          allow(User.billable).to receive(:count).and_return(active_user_count)
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:new_user_signups_cap).and_return(new_user_signups_cap)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#show_eoa_bronze_plan_banner?' do
    let_it_be(:user) { create(:user) }

    shared_examples 'shows and hides the banner depending on circumstances' do
      where(:show_billing_eoa_banner, :actual_plan_name, :dismissed_callout, :travel_to_date, :result) do
        true  | ::Plan::BRONZE     | false | eoa_bronze_plan_end_date - 1.day | true
        true  | ::Plan::BRONZE     | false | eoa_bronze_plan_end_date         | false
        true  | ::Plan::BRONZE     | false | eoa_bronze_plan_end_date + 1.day | false
        true  | ::Plan::BRONZE     | true  | eoa_bronze_plan_end_date - 1.day | false
        true  | ::Plan::SILVER     | false | eoa_bronze_plan_end_date - 1.day | false
        true  | ::Plan::PREMIUM    | false | eoa_bronze_plan_end_date - 1.day | false
        true  | ::Plan::GOLD       | false | eoa_bronze_plan_end_date - 1.day | false
        true  | ::Plan::ULTIMATE   | false | eoa_bronze_plan_end_date - 1.day | false
        false | ::Plan::BRONZE     | false | eoa_bronze_plan_end_date - 1.day | false
      end

      with_them do
        before do
          stub_feature_flags(show_billing_eoa_banner: show_billing_eoa_banner)
          allow(namespace).to receive(:actual_plan_name).and_return(actual_plan_name)
          allow(user).to receive(:dismissed_callout?).and_return(dismissed_callout)
        end

        it do
          travel_to(travel_to_date) do
            expect(helper.show_eoa_bronze_plan_banner?(namespace)).to eq(result)
          end
        end
      end
    end

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'with group namespace' do
      let(:group) { create(:group) }
      let(:current_user) { user }

      before do
        group.add_owner(current_user.id)
        allow(group).to receive(:actual_plan_name).and_return(::Plan::BRONZE)
        allow(helper).to receive(:current_user).and_return(current_user)
      end

      it_behaves_like 'shows and hides the banner depending on circumstances' do
        let(:namespace) { group }
      end
    end

    context 'with personal namespace' do
      let(:current_user) { user }

      before do
        allow(current_user.namespace).to receive(:actual_plan_name).and_return(::Plan::BRONZE)
      end

      it_behaves_like 'shows and hides the banner depending on circumstances' do
        let(:namespace) { current_user.namespace }
      end
    end
  end

  describe '#eoa_bronze_plan_end_date' do
    it 'returns a date type value' do
      expect(helper.send(:eoa_bronze_plan_end_date).is_a?(Date)).to eq(true)
    end
  end

  describe '#dismiss_two_factor_auth_recovery_settings_check' do
    let_it_be(:user) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'dismisses `TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK` callout' do
      expect(::Users::DismissUserCalloutService)
        .to receive(:new)
        .with(
          container: nil,
          current_user: user,
          params: { feature_name: UserCalloutsHelper::TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK }
        )
        .and_call_original

      helper.dismiss_two_factor_auth_recovery_settings_check
    end
  end
end
