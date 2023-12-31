// This file only applies to use of experiments through https://gitlab.com/gitlab-org/gitlab-experiment
import { get } from 'lodash';
import { DEFAULT_VARIANT, CANDIDATE_VARIANT, TRACKING_CONTEXT_SCHEMA } from './constants';

function getExperimentsData() {
  // Pull from deprecated window.gon.experiment
  const experimentsFromGon = get(window, ['gon', 'experiment'], {});
  // Pull from preferred window.gl.experiments
  const experimentsFromGl = get(window, ['gl', 'experiments'], {});

  return { ...experimentsFromGon, ...experimentsFromGl };
}

function convertExperimentDataToExperimentContext(experimentData) {
  // Bandaid to allow-list only the properties which the current gitlab_experiment context schema suppports.
  // See TRACKING_CONTEXT_SCHEMA for current version (1-0-0)
  // https://gitlab.com/gitlab-org/iglu/-/blob/master/public/schemas/com.gitlab/gitlab_experiment/jsonschema/1-0-0
  const { experiment: experimentName, key, variant, migration_keys } = experimentData;

  return {
    schema: TRACKING_CONTEXT_SCHEMA,
    data: { experiment: experimentName, key, variant, migration_keys },
  };
}

export function getExperimentData(experimentName) {
  return getExperimentsData()[experimentName];
}

export function getAllExperimentContexts() {
  return Object.values(getExperimentsData()).map(convertExperimentDataToExperimentContext);
}

export function isExperimentVariant(experimentName, variantName) {
  return getExperimentData(experimentName)?.variant === variantName;
}

export function getExperimentVariant(experimentName) {
  return getExperimentData(experimentName)?.variant || DEFAULT_VARIANT;
}

export function experiment(experimentName, { use, control, candidate, ...variants }) {
  const variant = getExperimentVariant(experimentName);

  switch (variant) {
    case DEFAULT_VARIANT:
      return (use || control).call();
    case CANDIDATE_VARIANT:
      return (variants.try || candidate).call();
    default:
      return variants[variant].call();
  }
}
