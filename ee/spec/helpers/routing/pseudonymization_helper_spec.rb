# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Routing::PseudonymizationHelper do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  before do
    stub_feature_flags(mask_page_urls: true)
    allow(helper).to receive(:group).and_return(group)
    allow(helper).to receive(:project).and_return(project)
  end

  shared_examples 'masked url' do
    it 'generates masked page url' do
      expect(helper.masked_page_url).to eq(masked_url)
    end
  end

  describe 'when url has params to mask' do
    context 'when project/insights page is loaded' do
      let(:masked_url) { "http://localhost/namespace#{group.id}/project#{project.id}/insights" }
      let(:request) do
        double(:Request,
          path_parameters: {
                controller: 'projects/insights',
                action: 'show',
                namespace_id: group.name,
                project_id: project.name
               },
               protocol: 'http',
               host: 'localhost',
               query_string: '')
      end

      before do
        allow(helper).to receive(:request).and_return(request)
      end

      it_behaves_like 'masked url'
    end

    context 'when groups/insights page is loaded' do
      let(:masked_url) { "http://localhost/groups/namespace#{group.id}/-/insights" }
      let(:request) do
        double(:Request,
          path_parameters: {
                controller: 'groups/insights',
                action: 'show',
                group_id: group.name
               },
               protocol: 'http',
               host: 'localhost',
               query_string: '')
      end

      before do
        allow(helper).to receive(:request).and_return(request)
      end

      it_behaves_like 'masked url'
    end
  end
end
