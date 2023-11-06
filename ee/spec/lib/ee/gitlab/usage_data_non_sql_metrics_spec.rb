# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::UsageDataNonSqlMetrics do
  include UsageDataHelpers

  before do
    stub_usage_data_connections
  end

  describe '.uncached_data' do
    it 'does make instrumentations_class DB calls' do
      recorder = ActiveRecord::QueryRecorder.new do
        described_class.uncached_data
      end

      expect(recorder.count).to eq(61)
    end
  end
end
