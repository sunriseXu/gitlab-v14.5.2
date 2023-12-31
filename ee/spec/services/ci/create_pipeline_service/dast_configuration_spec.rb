# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService do
  let_it_be_with_refind(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
  let_it_be(:user) { create(:user, developer_projects: [project]) }
  let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
  let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project) }

  let(:dast_variables) do
    dast_site_profile.ci_variables
      .concat(dast_scanner_profile.ci_variables)
      .to_runner_variables
  end

  let(:dast_secret_variables) do
    dast_site_profile.secret_ci_variables(user)
      .to_runner_variables
  end

  let(:config) do
    <<~EOY
    include:
      - template: Security/DAST.gitlab-ci.yml
    stages:
      - build
      - dast
    build:
      stage: build
      dast_configuration:
        site_profile: #{dast_site_profile.name}
        scanner_profile: #{dast_scanner_profile.name}
      script:
        - env
    dast:
      dast_configuration:
        site_profile: #{dast_site_profile.name}
        scanner_profile: #{dast_scanner_profile.name}
    EOY
  end

  let(:dast_build) { subject.builds.find_by(name: 'dast') }
  let(:dast_build_variables) { dast_build.variables.to_runner_variables }

  let(:build_variables) do
    subject.builds
      .find_by(name: 'build')
      .variables
      .to_runner_variables
  end

  subject { described_class.new(project, user, ref: 'refs/heads/master').execute(:push).payload }

  before do
    stub_ci_pipeline_yaml_file(config)
  end

  shared_examples 'it does not expand the dast variables' do
    it 'does not include the profile variables' do
      expect(build_variables).not_to include(*dast_variables)
    end
  end

  context 'when the feature is not licensed' do
    it_behaves_like 'it does not expand the dast variables'
  end

  context 'when the feature is licensed' do
    before do
      stub_licensed_features(dast: true, security_on_demand_scans: true)

      project_features = project.licensed_features
      allow(project).to receive(:licensed_features).and_return(project_features << :dast)

      # The latest version of the template does not run unless DAST is
      # configured via environment variables.
      stub_feature_flags(redirect_to_latest_template_security_dast: false)
    end

    context 'when the stage is dast' do
      it 'persists dast_configuration in build options' do
        expect(dast_build.options).to include(dast_configuration: { site_profile: dast_site_profile.name, scanner_profile: dast_scanner_profile.name })
      end

      it 'expands the dast variables' do
        expect(dast_variables).to include(*dast_variables)
      end

      context 'when the user has permission' do
        it 'expands the secret dast variables' do
          expect(dast_variables).to include(*dast_secret_variables)
        end
      end

      shared_examples 'a missing profile' do
        it 'communicates failure' do
          expect(subject.yaml_errors).to eq("DAST profile not found: #{profile.name}")
        end
      end

      context 'when the site profile does not exist' do
        let(:dast_site_profile) { double(DastSiteProfile, name: SecureRandom.hex) }
        let(:profile) { dast_site_profile }

        it_behaves_like 'a missing profile'
      end

      context 'when the scanner profile does not exist' do
        let(:dast_scanner_profile) { double(DastScannerProfile, name: SecureRandom.hex) }
        let(:profile) { dast_scanner_profile }

        it_behaves_like 'a missing profile'
      end

      context 'when there is an unexpected system error' do
        let_it_be(:error_tracking) { Gitlab::ErrorTracking }
        let_it_be(:exception) { ActiveRecord::ConnectionTimeoutError }

        before do
          allow(error_tracking).to receive(:track_exception).and_call_original

          allow_next_instance_of(AppSec::Dast::Profiles::BuildConfigService) do |instance|
            allow(instance).to receive(:execute).and_raise(exception)
          end
        end

        it 'handles the error', :aggregate_failures do
          expect(subject.errors.full_messages).to include('Failed to associate DAST profiles')

          expect(error_tracking).to have_received(:track_exception).with(exception, extra: { pipeline_id: subject.id })
        end
      end
    end

    context 'when the stage is not dast' do
      it_behaves_like 'it does not expand the dast variables'
    end
  end
end
