# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Subscriptions::Project do
  let_it_be_with_reload(:upstream_project) { create(:project, :public) }
  let_it_be_with_reload(:downstream_project) { create(:project) }

  describe 'Relations' do
    it { is_expected.to belong_to(:downstream_project).required }
    it { is_expected.to belong_to(:upstream_project).required }
  end

  it_behaves_like 'includes Limitable concern' do
    subject { build(:ci_subscriptions_project, upstream_project: upstream_project, downstream_project: downstream_project) }
  end

  describe 'Validations' do
    let!(:subscription) { create(:ci_subscriptions_project, upstream_project: upstream_project) }

    it { is_expected.to validate_uniqueness_of(:upstream_project_id).scoped_to(:downstream_project_id) }

    it 'validates that upstream project is public' do
      upstream_project.update!(visibility_level: Gitlab::VisibilityLevel::PRIVATE)

      expect(subscription).not_to be_valid
    end
  end
end
