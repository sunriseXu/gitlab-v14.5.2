<script>
import $ from 'jquery';
import { GlButton, GlIntersectionObserver, GlSafeHtmlDirective as SafeHtml } from '@gitlab/ui';

import { FLASH_TYPES, FLASH_CLOSED_EVENT } from '~/flash';
import { isLoggedIn } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import csrf from '~/lib/utils/csrf';
import '~/behaviors/markdown/render_gfm';

export default {
  name: 'TermsApp',
  i18n: {
    accept: __('Accept terms'),
    continue: __('Continue'),
    decline: __('Decline and sign out'),
  },
  flashElements: [],
  csrf,
  directives: {
    SafeHtml,
  },
  components: { GlButton, GlIntersectionObserver },
  inject: ['terms', 'permissions', 'paths'],
  data() {
    return {
      acceptDisabled: true,
    };
  },
  computed: {
    isLoggedIn,
  },
  mounted() {
    this.renderGFM();
    this.setScrollableViewportHeight();

    this.$options.flashElements = [
      ...document.querySelectorAll(
        Object.values(FLASH_TYPES)
          .map((flashType) => `.flash-${flashType}`)
          .join(','),
      ),
    ];

    this.$options.flashElements.forEach((flashElement) => {
      flashElement.addEventListener(FLASH_CLOSED_EVENT, this.handleFlashClose);
    });
  },
  beforeDestroy() {
    this.$options.flashElements.forEach((flashElement) => {
      flashElement.removeEventListener(FLASH_CLOSED_EVENT, this.handleFlashClose);
    });
  },
  methods: {
    renderGFM() {
      $(this.$refs.gfmContainer).renderGFM();
    },
    handleBottomReached() {
      this.acceptDisabled = false;
    },
    setScrollableViewportHeight() {
      // Reset `max-height` inline style
      this.$refs.scrollableViewport.style.maxHeight = '';

      const { scrollHeight, clientHeight } = document.documentElement;

      // Set `max-height` to 100vh minus all elements that are NOT the scrollable viewport (header, footer, alerts, etc)
      this.$refs.scrollableViewport.style.maxHeight = `calc(100vh - ${
        scrollHeight - clientHeight
      }px)`;
    },
    handleFlashClose(event) {
      this.setScrollableViewportHeight();
      event.target.removeEventListener(FLASH_CLOSED_EVENT, this.handleFlashClose);
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-card-body gl-relative gl-pb-0 gl-px-0" data-qa-selector="terms_content">
      <div
        class="terms-fade gl-absolute gl-left-5 gl-right-5 gl-bottom-0 gl-h-11 gl-pointer-events-none"
      ></div>
      <div
        ref="scrollableViewport"
        data-testid="scrollable-viewport"
        class="gl-h-100vh gl-overflow-y-auto gl-pb-11 gl-px-5"
      >
        <div ref="gfmContainer" v-safe-html="terms"></div>
        <gl-intersection-observer @appear="handleBottomReached">
          <div></div>
        </gl-intersection-observer>
      </div>
    </div>
    <div v-if="isLoggedIn" class="gl-card-footer gl-display-flex gl-justify-content-end">
      <form v-if="permissions.canDecline" method="post" :action="paths.decline">
        <gl-button type="submit">{{ $options.i18n.decline }}</gl-button>
        <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
      </form>
      <form v-if="permissions.canAccept" class="gl-ml-3" method="post" :action="paths.accept">
        <gl-button
          type="submit"
          variant="confirm"
          :disabled="acceptDisabled"
          data-qa-selector="accept_terms_button"
          >{{ $options.i18n.accept }}</gl-button
        >
        <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
      </form>
      <gl-button v-else class="gl-ml-3" :href="paths.root" variant="confirm">{{
        $options.i18n.continue
      }}</gl-button>
    </div>
  </div>
</template>
