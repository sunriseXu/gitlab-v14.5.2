# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::TopNavHelper do
  describe '#top_nav_view_model' do
    let_it_be(:user) { build_stubbed(:user) }

    let(:current_user) { user }
    let(:with_environments) { false }
    let(:with_operations) { false }
    let(:with_security) { false }

    let(:with_geo_secondary) { false }
    let(:with_geo_primary_node_configured) { false }

    let(:subject) { helper.top_nav_view_model(project: nil, group: nil) }

    before do
      allow(helper).to receive(:current_user) { current_user }

      allow(helper).to receive(:header_link?).with(anything) { false }

      # Defaulting all `dashboard_nav_link?` calls to false ensures the CE-specific behavior
      # is not tested in this EE spec
      allow(helper).to receive(:dashboard_nav_link?).with(anything) { false }
      allow(helper).to receive(:dashboard_nav_link?).with(:environments) { with_environments }
      allow(helper).to receive(:dashboard_nav_link?).with(:operations) { with_operations }
      allow(helper).to receive(:dashboard_nav_link?).with(:security) { with_security }

      allow(::Gitlab::Geo).to receive(:secondary?) { with_geo_secondary }
      allow(::Gitlab::Geo).to receive(:primary_node_configured?) { with_geo_primary_node_configured }
    end

    context 'with environments' do
      let(:with_environments) { true }

      it 'has expected :primary' do
        expected_primary = ::Gitlab::Nav::TopNavMenuItem.build(
          data: {
            qa_selector: 'environment_link'
          },
          href: '/-/operations/environments',
          icon: 'environment',
          id: 'environments',
          title: 'Environments'
        )
        expect(subject[:primary]).to eq([expected_primary])
      end
    end

    context 'with operations' do
      let(:with_operations) { true }

      it 'has expected :primary' do
        expected_primary = ::Gitlab::Nav::TopNavMenuItem.build(
          data: {
            qa_selector: 'operations_link'
          },
          href: '/-/operations',
          icon: 'cloud-gear',
          id: 'operations',
          title: 'Operations'
        )
        expect(subject[:primary]).to eq([expected_primary])
      end
    end

    context 'with security' do
      let(:with_security) { true }

      it 'has expected :primary' do
        expected_primary = ::Gitlab::Nav::TopNavMenuItem.build(
          data: {
            qa_selector: 'security_link'
          },
          href: '/-/security/dashboard',
          icon: 'shield',
          id: 'security',
          title: 'Security'
        )
        expect(subject[:primary]).to eq([expected_primary])
      end
    end

    context 'with geo' do
      let(:with_geo_secondary) { true }
      let(:with_geo_primary_node_configured) { true }
      let(:url) { 'fake_url' }

      before do
        allow(::Gitlab::Geo).to receive_message_chain(:primary_node, :url) { url }
      end

      it 'has expected :secondary' do
        expected_secondary = ::Gitlab::Nav::TopNavMenuItem.build(
          href: url,
          icon: 'location-dot',
          id: 'geo',
          title: 'Go to primary site'
        )
        expect(subject[:secondary]).to eq([expected_secondary])
      end
    end
  end
end
