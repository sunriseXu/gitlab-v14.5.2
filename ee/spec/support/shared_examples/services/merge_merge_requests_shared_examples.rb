# frozen_string_literal: true

RSpec.shared_examples 'merge validation hooks' do |args|
  def hooks_error
    service.hooks_validation_error(merge_request)
  end

  def hooks_pass?
    service.hooks_validation_pass?(merge_request)
  end

  shared_examples 'hook validations are skipped when push rules unlicensed' do
    subject { service.hooks_validation_pass?(merge_request) }

    before do
      stub_licensed_features(push_rules: false)
    end

    it { is_expected.to be_truthy }
  end

  it 'returns true when valid' do
    expect(service.hooks_validation_pass?(merge_request)).to be(true)
  end

  context 'commit message validation for required characters' do
    before do
      allow(project).to receive(:push_rule) { build(:push_rule, commit_message_regex: 'unmatched pattern .*') }
    end

    it_behaves_like 'hook validations are skipped when push rules unlicensed'

    it 'returns false and matches validation error' do
      expect(hooks_pass?).to be(false)
      expect(hooks_error).not_to be_empty

      if args[:persisted]
        expect(merge_request.merge_error).to eq(hooks_error)
      else
        expect(merge_request.merge_error).to be_nil
      end
    end
  end

  context 'commit message validation for forbidden characters' do
    before do
      allow(project).to receive(:push_rule) { build(:push_rule, commit_message_negative_regex: '.*') }
    end

    it_behaves_like 'hook validations are skipped when push rules unlicensed'

    it 'returns false and saves error when invalid' do
      expect(hooks_pass?).to be(false)
      expect(hooks_error).not_to be_empty

      if args[:persisted]
        expect(merge_request.merge_error).to eq(hooks_error)
      else
        expect(merge_request.merge_error).to be_nil
      end
    end
  end

  context 'authors email validation' do
    before do
      allow(project).to receive(:push_rule) { build(:push_rule, author_email_regex: '.*@unmatchedemaildomain.com') }
    end

    it_behaves_like 'hook validations are skipped when push rules unlicensed'

    it 'returns false and saves error when invalid' do
      expect(hooks_pass?).to be(false)
      expect(hooks_error).not_to be_empty

      if args[:persisted]
        expect(merge_request.merge_error).to eq(hooks_error)
      else
        expect(merge_request.merge_error).to be_nil
      end
    end

    it 'validates against the commit email' do
      user.commit_email = 'foo@unmatchedemaildomain.com'

      expect(hooks_pass?).to be(true)
      expect(hooks_error).to be_nil
    end
  end

  context 'fast forward merge request' do
    it 'returns true when fast forward is enabled' do
      allow(project).to receive(:merge_requests_ff_only_enabled) { true }

      expect(hooks_pass?).to be(true)
      expect(hooks_error).to be_nil
    end
  end
end

RSpec.shared_examples 'service with multiple reviewers' do
  context 'with multiple reviewer assignments' do
    let(:opts) { super().merge(reviewer_ids_param) }
    let(:reviewer_ids_param) { { reviewer_ids: [reviewer1.id, reviewer2.id] } }
    let(:reviewer1) { create(:user) }
    let(:reviewer2) { create(:user) }

    before do
      stub_feature_flags(merge_request_reviewer: true)
      project.add_developer(reviewer1)
      project.add_developer(reviewer2)
    end

    context 'with multiple_merge_request_reviewers feature on' do
      before do
        stub_licensed_features(multiple_merge_request_reviewers: true)
      end

      it 'allows multiple reviewers' do
        expect(execute.reviewers).to contain_exactly(reviewer1, reviewer2)
      end
    end

    context 'with multiple_merge_request_reviewers feature off' do
      before do
        stub_licensed_features(multiple_merge_request_reviewers: false)
      end

      it 'only allows one reviewer' do
        expect(execute.reviewers).to contain_exactly(reviewer1)
      end
    end
  end
end
