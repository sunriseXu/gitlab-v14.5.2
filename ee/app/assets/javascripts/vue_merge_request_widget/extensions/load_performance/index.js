import { s__, sprintf, n__ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { formattedChangeInPercent } from '~/lib/utils/number_utils';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';

export default {
  name: 'WidgetLoadPerformance',
  i18n: {
    label: s__('ciReport|Load Performance'),
    loading: s__('ciReport|Load performance test metrics results are being parsed'),
  },
  expandEvent: 'i_testing_load_performance_widget_total',
  props: ['loadPerformance'],
  computed: {
    summary() {
      const { improved, degraded, same } = this.collapsedData;
      const changesFound = improved.length + degraded.length + same.length;
      const text = sprintf(
        n__(
          'ciReport|Load performance test metrics detected %{strongStart}%{changesFound}%{strongEnd} change',
          'ciReport|Load performance test metrics detected %{strongStart}%{changesFound}%{strongEnd} changes',
          changesFound,
        ),
        {
          changesFound,
          strongStart: `<strong>`,
          strongEnd: `</strong>`,
        },
        false,
      );

      const reportNumbers = [];

      if (degraded.length > 0) {
        reportNumbers.push(
          `<strong class="gl-text-red-500">${sprintf(s__('ciReport|%{degradedNum} degraded'), {
            degradedNum: degraded.length,
          })}</strong>`,
        );
      }

      if (same.length > 0) {
        reportNumbers.push(
          `<strong class="gl-text-gray-700">${sprintf(s__('ciReport|%{sameNum} same'), {
            sameNum: same.length,
          })}</strong>`,
        );
      }

      if (improved.length > 0) {
        reportNumbers.push(
          `<strong class="gl-text-green-500">${sprintf(s__('ciReport|%{improvedNum} improved'), {
            improvedNum: improved.length,
          })}</strong>`,
        );
      }

      return `${text}
      <br>
      ${reportNumbers.join(', ')}
      `;
    },
    statusIcon() {
      if (this.collapsedData.degraded.length || this.collapsedData.same.length) {
        return EXTENSION_ICONS.warning;
      }
      return EXTENSION_ICONS.success;
    },
  },
  methods: {
    fetchCollapsedData() {
      return Promise.all([
        this.fetchReport(this.loadPerformance?.head_path),
        this.fetchReport(this.loadPerformance?.base_path),
      ]).then((values) => {
        return this.compareLoadPerformanceMetrics(values[0], values[1]);
      });
    },
    fetchFullData() {
      const { improved, degraded, same } = this.collapsedData;

      return Promise.resolve([...improved, ...degraded, ...same]);
    },
    compareLoadPerformanceMetrics(headMetrics, baseMetrics) {
      const headMetricsIndexed = this.normalizeLoadPerformanceMetrics(headMetrics);
      const baseMetricsIndexed = this.normalizeLoadPerformanceMetrics(baseMetrics);
      const improved = [];
      const degraded = [];
      const same = [];

      Object.keys(headMetricsIndexed).forEach((metric) => {
        const headMetricData = headMetricsIndexed[metric];
        if (metric in baseMetricsIndexed) {
          const baseMetricData = baseMetricsIndexed[metric];
          const metricData = {
            name: metric,
            score: headMetricData,
            delta: parseFloat((parseFloat(headMetricData) - parseFloat(baseMetricData)).toFixed(2)),
          };

          if (metricData.delta !== 0.0) {
            const isImproved = [s__('ciReport|RPS'), s__('ciReport|Checks')].includes(metric)
              ? metricData.delta > 0
              : metricData.delta < 0;

            if (isImproved) {
              improved.push(
                this.prepareMetricData(metricData, {
                  name: EXTENSION_ICONS.success,
                }),
              );
            } else {
              degraded.push(
                this.prepareMetricData(metricData, {
                  name: EXTENSION_ICONS.failed,
                }),
              );
            }
          } else {
            same.push(
              this.prepareMetricData(metricData, {
                name: EXTENSION_ICONS.neutral,
              }),
            );
          }
        }
      });

      return { improved, degraded, same };
    },

    // normalize load performance metrics for comsumption
    normalizeLoadPerformanceMetrics(loadPerformanceData) {
      if (!('metrics' in loadPerformanceData)) return {};

      const { metrics } = loadPerformanceData;
      const indexedMetrics = {};

      Object.keys(loadPerformanceData.metrics).forEach((metric) => {
        switch (metric) {
          case 'http_reqs':
            indexedMetrics[s__('ciReport|RPS')] = metrics.http_reqs.rate;
            break;
          case 'http_req_waiting':
            indexedMetrics[s__('ciReport|TTFB P90')] = metrics.http_req_waiting['p(90)'];
            indexedMetrics[s__('ciReport|TTFB P95')] = metrics.http_req_waiting['p(95)'];
            break;
          case 'checks':
            indexedMetrics[s__('ciReport|Checks')] = `${(
              (metrics.checks.passes / (metrics.checks.passes + metrics.checks.fails)) *
              100.0
            ).toFixed(2)}%`;
            break;
          default:
            break;
        }
      });

      return indexedMetrics;
    },
    prepareMetricData(metricData, icon) {
      const preparedMetricData = metricData;

      const prefix = metricData.score ? `${metricData.name}:` : metricData.name;
      const score = metricData.score
        ? `<strong>${this.formatScore(metricData.score)}</strong>`
        : '';
      const delta = metricData.delta ? `(${this.formatScore(metricData.delta)})` : '';
      let deltaPercent = '';

      if (metricData.delta && metricData.score) {
        const oldScore = parseFloat(metricData.score) - metricData.delta;
        deltaPercent = `(${formattedChangeInPercent(oldScore, metricData.score)})`;
      }

      const text = `${prefix} ${score} ${delta} ${deltaPercent}`;

      preparedMetricData.icon = icon;
      preparedMetricData.text = text;

      return preparedMetricData;
    },
    formatScore(value) {
      if (Number(value) && !Number.isInteger(value)) {
        return (Math.floor(parseFloat(value) * 100) / 100).toFixed(2);
      }
      return value;
    },
    fetchReport(endpoint) {
      return axios.get(endpoint).then((res) => res.data);
    },
  },
};
