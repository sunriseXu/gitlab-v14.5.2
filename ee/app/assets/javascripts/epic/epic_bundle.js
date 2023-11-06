import { GlBreakpointInstance as bp } from '@gitlab/ui/dist/utils';
import Cookies from 'js-cookie';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { mapActions } from 'vuex';
import { parseIssuableData } from '~/issue_show/utils/parse_data';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import { defaultClient } from '~/sidebar/graphql';
import labelsSelectModule from '~/vue_shared/components/sidebar/labels_select_vue/store';

import EpicApp from './components/epic_app.vue';
import createStore from './store';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient,
});

export default () => {
  const el = document.getElementById('epic-app-root');

  if (!el) {
    return false;
  }

  const store = createStore();
  store.registerModule('labelsSelect', labelsSelectModule());

  const epicMeta = convertObjectPropsToCamelCase(JSON.parse(el.dataset.meta), { deep: true });
  const epicData = parseIssuableData(el);

  // Collapse the sidebar on mobile screens by default
  const bpBreakpoint = bp.getBreakpointSize();
  if (bpBreakpoint === 'xs' || bpBreakpoint === 'sm' || bpBreakpoint === 'md') {
    Cookies.set('collapsed_gutter', true);
  }

  return new Vue({
    el,
    apolloProvider,
    store,
    components: { EpicApp },
    provide: {
      canUpdate: epicData.canUpdate,
      allowLabelCreate: parseBoolean(epicData.canUpdate),
      allowLabelEdit: parseBoolean(epicData.canUpdate),
      fullPath: epicData.fullPath,
      iid: epicMeta.epicIid,
      isClassicSidebar: true,
      allowScopedLabels: epicMeta.scopedLabels,
      labelsManagePath: epicMeta.labelsWebUrl,
    },
    created() {
      this.setEpicMeta({
        ...epicMeta,
        allowSubEpics: parseBoolean(el.dataset.allowSubEpics),
      });
      this.setEpicData(epicData);
    },
    methods: {
      ...mapActions(['setEpicMeta', 'setEpicData']),
    },
    render: (createElement) => createElement('epic-app'),
  });
};
