# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Iterations::UpdateService do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:iteration) { create(:iteration, group: group) }

  describe '#execute' do
    context "valid params" do
      before do
        group.add_maintainer(user)
      end

      subject { described_class.new(group, user, { title: 'new_title' }).execute(iteration) }

      it { expect(subject).to be_success }
      it { expect(subject.payload[:iteration].title).to eq('new_title') }

      it 'ignores state change attempts' do
        expect do
          described_class.new(group, user, { state_enum: 'activate' }).execute(iteration)
        end.not_to change { iteration.state_enum }
      end
    end
  end
end
