import {
  getTypeFromEntityType,
  getEntityTypeFromType,
  parseAuditEventSearchQuery,
  createAuditEventSearchQuery,
} from 'ee/audit_events/utils';

describe('Audit Event Utils', () => {
  describe('getTypeFromEntityType', () => {
    it('returns the correct type when given a valid entity type', () => {
      expect(getTypeFromEntityType('User')).toEqual('user');
    });

    it('returns `undefined` when given an invalid entity type', () => {
      expect(getTypeFromEntityType('ABCDEF')).toBeUndefined();
    });
  });

  describe('getEntityTypeFromType', () => {
    it('returns the correct entity type when given a valid type', () => {
      expect(getEntityTypeFromType('member')).toEqual('Author');
    });

    it('returns `undefined` when given an invalid type', () => {
      expect(getTypeFromEntityType('abcdef')).toBeUndefined();
    });
  });

  describe('parseAuditEventSearchQuery', () => {
    it('returns a query object with parsed date values', () => {
      const input = {
        created_after: '2020-03-13',
        created_before: '2020-04-13',
        sortBy: 'created_asc',
      };

      expect(parseAuditEventSearchQuery(input)).toMatchObject({
        created_after: new Date('2020-03-13'),
        created_before: new Date('2020-04-13'),
        sortBy: 'created_asc',
      });
    });
  });

  describe('createAuditEventSearchQuery', () => {
    const createFilterParams = (type, data) => ({
      filterValue: [{ type, value: { data, operator: '=' } }],
      startDate: new Date('2020-03-13'),
      endDate: new Date('2020-04-13'),
      sortBy: 'bar',
    });

    it.each`
      type         | entity_type  | data       | entity_id | entity_username | author_username
      ${'user'}    | ${'User'}    | ${'@root'} | ${null}   | ${'root'}       | ${null}
      ${'member'}  | ${'Author'}  | ${'@root'} | ${null}   | ${null}         | ${'root'}
      ${'project'} | ${'Project'} | ${'1'}     | ${'1'}    | ${null}         | ${null}
      ${'group'}   | ${'Group'}   | ${'1'}     | ${'1'}    | ${null}         | ${null}
    `(
      'returns a query object with remapped keys and stringified dates for type $type',
      ({ type, entity_type, data, entity_id, entity_username, author_username }) => {
        const input = createFilterParams(type, data);

        expect(createAuditEventSearchQuery(input)).toEqual({
          entity_id,
          entity_username,
          author_username,
          entity_type,
          created_after: '2020-03-13',
          created_before: '2020-04-13',
          sort: 'bar',
          page: null,
        });
      },
    );
  });
});
