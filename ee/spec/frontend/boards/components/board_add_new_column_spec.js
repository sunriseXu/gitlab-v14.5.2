import { GlAvatarLabeled, GlDropdown, GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
import Vuex from 'vuex';
import BoardAddNewColumn, { listTypeInfo } from 'ee/boards/components/board_add_new_column.vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import BoardAddNewColumnForm from '~/boards/components/board_add_new_column_form.vue';
import { ListType } from '~/boards/constants';
import defaultState from '~/boards/stores/state';
import { mockAssignees, mockLists, mockIterations } from '../mock_data';

const mockLabelList = mockLists[1];

Vue.use(Vuex);

describe('BoardAddNewColumn', () => {
  let wrapper;

  const selectItem = (id) => {
    wrapper.findByTestId('selectItem').vm.$emit('change', id);
  };

  const createStore = ({ actions = {}, getters = {}, state = {} } = {}) => {
    return new Vuex.Store({
      state: {
        ...defaultState,
        ...state,
      },
      actions,
      getters,
    });
  };

  const mountComponent = ({
    selectedId,
    labels = [],
    assignees = [],
    iterations = [],
    getListByTypeId = jest.fn(),
    actions = {},
    glFeatures = {},
  } = {}) => {
    wrapper = extendedWrapper(
      shallowMount(BoardAddNewColumn, {
        stubs: {
          BoardAddNewColumnForm,
          GlFormRadio,
          GlFormRadioGroup,
        },
        data() {
          return {
            selectedId,
          };
        },
        store: createStore({
          actions: {
            fetchLabels: jest.fn(),
            setAddColumnFormVisibility: jest.fn(),
            ...actions,
          },
          getters: {
            getListByTypeId: () => getListByTypeId,
            isEpicBoard: () => false,
          },
          state: {
            labels,
            labelsLoading: false,
            assignees,
            assigneesLoading: false,
            iterations,
            iterationsLoading: false,
          },
        }),
        provide: {
          scopedLabelsAvailable: true,
          milestoneListsAvailable: true,
          assigneeListsAvailable: true,
          iterationListsAvailable: true,
          glFeatures,
        },
      }),
    );

    // trigger change event
    if (selectedId) {
      selectItem(selectedId);
    }
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findForm = () => wrapper.findComponent(BoardAddNewColumnForm);
  const cancelButton = () => wrapper.findByTestId('cancelAddNewColumn');
  const submitButton = () => wrapper.findByTestId('addNewColumnButton');
  const findLabels = () => wrapper.findComponent(GlDropdown).findAll('label');
  const findIterationPeriod = (item) => item.find('[data-testid="new-column-iteration-period"]');
  const listTypeSelect = (type) => {
    const radio = wrapper
      .findAllComponents(GlFormRadio)
      .filter((r) => r.attributes('value') === type)
      .at(0);
    radio.element.value = type;
    radio.vm.$emit('change', type);
  };
  const selectIteration = async () => {
    listTypeSelect(ListType.iteration);

    await nextTick();
  };

  it('clicking cancel hides the form', () => {
    const setAddColumnFormVisibility = jest.fn();
    mountComponent({
      actions: {
        setAddColumnFormVisibility,
      },
    });

    cancelButton().vm.$emit('click');

    expect(setAddColumnFormVisibility).toHaveBeenCalledWith(expect.anything(), false);
  });

  describe('Add list button', () => {
    it('is disabled if no item is selected', () => {
      mountComponent();

      expect(submitButton().props('disabled')).toBe(true);
    });

    it('adds a new list on click', async () => {
      const labelId = mockLabelList.label.id;
      const highlightList = jest.fn();
      const createList = jest.fn();

      mountComponent({
        labels: [mockLabelList.label],
        selectedId: labelId,
        actions: {
          createList,
          highlightList,
        },
      });

      await nextTick();

      submitButton().vm.$emit('click');

      expect(highlightList).not.toHaveBeenCalled();
      expect(createList).toHaveBeenCalledWith(expect.anything(), { labelId });
    });

    it('highlights existing list if trying to re-add', async () => {
      const getListByTypeId = jest.fn().mockReturnValue(mockLabelList);
      const highlightList = jest.fn();
      const createList = jest.fn();

      mountComponent({
        labels: [mockLabelList.label],
        selectedId: mockLabelList.label.id,
        getListByTypeId,
        actions: {
          createList,
          highlightList,
        },
      });

      await nextTick();

      submitButton().vm.$emit('click');

      expect(highlightList).toHaveBeenCalledWith(expect.anything(), mockLabelList.id);
      expect(createList).not.toHaveBeenCalled();
    });
  });

  describe('assignee list', () => {
    beforeEach(async () => {
      mountComponent({
        assignees: mockAssignees,
        actions: {
          fetchAssignees: jest.fn(),
        },
      });

      listTypeSelect(ListType.assignee);

      await nextTick();
    });

    it('sets assignee placeholder text in form', async () => {
      expect(findForm().props()).toMatchObject({
        noneSelected: listTypeInfo.assignee.noneSelected,
        searchLabel: BoardAddNewColumn.i18n.value,
        searchPlaceholder: listTypeInfo.assignee.searchPlaceholder,
      });
    });

    it('shows list of assignees', () => {
      const userList = wrapper.findAllComponents(GlAvatarLabeled);

      const [firstUser] = mockAssignees;

      expect(userList).toHaveLength(mockAssignees.length);
      expect(userList.at(0).props()).toMatchObject({
        label: firstUser.name,
        subLabel: `@${firstUser.username}`,
      });
    });
  });

  describe('iteration list', () => {
    const iterationMountOptions = {
      iterations: mockIterations,
      actions: {
        fetchIterations: jest.fn(),
      },
    };

    beforeEach(async () => {
      mountComponent({
        ...iterationMountOptions,
      });

      await selectIteration();
    });

    it('sets iteration placeholder text in form', () => {
      expect(findForm().props()).toMatchObject({
        searchLabel: BoardAddNewColumn.i18n.value,
        searchPlaceholder: listTypeInfo.iteration.searchPlaceholder,
      });
    });

    it('shows list of iterations', () => {
      const itemList = wrapper.findComponent(GlDropdown).findAllComponents(GlFormRadio);

      expect(itemList).toHaveLength(mockIterations.length);
      expect(itemList.at(0).attributes('value')).toBe(mockIterations[0].id);
      expect(itemList.at(1).attributes('value')).toBe(mockIterations[1].id);
    });

    describe('iteration_cadences feature flag is off', () => {
      it('does not display iteration period', async () => {
        const labels = findLabels();
        expect(findIterationPeriod(labels.at(0)).exists()).toBe(false);
        expect(findIterationPeriod(labels.at(1)).exists()).toBe(false);
      });
    });

    describe('iteration_cadences feature flag is on', () => {
      it('displays iteration period', async () => {
        mountComponent({
          ...iterationMountOptions,
          glFeatures: {
            iterationCadences: true,
          },
        });

        await selectIteration();

        const labels = findLabels();
        expect(labels.at(0).text()).toContain('Oct 5, 2021 - Oct 10, 2021');
        expect(findIterationPeriod(labels.at(0)).isVisible()).toBe(true);
        expect(labels.at(1).text()).toContain('Oct 12, 2021 - Oct 17, 2021');
        expect(findIterationPeriod(labels.at(1)).isVisible()).toBe(true);
      });
    });
  });
});
