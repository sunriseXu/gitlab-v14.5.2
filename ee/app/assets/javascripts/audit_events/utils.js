import { parsePikadayDate, pikadayToString } from '~/lib/utils/datetime_utility';
import { AVAILABLE_TOKEN_TYPES, AUDIT_FILTER_CONFIGS, ENTITY_TYPES } from './constants';
import { parseUsername, displayUsername } from './token_utils';

export const getTypeFromEntityType = (entityType) => {
  return AUDIT_FILTER_CONFIGS.find(
    ({ entityType: configEntityType }) => configEntityType === entityType,
  )?.type;
};

export const getEntityTypeFromType = (type) => {
  return AUDIT_FILTER_CONFIGS.find(({ type: configType }) => configType === type)?.entityType;
};

export const parseAuditEventSearchQuery = ({
  created_after: createdAfter,
  created_before: createdBefore,
  entity_type: entityType,
  entity_username: entityUsername,
  author_username: authorUsername,
  ...restOfParams
}) => ({
  ...restOfParams,
  created_after: createdAfter ? parsePikadayDate(createdAfter) : null,
  created_before: createdBefore ? parsePikadayDate(createdBefore) : null,
  entity_type: getTypeFromEntityType(entityType),
  entity_username: displayUsername(entityUsername),
  author_username: displayUsername(authorUsername),
});

export const createAuditEventSearchQuery = ({ filterValue, startDate, endDate, sortBy }) => {
  const entityValue = filterValue.find((value) => AVAILABLE_TOKEN_TYPES.includes(value.type));
  const entityType = getEntityTypeFromType(entityValue?.type);
  const filterData = entityValue?.value.data;

  const params = {
    created_after: startDate ? pikadayToString(startDate) : null,
    created_before: endDate ? pikadayToString(endDate) : null,
    sort: sortBy,
    entity_type: entityType,
    entity_id: null,
    entity_username: null,
    author_username: null,
    // When changing the search parameters, we should be resetting to the first page
    page: null,
  };

  switch (entityType) {
    case ENTITY_TYPES.USER:
      params.entity_username = parseUsername(filterData);
      break;
    case ENTITY_TYPES.AUTHOR:
      params.author_username = parseUsername(filterData);
      break;
    default:
      params.entity_id = filterData;
  }

  return params;
};
