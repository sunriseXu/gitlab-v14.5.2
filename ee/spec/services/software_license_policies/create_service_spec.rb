# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicies::CreateService do
  let(:project) { create(:project) }
  let(:params) { { name: 'ExamplePL/2.1', approval_status: 'blacklisted' } }

  let(:user) do
    create(:user).tap do |u|
      project.add_maintainer(u)
    end
  end

  before do
    stub_licensed_features(license_scanning: true)
  end

  subject { described_class.new(project, user, params) }

  describe '#execute' do
    context 'with license management unavailable' do
      before do
        stub_licensed_features(license_scanning: false)
      end

      it 'does not creates a software license policy' do
        expect { subject.execute }.to change { project.software_license_policies.count }.by(0)
      end
    end

    context 'with a user who is allowed to admin' do
      context 'when valid parameters are specified' do
        where(:approval_status, :expected_classification) do
          [
            %w[allowed allowed],
            %w[approved allowed],
            %w[denied denied],
            %w[blacklisted denied]
          ]
        end

        with_them do
          let(:params) { { name: 'MIT', approval_status: approval_status } }
          let(:result) { subject.execute }

          before do
            allow(RefreshLicenseComplianceChecksWorker).to receive(:perform_async)
            result
          end

          it 'creates one software license policy correctly' do
            expect(project.software_license_policies.count).to be(1)
            expect(result[:status]).to be(:success)
            expect(result[:software_license_policy]).to be_present
            expect(result[:software_license_policy]).to be_persisted
            expect(result[:software_license_policy].name).to eql(params[:name])
            expect(result[:software_license_policy].classification).to eql(expected_classification)
            expect(RefreshLicenseComplianceChecksWorker).to have_received(:perform_async).with(project.id)
          end
        end
      end

      context "when an argument error is raised" do
        before do
          allow_next_instance_of(Project) do |instance|
            allow(instance).to receive(:software_license_policies).and_raise(ArgumentError)
          end
        end

        specify { expect(subject.execute[:status]).to be(:error) }
        specify { expect(subject.execute[:message]).to be_present }
        specify { expect(subject.execute[:http_status]).to be(400) }
      end

      context "when invalid input is provided" do
        before do
          params[:approval_status] = nil
        end

        specify { expect(subject.execute[:status]).to be(:error) }
        specify { expect(subject.execute[:message]).to be_present }
        specify { expect(subject.execute[:http_status]).to be(400) }
      end
    end

    context 'with a user not allowed to admin' do
      let(:user) { create(:user) }

      it 'does not create a software license policy' do
        expect { subject.execute }.to change { project.software_license_policies.count }.by(0)
      end
    end
  end
end
