# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::GonHelper do
  let(:helper) do
    Class.new do
      include Gitlab::GonHelper

      def current_user
        nil
      end
    end.new
  end

  describe '#add_gon_variables' do
    let(:gon) { instance_double('gon').as_null_object }

    before do
      allow(helper).to receive(:gon).and_return(gon)
    end

    it 'includes ee exclusive settings' do
      expect(gon).to receive(:roadmap_epics_limit=).with(1000)

      helper.add_gon_variables
    end

    context 'when GitLab.com' do
      before do
        allow(Gitlab).to receive(:dev_env_or_com?).and_return(true)
      end

      it 'includes CustomersDot variables' do
        expect(gon).to receive(:subscriptions_url=).with(Gitlab::SubscriptionPortal::SUBSCRIPTIONS_URL)
        expect(gon).to receive(:payment_form_url=).with(Gitlab::SubscriptionPortal::PAYMENT_FORM_URL)

        helper.add_gon_variables
      end
    end
  end

  describe '#push_licensed_feature' do
    let_it_be(:feature) { License::EEU_FEATURES.first }

    shared_examples 'sets the licensed features flag' do
      it 'pushes the licensed feature flag to the frotnend' do
        gon = instance_double('gon')
        stub_licensed_features(feature => true)

        allow(helper)
          .to receive(:gon)
          .and_return(gon)

        expect(gon)
          .to receive(:push)
          .with({ licensed_features: { feature.to_s.camelize(:lower) => true } }, true)

        subject
      end
    end

    context 'no obj given' do
      subject { helper.push_licensed_feature(feature) }

      before do
        expect(License).to receive(:feature_available?).with(feature)
      end

      it_behaves_like 'sets the licensed features flag'
    end

    context 'obj given' do
      let(:project) { create(:project) }

      subject { helper.push_licensed_feature(feature, project) }

      before do
        expect(project).to receive(:feature_available?).with(feature).and_call_original
      end

      it_behaves_like 'sets the licensed features flag'
    end
  end
end
