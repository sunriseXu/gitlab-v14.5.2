# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserDetail do
  it { is_expected.to belong_to(:provisioned_by_group) }

  describe '#provisioned_by_group?' do
    let(:user) { create(:user, provisioned_by_group: build(:group)) }

    subject { user.user_detail.provisioned_by_group? }

    it 'returns true when user is provisoned by group' do
      expect(subject).to eq(true)
    end

    it 'returns true when user is provisoned by group' do
      user.user_detail.update!(provisioned_by_group: nil)

      expect(subject).to eq(false)
    end
  end
end
