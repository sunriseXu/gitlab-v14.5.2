# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::ProjectsSearch do
  subject do
    Class.new do
      include Elastic::ProjectsSearch

      def id
        1
      end

      def es_id
        1
      end
    end.new
  end

  describe '#maintain_elasticsearch_create' do
    it 'calls track!' do
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!).and_return(true)

      subject.maintain_elasticsearch_create
    end
  end

  describe '#maintain_elasticsearch_destroy' do
    it 'calls delete worker' do
      expect(ElasticDeleteProjectWorker).to receive(:perform_async)

      subject.maintain_elasticsearch_destroy
    end
  end
end
