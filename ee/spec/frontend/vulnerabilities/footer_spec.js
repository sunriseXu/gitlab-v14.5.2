import { GlLoadingIcon } from '@gitlab/ui';
import Visibility from 'visibilityjs';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import Api from 'ee/api';
import vulnerabilityDiscussionsQuery from 'ee/security_dashboard/graphql/queries/vulnerability_discussions.query.graphql';
import MergeRequestNote from 'ee/vue_shared/security_reports/components/merge_request_note.vue';
import SolutionCard from 'ee/vue_shared/security_reports/components/solution_card.vue';
import VulnerabilityFooter from 'ee/vulnerabilities/components/footer.vue';
import GenericReportSection from 'ee/vulnerabilities/components/generic_report/report_section.vue';
import HistoryEntry from 'ee/vulnerabilities/components/history_entry.vue';
import RelatedIssues from 'ee/vulnerabilities/components/related_issues.vue';
import RelatedJiraIssues from 'ee/vulnerabilities/components/related_jira_issues.vue';
import StatusDescription from 'ee/vulnerabilities/components/status_description.vue';
import { VULNERABILITY_STATES } from 'ee/vulnerabilities/constants';
import { normalizeGraphQLNote } from 'ee/vulnerabilities/helpers';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createFlash from '~/flash';
import initUserPopovers from '~/user_popovers';
import { generateNote } from './mock_data';

jest.mock('~/flash');
jest.mock('~/user_popovers');

Vue.use(VueApollo);

