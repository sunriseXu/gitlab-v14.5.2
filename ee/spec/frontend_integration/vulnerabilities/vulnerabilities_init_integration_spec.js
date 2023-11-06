import { screen, within } from '@testing-library/dom';
import initVulnerabilities from 'ee/vulnerabilities/vulnerabilities_init';
import { waitForText } from 'helpers/wait_for_text';
import { mockIssueLink } from '../test_helpers/mock_data/vulnerabilities_mock_data';
import { mockVulnerability } from './mock_data';

describe('Vulnerability Report', () => {
  let vm;
  let container;

  const createComponent = () => {
    const el = document.createElement('div');
    const elDataSet = {
      vulnerability: JSON.stringify(mockVulnerability),
    };

    Object.assign(el.dataset, {
      ...elDataSet,
    });

    container.appendChild(el);

    return initVulnerabilities(el);
  };

  beforeEach(() => {
    setFixtures('<div class="vulnerability-details"></div>');

    container = document.querySelector('.vulnerability-details');
    vm = createComponent(container);
  });

  afterEach(() => {
    vm.$destroy();
    vm = null;
    container = null;
  });

  it("displays the vulnerability's status", () => {
    const headerBody = screen.getByTestId('vulnerability-detail-body');

    expect(within(headerBody).getByText(mockVulnerability.state)).toBeInstanceOf(HTMLElement);
  });

  it("displays the vulnerability's severity", () => {
    const severitySection = screen.getByTestId('severity');
    const severityValue = within(severitySection).getByTestId('value');

    expect(severityValue.textContent.toLowerCase()).toContain(
      mockVulnerability.severity.toLowerCase(),
    );
  });

  it("displays a heading containing the vulnerability's title", () => {
    expect(screen.getByRole('heading', { name: mockVulnerability.title })).toBeInstanceOf(
      HTMLElement,
    );
  });

  it("displays the vulnerability's description", () => {
    expect(screen.getByText(mockVulnerability.description)).toBeInstanceOf(HTMLElement);
  });

  it('displays related issues', async () => {
    const relatedIssueTitle = await waitForText(mockIssueLink.title);

    expect(relatedIssueTitle).toBeInstanceOf(HTMLElement);
  });
});
