# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::IssueLinks do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:target_issue) { create(:issue, project: project) }

  before do
    project.add_reporter(user)
  end

  describe 'POST /links' do
    context 'when creating a blocked relationship' do
      context 'when feature is enabled' do
        it 'returns 201 status and contains the expected link response' do
          post api("/projects/#{project.id}/issues/#{issue.iid}/links", user),
               params: { target_project_id: project.id, target_issue_iid: target_issue.iid, link_type: 'blocks' }

          expect(response).to have_gitlab_http_status(:created)
          expect(response).to match_response_schema('public_api/v4/issue_link')
          expect(json_response['link_type']).to eq('blocks')
        end
      end

      context 'when feature is disabled' do
        before do
          stub_licensed_features(blocked_issues: false)
        end

        it 'returns 403' do
          post api("/projects/#{project.id}/issues/#{issue.iid}/links", user),
               params: { target_project_id: project.id, target_issue_iid: target_issue.iid, link_type: 'blocks' }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end
end
