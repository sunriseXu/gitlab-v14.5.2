import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import COLUMNS from '../constants';

export default class GroupMemberStore {
  constructor(memberContributionsPath) {
    this.memberContributionsPath = memberContributionsPath;

    this.state = {};
    this.state.isLoading = true;
    this.state.members = [];
    this.state.columns = [];
    this.state.sortOrders = {};
    this.state.currentSortedColumn = '';
  }

  get isLoading() {
    return this.state.isLoading;
  }

  get members() {
    return this.state.members;
  }

  get sortOrders() {
    return this.state.sortOrders;
  }

  setColumns(columns) {
    this.state.columns = columns;
    this.state.sortOrders = this.state.columns.reduce(
      (acc, column) => ({ ...acc, [column.name]: 1 }),
      {},
    );
  }

  setMembers(rawMembers) {
    this.state.members = rawMembers.map((rawMember) => GroupMemberStore.formatMember(rawMember));
  }

  sortMembers(sortByColumn) {
    if (sortByColumn) {
      this.state.currentSortedColumn = sortByColumn;
      this.state.sortOrders[sortByColumn] *= -1;

      const currentColumnOrder = this.state.sortOrders[sortByColumn] || 1;
      const members = this.state.members.slice().sort((a, b) => {
        let delta = -1;
        const columnOrderA = a[sortByColumn];
        const columnOrderB = b[sortByColumn];

        if (columnOrderA === columnOrderB) {
          delta = 0;
        } else if (columnOrderA > columnOrderB) {
          delta = 1;
        }

        return delta * currentColumnOrder;
      });

      this.state.members = members;
    }
  }

  fetchContributedMembers() {
    return axios
      .get(this.memberContributionsPath)
      .then((res) => res.data)
      .then((members) => {
        this.setColumns(COLUMNS);
        this.setMembers(members);
        this.state.isLoading = false;
      })
      .catch((e) => {
        this.state.isLoading = false;
        createFlash({
          message: __('Something went wrong while fetching group member contributions'),
        });
        throw e;
      });
  }

  static formatMember(rawMember) {
    return convertObjectPropsToCamelCase(rawMember);
  }
}
