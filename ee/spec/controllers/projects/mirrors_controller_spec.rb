# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::MirrorsController do
  include ReactiveCachingHelpers

  describe 'setting up a remote mirror' do
    let_it_be(:project) { create(:project, :repository) }

    let(:url) { 'http://foo.com' }

    context 'when the current project is a mirror' do
      let(:project) { create(:project, :repository, :mirror) }

      before do
        sign_in(project.owner)
      end

      it 'allows to create a remote mirror' do
        expect do
          do_put(project, remote_mirrors_attributes: { '0' => { 'enabled' => 1, 'url' => url } })
        end.to change { RemoteMirror.count }.to(1)
      end
    end

    context 'when the current project has a remote mirror' do
      let(:remote_mirror) { project.remote_mirrors.create!(enabled: 1, url: 'http://local.dev') }

      before do
        sign_in(project.owner)
      end

      context 'mirror_user is unset' do
        it 'sets up a pull mirror with the mirror user set to the signed-in user' do
          expect(project.mirror_user).to be_nil

          do_put(project, mirror: true, import_url: 'http://local.dev')
          project.reload

          expect(project.mirror).to eq(true)
          expect(project.import_url).to eq('http://local.dev')
          expect(project.mirror_user).to eq(project.owner)
        end
      end

      context 'mirror_user is not the current user' do
        it 'sets up a pull mirror with the mirror user set to the signed-in user' do
          new_user = create(:user)
          project.add_maintainer(new_user)

          do_put(project, mirror: true, mirror_user_id: new_user.id, import_url: 'http://local.dev')

          expect(project.mirror).to eq(true)
          expect(project.import_url).to eq('http://local.dev')
          expect(project.mirror_user).to eq(project.owner)
        end
      end
    end
  end

  describe 'setting up a mirror' do
    let(:url) { 'http://foo.com' }
    let(:project) { create(:project, :repository) }

    context 'when mirrors are disabled' do
      before do
        stub_application_setting(mirror_available: false)
      end

      context 'when user is admin', :enable_admin_mode do
        let(:admin) { create(:user, :admin) }

        it 'creates a new mirror' do
          sign_in(admin)

          expect do
            do_put(project, mirror: true, import_url: url)
          end.to change { Project.mirror.count }.to(1)
        end
      end

      context 'when user is not an admin' do
        it 'does not create a new mirror' do
          sign_in(project.owner)

          expect do
            do_put(project, mirror: true, import_url: url)
          end.not_to change { Project.mirror.count }
        end
      end
    end

    context 'when mirrors are enabled' do
      before do
        sign_in(project.owner)
      end

      context 'when project does not have a mirror' do
        it 'allows to create a mirror' do
          expect do
            do_put(project, mirror: true, mirror_user_id: project.owner.id, import_url: url)
          end.to change { Project.mirror.count }.to(1)
        end
      end

      context 'when project has a mirror' do
        let(:project) { create(:project, :mirror, :import_finished) }

        it 'is able to disable the mirror' do
          expect { do_put(project, mirror: false) }.to change { Project.mirror.count }.to(0)
        end
      end
    end
  end

  describe 'forcing an update on a pull mirror' do
    it 'forces update' do
      project = create(:project, :mirror)
      sign_in(project.owner)

      Sidekiq::Testing.fake! do
        expect { put :update_now, params: { namespace_id: project.namespace.to_param, project_id: project.to_param } }
          .to change { UpdateAllMirrorsWorker.jobs.size }
          .by(1)
      end
    end
  end

  describe '#update' do
    let(:project) { create(:project, :repository, :mirror, :remote_mirror) }
    let(:attributes) { { project: { mirror_user_id: project.owner.id, mirror_trigger_builds: 0 }, namespace_id: project.namespace.to_param, project_id: project.to_param } }

    before do
      sign_in(project.owner)
    end

    around do |example|
      Sidekiq::Testing.fake! { example.run }
    end

    context 'JSON' do
      it 'processes a successful update' do
        do_put(project, { import_url: 'https://updated.example.com' }, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['import_url']).to eq('https://updated.example.com')
      end

      it 'processes an unsuccessful update' do
        do_put(project, { import_url: 'ftp://invalid.invalid' }, format: :json)

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
        expect(json_response['import_url'].first).to match /is blocked/
      end

      it "preserves the import_data object when the ID isn't in the request" do
        import_data_id = project.import_data.id

        do_put(project, { import_data_attributes: { password: 'update' } }, format: :json)

        expect(response).to have_gitlab_http_status(:ok)
        expect(project.reload_import_data.id).to eq(import_data_id)
      end

      it 'sets ssh_known_hosts_verified_at and verified_by when the update sets known hosts' do
        do_put(project, { import_data_attributes: { ssh_known_hosts: 'update' } }, format: :json)

        expect(response).to have_gitlab_http_status(:ok)

        import_data = project.reload_import_data
        expect(import_data.ssh_known_hosts_verified_at).to be_within(1.minute).of(Time.current)
        expect(import_data.ssh_known_hosts_verified_by).to eq(project.owner)
      end

      it 'unsets ssh_known_hosts_verified_at and verified_by when the update unsets known hosts' do
        project.import_data.update!(ssh_known_hosts: 'foo')

        do_put(project, { import_data_attributes: { ssh_known_hosts: '' } }, format: :json)

        expect(response).to have_gitlab_http_status(:ok)

        import_data = project.reload_import_data
        expect(import_data.ssh_known_hosts_verified_at).to be_nil
        expect(import_data.ssh_known_hosts_verified_by).to be_nil
      end

      it 'only allows the current user to be the mirror user' do
        other_user = create(:user)
        project.add_maintainer(other_user)

        do_put(project, { mirror_user_id: other_user.id }, format: :json)

        expect(project.reload.mirror_user).to eq(project.owner)
      end
    end

    context 'with a valid URL for a pull' do
      it 'processes a successful update' do
        do_put(project, username_only_import_url: "https://updated.example.com")

        expect(response).to redirect_to(project_settings_repository_path(project, anchor: 'js-push-remote-settings'))
        expect(flash[:notice]).to match(/successfully updated/)
      end
    end

    context 'with a invalid URL for a pull' do
      it 'processes an unsuccessful update' do
        do_put(project, username_only_import_url: "ftp://invalid.invalid'")

        expect(response).to redirect_to(project_settings_repository_path(project, anchor: 'js-push-remote-settings'))
        expect(flash[:alert]).to match(/is blocked/)
      end
    end
  end

  def do_put(project, options, extra_attrs = {})
    attrs = extra_attrs.merge(namespace_id: project.namespace.to_param, project_id: project.to_param)
    attrs[:project] = options

    put :update, params: attrs
  end
end
