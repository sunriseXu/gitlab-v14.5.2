# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppSec::Dast::ScanConfigs::BuildService do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }
  let_it_be(:dast_scanner_profile) { create(:dast_scanner_profile, project: project, spider_timeout: 5, target_timeout: 20) }
  let_it_be(:dast_profile) { create(:dast_profile, project: project, dast_site_profile: dast_site_profile, dast_scanner_profile: dast_scanner_profile, branch_name: 'master') }

  let(:dast_website) { dast_site_profile.dast_site.url }
  let(:dast_exclude_urls) { dast_site_profile.excluded_urls.join(',') }
  let(:dast_auth_url) { dast_site_profile.auth_url }
  let(:dast_username) { dast_site_profile.auth_username }
  let(:dast_username_field) { dast_site_profile.auth_username_field }
  let(:dast_password_field) { dast_site_profile.auth_password_field }
  let(:dast_spider_mins) { dast_scanner_profile.spider_timeout }
  let(:dast_target_availability_timeout) { dast_scanner_profile.target_timeout }
  let(:dast_full_scan_enabled) { dast_scanner_profile.full_scan_enabled? }
  let(:dast_use_ajax_spider) { dast_scanner_profile.use_ajax_spider? }
  let(:dast_debug) { dast_scanner_profile.show_debug_messages? }

  let(:params) { { dast_site_profile: dast_site_profile, dast_scanner_profile: dast_scanner_profile } }

  let(:expected_yaml_configuration) do
    <<~YAML
        ---
        stages:
        - dast
        include:
        - template: Security/DAST-On-Demand-Scan.gitlab-ci.yml
        dast:
          dast_configuration:
            site_profile: #{dast_site_profile.name}
            scanner_profile: #{dast_scanner_profile.name}
    YAML
  end

  subject { described_class.new(container: project, params: params).execute }

  describe 'execute' do
    context 'when a dast_profile is provided' do
      let(:params) { { dast_profile: dast_profile } }

      it 'returns a dast_profile, branch and YAML configuration' do
        expected_payload = {
          dast_profile: dast_profile,
          branch: dast_profile.branch_name,
          ci_configuration: expected_yaml_configuration
        }

        expect(subject.payload).to eq(expected_payload)
      end
    end

    context 'when a dast_site_profile is provided' do
      shared_examples 'a payload without a dast_profile' do
        it 'returns a branch and YAML configuration' do
          expected_payload = {
            dast_profile: nil,
            branch: dast_profile.branch_name,
            ci_configuration: expected_yaml_configuration
          }

          expect(subject.payload).to eq(expected_payload)
        end
      end

      context 'when a dast_scanner_profile is provided' do
        let(:params) { { dast_site_profile: dast_site_profile, dast_scanner_profile: dast_scanner_profile } }

        it_behaves_like 'a payload without a dast_profile'

        context 'when the target is not validated and an active scan is requested' do
          let_it_be(:active_dast_scanner_profile) { create(:dast_scanner_profile, project: project, scan_type: 'active') }

          let(:params) { { dast_site_profile: dast_site_profile, dast_scanner_profile: active_dast_scanner_profile } }

          it 'responds with an error message', :aggregate_failures do
            expect(subject).not_to be_success
            expect(subject.message).to eq('Cannot run active scan against unvalidated target')
          end
        end
      end

      context 'when a dast_scanner_profile is not provided' do
        let(:params) { { dast_site_profile: dast_site_profile } }

        let(:expected_yaml_configuration) do
          <<~YAML
            ---
            stages:
            - dast
            include:
            - template: Security/DAST-On-Demand-Scan.gitlab-ci.yml
            dast:
              dast_configuration:
                site_profile: #{dast_site_profile.name}
          YAML
        end

        it_behaves_like 'a payload without a dast_profile'
      end
    end

    context 'when a dast_site_profile is not provided' do
      let(:params) { { dast_site_profile: nil, dast_scanner_profile: dast_scanner_profile } }

      it 'responds with an error message', :aggregate_failures do
        expect(subject).not_to be_success
        expect(subject.message).to eq('Dast site profile was not provided')
      end
    end

    context 'when a branch is provided' do
      let(:params) { { dast_site_profile: dast_site_profile, dast_scanner_profile: dast_scanner_profile, branch: 'hello-world' } }

      it 'returns the branch in the payload' do
        expect(subject.payload[:branch]).to match('hello-world')
      end
    end
  end
end
