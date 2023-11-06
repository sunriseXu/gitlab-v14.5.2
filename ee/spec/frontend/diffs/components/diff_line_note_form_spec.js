import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import diffFileMockData from 'jest/diffs/mock_data/diff_file';
import note from 'jest/notes/mock_data';
import DiffLineNoteForm from '~/diffs/components/diff_line_note_form.vue';
import NoteForm from '~/notes/components/note_form.vue';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('EE DiffLineNoteForm', () => {
  let storeOptions;
  let saveDraft;
  let wrapper;

  const createStoreOptions = (headSha) => {
    const state = {
      notes: {
        notesData: { draftsPath: null },
        noteableData: {},
      },
    };
    const getters = {
      getUserData: jest.fn(),
      isLoggedIn: jest.fn(),
      noteableType: jest.fn(),
    };

    return {
      state,
      getters,
      modules: {
        diffs: {
          namespaced: true,
          state: { commit: headSha || null },
          getters: {
            getDiffFileByHash: jest.fn().mockReturnValue(() => ({
              diff_refs: {
                head_sha: headSha || null,
              },
              highlighted_diff_lines: [],
            })),
          },
        },
        batchComments: {
          namespaced: true,
          actions: { saveDraft },
        },
      },
    };
  };

  const createComponent = (props = {}) => {
    const store = new Vuex.Store(storeOptions);

    // deep clone the mock data
    const diffFile = JSON.parse(JSON.stringify(diffFileMockData));
    const diffLines = diffFile.highlighted_diff_lines;

    wrapper = shallowMount(DiffLineNoteForm, {
      propsData: {
        diffFileHash: diffFile.file_hash,
        diffLines,
        line: diffLines[0],
        noteTargetLine: diffLines[0],
        ...props,
      },
      store,
      localVue,
    });
  };

  beforeEach(() => {
    saveDraft = jest.fn();
    storeOptions = createStoreOptions();
  });

  afterEach(() => {
    wrapper.destroy();
  });

  const submitNoteAddToReview = () =>
    wrapper.find(NoteForm).vm.$emit('handleFormUpdateAddToReview', note);
  const saveDraftCommitId = () => saveDraft.mock.calls[0][1].data.note.commit_id;

  describe('when user submits note to review', () => {
    it('should call saveDraft action with commit_id === null when store has no commit', () => {
      createComponent();

      submitNoteAddToReview();

      expect(saveDraft).toHaveBeenCalledTimes(1);
      expect(saveDraftCommitId()).toBe(null);
    });

    it('should call saveDraft action with commit_id when store has commit', () => {
      const HEAD_SHA = 'abc123';
      storeOptions = createStoreOptions(HEAD_SHA);
      createComponent();

      submitNoteAddToReview();

      expect(saveDraft).toHaveBeenCalledTimes(1);
      expect(saveDraftCommitId()).toBe(HEAD_SHA);
    });
  });
});
