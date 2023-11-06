import { GlLink, GlSprintf } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import MergeImmediatelyConfirmationDialog from 'ee/vue_merge_request_widget/components/merge_immediately_confirmation_dialog.vue';
import MergeTrainFailedPipelineConfirmationDialog from 'ee/vue_merge_request_widget/components/merge_train_failed_pipeline_confirmation_dialog.vue';
import MergeTrainHelperIcon from 'ee/vue_merge_request_widget/components/merge_train_helper_icon.vue';
import { MERGE_DISABLED_TEXT_UNAPPROVED } from 'ee/vue_merge_request_widget/mixins/ready_to_merge';
import ReadyToMerge from '~/vue_merge_request_widget/components/states/ready_to_merge.vue';
import {
  MWPS_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
  MTWPS_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';
import {
  MERGE_DISABLED_TEXT,
  MERGE_DISABLED_SKIPPED_PIPELINE_TEXT,
  PIPELINE_MUST_SUCCEED_CONFLICT_TEXT,
  PIPELINE_SKIPPED_STATUS,
} from '~/vue_merge_request_widget/mixins/ready_to_merge';

describe('ReadyToMerge', () => {
  let wrapper;
  let vm;

  const service = {
    merge: () => {},
    poll: () => {},
  };

  const activePipeline = {
    id: 1,
    path: 'path/to/pipeline',
    active: true,
  };

  const mr = {
    isPipelineActive: false,
    pipeline: { id: 1, path: 'path/to/pipeline' },
    isPipelineFailed: false,
    isPipelinePassing: false,
    isMergeAllowed: true,
    onlyAllowMergeIfPipelineSucceeds: false,
    ffOnlyEnabled: false,
    hasCI: false,
    ciStatus: null,
    sha: '12345678',
    squash: false,
    squashIsEnabledByDefault: false,
    squashIsReadonly: false,
    squashIsSelected: false,
    commitMessage: 'This is the commit message',
    squashCommitMessage: 'This is the squash commit message',
    commitMessageWithDescription: 'This is the commit message description',
    shouldRemoveSourceBranch: true,
    canRemoveSourceBranch: false,
    targetBranch: 'main',
    preferredAutoMergeStrategy: MWPS_MERGE_STRATEGY,
    availableAutoMergeStrategies: [MWPS_MERGE_STRATEGY],
    mergeImmediatelyDocsPath: 'path/to/merge/immediately/docs',
    mergeTrainWhenPipelineSucceedsDocsPath: '/merge-train/docs',
    mergeTrainsCount: 0,
  };

  const factory = (mrUpdates = {}, shallow = true) => {
    const func = shallow ? shallowMount : mount;
    wrapper = func(ReadyToMerge, {
      propsData: {
        mr: { ...mr, ...mrUpdates },
        service,
      },
      stubs: {
        MergeImmediatelyConfirmationDialog,
        MergeTrainHelperIcon,
        GlSprintf,
        GlLink,
        MergeTrainFailedPipelineConfirmationDialog,
      },
    });

    ({ vm } = wrapper);
  };

  const findResolveItemsMessage = () => wrapper.find(GlSprintf);
  const findPipelineConflictMessage = () =>
    wrapper.find('[data-testid="pipeline-succeed-conflict"]');
  const findMergeButton = () => wrapper.find('[data-testid="merge-button"]');
  const findMergeButtonDropdown = () => wrapper.find('.js-merge-moment');
  const findMergeImmediatelyButton = () => wrapper.find('.js-merge-immediately-button');
  const findMergeTrainHelperIcon = () => wrapper.find(MergeTrainHelperIcon);
  const findFailedPipelineMergeTrainText = () =>
    wrapper.find('[data-testid="failed-pipeline-merge-train-text"]');
  const findMergeTrainFailedPipelineConfirmationDialog = () =>
    wrapper.findComponent(MergeTrainFailedPipelineConfirmationDialog);

  afterEach(() => {
    if (wrapper?.destroy) {
      wrapper.destroy();
      wrapper = null;
    }
  });

  describe('computed', () => {
    describe('mergeButtonText', () => {
      it('should return "Merge" when no auto merge strategies are available', () => {
        factory({ availableAutoMergeStrategies: [] });

        expect(vm.mergeButtonText).toEqual('Merge');
      });

      it('should return "Merge in progress"', () => {
        factory();
        wrapper.setData({ isMergingImmediately: true });

        expect(vm.mergeButtonText).toEqual('Merge in progress');
      });

      it('should return "Merge when pipeline succeeds" when the MWPS auto merge strategy is available', () => {
        factory({
          preferredAutoMergeStrategy: MWPS_MERGE_STRATEGY,
        });

        expect(vm.mergeButtonText).toEqual('Merge when pipeline succeeds');
      });

      it('should return "Start merge train" when the merge train auto merge stategy is available and there is no existing merge train', () => {
        factory({
          preferredAutoMergeStrategy: MT_MERGE_STRATEGY,
          mergeTrainsCount: 0,
        });

        expect(vm.mergeButtonText).toEqual('Start merge train');
      });

      it('should return "Add to merge train" when the merge train auto merge stategy is available and a merge train already exists', () => {
        factory({
          preferredAutoMergeStrategy: MT_MERGE_STRATEGY,
          mergeTrainsCount: 1,
        });

        expect(vm.mergeButtonText).toEqual('Add to merge train');
      });

      it('should return "Start merge train when pipeline succeeds" when the MTWPS auto merge strategy is available and there is no existing merge train', () => {
        factory({
          preferredAutoMergeStrategy: MTWPS_MERGE_STRATEGY,
          mergeTrainsCount: 0,
        });

        expect(vm.mergeButtonText).toEqual('Start merge train when pipeline succeeds');
      });

      it('should return "Add to merge train when pipeline succeeds" when the MTWPS auto merge strategy is available and a merge train already exists', () => {
        factory({
          preferredAutoMergeStrategy: MTWPS_MERGE_STRATEGY,
          mergeTrainsCount: 1,
        });

        expect(vm.mergeButtonText).toEqual('Add to merge train when pipeline succeeds');
      });
    });

    describe('autoMergeText', () => {
      it('should return Merge when pipeline succeeds', () => {
        factory({ preferredAutoMergeStrategy: MWPS_MERGE_STRATEGY });

        expect(vm.autoMergeText).toEqual('Merge when pipeline succeeds');
      });

      it('should return Start merge train when pipeline succeeds', () => {
        factory({
          preferredAutoMergeStrategy: MTWPS_MERGE_STRATEGY,
          mergeTrainsCount: 0,
        });

        expect(vm.autoMergeText).toEqual('Start merge train when pipeline succeeds');
      });

      it('should return Add to merge train when pipeline succeeds', () => {
        factory({
          preferredAutoMergeStrategy: MTWPS_MERGE_STRATEGY,
          mergeTrainsCount: 1,
        });

        expect(vm.autoMergeText).toEqual('Add to merge train when pipeline succeeds');
      });
    });

    describe('isMergeImmediatelyDangerous', () => {
      it('should return false if the preferred auto merge strategy is not merge train-related', () => {
        factory({ preferredAutoMergeStrategy: MWPS_MERGE_STRATEGY });

        expect(vm.isMergeImmediatelyDangerous).toBe(false);
      });

      it('should return true if the preferred auto merge strategy is merge trains', () => {
        factory({ preferredAutoMergeStrategy: MT_MERGE_STRATEGY });

        expect(vm.isMergeImmediatelyDangerous).toBe(true);
      });

      it('should return true if the preferred auto merge strategy is merge trains when pipeline succeeds', () => {
        factory({ preferredAutoMergeStrategy: MTWPS_MERGE_STRATEGY });

        expect(vm.isMergeImmediatelyDangerous).toBe(true);
      });
    });
  });

  describe('shouldRenderMergeTrainHelperIcon', () => {
    it('should render the helper icon if MTWPS is available and the user has not yet pressed the MTWPS button', () => {
      factory({
        onlyAllowMergeIfPipelineSucceeds: true,
        preferredAutoMergeStrategy: MTWPS_MERGE_STRATEGY,
        autoMergeEnabled: false,
      });

      expect(findMergeTrainHelperIcon().exists()).toBe(true);
    });
  });

  describe('merge train helper icon', () => {
    it('does not render the merge train helper icon if the MTWPS strategy is not available', () => {
      factory({
        availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
        pipeline: activePipeline,
      });

      expect(findMergeTrainHelperIcon().exists()).toBe(false);
    });
  });

  describe('shouldShowMergeImmediatelyDropdown', () => {
    it('should return false if no pipeline is active', () => {
      factory({
        isPipelineActive: false,
        onlyAllowMergeIfPipelineSucceeds: false,
      });

      expect(vm.shouldShowMergeImmediatelyDropdown).toBe(false);
    });

    it('should return false if "Pipelines must succeed" is enabled for the current project', () => {
      factory({
        isPipelineActive: true,
        onlyAllowMergeIfPipelineSucceeds: true,
      });

      expect(vm.shouldShowMergeImmediatelyDropdown).toBe(false);
    });

    it('should return true if the MR\'s pipeline is active and "Pipelines must succeed" is not enabled for the current project', () => {
      factory({
        isPipelineActive: true,
        onlyAllowMergeIfPipelineSucceeds: false,
      });

      expect(vm.shouldShowMergeImmediatelyDropdown).toBe(true);
    });

    it('should return true when the merge train auto merge stategy is available ', () => {
      factory({
        preferredAutoMergeStrategy: MT_MERGE_STRATEGY,
        isPipelineActive: false,
        onlyAllowMergeIfPipelineSucceeds: true,
      });

      expect(vm.shouldShowMergeImmediatelyDropdown).toBe(true);
    });
  });

  describe('merge train failed confirmation dialog', () => {
    it.each`
      mergeStrategy           | isPipelineFailed | isVisible
      ${MT_MERGE_STRATEGY}    | ${true}          | ${true}
      ${MT_MERGE_STRATEGY}    | ${false}         | ${false}
      ${MTWPS_MERGE_STRATEGY} | ${true}          | ${false}
      ${MWPS_MERGE_STRATEGY}  | ${true}          | ${false}
    `(
      'with merge stragtegy $mergeStrategy and pipeline failed status of $isPipelineFailed we should show the modal: $isVisible',
      async ({ mergeStrategy, isPipelineFailed, isVisible }) => {
        factory({ preferredAutoMergeStrategy: mergeStrategy, isPipelineFailed });
        const modalConfirmation = findMergeTrainFailedPipelineConfirmationDialog();

        if (!isVisible) {
          // need to mock if we don't show modal
          // to prevent internals from being invoked
          vm.handleMergeButtonClick = jest.fn();
        }

        await findMergeButton().vm.$emit('click');

        expect(modalConfirmation.props('visible')).toBe(isVisible);
      },
    );
  });

  describe('merge immediately warning dialog', () => {
    let dialog;

    const clickMergeImmediately = () => {
      dialog = wrapper.find(MergeImmediatelyConfirmationDialog);

      expect(dialog.exists()).toBe(true);
      dialog.vm.show = jest.fn();
      vm.handleMergeButtonClick = jest.fn();
      findMergeButtonDropdown().trigger('click');
      return wrapper.vm.$nextTick().then(() => {
        findMergeImmediatelyButton().trigger('click');
        return wrapper.vm.$nextTick();
      });
    };

    it('should show a warning dialog asking for confirmation if the user is trying to skip the merge train', () => {
      factory({ preferredAutoMergeStrategy: MT_MERGE_STRATEGY }, false);
      return clickMergeImmediately().then(() => {
        expect(dialog.vm.show).toHaveBeenCalled();
        expect(vm.handleMergeButtonClick).not.toHaveBeenCalled();
      });
    });

    it('should perform the merge when the user confirms their intent to merge immediately', () => {
      factory({ preferredAutoMergeStrategy: MT_MERGE_STRATEGY }, false);
      return clickMergeImmediately()
        .then(() => {
          dialog.vm.$emit('mergeImmediately');
          return wrapper.vm.$nextTick();
        })
        .then(() => {
          // false (no auto merge), true (merge immediately), true (confirmation clicked)
          expect(vm.handleMergeButtonClick).toHaveBeenCalledWith(false, true, true);
        });
    });

    it('should not ask for confirmation in non-merge train scenarios', () => {
      factory(
        {
          isPipelineActive: true,
          onlyAllowMergeIfPipelineSucceeds: false,
        },
        false,
      );
      return clickMergeImmediately().then(() => {
        expect(dialog.vm.show).not.toHaveBeenCalled();
        expect(vm.handleMergeButtonClick).toHaveBeenCalled();
      });
    });
  });

  describe('cannot merge', () => {
    describe('when isMergeAllowed=false', () => {
      it('should show merge blocked because of skipped pipeline text', () => {
        factory({
          isMergeAllowed: false,
          availableAutoMergeStrategies: [],
          pipeline: { id: 1, path: 'path/to/pipeline', status: PIPELINE_SKIPPED_STATUS },
        });

        expect(findResolveItemsMessage().text()).toBe(MERGE_DISABLED_SKIPPED_PIPELINE_TEXT);
      });

      it('should show cannot merge text', () => {
        factory({
          isMergeAllowed: false,
          availableAutoMergeStrategies: [],
        });

        expect(findResolveItemsMessage().text()).toBe(MERGE_DISABLED_TEXT);
      });

      it('should show disabled merge button', () => {
        factory({
          isMergeAllowed: false,
          availableAutoMergeStrategies: [],
        });

        const button = findMergeButton();

        expect(button.exists()).toBe(true);
        expect(button.attributes('disabled')).toBe('true');
      });
    });
  });

  describe('when needs approval', () => {
    beforeEach(() => {
      factory({
        isMergeAllowed: false,
        availableAutoMergeStrategies: [],
        hasApprovalsAvailable: true,
        isApproved: false,
      });
    });

    it('should show approvals needed text', () => {
      expect(findResolveItemsMessage().text()).toBe(MERGE_DISABLED_TEXT_UNAPPROVED);
    });
  });

  describe('when no CI service are found and enforce `Pipeline must succeed`', () => {
    beforeEach(() => {
      factory({
        isMergeAllowed: false,
        availableAutoMergeStrategies: [],
        hasCI: false,
        onlyAllowMergeIfPipelineSucceeds: true,
      });
    });

    it('should show a custom message that explains the conflict', () => {
      expect(findPipelineConflictMessage().text()).toBe(PIPELINE_MUST_SUCCEED_CONFLICT_TEXT);
    });
  });

  describe('Merge button variant', () => {
    it('danger variant and failed text should show if pipeline failed', () => {
      factory({
        isPipelineFailed: true,
        preferredAutoMergeStrategy: MT_MERGE_STRATEGY,
        availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
        hasCI: true,
        onlyAllowMergeIfPipelineSucceeds: false,
      });

      expect(findMergeButton().attributes('variant')).toBe('danger');
      expect(findFailedPipelineMergeTrainText().exists()).toBe(true);
    });

    it('confirm variant and failed text should not show if pipeline passed', () => {
      factory({
        preferredAutoMergeStrategy: MT_MERGE_STRATEGY,
        availableAutoMergeStrategies: [MT_MERGE_STRATEGY],
        hasCI: true,
        onlyAllowMergeIfPipelineSucceeds: false,
        ciStatus: 'success',
      });

      expect(findMergeButton().attributes('variant')).toBe('confirm');
      expect(findFailedPipelineMergeTrainText().exists()).toBe(false);
    });
  });
});
