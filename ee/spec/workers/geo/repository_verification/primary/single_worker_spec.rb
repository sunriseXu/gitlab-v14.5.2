# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::RepositoryVerification::Primary::SingleWorker, :clean_gitlab_redis_cache do
  include ::EE::GeoHelpers
  include ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project) }

  let!(:primary) { create(:geo_node, :primary) }

  before do
    stub_current_geo_node(primary)
  end

  it 'disables retrying of failed jobs' do
    expect(subject.sidekiq_options_hash).to match(
      'retry' => false,
      'version' => an_instance_of(Integer),
      'queue' => 'geo:geo_repository_verification_primary_single',
      'queue_namespace' => :geo
    )
  end

  describe '#perform' do
    it 'does not calculate the checksum when not running on a primary' do
      allow(Gitlab::Geo).to receive(:primary?) { false }

      subject.perform(project.id)

      expect(project.reload.repository_state).to be_nil
    end

    it 'does not calculate the checksum when project is pending deletion' do
      project.update!(pending_delete: true)

      subject.perform(project.id)

      expect(project.reload.repository_state).to be_nil
    end

    it 'does not raise an error when project could not be found' do
      expect { subject.perform(-1) }.not_to raise_error
    end

    it 'delegates the checksum calculation to Geo::RepositoryVerificationPrimaryService' do
      stub_exclusive_lease

      service = instance_double(Geo::RepositoryVerificationPrimaryService, execute: true)

      allow(Geo::RepositoryVerificationPrimaryService)
        .to receive(:new)
        .with(project)
        .and_return(service)

      subject.perform(project.id)

      expect(service).to have_received(:execute)
    end
  end
end
