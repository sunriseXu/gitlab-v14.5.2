# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ManuallyCreateService do
  before do
    stub_licensed_features(security_dashboard: true)
  end

  let_it_be(:user) { create(:user) }

  let(:project) { create(:project) } # cannot use let_it_be here: caching causes problems with permission-related tests

  subject { described_class.new(project, user, params: params).execute }

  context 'with an authorized user with proper permissions' do
    before do
      project.add_developer(user)
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(create_vulnerabilities_via_api: false)
      end

      let(:scanner_attributes) do
        {
          id: "my-custom-scanner",
          name: "My Custom Scanner",
          url: "https://superscanner.com",
          vendor: vendor_attributes,
          version: "21.37.00"
        }
      end

      let(:vendor_attributes) do
        {
          name: "Custom Scanner Vendor"
        }
      end

      let(:identifier_attributes) do
        {
          name: "Test identifier 1",
          url: "https://test.com"
        }
      end

      let(:params) do
        {
          vulnerability: {
            name: "Test vulnerability",
            state: "detected",
            severity: "unknown",
            confidence: "unknown",
            identifiers: [identifier_attributes],
            scanner: scanner_attributes,
            solution: "rm -rf --no-preserve-root /"
          }
        }
      end

      it 'returns an error' do
        result = subject
        expect(result.success?).to be_falsey
        expect(subject.message).to match(/create_vulnerabilities_via_api feature flag is not enabled for this project/)
      end
    end

    context 'when feature flag is enabled' do
      before do
        stub_feature_flags(create_vulnerabilities_via_api: project)
      end

      context 'with valid parameters' do
        let(:scanner_attributes) do
          {
            id: "my-custom-scanner",
            name: "My Custom Scanner",
            url: "https://superscanner.com",
            vendor: vendor_attributes,
            version: "21.37.00"
          }
        end

        let(:vendor_attributes) do
          {
            name: "Custom Scanner Vendor"
          }
        end

        let(:identifier_attributes) do
          {
            name: "Test identifier 1",
            url: "https://test.com"
          }
        end

        let(:identifier_fingerprint) do
          Digest::SHA1.hexdigest("other:#{identifier_attributes[:name]}")
        end

        let(:params) do
          {
            vulnerability: {
              name: "Test vulnerability",
              state: "detected",
              severity: "unknown",
              confidence: "unknown",
              identifiers: [identifier_attributes],
              scanner: scanner_attributes,
              solution: "Explanation of how to fix the vulnerability.",
              description: "A long text section describing the vulnerability more fully.",
              message: "A short text section that describes the vulnerability. This may include the finding's specific information."
            }
          }
        end

        let(:vulnerability) { subject.payload[:vulnerability] }

        context 'with custom external_type and external_id' do
          let(:identifier_attributes) do
            {
              name: "Test identifier 1",
              url: "https://test.com",
              external_id: "my external id",
              external_type: "my external type"
            }
          end

          let(:identifier_fingerprint) do
            Digest::SHA1.hexdigest("#{identifier_attributes[:external_type]}:#{identifier_attributes[:external_id]}")
          end

          it 'uses them to create a Vulnerabilities::Identifier' do
            primary_identifier = vulnerability.finding.primary_identifier
            expect(primary_identifier.external_id).to eq(identifier_attributes.dig(:external_id))
            expect(primary_identifier.external_type).to eq(identifier_attributes.dig(:external_type))
            expect(primary_identifier.fingerprint).to eq(identifier_fingerprint)
          end
        end

        it 'does not exceed query limit' do
          expect { subject }.not_to exceed_query_limit(20)
        end

        it 'creates a new Vulnerability' do
          expect { subject }.to change(Vulnerability, :count).by(1)
        end

        it 'creates a Vulnerability with correct attributes' do
          expect(vulnerability.report_type).to eq("generic")
          expect(vulnerability.state).to eq(params.dig(:vulnerability, :state))
          expect(vulnerability.severity).to eq(params.dig(:vulnerability, :severity))
          expect(vulnerability.confidence).to eq(params.dig(:vulnerability, :confidence))
        end

        it 'creates associated objects', :aggregate_failures do
          expect { subject }.to change(Vulnerabilities::Finding, :count).by(1)
            .and change(Vulnerabilities::Scanner, :count).by(1)
            .and change(Vulnerabilities::Identifier, :count).by(1)
        end

        context 'when Scanner already exists' do
          let!(:scanner) { create(:vulnerabilities_scanner, external_id: scanner_attributes[:id]) }

          it 'does not create a new Scanner' do
            expect { subject }.to change(Vulnerabilities::Scanner, :count).by(0)
          end
        end

        context 'when Identifier already exists' do
          let!(:identifier) { create(:vulnerabilities_identifier, name: identifier_attributes[:name]) }

          it 'does not create a new Identifier' do
            expect { subject }.not_to change(Vulnerabilities::Identifier, :count)
          end
        end

        it 'creates all objects with correct attributes' do
          expect(vulnerability.title).to eq(params.dig(:vulnerability, :name))
          expect(vulnerability.report_type).to eq("generic")
          expect(vulnerability.state).to eq(params.dig(:vulnerability, :state))
          expect(vulnerability.severity).to eq(params.dig(:vulnerability, :severity))
          expect(vulnerability.confidence).to eq(params.dig(:vulnerability, :confidence))
          expect(vulnerability.description).to eq(params.dig(:vulnerability, :description))
          expect(vulnerability.finding_description).to eq(params.dig(:vulnerability, :description))
          expect(vulnerability.finding_message).to eq(params.dig(:vulnerability, :message))
          expect(vulnerability.solution).to eq(params.dig(:vulnerability, :solution))

          finding = vulnerability.finding
          expect(finding.report_type).to eq("generic")
          expect(finding.severity).to eq(params.dig(:vulnerability, :severity))
          expect(finding.confidence).to eq(params.dig(:vulnerability, :confidence))
          expect(finding.message).to eq(params.dig(:vulnerability, :message))
          expect(finding.description).to eq(params.dig(:vulnerability, :description))
          expect(finding.solution).to eq(params.dig(:vulnerability, :solution))

          scanner = finding.scanner
          expect(scanner.name).to eq(params.dig(:vulnerability, :scanner, :name))

          primary_identifier = finding.primary_identifier
          expect(primary_identifier.name).to eq(params.dig(:vulnerability, :identifiers, 0, :name))
          expect(primary_identifier.url).to eq(params.dig(:vulnerability, :identifiers, 0, :url))
          expect(primary_identifier.external_id).to eq(params.dig(:vulnerability, :identifiers, 0, :name))
          expect(primary_identifier.external_type).to eq("other")
          expect(primary_identifier.fingerprint).to eq(identifier_fingerprint)
        end

        context "when state fields match state" do
          let(:params) do
            {
              vulnerability: {
                name: "Test vulnerability",
                state: "confirmed",
                severity: "unknown",
                confidence: "unknown",
                confirmed_at: Time.now.iso8601,
                identifiers: [identifier_attributes],
                scanner: scanner_attributes
              }
            }
          end

          it 'creates Vulnerability in a different state with timestamps' do
            freeze_time do
              expect(vulnerability.state).to eq(params.dig(:vulnerability, :state))
              expect(vulnerability.confirmed_at).to eq(params.dig(:vulnerability, :confirmed_at))
              expect(vulnerability.confirmed_by).to eq(user)
            end
          end
        end

        context "when state fields don't match state" do
          let(:params) do
            {
              vulnerability: {
                name: "Test vulnerability",
                state: "detected",
                severity: "unknown",
                confidence: "unknown",
                confirmed_at: Time.now.iso8601,
                identifiers: [identifier_attributes],
                scanner: scanner_attributes
              }
            }
          end

          it 'returns an error' do
            result = subject
            expect(result.success?).to be_falsey
            expect(subject.message).to match(/confirmed_at can only be set/)
          end
        end
      end

      context 'with invalid parameters' do
        let(:params) do
          {
            vulnerability: {
              identifiers: [{
                name: "Test identfier 1",
                url: "https://test.com"
              }],
              scanner: {
                name: "My manual scanner"
              }
            }
          }
        end

        it 'returns an error' do
          expect(subject.error?).to be_truthy
        end
      end
    end
  end

  context 'when user does not have rights to dismiss a vulnerability' do
    let(:params) { {} }

    before do
      project.add_reporter(user)
    end

    it 'raises an "access denied" error' do
      expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
    end
  end
end
