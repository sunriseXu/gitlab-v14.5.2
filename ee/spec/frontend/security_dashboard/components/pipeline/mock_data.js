import { merge } from 'lodash';

export const pipelineSecurityReportSummary = {
  data: {
    project: {
      pipeline: {
        id: 'gid://gitlab/Ci::Pipeline/99',
        securityReportSummary: {
          dast: {
            vulnerabilitiesCount: 5,
            scannedResourcesCsvPath:
              '/security/security-reports/-/security/scanned_resources.csv?pipeline_id=99',
            scans: {
              nodes: [{ name: 'dast', errors: [] }],
            },
          },
          sast: {
            vulnerabilitiesCount: 67,
            scans: {
              nodes: [{ name: 'sast', errors: [] }],
            },
          },
          containerScanning: {
            vulnerabilitiesCount: 2,
            scans: {
              nodes: [
                {
                  name: 'container-scanning',
                  errors: [],
                },
              ],
            },
          },
          dependencyScanning: {
            vulnerabilitiesCount: 66,
            scans: {
              nodes: [
                {
                  name: 'dependency-scanning',
                  errors: [],
                },
              ],
            },
          },
          apiFuzzing: {
            vulnerabilitiesCount: 6,
            scans: {
              nodes: [{ name: 'api-fuzzing', errors: [] }],
            },
          },
          coverageFuzzing: {
            vulnerabilitiesCount: 1,
            scans: {
              nodes: [{ name: 'coverage-fuzzing', errors: [] }],
            },
          },
          clusterImageScanning: {
            vulnerabilitiesCount: 2,
            scans: {
              nodes: [
                {
                  name: 'cluster-image-scanning',
                  errors: [],
                },
              ],
            },
          },
        },
        jobs: {
          nodes: [
            {
              name: 'api_fuzzing',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1038/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1038/artifacts/download?file_type=api_fuzzing',
                    fileType: 'API_FUZZING',
                  },
                ],
              },
            },
            {
              name: 'coverage_fuzzing',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1037/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1037/artifacts/download?file_type=coverage_fuzzing',
                    fileType: 'COVERAGE_FUZZING',
                  },
                ],
              },
            },
            {
              name: 'sast-tslint',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1036/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1036/artifacts/download?file_type=sast',
                    fileType: 'SAST',
                  },
                ],
              },
            },
            {
              name: 'sast-spotbugs',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1035/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1035/artifacts/download?file_type=sast',
                    fileType: 'SAST',
                  },
                ],
              },
            },
            {
              name: 'sast-sobelow',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1034/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1034/artifacts/download?file_type=sast',
                    fileType: 'SAST',
                  },
                ],
              },
            },
            {
              name: 'sast-pmd-apex',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1033/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1033/artifacts/download?file_type=sast',
                    fileType: 'SAST',
                  },
                ],
              },
            },
            {
              name: 'sast-eslint',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1032/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1032/artifacts/download?file_type=sast',
                    fileType: 'SAST',
                  },
                ],
              },
            },
            {
              name: 'secrets',
              artifacts: {
                nodes: [
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1031/artifacts/download?file_type=trace',
                    fileType: 'TRACE',
                  },
                  {
                    downloadPath:
                      '/security/security-reports/-/jobs/1031/artifacts/download?file_type=secret_detection',
                    fileType: 'SECRET_DETECTION',
                  },
                ],
              },
            },
          ],
        },
      },
    },
  },
};

export const scansWithErrors = [{ errors: ['error description'], name: 'scan-name' }];

export const pipelineSecurityReportSummaryWithErrors = merge({}, pipelineSecurityReportSummary, {
  data: {
    project: {
      pipeline: {
        securityReportSummary: {
          dast: {
            scans: {
              nodes: scansWithErrors,
            },
          },
        },
      },
    },
  },
});

export const pipelineSecurityReportSummaryEmpty = merge({}, pipelineSecurityReportSummary, {
  data: {
    project: {
      pipeline: {
        securityReportSummary: null,
      },
    },
  },
});
