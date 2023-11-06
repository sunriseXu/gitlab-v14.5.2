# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::MigrateRequirementsToWorkItems, schema: 20211005194425 do
  let(:issues) { table(:issues) }
  let(:requirements) { table(:requirements) }
  let(:namespaces) { table(:namespaces) }
  let(:users) { table(:users) }
  let(:projects) { table(:projects) }
  let(:internal_ids) { table(:internal_ids) }
  let!(:group) { namespaces.create!(name: 'gitlab', path: 'gitlab-org') }

  let!(:project) { projects.create!(namespace_id: group.id, name: 'gitlab', path: 'gitlab') }
  let!(:project2) { projects.create!(namespace_id: group.id, name: 'gitlab2', path: 'gitlab2') }

  let!(:user1) { users.create!(email: 'author@example.com', notification_email: 'author@example.com', name: 'author', username: 'author', projects_limit: 10, state: 'active') }
  let!(:user2) { users.create!(email: 'author2@example.com', notification_email: 'author2@example.com', name: 'author2', username: 'author2', projects_limit: 10, state: 'active') }

  let(:migration) { described_class::MIGRATION }
  let!(:issue) { issues.create!(iid: 5, state_id: 1, project_id: project2.id) }

  let!(:requirement_1) { requirements.create!(iid: 1, project_id: project.id, author_id: user1.id, title: 'r 1', state: 1, created_at: 2.days.ago, updated_at: 1.day.ago) }

  # Already in sync
  let!(:requirement_2) { requirements.create!(iid: 2, project_id: project2.id, author_id: user1.id, issue_id: issue.id, title: 'r 2', state: 1, created_at: Time.current, updated_at: Time.current) }

  let!(:requirement_3) { requirements.create!(iid: 3, project_id: project.id, title: 'r 3', state: 1, created_at: 3.days.ago, updated_at: 2.days.ago) }
  let!(:requirement_4) { requirements.create!(iid: 99, project_id: project2.id, author_id: user1.id, title: 'r 4', state: 2, created_at: 1.hour.ago, updated_at: Time.current) }
  let!(:requirement_5) { requirements.create!(iid: 5, project_id: project2.id, author_id: user2.id, title: 'r 5', state: 1, created_at: 2.hours.ago, updated_at: Time.current) }

  let(:now) { Time.now.utc.to_s }

  around do |example|
    freeze_time { example.run }
  end

  it 'creates work items for not synced requirements' do
    expect do
      described_class.new.perform(requirement_1.id, requirement_5.id)
    end.to change { issues.count }.by(4)
  end

  it 'creates requirement work items with correct attributes' do
    described_class.new.perform(requirement_1.id, requirement_5.id)

    [requirement_1, requirement_3, requirement_4, requirement_5].each do |requirement|
      issue = issues.find(requirement.reload.issue_id)

      expect(issue.issue_type).to eq(3) # requirement work item type
      expect(issue.title).to eq(requirement.title)
      expect(issue.description).to eq(requirement.description)
      expect(issue.project_id).to eq(requirement.project_id)
      expect(issue.state_id).to eq(requirement.state)
      expect(issue.author_id).to eq(requirement.author_id)
      expect(issue.iid).to be_present
      expect(issue.created_at).to eq(requirement.created_at)
      expect(issue.updated_at.to_s).to eq(now) # issues updated_at column do not persist timezone
    end
  end

  it 'populates iid correctly' do
    described_class.new.perform(requirement_1.id, requirement_5.id)

    # Projects without issues
    expect(issues.find(requirement_1.reload.issue_id).iid).to eq(1)
    expect(issues.find(requirement_3.reload.issue_id).iid).to eq(2)
    # Project that already has one issue with iid = 5
    expect(issues.find(requirement_4.reload.issue_id).iid).to eq(6)
    expect(issues.find(requirement_5.reload.issue_id).iid).to eq(7)
  end

  it 'tracks iid greatest value' do
    internal_ids.create!(project_id: issue.project_id, usage: 0, last_value: issue.iid)

    described_class.new.perform(requirement_1.id, requirement_5.id)

    expect(internal_ids.count).to eq(2) # Creates record for project when there is not one
    expect(internal_ids.find_by_project_id(project.id).last_value).to eq(2)
    expect(internal_ids.find_by_project_id(project2.id).last_value).to eq(7)
  end
end
