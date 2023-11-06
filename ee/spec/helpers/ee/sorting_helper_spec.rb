# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SortingHelper do
  describe '#sort_direction_icon' do
    it 'returns lowest for weight' do
      expect(sort_direction_icon('weight')).to eq('sort-lowest')
    end

    it 'behaves like non-ee for other sort values' do
      expect(sort_direction_icon('milestone')).to eq('sort-lowest')
      expect(sort_direction_icon('last_joined')).to eq('sort-highest')
    end
  end
end
