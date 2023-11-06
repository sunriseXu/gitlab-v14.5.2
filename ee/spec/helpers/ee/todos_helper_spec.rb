# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::TodosHelper do
  describe '#todo_types_options' do
    it 'includes options for an epic todo' do
      expect(helper.todo_types_options).to include(
        { id: 'Epic', text: 'Epic' }
      )
    end
  end

  describe '#todo_target_path' do
    context 'when target is vulnerability' do
      let(:vulnerability) { create(:vulnerability) }
      let(:todo) { create(:todo, target: vulnerability, project: vulnerability.project) }

      subject(:todo_target_path) { helper.todo_target_path(todo) }

      it { is_expected.to eq("/#{todo.project.full_path}/-/security/vulnerabilities/#{todo.target.id}") }
    end
  end

  describe '#todo_author_display?' do
    using RSpec::Parameterized::TableSyntax

    let!(:todo) { create(:todo) }

    subject { helper.todo_author_display?(todo) }

    where(:action, :result) do
      ::Todo::MERGE_TRAIN_REMOVED | false
      ::Todo::ASSIGNED            | true
    end

    with_them do
      before do
        todo.action = action
      end

      it { is_expected.to eq(result) }
    end
  end
end
