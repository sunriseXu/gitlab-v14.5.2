# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Boards::IssuesController do
  include ExternalAuthorizationServiceHelpers

  let(:group) { create(:group, :private) }
  let(:project_1) { create(:project, namespace: group) }
  let(:project_2) { create(:project, namespace: group) }
  let(:board) { create(:board, group: group) }
  let(:user)  { create(:user) }
  let(:guest) { create(:user) }

  let(:planning)    { create(:group_label, group: group, name: 'Planning') }
  let(:development) { create(:group_label, group: group, name: 'Development') }

  let!(:list1) { create(:list, board: board, label: planning, position: 0) }
  let!(:list2) { create(:list, board: board, label: development, position: 1) }

  before do
    group.add_maintainer(user)
    group.add_guest(guest)
  end

  describe 'GET index' do
    let(:johndoe) { create(:user, avatar: fixture_file_upload('spec/fixtures/dk.png')) }

    context 'with invalid board id' do
      it 'returns a not found 404 response' do
        list_issues user: user, board: non_existing_record_id, list: list2

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when list id is present' do
      context 'with valid list id' do
        it 'returns issues that have the list label applied' do
          issue = create(:labeled_issue, project: project_1, labels: [planning])
          create(:labeled_issue, project: project_1, labels: [planning])
          create(:labeled_issue, project: project_2, labels: [development], due_date: Date.tomorrow)
          create(:labeled_issue, project: project_2, labels: [development], assignees: [johndoe])
          issue.subscribe(johndoe, project_1)

          list_issues user: user, board: board, list: list2

          expect(response).to match_response_schema('issues')
          expect(json_response['issues'].length).to eq 2
          expect(development.issues.map(&:relative_position)).not_to include(nil)
        end

        it 'returns blocked status for each issue where the blocking issue is still opened' do
          issue1 = create(:labeled_issue, project: project_1, labels: [development], relative_position: 1)
          issue2 = create(:labeled_issue, project: project_1, labels: [development], relative_position: 2)
          issue3 = create(:labeled_issue, project: project_1, labels: [development], relative_position: 3)
          issue4 = create(:labeled_issue, project: project_1, labels: [development], relative_position: 4)
          closed_issue = create(:issue, :closed, project: project_1)

          create(:issue_link, source: issue2, target: issue1, link_type: IssueLink::TYPE_BLOCKS)
          create(:issue_link, source: issue2, target: issue3, link_type: IssueLink::TYPE_BLOCKS)
          create(:issue_link, source: closed_issue, target: issue4, link_type: IssueLink::TYPE_BLOCKS)

          list_issues user: user, board: board, list: list2

          expect(response).to match_response_schema('entities/issue_boards')
          issues = json_response['issues']
          expect(issues.length).to eq 4
          expect(issues[0]['blocked']).to be_truthy
          expect(issues[1]['blocked']).to be_falsey
          expect(issues[2]['blocked']).to be_truthy
          expect(issues[3]['blocked']).to be_falsey
        end

        context 'with search param' do
          it 'returns matching issues using optimized search' do
            create(:labeled_issue, project: project_1, labels: [planning], title: 'Test Issue')
            create(:labeled_issue, project: project_1, labels: [planning], title: 'Sample Issue')

            list_issues user: user, board: board, list: list1, search: 'Te'

            expect(response).to match_response_schema('issues')
            expect(json_response['issues'].length).to eq 1
          end
        end
      end

      context 'with invalid list id' do
        it 'returns a not found 404 response' do
          list_issues user: user, board: board, list: non_existing_record_id

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'when list id is missing' do
      it 'returns opened issues without board labels applied' do
        bug = create(:label, project: project_1, name: 'Bug')
        create(:issue, project: project_1)
        create(:labeled_issue, project: project_2, labels: [planning])
        create(:labeled_issue, project: project_2, labels: [development])
        create(:labeled_issue, project: project_2, labels: [bug])

        list_issues user: user, board: board

        expect(response).to match_response_schema('issues')
        expect(json_response['issues'].length).to eq 2
      end

      context 'with search param' do
        it 'returns matching issues using optimized search' do
          create(:issue, project: project_1, title: 'Issue XI')
          create(:issue, project: project_1, title: 'Issue XX')

          list_issues user: user, board: board, search: 'XI'

          expect(response).to match_response_schema('issues')
          expect(json_response['issues'].length).to eq 1
        end
      end
    end

    context 'with unauthorized user' do
      before do
        group.group_member(user).destroy!
      end

      it 'returns a forbidden 403 response' do
        list_issues user: user, board: board, list: list2

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    def list_issues(user:, board:, list: nil, search: nil)
      sign_in(user)

      params = {
        board_id: board.to_param,
        list_id: list.try(:to_param),
        search: search.try(:to_param)
      }

      get :index, params: params.compact
    end
  end

  describe 'POST create' do
    context 'with valid params' do
      it 'returns a successful 200 response' do
        create_issue user: user, board: board, list: list1, title: 'New issue'

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns the created issue' do
        create_issue user: user, board: board, list: list1, title: 'New issue'

        expect(response).to match_response_schema('issue')
      end
    end

    context 'with invalid params' do
      context 'when title is nil' do
        it 'returns an unprocessable entity 422 response' do
          create_issue user: user, board: board, list: list1, title: nil

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when list does not belongs to project board' do
        it 'returns a not found 404 response' do
          list = create(:list)

          create_issue user: user, board: board, list: list, title: 'New issue'

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with invalid board id' do
        it 'returns a not found 404 response' do
          create_issue user: user, board: non_existing_record_id, list: list1, title: 'New issue'

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with invalid list id' do
        it 'returns a not found 404 response' do
          create_issue user: user, board: board, list: non_existing_record_id, title: 'New issue'

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with unauthorized user' do
      it 'returns a forbidden 403 response' do
        create_issue user: guest, board: board, list: list1, title: 'New issue'

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    def create_issue(user:, board:, list:, title:)
      sign_in(user)

      post :create, params: {
                      board_id: board.to_param,
                      list_id: list.to_param,
                      issue: { title: title, project_id: project_1.id }
                    },
                    format: :json
    end
  end

  describe 'PATCH update' do
    let!(:issue) { create(:labeled_issue, project: project_1, labels: [planning]) }

    context 'with valid params' do
      it 'returns a successful 200 response' do
        move user: user, board: board, issue: issue, from_list_id: list1.id, to_list_id: list2.id

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'moves issue to the desired list' do
        move user: user, board: board, issue: issue, from_list_id: list1.id, to_list_id: list2.id

        expect(issue.reload.labels).to contain_exactly(development)
      end
    end

    context 'with invalid params' do
      it 'returns a unprocessable entity 422 response for invalid lists' do
        move user: user, board: board, issue: issue, from_list_id: nil, to_list_id: nil

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
      end

      it 'returns a not found 404 response for invalid board id' do
        move user: user, board: non_existing_record_id, issue: issue, from_list_id: list1.id, to_list_id: list2.id

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'returns a not found 404 response for invalid issue id' do
        move user: user, board: board, issue: double(id: non_existing_record_id), from_list_id: list1.id, to_list_id: list2.id

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'with unauthorized user' do
      let(:guest) { create(:user) }

      before do
        group.add_guest(guest)
      end

      it 'returns a forbidden 403 response' do
        move user: guest, board: board, issue: issue, from_list_id: list1.id, to_list_id: list2.id

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    def move(user:, board:, issue:, from_list_id:, to_list_id:)
      sign_in(user)

      patch :update, params: {
                       board_id: board.to_param,
                       id: issue.id,
                       from_list_id: from_list_id,
                       to_list_id: to_list_id
                     },
                     format: :json
    end
  end
end
