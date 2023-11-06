import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import Project from 'ee/operations/components/dashboard/project.vue';
import ProjectHeader from 'ee/operations/components/dashboard/project_header.vue';
import Alerts from 'ee/vue_shared/dashboards/components/alerts.vue';
import store from 'ee/vue_shared/dashboards/store';
import Commit from '~/vue_shared/components/commit.vue';
import { mockOneProject } from '../../mock_data';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('project component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(Project, {
      store,
      localVue,
      propsData: {
        project: mockOneProject,
        ...props,
      },
      stubs: {
        GlSprintf,
        GlLink,
      },
    });
  };

  const findDashboardCard = () => wrapper.find('[data-testid="dashboard-card-body"]');

  afterEach(() => {
    wrapper.destroy();
  });

  describe('with unlicensed project', () => {
    let project;

    describe('can upgrade project group', () => {
      beforeEach(() => {
        project = {
          ...mockOneProject,
          upgrade_required: true,
          upgrade_path: '/upgrade',
        };

        createComponent({ project });
      });

      it('shows project title', () => {
        const header = wrapper.find(ProjectHeader);

        expect(header.props('project')).toEqual(project);
      });

      it('styles card with gray background', () => {
        expect(wrapper.find('.dashboard-card-body.bg-secondary').exists()).toBe(true);
      });

      it('shows upgrade license text', () => {
        expect(findDashboardCard().text()).toContain('upgrade its group plan to Premium');
        expect(findDashboardCard().find(GlLink).attributes('href')).toBe(project.upgrade_path);
      });

      it('hides commit info', () => {
        expect(wrapper).not.toContain(Commit);
      });
    });

    describe('cannot upgrade project group', () => {
      beforeEach(() => {
        project = {
          ...mockOneProject,
          upgrade_required: true,
          upgrade_path: '',
        };

        createComponent({ project });
      });

      it('shows upgrade license text', () => {
        expect(findDashboardCard().text()).not.toContain('upgrade its group plan to Premium');
        expect(findDashboardCard().text()).toContain(
          `contact an owner of group ${project.namespace.name}`,
        );
      });
    });
  });

  describe('wrapped components', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('project header', () => {
      it('binds project', () => {
        const header = wrapper.find(ProjectHeader);

        expect(header.props('project')).toEqual(mockOneProject);
      });
    });

    describe('alerts', () => {
      it('binds alert count to count', () => {
        const alert = wrapper.find(Alerts);

        expect(alert.props('count')).toBe(mockOneProject.alert_count);
      });
    });

    describe('commit', () => {
      let commit;

      beforeEach(() => {
        commit = wrapper.find(Commit);
      });

      it('binds commitRef', () => {
        expect(commit.props('commitRef')).toBe(wrapper.vm.commitRef);
      });

      it('binds short_id to shortSha', () => {
        expect(commit.props('shortSha')).toBe(
          wrapper.props().project.last_pipeline.commit.short_id,
        );
      });

      it('binds commitUrl', () => {
        expect(commit.props('commitUrl')).toBe(
          wrapper.props().project.last_pipeline.commit.commit_url,
        );
      });

      it('binds title', () => {
        expect(commit.props('title')).toBe(wrapper.props().project.last_pipeline.commit.title);
      });

      it('binds author', () => {
        expect(commit.props('author')).toBe(wrapper.props().project.last_pipeline.commit.author);
      });

      it('binds tag', () => {
        expect(commit.props('tag')).toBe(wrapper.props().project.last_pipeline.ref.tag);
      });
    });
  });
});
