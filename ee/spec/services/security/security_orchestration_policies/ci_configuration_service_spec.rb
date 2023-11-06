# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiConfigurationService do
  describe '#execute' do
    let_it_be(:service) { described_class.new }
    let_it_be(:ci_variables) do
      { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_DISABLED' => nil }
    end

    subject { service.execute(action, ci_variables) }

    shared_examples 'with template name for scan type' do
      it 'fetches template content using ::TemplateFinder' do
        expect(::TemplateFinder).to receive(:build).with(:gitlab_ci_ymls, nil, name: template_name).and_call_original

        subject
      end
    end

    context 'when action is valid' do
      context 'when scan type is secret_detection' do
        let_it_be(:action) { { scan: 'secret_detection' } }
        let_it_be(:template_name) { 'Jobs/Secret-Detection' }

        it_behaves_like 'with template name for scan type'

        it 'returns prepared CI configuration with Secret Detection scans' do
          expected_configuration = {
            rules: [{ if: '$SECRET_DETECTION_DISABLED', when: 'never' }, { if: '$CI_COMMIT_BRANCH' }],
            script:
              ['if [ -n "$CI_COMMIT_TAG" ]; then echo "Skipping Secret Detection for tags. No code changes have occurred."; exit 0; fi',
               'if [ "$CI_COMMIT_BRANCH" = "$CI_DEFAULT_BRANCH" ]; then echo "Running Secret Detection on default branch."; /analyzer run; exit 0; fi',
               'git fetch origin $CI_DEFAULT_BRANCH $CI_COMMIT_REF_NAME',
               'git log --left-right --cherry-pick --pretty=format:"%H" refs/remotes/origin/$CI_DEFAULT_BRANCH...refs/remotes/origin/$CI_COMMIT_REF_NAME > "$CI_COMMIT_SHA"_commit_list.txt',
               'export SECRET_DETECTION_COMMITS_FILE="$CI_COMMIT_SHA"_commit_list.txt',
               '/analyzer run',
               'rm "$CI_COMMIT_SHA"_commit_list.txt'],
            stage: 'test',
            image: '$SECURE_ANALYZERS_PREFIX/secrets:$SECRETS_ANALYZER_VERSION',
            services: [],
            allow_failure: true,
            artifacts: {
              reports: {
                secret_detection: 'gl-secret-detection-report.json'
              }
            },
            variables: {
              SECURE_ANALYZERS_PREFIX: 'registry.gitlab.com/gitlab-org/security-products/analyzers',
              SECRETS_ANALYZER_VERSION: '3',
              SECRET_DETECTION_EXCLUDED_PATHS: '',
              SECRET_DETECTION_HISTORIC_SCAN: 'false'
            }
          }

          expect(subject.deep_symbolize_keys).to eq(expected_configuration)
        end
      end

      context 'when scan type is cluster_image_scanning' do
        let_it_be(:action) { { scan: 'cluster_image_scanning' } }
        let_it_be(:template_name) { 'Security/Cluster-Image-Scanning' }
        let_it_be(:ci_variables) { {} }

        it_behaves_like 'with template name for scan type'

        it 'returns prepared CI configuration for Cluster Image Scanning' do
          expected_configuration = {
            image: '$CIS_ANALYZER_IMAGE',
            stage: 'test',
            allow_failure: true,
            artifacts: {
              reports: { cluster_image_scanning: 'gl-cluster-image-scanning-report.json' },
              paths: ['gl-cluster-image-scanning-report.json']
            },
            dependencies: [],
            script: ['/analyzer run'],
            variables: {
              CIS_ANALYZER_IMAGE: 'registry.gitlab.com/security-products/cluster-image-scanning:0'
            }
          }

          expect(subject.deep_symbolize_keys).to eq(expected_configuration)
        end
      end

      context 'when scan type is container_scanning' do
        let_it_be(:action) { { scan: 'container_scanning' } }
        let_it_be(:template_name) { 'Security/Container-Scanning' }
        let_it_be(:ci_variables) { {} }

        it_behaves_like 'with template name for scan type'

        it 'returns prepared CI configuration for Container Scanning' do
          expected_configuration = {
            image: '$CS_ANALYZER_IMAGE',
            stage: 'test',
            allow_failure: true,
            artifacts: {
              reports: { container_scanning: 'gl-container-scanning-report.json' },
              paths: ['gl-container-scanning-report.json']
            },
            dependencies: [],
            script: ['gtcs scan'],
            variables: {
              CS_ANALYZER_IMAGE: "#{Gitlab::Saas.registry_prefix}/security-products/container-scanning:4",
              GIT_STRATEGY: 'none'
            }
          }

          expect(subject.deep_symbolize_keys).to eq(expected_configuration)
        end
      end
    end

    context 'when action is invalid' do
      let_it_be(:action) { { scan: 'invalid_type' } }

      it 'returns prepared CI configuration with error script' do
        expected_configuration = {
          'allow_failure' => true,
          'script' => "echo \"Error during Scan execution: Invalid Scan type\" && false"
        }

        expect(subject).to eq(expected_configuration)
      end
    end
  end
end
