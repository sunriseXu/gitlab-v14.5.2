# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AutocompleteService do
  let_it_be(:group, refind: true) { create(:group, :nested, :private, avatar: fixture_file_upload('spec/fixtures/dk.png')) }
  let_it_be(:sub_group) { create(:group, :private, parent: group) }

  let(:user) { create(:user) }
  let!(:epic) { create(:epic, group: group, author: user) }

  subject { described_class.new(group, user) }

  before do
    group.add_developer(user)
  end

  def expect_labels_to_equal(labels, expected_labels)
    extract_title = lambda { |label| label['title'] }
    expect(labels.map(&extract_title)).to match_array(expected_labels.map(&extract_title))
  end

  describe '#labels_as_hash' do
    let!(:label1) { create(:group_label, group: group) }
    let!(:label2) { create(:group_label, group: group) }
    let!(:sub_group_label) { create(:group_label, group: sub_group) }
    let!(:parent_group_label) { create(:group_label, group: group.parent) }

    context 'some labels are already assigned' do
      before do
        epic.labels << label1
      end

      it 'marks already assigned as set' do
        results = subject.labels_as_hash(epic)
        expected_labels = [label1, label2, parent_group_label]

        expect_labels_to_equal(results, expected_labels)

        assigned_label_titles = epic.labels.map(&:title)
        results.each do |hash|
          if assigned_label_titles.include?(hash['title'])
            expect(hash[:set]).to eq(true)
          else
            expect(hash.key?(:set)).to eq(false)
          end
        end
      end
    end
  end

  describe '#epics' do
    let(:expected_attributes) { %i(iid title group_id) }

    before do
      stub_licensed_features(epics: true)
    end

    it 'returns nothing if not allowed' do
      guest = create(:user)

      epics = described_class.new(group, guest).epics

      expect(epics).to be_empty
    end

    it 'returns epics from group' do
      result = subject.epics.map { |epic| epic.slice(expected_attributes) }

      expect(result).to contain_exactly(epic.slice(expected_attributes))
    end

    it 'returns only confidential epics if confidential_only is true' do
      confidential_epic = create(:epic, :confidential, group: group)

      result = subject.epics(confidential_only: true)
                 .map { |epic| epic.slice(expected_attributes) }

      expect(result).to contain_exactly(confidential_epic.slice(expected_attributes))
    end
  end

  describe '#vulnerability' do
    let_it_be_with_refind(:project) { create(:project, group: group) }
    let_it_be(:vulnerability) { create(:vulnerability, project: project) }
    let_it_be(:guest) { create(:user) }

    let(:autocomplete_user) { user }

    subject { described_class.new(group, autocomplete_user).vulnerabilities.map(&:id) }

    context 'when the feature is not available' do
      context 'when the user is not allowed' do
        it { is_expected.to be_empty }
      end

      context 'when the user is allowed' do
        before do
          project.add_developer(user)
        end

        it { is_expected.to be_empty }
      end
    end

    context 'when the feature is available' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when the user is not allowed' do
        let(:autocomplete_user) { guest }

        it { is_expected.to be_empty }
      end

      context 'when the user is allowed' do
        before do
          project.add_developer(user)
        end

        it { is_expected.to contain_exactly(vulnerability.id) }
      end
    end
  end

  describe '#commands' do
    context 'when target is an epic' do
      let(:parent_epic) { create(:epic, group: group, author: user) }
      let(:epic)        { create(:epic, group: group, author: user, parent: parent_epic) }

      context 'with subepics feature enabled' do
        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        it 'returns available commands' do
          available_commands = [
            :todo, :unsubscribe, :award, :shrug, :tableflip, :cc, :title, :close,
            :child_epic, :remove_child_epic, :parent_epic, :remove_parent_epic
          ]

          expect(subject.commands(epic).map { |c| c[:name] }).to match_array(available_commands)
        end
      end

      context 'with subepics feature disabled' do
        before do
          stub_licensed_features(epics: true, subepics: false)
        end

        it 'returns available commands' do
          available_commands = [
            :todo, :unsubscribe, :award, :shrug, :tableflip, :cc, :title, :close
          ]

          expect(subject.commands(epic).map { |c| c[:name] }).to match_array(available_commands)
        end
      end
    end
  end
end
