import Vue from 'vue';
import Translate from '~/vue_shared/translate';
import GeoReplicableApp from './components/app.vue';
import createStore from './store';

Vue.use(Translate);

export default () => {
  const el = document.getElementById('js-geo-replicable');
  const {
    replicableType,
    geoTroubleshootingLink,
    geoReplicableEmptySvgPath,
    graphqlFieldName,
  } = el.dataset;

  return new Vue({
    el,
    store: createStore({ replicableType, graphqlFieldName }),
    components: {
      GeoReplicableApp,
    },

    render(createElement) {
      return createElement('geo-replicable-app', {
        props: {
          geoTroubleshootingLink,
          geoReplicableEmptySvgPath,
        },
      });
    },
  });
};
