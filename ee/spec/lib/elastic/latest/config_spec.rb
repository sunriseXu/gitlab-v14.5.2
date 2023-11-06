# frozen_string_literal: true

require 'fast_spec_helper'
require_relative './config_shared_examples'

RSpec.describe Elastic::Latest::Config do
  describe '.document_type' do
    it 'returns config' do
      expect(described_class.document_type).to eq('doc')
    end
  end

  describe '.settings' do
    it_behaves_like 'config settings return correct values'
  end

  describe '.mappings' do
    it 'returns config' do
      expect(described_class.mapping).to be_a(Elasticsearch::Model::Indexing::Mappings)
    end
  end
end
