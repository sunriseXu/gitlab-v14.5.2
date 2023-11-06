# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ResetChecksumEvent, type: :model do
  describe 'relationships' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
  end
end
