# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Minutes::RunnersAvailability do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:instance_runner) { create(:ci_runner, :instance, :online) }

  let(:build) { build_stubbed(:ci_build, project: project) }
  let(:minutes) { described_class.new(project) }

  describe '#available?' do
    where(:shared_runners_enabled, :minutes_quota, :private_runner_available, :result) do
      true  | :with_not_used_build_minutes_limit  | false | true
      true  | :with_not_used_build_minutes_limit  | true  | true
      true  | :with_used_build_minutes_limit      | false | false
      true  | :with_used_build_minutes_limit      | true  | true
      false | :with_used_build_minutes_limit      | false | true
      false | :with_used_build_minutes_limit      | true  | true
      false | :with_not_used_build_minutes_limit  | true  | true
      false | :with_not_used_build_minutes_limit  | false | true
    end

    with_them do
      let!(:namespace) { create(:namespace, minutes_quota) }
      let!(:project) { create(:project, namespace: namespace, shared_runners_enabled: shared_runners_enabled) }
      let!(:private_runner) { create(:ci_runner, :project, :online, projects: [project], active: private_runner_available) }

      subject { minutes.available?(build.build_matcher) }

      it { is_expected.to eq(result) }
    end
  end

  context 'N+1 queries' do
    let_it_be(:project) { create(:project) }
    let_it_be(:private_runner) { create(:ci_runner, :project, :online, projects: [project]) }

    it 'caches records loaded from database' do
      ActiveRecord::QueryRecorder.new(skip_cached: false) do
        minutes.available?(build.build_matcher)
      end

      expect { minutes.available?(build.build_matcher) }.not_to exceed_all_query_limit(0)
    end
  end
end
