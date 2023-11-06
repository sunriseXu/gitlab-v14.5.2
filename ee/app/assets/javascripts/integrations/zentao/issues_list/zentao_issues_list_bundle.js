import externalIssuesListFactory from 'ee/external_issues_list';
import zentaoLogo from 'images/logos/zentao.svg';
import { s__ } from '~/locale';
import getIssuesQuery from './graphql/queries/get_zentao_issues.query.graphql';
import zentaoIssues from './graphql/resolvers/zentao_issues';

export default externalIssuesListFactory({
  externalIssuesQueryResolver: zentaoIssues,
  provides: {
    getIssuesQuery,
    externalIssuesLogo: zentaoLogo,
    // This like below is passed to <gl-sprintf :message="%authorName in {}" />
    // So we don't translate it since this should be a proper noun
    externalIssueTrackerName: 'ZenTao',
    searchInputPlaceholderText: s__('Integrations|Search ZenTao issues'),
    recentSearchesStorageKey: 'zentao_issues',
    createNewIssueText: s__('Integrations|Create new issue in ZenTao'),
    logoContainerClass: 'logo-container',
    emptyStateNoIssueText: s__(
      'Integrations|ZenTao issues display here when you create issues in your project in ZenTao.',
    ),
  },
});
