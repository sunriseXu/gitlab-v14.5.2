# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::Geo::NodesController, :geo do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be(:geo_node) { create(:geo_node) }

  before do
    enable_admin_mode!(admin)
    login_as(admin)
  end

  describe 'GET /geo/nodes' do
    context 'with a valid license' do
      before do
        stub_licensed_features(geo: true)
      end

      it 'renders the Geo Nodes View', :aggregate_failures do
        get admin_geo_nodes_path

        expect(response).to render_template(:index)
        expect(response.body).to include('js-geo-nodes')
      end
    end

    context 'without a valid license' do
      before do
        stub_licensed_features(geo: false)
        get admin_geo_nodes_path
      end

      it 'does show license alert' do
        expect(response).to render_template(partial: '_license_alert')
        expect(response.body).to include('Geo is only available for users who have at least a Premium license.')
      end

      it 'does not redirects to the 403 page' do
        expect(response).not_to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