describe('Vulnerability Footer', () => {
  let wrapper;

  const vulnerability = {
    id: 1,
    notesUrl: '/notes',
    project: {
      fullPath: '/root/security-reports',
      fullName: 'Administrator / Security Reports',
    },
    canModifyRelatedIssues: true,
    relatedIssuesHelpPath: 'help/path',
    hasMr: false,
    pipeline: {},
  };

  let discussion1;
  let discussion2;

  const discussionsHandler = ({
    discussions: nodes,
    errors = [],
    success = true,
    handler = jest.fn(),
  }) =>
    handler[success ? 'mockResolvedValueOnce' : 'mockRejectedValueOnce']({
      data: {
        errors,
        vulnerability: {
          id: `gid://gitlab/Vulnerability/${vulnerability.id}`,
          discussions: {
            nodes,
          },
        },
      },
    });

  const createWrapper = ({ properties, queryHandler, mountOptions } = {}) => {
    wrapper = shallowMountExtended(VulnerabilityFooter, {
      propsData: { vulnerability: { ...vulnerability, ...properties } },
      apolloProvider: createMockApollo([[vulnerabilityDiscussionsQuery, queryHandler]]),
      ...mountOptions,
    });
  };

  const findDiscussions = () => wrapper.findAllComponents(HistoryEntry);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findMergeRequestNote = () => wrapper.findComponent(MergeRequestNote);
  const findRelatedIssues = () => wrapper.findComponent(RelatedIssues);
  const findRelatedJiraIssues = () => wrapper.findComponent(RelatedJiraIssues);

  beforeEach(() => {
    discussion1 = {
      id: 'gid://gitlab/Discussion/7b4aa2d000ec81ba374a29b3ca3ee4c5f274f9ab',
      replyId: 'gid://gitlab/Discussion/7b4aa2d000ec81ba374a29b3ca3ee4c5f274f9ab',
      notes: {
        nodes: [generateNote({ id: 100 })],
      },
    };

    discussion2 = {
      id: 'gid://gitlab/Discussion/0656f86109dc755c99c288c54d154b9705aaa796',
      replyId: 'gid://gitlab/Discussion/0656f86109dc755c99c288c54d154b9705aaa796',
      notes: {
        nodes: [generateNote({ id: 200 })],
      },
    };
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('discussions', () => {
    const createWrapperAndFetchDiscussions = async ({ discussions, errors, success }) => {
      createWrapper({ queryHandler: discussionsHandler({ discussions, errors, success }) });
      await waitForPromises();
    };

    const refetchDiscussions = async () => {
      findDiscussions().at(0).vm.$emit('onCommentUpdated');
      await waitForPromises();
    };

    it('displays a loading spinner while fetching discussions', async () => {
      createWrapper({ queryHandler: discussionsHandler({ discussions: [] }) });
      expect(findDiscussions().exists()).toBe(false);
      expect(findLoadingIcon().exists()).toBe(true);
      await waitForPromises();
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('fetches discussions and notes on mount', async () => {
      await createWrapperAndFetchDiscussions({ discussions: [discussion1, discussion2] });

      expect(findDiscussions().at(0).props()).toStrictEqual({
        discussion: {
          ...discussion1,
          notes: [normalizeGraphQLNote(discussion1.notes.nodes[0])],
        },
      });

      expect(findDiscussions().at(1).props()).toStrictEqual({
        discussion: {
          ...discussion2,
          notes: [normalizeGraphQLNote(discussion2.notes.nodes[0])],
        },
      });
    });

    it('calls initUserPopovers when the component is updated', async () => {
      createWrapper({ queryHandler: discussionsHandler({ discussions: [] }) });
      expect(initUserPopovers).not.toHaveBeenCalled();
      await waitForPromises();
      expect(initUserPopovers).toHaveBeenCalled();
    });

    it('shows an error the discussions could not be retrieved', async () => {
      await createWrapperAndFetchDiscussions({
        errors: [{ message: 'Something went wrong' }],
        success: false,
      });
      expect(createFlash).toHaveBeenCalledWith({
        message:
          'Something went wrong while trying to retrieve the vulnerability history. Please try again later.',
      });
    });

    it('polls the server every 10 seconds for new discussions and attaches a listener to visibility-js', async () => {
      const setIntervalSpy = jest.spyOn(window, 'setInterval');
      const visibilityChangeSpy = jest.spyOn(Visibility, 'change');
      createWrapper({ queryHandler: discussionsHandler({ discussions: [] }) });
      expect(setIntervalSpy).not.toHaveBeenCalled();
      expect(visibilityChangeSpy).not.toHaveBeenCalled();
      await waitForPromises();
      expect(setIntervalSpy).toHaveBeenCalledWith(wrapper.vm.fetchDiscussions, 10000);
      expect(visibilityChangeSpy).toHaveBeenCalled();
    });

    it('removes the poll and visibility listener when unmounted', async () => {
      const clearIntervalSpy = jest.spyOn(window, 'clearInterval');
      const visibilityUnbindSpy = jest.spyOn(Visibility, 'unbind');
      await createWrapperAndFetchDiscussions({ discussions: [] });
      wrapper.destroy();
      expect(clearIntervalSpy).toHaveBeenCalled();
      expect(visibilityUnbindSpy).toHaveBeenCalled();
    });

    it('does not remove the listener when the visibility changes', async () => {
      const clearIntervalSpy = jest.spyOn(window, 'clearInterval');
      const visibilityUnbindSpy = jest.spyOn(Visibility, 'unbind');
      const visibilityHiddenSpy = jest
        .spyOn(Visibility, 'hidden')
        .mockImplementationOnce(() => false) // This is called in startPolling
        .mockImplementationOnce(() => true); // This is called in visibilityChangeListener
      const visibilityChangeSpy = jest
        .spyOn(Visibility, 'change')
        .mockImplementation((callback) => callback());
      await createWrapperAndFetchDiscussions({ discussions: [] });
      expect(visibilityHiddenSpy).toHaveBeenCalled();
      expect(visibilityChangeSpy).toHaveBeenCalled();
      expect(clearIntervalSpy).toHaveBeenCalled();
      expect(visibilityUnbindSpy).not.toHaveBeenCalled();
    });

    it('emits the vulnerability-state-change event when the system note is new', async () => {
      const eventName = 'vulnerability-state-change';
      const queryHandler = discussionsHandler({ discussions: [discussion1] }); // first call
      discussionsHandler({ discussions: [discussion1], handler: queryHandler }); // second call is the same
      discussionsHandler({ discussions: [discussion1, discussion2], handler: queryHandler }); // for the third call we change the number of discussions

      createWrapper({
        queryHandler,
      });

      // Wait that the initial call has been made
      await waitForPromises();

      // At this stage the handler should not be called because it's the first call (so page load).
      expect(wrapper.emitted(eventName)).toBeUndefined();

      // Fetch again with same data
      await refetchDiscussions();

      // There should be no new discussions so the event should be emitted once
      expect(wrapper.emitted(eventName)).toBeUndefined();

      // Fetch again with different data
      await refetchDiscussions();

      // The event should be emitted once as there is a new discussion
      expect(wrapper.emitted(eventName)).toHaveLength(1);
    });
  });

  describe('solution card', () => {
    it('does show solution card when there is one', () => {
      const properties = { remediations: [{ diff: [{}] }], solution: 'some solution' };
      createWrapper({ properties, discussionsHandler: discussionsHandler({ discussions: [] }) });

      expect(wrapper.find(SolutionCard).exists()).toBe(true);
      expect(wrapper.find(SolutionCard).props()).toEqual({
        solution: properties.solution,
        remediation: properties.remediations[0],
        hasDownload: true,
        hasMr: vulnerability.hasMr,
      });
    });

    it('does not show solution card when there is not one', () => {
      createWrapper();
      expect(wrapper.find(SolutionCard).exists()).toBe(false);
    });
  });

  describe('merge request note', () => {
    it('does not show merge request note when a merge request does not exist for the vulnerability', () => {
      createWrapper();
      expect(findMergeRequestNote().exists()).toBe(false);
    });

    it('shows merge request note when a merge request exists for the vulnerability', () => {
      // The object itself does not matter, we just want to make sure it's passed to the issue note.
      const mergeRequestFeedback = {};

      createWrapper({ properties: { mergeRequestFeedback } });
      expect(findMergeRequestNote().exists()).toBe(true);
      expect(findMergeRequestNote().props('feedback')).toBe(mergeRequestFeedback);
    });
  });

  describe('related issues', () => {
    it('has the correct props', () => {
      const endpoint = Api.buildUrl(Api.vulnerabilityIssueLinksPath).replace(
        ':id',
        vulnerability.id,
      );

      createWrapper();

      expect(findRelatedIssues().exists()).toBe(true);
      expect(findRelatedIssues().props()).toMatchObject({
        endpoint,
        canModifyRelatedIssues: vulnerability.canModifyRelatedIssues,
        projectPath: vulnerability.project.fullPath,
        helpPath: vulnerability.relatedIssuesHelpPath,
      });
    });
  });

  describe('related jira issues', () => {
    describe.each`
      createJiraIssueUrl | shouldShowRelatedJiraIssues
      ${'http://foo'}    | ${true}
      ${''}              | ${false}
    `(
      'with "createJiraIssueUrl" set to "$createJiraIssueUrl"',
      ({ createJiraIssueUrl, shouldShowRelatedJiraIssues }) => {
        beforeEach(() => {
          createWrapper({
            mountOptions: {
              provide: {
                createJiraIssueUrl,
              },
            },
          });
        });

        it(`${
          shouldShowRelatedJiraIssues ? 'should' : 'should not'
        } show related Jira issues`, () => {
          expect(findRelatedJiraIssues().exists()).toBe(shouldShowRelatedJiraIssues);
        });
      },
    );
  });

  describe('detection note', () => {
    const detectionNote = () => wrapper.find('[data-testid="detection-note"]');
    const statusDescription = () => wrapper.find(StatusDescription);
    const vulnerabilityStates = Object.keys(VULNERABILITY_STATES);

    it.each(vulnerabilityStates)(
      `shows detection note when vulnerability state is '%s'`,
      (state) => {
        createWrapper({ properties: { state } });

        expect(detectionNote().exists()).toBe(true);
        expect(statusDescription().props('vulnerability')).toEqual({
          state: 'detected',
          pipeline: vulnerability.pipeline,
        });
      },
    );
  });

  describe('generic report', () => {
    const mockDetails = { foo: { type: 'bar' } };

    const genericReportSection = () => wrapper.findComponent(GenericReportSection);

    describe('when a vulnerability contains a details property', () => {
      beforeEach(() => {
        createWrapper({ properties: { details: mockDetails } });
      });

      it('renders the report section', () => {
        expect(genericReportSection().exists()).toBe(true);
      });

      it('passes the correct props to the report section', () => {
        expect(genericReportSection().props()).toMatchObject({
          details: mockDetails,
        });
      });
    });

    describe('when a vulnerability does not contain a details property', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('does not render the report section', () => {
        expect(genericReportSection().exists()).toBe(false);
      });
    });
  });
});
