import { GlButton, GlDropdown, GlDropdownItem } from '@gitlab/ui';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import Vuex from 'vuex';
import LabelsSelect from 'ee/boards/components/labels_select.vue';

import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import {
  boardObj,
  mockProjectLabelsResponse,
  mockGroupLabelsResponse,
  mockLabel1,
} from 'jest/boards/mock_data';

import defaultStore from '~/boards/stores';
import searchGroupLabels from '~/vue_shared/components/sidebar/labels_select_widget/graphql/group_labels.query.graphql';
import searchProjectLabels from '~/vue_shared/components/sidebar/labels_select_widget/graphql/project_labels.query.graphql';
import DropdownValue from '~/vue_shared/components/sidebar/labels_select_widget/dropdown_value.vue';
import DropdownWidget from '~/vue_shared/components/dropdown/dropdown_widget/dropdown_widget.vue';

const localVue = createLocalVue();
localVue.use(VueApollo);

describe('Labels select component', () => {
  let wrapper;
  let fakeApollo;
  let store;

  const selectedText = () => wrapper.find('[data-testid="selected-labels"]').text();
  const findEditButton = () => wrapper.findComponent(GlButton);
  const findDropdown = () => wrapper.findComponent(DropdownWidget);
  const findDropdownValue = () => wrapper.findComponent(DropdownValue);

  const projectLabelsQueryHandlerSuccess = jest.fn().mockResolvedValue(mockProjectLabelsResponse);
  const groupLabelsQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupLabelsResponse);

  async function openLabelsDropdown() {
    findEditButton().vm.$emit('click');
    await waitForPromises();
  }

  const createStore = ({ isGroupBoard = false, isProjectBoard = false } = {}) => {
    store = new Vuex.Store({
      ...defaultStore,
      actions: {
        setError: jest.fn(),
      },
      getters: {
        isGroupBoard: () => isGroupBoard,
        isProjectBoard: () => isProjectBoard,
      },
      state: {
        boardType: isGroupBoard ? 'group' : 'project',
      },
    });
  };

  const createComponent = ({ props = {} } = {}) => {
    fakeApollo = createMockApollo([
      [searchProjectLabels, projectLabelsQueryHandlerSuccess],
      [searchGroupLabels, groupLabelsQueryHandlerSuccess],
    ]);
    wrapper = shallowMount(LabelsSelect, {
      localVue,
      store,
      apolloProvider: fakeApollo,
      propsData: {
        board: boardObj,
        canEdit: true,
        ...props,
      },
      provide: {
        fullPath: 'gitlab-org',
        labelsManagePath: 'gitlab-org/labels',
      },
      stubs: {
        GlDropdown,
        GlDropdownItem,
      },
    });

    // We need to mock out `showDropdown` which
    // invokes `show` method of BDropdown used inside GlDropdown.
    wrapper.vm.$refs.editDropdown.showDropdown = jest.fn();
  };

  beforeEach(() => {
    createStore({ isProjectBoard: true });
    createComponent();
  });

  afterEach(() => {
    wrapper.destroy();
    fakeApollo = null;
    store = null;
  });

  describe('when not editing', () => {
    it('defaults to Any label', () => {
      expect(selectedText()).toContain('Any label');
    });

    it('skips the queries and does not render dropdown', () => {
      expect(projectLabelsQueryHandlerSuccess).not.toHaveBeenCalled();
      expect(findDropdown().isVisible()).toBe(false);
    });

    it('renders selected labels in DropdownValue', async () => {
      await openLabelsDropdown();
      findDropdown().vm.$emit('set-option', mockLabel1);

      await openLabelsDropdown();
      expect(findDropdownValue().isVisible()).toBe(true);
      expect(findDropdownValue().props('selectedLabels')).toEqual([mockLabel1]);
    });
  });

  describe('when editing', () => {
    it('trigger query and renders dropdown with passed labels', async () => {
      await openLabelsDropdown();
      expect(projectLabelsQueryHandlerSuccess).toHaveBeenCalled();

      expect(findDropdown().isVisible()).toBe(true);
      expect(findDropdown().props('options')).toHaveLength(2);
    });
  });

  describe('canEdit', () => {
    it('hides Edit button', async () => {
      wrapper.setProps({ canEdit: false });
      await nextTick();

      expect(findEditButton().exists()).toBe(false);
    });

    it('shows Edit button if true', () => {
      expect(findEditButton().exists()).toBe(true);
    });
  });

  it.each`
    boardType    | mockedResponse               | queryHandler                        | notCalledHandler
    ${'group'}   | ${mockGroupLabelsResponse}   | ${groupLabelsQueryHandlerSuccess}   | ${projectLabelsQueryHandlerSuccess}
    ${'project'} | ${mockProjectLabelsResponse} | ${projectLabelsQueryHandlerSuccess} | ${groupLabelsQueryHandlerSuccess}
  `(
    'fetches $boardType labels',
    async ({ boardType, mockedResponse, queryHandler, notCalledHandler }) => {
      createStore({ isProjectBoard: boardType === 'project', isGroupBoard: boardType === 'group' });
      createComponent({
        [queryHandler]: jest.fn().mockResolvedValue(mockedResponse),
      });
      await openLabelsDropdown();

      expect(queryHandler).toHaveBeenCalled();
      expect(notCalledHandler).not.toHaveBeenCalled();
    },
  );
});
