import { getFormattedSummary, preparePageInfo } from 'ee/security_dashboard/helpers';

describe('getFormattedSummary', () => {
  it('returns a properly formatted array given a valid, non-empty summary', () => {
    const summary = {
      dast: { vulnerabilitiesCount: 0 },
      containerScanning: { vulnerabilitiesCount: 1 },
      dependencyScanning: { vulnerabilitiesCount: 2 },
    };

    expect(getFormattedSummary(summary)).toEqual([
      ['DAST', summary.dast],
      ['Container Scanning', summary.containerScanning],
      ['Dependency Scanning', summary.dependencyScanning],
    ]);
  });

  it('filters empty reports out', () => {
    const summary = {
      dast: { vulnerabilitiesCount: 0 },
      containerScanning: null,
      dependencyScanning: {},
    };

    expect(getFormattedSummary(summary)).toEqual([['DAST', summary.dast]]);
  });

  it('filters invalid report types out', () => {
    const summary = {
      dast: { vulnerabilitiesCount: 0 },
      invalidReportType: { vulnerabilitiesCount: 1 },
    };

    expect(getFormattedSummary(summary)).toEqual([['DAST', summary.dast]]);
  });

  it.each([undefined, [], [1], 'hello world', 123])(
    'returns an empty array when summary is %s',
    (summary) => {
      expect(getFormattedSummary(summary)).toEqual([]);
    },
  );
});

describe('preparePageInfo', () => {
  describe('when pageInfo is empty', () => {
    it('returns pageInfo object with hasNextPage set to false', () => {
      expect(preparePageInfo(null)).toEqual({ hasNextPage: false });
    });
  });

  describe('when pageInfo.endCursor is NULL', () => {
    it('returns pageInfo object with hasNextPage set to false', () => {
      expect(preparePageInfo({ endCursor: null })).toEqual({ endCursor: null, hasNextPage: false });
    });
  });

  describe('when pageInfo.endCursor is provided', () => {
    it('returns pageInfo object with hasNextPage set to true', () => {
      expect(preparePageInfo({ endCursor: 'ENDCURSORVALUE' })).toEqual({
        endCursor: 'ENDCURSORVALUE',
        hasNextPage: true,
      });
    });
  });
});
