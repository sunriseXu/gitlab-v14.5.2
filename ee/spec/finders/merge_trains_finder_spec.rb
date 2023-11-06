# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeTrainsFinder do
  let_it_be(:project) { create(:project) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }

  let(:finder) { described_class.new(project, user, params) }
  let(:user) { developer }
  let(:params) { {} }

  before_all do
    project.add_developer(developer)
    project.add_guest(guest)
  end

  describe '#execute' do
    subject { finder.execute }

    let!(:merge_train_1) { create(:merge_train, target_project: project) }
    let!(:merge_train_2) { create(:merge_train, target_project: project) }

    it 'returns merge trains ordered by id' do
      is_expected.to eq([merge_train_1, merge_train_2])
    end

    context 'when sort is asc' do
      let(:params) { { sort: 'asc' } }

      it 'returns merge trains in ascending order' do
        is_expected.to eq([merge_train_1, merge_train_2])
      end
    end

    context 'when sort is asc' do
      let(:params) { { sort: 'desc' } }

      it 'returns merge trains in descending order' do
        is_expected.to eq([merge_train_2, merge_train_1])
      end
    end

    context 'when user is a guest' do
      let(:user) { guest }

      it 'returns an empty list' do
        is_expected.to be_empty
      end
    end

    context 'when scope is given' do
      let!(:merge_train_1) { create(:merge_train, :idle, target_project: project) }
      let!(:merge_train_2) { create(:merge_train, :merged, target_project: project) }

      context 'when scope is active' do
        let(:params) { { scope: 'active' } }

        it 'returns active merge train' do
          is_expected.to eq([merge_train_1])
        end
      end

      context 'when scope is complete' do
        let(:params) { { scope: 'complete' } }

        it 'returns complete merge train' do
          is_expected.to eq([merge_train_2])
        end
      end
    end
  end
end
