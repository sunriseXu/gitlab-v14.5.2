# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNoteService do
  include ProjectForksHelper
  include Gitlab::Routing
  include RepoHelpers

  let_it_be(:group)    { create(:group) }
  let_it_be(:project)  { create(:project, :repository, group: group) }
  let_it_be(:author)   { create(:user) }
  let_it_be(:noteable) { create(:issue, project: project) }
  let_it_be(:issue)    { noteable }
  let_it_be(:epic)     { create(:epic, group: group) }

  describe '.change_health_status_note' do
    it 'calls IssuableService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:change_health_status_note)
      end

      described_class.change_health_status_note(noteable, project, author)
    end
  end

  describe '.change_epic_date_note' do
    let(:date_type) { double }
    let(:date) { double }

    it 'calls EpicsService' do
      expect_next_instance_of(SystemNotes::EpicsService) do |service|
        expect(service).to receive(:change_epic_date_note).with(date_type, date)
      end

      described_class.change_epic_date_note(noteable, author, date_type, date)
    end
  end

  describe '.epic_issue' do
    let(:type) { double }

    it 'calls EpicsService' do
      expect_next_instance_of(SystemNotes::EpicsService) do |service|
        expect(service).to receive(:epic_issue).with(noteable, type)
      end

      described_class.epic_issue(epic, noteable, author, type)
    end
  end

  describe '.issue_on_epic' do
    let(:type) { double }

    it 'calls EpicsService' do
      expect_next_instance_of(SystemNotes::EpicsService) do |service|
        expect(service).to receive(:issue_on_epic).with(noteable, type)
      end

      described_class.issue_on_epic(noteable, epic, author, type)
    end
  end

  describe '.change_epics_relation' do
    let(:child_epic) { double }
    let(:type) { double }

    it 'calls EpicsService' do
      expect_next_instance_of(SystemNotes::EpicsService) do |service|
        expect(service).to receive(:change_epics_relation).with(child_epic, type)
      end

      described_class.change_epics_relation(epic, child_epic, author, type)
    end
  end

  describe '.merge_train' do
    let(:merge_train) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:enqueue).with(merge_train)
      end

      described_class.merge_train(noteable, project, author, merge_train)
    end
  end

  describe '.cancel_merge_train' do
    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:cancel)
      end

      described_class.cancel_merge_train(noteable, project, author)
    end
  end

  describe '.abort_merge_train' do
    let(:message) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:abort).with(message)
      end

      described_class.abort_merge_train(noteable, project, author, message)
    end
  end

  describe '.add_to_merge_train_when_pipeline_succeeds' do
    let(:sha) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:add_when_pipeline_succeeds).with(sha)
      end

      described_class.add_to_merge_train_when_pipeline_succeeds(noteable, project, author, sha)
    end
  end

  describe '.cancel_add_to_merge_train_when_pipeline_succeeds' do
    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:cancel_add_when_pipeline_succeeds)
      end

      described_class.cancel_add_to_merge_train_when_pipeline_succeeds(noteable, project, author)
    end
  end

  describe '.abort_add_to_merge_train_when_pipeline_succeeds' do
    let(:message) { double }

    it 'calls MergeTrainService' do
      expect_next_instance_of(SystemNotes::MergeTrainService) do |service|
        expect(service).to receive(:abort_add_when_pipeline_succeeds).with(message)
      end

      described_class.abort_add_to_merge_train_when_pipeline_succeeds(noteable, project, author, message)
    end
  end

  describe '.change_vulnerability_state' do
    it 'calls VulnerabilitiesService' do
      expect_next_instance_of(SystemNotes::VulnerabilitiesService) do |service|
        expect(service).to receive(:change_vulnerability_state)
      end

      described_class.change_vulnerability_state(noteable, author)
    end
  end

  describe '.publish_issue_to_status_page' do
    it 'calls IssuablesService' do
      expect_next_instance_of(::SystemNotes::IssuablesService) do |service|
        expect(service).to receive(:publish_issue_to_status_page)
      end

      described_class.publish_issue_to_status_page(noteable, project, author)
    end
  end
end
