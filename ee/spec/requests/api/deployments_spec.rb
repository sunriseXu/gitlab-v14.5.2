# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Deployments do
  let(:user) { create(:user) }
  let!(:project) { create(:project, :repository) }
  let!(:environment) { create(:environment, project: project) }

  before do
    stub_licensed_features(protected_environments: true)
  end

  describe 'POST /projects/:id/deployments' do
    context 'when deploying to a protected environment that requires maintainer access' do
      before do
        create(
          :protected_environment,
          :maintainers_can_deploy,
          project: environment.project,
          name: environment.name
        )
      end

      it 'returns a 403 when the user is a developer' do
        project.add_developer(user)

        post(
          api("/projects/#{project.id}/deployments", user),
          params: {
            environment: environment.name,
            sha: 'b83d6e391c22777fca1ed3012fce84f633d7fed0',
            ref: 'master',
            tag: false,
            status: 'success'
          }
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'creates the deployment when the user is a maintainer' do
        project.add_maintainer(user)

        post(
          api("/projects/#{project.id}/deployments", user),
          params: {
            environment: environment.name,
            sha: 'b83d6e391c22777fca1ed3012fce84f633d7fed0',
            ref: 'master',
            tag: false,
            status: 'success'
          }
        )

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    context 'when deploying to a protected environment that requires developer access' do
      before do
        create(
          :protected_environment,
          :developers_can_deploy,
          project: environment.project,
          name: environment.name
        )
      end

      it 'returns a 403 when the user is a guest' do
        project.add_guest(user)

        post(
          api("/projects/#{project.id}/deployments", user),
          params: {
            environment: environment.name,
            sha: 'b83d6e391c22777fca1ed3012fce84f633d7fed0',
            ref: 'master',
            tag: false,
            status: 'success'
          }
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'creates the deployment when the user is a developer' do
        project.add_developer(user)

        post(
          api("/projects/#{project.id}/deployments", user),
          params: {
            environment: environment.name,
            sha: 'b83d6e391c22777fca1ed3012fce84f633d7fed0',
            ref: 'master',
            tag: false,
            status: 'success'
          }
        )

        expect(response).to have_gitlab_http_status(:created)
      end
    end
  end

  describe 'PUT /projects/:id/deployments/:deployment_id' do
    let(:deploy) do
      create(
        :deployment,
        :running,
        project: project,
        deployable: nil,
        environment: environment
      )
    end

    context 'when updating a deployment for a protected environment that requires maintainer access' do
      before do
        create(
          :protected_environment,
          :maintainers_can_deploy,
          project: environment.project,
          name: environment.name
        )
      end

      it 'returns a 403 when the user is a developer' do
        project.add_developer(user)

        put(
          api("/projects/#{project.id}/deployments/#{deploy.id}", user),
          params: { status: 'success' }
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'updates the deployment when the user is a maintainer' do
        project.add_maintainer(user)

        put(
          api("/projects/#{project.id}/deployments/#{deploy.id}", user),
          params: { status: 'success' }
        )

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when updating a deployment for a protected environment that requires developer access' do
      before do
        create(
          :protected_environment,
          :developers_can_deploy,
          project: environment.project,
          name: environment.name
        )
      end

      it 'returns a 403 when the user is a guest' do
        project.add_guest(user)

        put(
          api("/projects/#{project.id}/deployments/#{deploy.id}", user),
          params: { status: 'success' }
        )

        expect(response).to have_gitlab_http_status(:forbidden)
      end

      it 'updates the deployment when the user is a developer' do
        project.add_developer(user)

        put(
          api("/projects/#{project.id}/deployments/#{deploy.id}", user),
          params: { status: 'success' }
        )

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
