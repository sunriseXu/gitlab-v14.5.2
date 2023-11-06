# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseHighlight, :clean_gitlab_redis_cache do
  let(:fixture_dir_glob) { Dir.glob(File.join(Rails.root, 'spec', 'fixtures', 'whats_new', '*.yml')).grep(/\d*\_(\d*\_\d*)\.yml$/) }
  let(:starter_plan) { create(:license, plan: License::STARTER_PLAN) }
  let(:premium_plan) { create(:license, plan: License::PREMIUM_PLAN) }
  let(:ultimate_plan) { create(:license, plan: License::ULTIMATE_PLAN) }

  before do
    allow(Dir).to receive(:glob).with(Rails.root.join('data', 'whats_new', '*.yml')).and_return(fixture_dir_glob)
    Gitlab::CurrentSettings.update!(whats_new_variant: ApplicationSetting.whats_new_variants[:all_tiers])
  end

  after do
    ReleaseHighlight.instance_variable_set(:@file_paths, nil)
  end

  describe '.load_items' do
    context 'whats new for current tier only' do
      before do
        Gitlab::CurrentSettings.update!(whats_new_variant: ApplicationSetting.whats_new_variants[:all_tiers])
      end

      it 'returns all items' do
        items = described_class.load_items(page: 2)

        expect(items.count).to eq(3)
      end
    end

    context 'whats new for current tier only' do
      before do
        Gitlab::CurrentSettings.update!(whats_new_variant: ApplicationSetting.whats_new_variants[:current_tier])
      end

      context 'with no license' do
        it 'returns items with package=Free' do
          items = described_class.load_items(page: 2)

          expect(items.count).to eq(1)
          expect(items.first['packages']).to include('Free')
        end
      end

      context 'with Starter license' do
        before do
          allow(License).to receive(:current).and_return(starter_plan)
        end

        it 'returns items with package=Free' do
          items = described_class.load_items(page: 2)

          expect(items.count).to eq(1)
          expect(items.first['packages']).to include('Free')
        end
      end

      context 'with Premium license' do
        before do
          allow(License).to receive(:current).and_return(premium_plan)
        end

        it 'returns items with package=Premium' do
          items = described_class.load_items(page: 2)

          expect(items.count).to eq(2)
          expect(items.map { |item| item['packages'] }).to all( include('Premium') )
        end
      end

      context 'with Ultimate license' do
        before do
          allow(License).to receive(:current).and_return(ultimate_plan)
        end

        it 'returns items with package=Ultimate' do
          items = described_class.load_items(page: 2)

          expect(items.count).to eq(3)
          expect(items.map { |item| item['packages'] }).to all( include('Ultimate') )
        end
      end
    end
  end

  describe '.current_package' do
    subject { described_class.current_package }

    it 'returns package for no license' do
      allow(License).to receive(:current).and_return(nil)

      expect(subject).to eq('Free')
    end

    it 'returns package for Starter license' do
      allow(License).to receive(:current).and_return(starter_plan)

      expect(subject).to eq('Free')
    end

    it 'returns package for Premium license' do
      allow(License).to receive(:current).and_return(premium_plan)

      expect(subject).to eq('Premium')
    end

    it 'returns package for Ultimate license' do
      allow(License).to receive(:current).and_return(ultimate_plan)

      expect(subject).to eq('Ultimate')
    end
  end
end
