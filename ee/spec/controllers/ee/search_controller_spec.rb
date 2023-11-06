# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SearchController, :elastic do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET #show' do
    context 'unique users tracking' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
      end

      context 'i_search_advanced' do
        it_behaves_like 'tracking unique hll events' do
          subject(:request) { get :show, params: { scope: 'projects', search: 'term' } }

          let(:target_id) { 'i_search_advanced' }
          let(:expected_type) { instance_of(String) }
        end
      end

      context 'i_search_paid' do
        let_it_be(:group) { create(:group) }

        let(:request_params) { { group_id: group.id, scope: 'blobs', search: 'term' } }
        let(:target_id) { 'i_search_paid' }

        context 'on Gitlab.com' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(true)
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
          end

          it_behaves_like 'tracking unique hll events' do
            subject(:request) { get :show, params: request_params }

            let(:expected_type) { instance_of(String) }
          end
        end

        context 'self-managed instance' do
          before do
            allow(::Gitlab).to receive(:com?).and_return(false)
          end

          context 'license is available' do
            before do
              stub_licensed_features(elastic_search: true)
            end

            it_behaves_like 'tracking unique hll events' do
              subject(:request) { get :show, params: request_params }

              let(:expected_type) { instance_of(String) }
            end
          end

          it 'does not track if there is no license available' do
            stub_licensed_features(elastic_search: false)
            expect(Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event).with(target_id, values: instance_of(String))

            get :show, params: request_params, format: :html
          end
        end
      end
    end

    shared_examples 'renders the elasticsearch tabs if elasticsearch is enabled' do
      using RSpec::Parameterized::TableSyntax

      render_views

      subject { get :show, params: request_params, format: :html }

      where(:scope) { %w[projects issues merge_requests milestones epics notes blobs commits wiki_blobs users] }

      with_them do
        context 'when elasticsearch is enabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
          end

          it 'shows the elasticsearch tabs' do
            subject

            expect(response.body).to have_link('Code')
            expect(response.body).to have_link('Wiki')
            expect(response.body).to have_link('Comments')
            expect(response.body).to have_link('Commits')
          end
        end

        context 'when elasticsearch is disabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
          end

          it 'does not show the elasticsearch tabs' do
            subject

            expect(response.body).not_to have_link('Code')
            expect(response.body).not_to have_link('Wiki')
            expect(response.body).not_to have_link('Comments')
            expect(response.body).not_to have_link('Commits')
          end
        end
      end
    end

    shared_examples 'search tabs displayed in consistent order' do
      render_views

      let(:scope) { 'issues' }

      subject { get :show, params: request_params, format: :html }

      it 'keeps search tab order' do
        subject

        # this order should be consistent across global, group, and project scoped searches
        # though all tabs may not be available depending on the search scope and features enabled (epics, advanced search)
        global_expected_order = %w[projects blobs epics issues merge_requests wiki_blobs commits notes milestones users]
        tabs = response.body.scan(/search\?.*scope=(\w*)&amp/).flatten
        expect(tabs).to eq(global_expected_order & tabs)
      end
    end

    context 'global search' do
      let(:request_params) { { scope: scope, search: 'term' } }

      it_behaves_like 'renders the elasticsearch tabs if elasticsearch is enabled'

      context 'scope tab order' do
        context 'when elasticsearch is disabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
          end

          it_behaves_like 'search tabs displayed in consistent order'
        end

        context 'when elasticsearch is enabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
          end

          it_behaves_like 'search tabs displayed in consistent order'
        end
      end
    end

    context 'group search' do
      let_it_be(:group) { create(:group) }

      let(:request_params) { { group_id: group.id, scope: scope, search: 'term' } }

      it_behaves_like 'renders the elasticsearch tabs if elasticsearch is enabled'

      context 'scope tab order' do
        context 'when elasticsearch is disabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
          end

          context 'when epics are disabled' do
            before do
              stub_licensed_features(epics: false)
            end

            it_behaves_like 'search tabs displayed in consistent order'
          end

          context 'when epics are enabled' do
            before do
              stub_licensed_features(epics: true)
            end

            it_behaves_like 'search tabs displayed in consistent order'
          end
        end

        context 'when elasticsearch is enabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
          end

          context 'when epics are disabled' do
            before do
              stub_licensed_features(epics: false)
            end

            it_behaves_like 'search tabs displayed in consistent order'
          end

          context 'when epics are enabled' do
            before do
              stub_licensed_features(epics: true)
            end

            it_behaves_like 'search tabs displayed in consistent order'
          end
        end
      end
    end

    context 'project search' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }

      let(:request_params) { { project_id: project.id, group_id: project.group, scope: scope, search: 'term' } }

      before do
        project.add_developer(user)
      end

      context 'scope tab order' do
        context 'when elasticsearch is disabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
          end

          it_behaves_like 'search tabs displayed in consistent order'
        end

        context 'when elasticsearch is enabled' do
          before do
            stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
          end

          it_behaves_like 'search tabs displayed in consistent order'
        end
      end
    end
  end
end
