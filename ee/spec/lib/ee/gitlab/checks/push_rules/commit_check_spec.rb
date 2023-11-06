# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Checks::PushRules::CommitCheck do
  include_context 'push rules checks context'

  describe '#validate!' do
    context 'commit message rules' do
      let!(:push_rule) { create(:push_rule, :commit_message) }

      it_behaves_like 'check ignored when push rule unlicensed'

      it 'returns an error if the rule fails due to missing required characters' do
        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Commit message does not follow the pattern '#{push_rule.commit_message_regex}'")
      end

      it 'returns an error if the rule fails due to forbidden characters' do
        push_rule.commit_message_regex = nil
        push_rule.commit_message_negative_regex = '.*'

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Commit message contains the forbidden pattern '#{push_rule.commit_message_negative_regex}'")
      end

      it 'returns an error if the regex is invalid' do
        push_rule.commit_message_regex = '+'

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, /\ARegular expression '\+' is invalid/)
      end

      it 'returns an error if the negative regex is invalid' do
        push_rule.commit_message_regex = nil
        push_rule.commit_message_negative_regex = '+'

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, /\ARegular expression '\+' is invalid/)
      end
    end

    context 'author email rules' do
      let!(:push_rule) { create(:push_rule, author_email_regex: '.*@valid.com') }

      before do
        allow_any_instance_of(Commit).to receive(:committer_email).and_return('mike@valid.com')
        allow_any_instance_of(Commit).to receive(:author_email).and_return('mike@valid.com')
      end

      it_behaves_like 'check ignored when push rule unlicensed'

      it 'returns an error if the rule fails for the committer' do
        allow_any_instance_of(Commit).to receive(:committer_email).and_return('ana@invalid.com')

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Committer's email 'ana@invalid.com' does not follow the pattern '.*@valid.com'")
      end

      it 'returns an error if the rule fails for the author' do
        allow_any_instance_of(Commit).to receive(:author_email).and_return('joan@invalid.com')

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Author's email 'joan@invalid.com' does not follow the pattern '.*@valid.com'")
      end

      it 'returns an error if the regex is invalid' do
        push_rule.author_email_regex = '+'

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, /\ARegular expression '\+' is invalid/)
      end
    end

    context 'existing member rules' do
      let(:push_rule) { create(:push_rule, member_check: true) }

      context 'with private commit email' do
        it 'returns error if private commit email was not associated to a user' do
          user_email = "#{non_existing_record_id}-foo@#{::Gitlab::CurrentSettings.current_application_settings.commit_email_hostname}"

          allow_any_instance_of(Commit).to receive(:author_email).and_return(user_email)

          expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Author '#{user_email}' is not a member of team")
        end

        it 'returns true when private commit email was associated to a user' do
          allow_any_instance_of(Commit).to receive(:committer_email).and_return(user.private_commit_email)
          allow_any_instance_of(Commit).to receive(:author_email).and_return(user.private_commit_email)

          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'without private commit email' do
        before do
          allow_any_instance_of(Commit).to receive(:author_email).and_return('some@mail.com')
        end

        it_behaves_like 'check ignored when push rule unlicensed'

        it 'returns an error if the commit author is not a GitLab member' do
          expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Author 'some@mail.com' is not a member of team")
        end
      end
    end

    context 'GPG sign rules' do
      let(:push_rule) { create(:push_rule, reject_unsigned_commits: true) }

      before do
        stub_licensed_features(reject_unsigned_commits: true)
      end

      it_behaves_like 'check ignored when push rule unlicensed'

      context 'when it is only enabled in Global settings' do
        before do
          project.push_rule.update_column(:reject_unsigned_commits, nil)
          create(:push_rule_sample, reject_unsigned_commits: true)
        end

        context 'and commit is not signed' do
          before do
            allow_any_instance_of(Commit).to receive(:has_signature?).and_return(false)
          end

          it 'returns an error' do
            expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Commit must be signed with a GPG key")
          end
        end
      end

      context 'when enabled in Project' do
        context 'and commit is not signed' do
          before do
            allow_any_instance_of(Commit).to receive(:has_signature?).and_return(false)
          end

          it 'returns an error' do
            expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError, "Commit must be signed with a GPG key")
          end

          context 'but the change is made in the web application' do
            let(:protocol) { 'web' }

            it 'does not return an error' do
              expect { subject.validate! }.not_to raise_error
            end
          end
        end

        context 'and commit is signed' do
          before do
            allow_any_instance_of(Commit).to receive(:has_signature?).and_return(true)
          end

          it 'does not return an error' do
            expect { subject.validate! }.not_to raise_error
          end
        end
      end

      context 'when disabled in Project' do
        let(:push_rule) { create(:push_rule, reject_unsigned_commits: false) }

        context 'and commit is not signed' do
          before do
            allow_any_instance_of(Commit).to receive(:has_signature?).and_return(false)
          end

          it 'does not return an error' do
            expect { subject.validate! }.not_to raise_error
          end
        end
      end
    end

    context 'Check commit author rules' do
      let(:push_rule) { create(:push_rule, commit_committer_check: true) }

      before do
        stub_licensed_features(commit_committer_check: true)
      end

      context 'with a commit from the authenticated user' do
        context 'with private commit email' do
          it 'allows the commit when they were done with private commit email of the current user' do
            allow_any_instance_of(Commit).to receive(:committer_email).and_return(user.private_commit_email)

            expect { subject.validate! }.not_to raise_error
          end

          it 'raises an error when using an unknown private commit email' do
            user_email = "#{non_existing_record_id}-foobar@users.noreply.gitlab.com"

            allow_any_instance_of(Commit).to receive(:committer_email).and_return(user_email)

            expect { subject.validate! }
              .to raise_error(Gitlab::GitAccess::ForbiddenError,
                              "You cannot push commits for '#{user_email}'. You can only push commits that were committed with one of your own verified emails.")
          end
        end

        context 'without private commit email' do
          before do
            allow_any_instance_of(Commit).to receive(:committer_email).and_return(user.email)
          end

          it 'does not return an error' do
            expect { subject.validate! }.not_to raise_error
          end

          it 'allows the commit when they were done with another email that belongs to the current user' do
            user.emails.create(email: 'secondary_email@user.com', confirmed_at: Time.now)
            allow_any_instance_of(Commit).to receive(:committer_email).and_return('secondary_email@user.com')

            expect { subject.validate! }.not_to raise_error
          end

          it 'raises an error when the commit was done with an unverified email' do
            user.emails.create(email: 'secondary_email@user.com')
            allow_any_instance_of(Commit).to receive(:committer_email).and_return('secondary_email@user.com')

            expect { subject.validate! }
              .to raise_error(Gitlab::GitAccess::ForbiddenError,
                              "Committer email 'secondary_email@user.com' is not verified.")
          end

          it 'raises an error when using an unknown email' do
            allow_any_instance_of(Commit).to receive(:committer_email).and_return('some@mail.com')

            expect { subject.validate! }
              .to raise_error(Gitlab::GitAccess::ForbiddenError,
                              "You cannot push commits for 'some@mail.com'. You can only push commits that were committed with one of your own verified emails.")
          end
        end
      end

      context 'for an ff merge request' do
        # the signed-commits branch fast-forwards onto master
        let(:newrev) { "2d1096e3a0ecf1d2baf6dee036cc80775d4940ba" }

        before do
          allow(project.repository).to receive(:new_commits).and_call_original
        end

        it 'does not raise errors for a fast forward' do
          expect(subject).not_to receive(:committer_check)
          expect { subject.validate! }.not_to raise_error
        end
      end

      context 'for a normal merge' do
        # This creates a merge commit without adding it to a target branch
        # that is what the repository would look like during the `pre-receive` hook.
        #
        # That means only the merge commit should be validated.
        let(:newrev) do
          rugged = rugged_repo(project.repository)
          base = oldrev
          to_merge = '2d1096e3a0ecf1d2baf6dee036cc80775d4940ba'

          merge_index = rugged.merge_commits(base, to_merge)
          options = {
            parents: [base, to_merge],
            tree: merge_index.write_tree(rugged),
            message: 'The merge commit',
            author: { name: user.name, email: user.email, time: Time.now },
            committer: { name: user.name, email: user.email, time: Time.now }
          }

          Rugged::Commit.create(rugged, options)
        end

        before do
          allow(project.repository).to receive(:new_commits).and_call_original
        end

        it 'does not raise errors for a merge commit' do
          expect(subject).to receive(:committer_check).once
                                     .and_call_original

          expect { subject.validate! }.not_to raise_error
        end
      end
    end
  end
end
