<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { mapState, mapGetters } from 'vuex';
import { s__ } from '~/locale';
import formattingMixins from '../../formatting_mixins';

export default {
  components: {
    GlLink,
    GlSprintf,
  },
  mixins: [formattingMixins],
  computed: {
    ...mapState(['startDate', 'taxRate', 'numberOfUsers']),
    ...mapGetters([
      'selectedPlanText',
      'selectedPlanPrice',
      'endDate',
      'totalExVat',
      'vat',
      'totalAmount',
      'usersPresent',
    ]),
    taxAmount() {
      return this.taxRate ? this.formatAmount(this.vat, this.usersPresent) : '–';
    },
    taxLine() {
      return `${this.$options.i18n.tax} ${this.$options.i18n.taxNote}`;
    },
  },
  i18n: {
    selectedPlanText: s__('Checkout|%{selectedPlanText} plan'),
    numberOfUsers: s__('Checkout|(x%{numberOfUsers})'),
    pricePerUserPerYear: s__('Checkout|$%{selectedPlanPrice} per user per year'),
    dates: s__('Checkout|%{startDate} - %{endDate}'),
    subtotal: s__('Checkout|Subtotal'),
    tax: s__('Checkout|Tax'),
    taxNote: s__('Checkout|(may be %{linkStart}charged upon purchase%{linkEnd})'),
    total: s__('Checkout|Total'),
  },
};
</script>
<template>
  <div>
    <div class="gl-display-flex gl-justify-content-space-between gl-font-weight-bold gl-my-3">
      <div class="js-selected-plan">
        {{ sprintf($options.i18n.selectedPlanText, { selectedPlanText }) }}
        <span v-if="usersPresent" class="js-number-of-users">{{
          sprintf($options.i18n.numberOfUsers, { numberOfUsers })
        }}</span>
      </div>
      <div class="js-amount">{{ formatAmount(totalExVat, usersPresent) }}</div>
    </div>
    <div class="gl-text-gray-500 js-per-user">
      {{
        sprintf($options.i18n.pricePerUserPerYear, {
          selectedPlanPrice: selectedPlanPrice.toLocaleString(),
        })
      }}
    </div>
    <div class="gl-text-gray-500 js-dates">
      {{
        sprintf($options.i18n.dates, {
          startDate: formatDate(startDate),
          endDate: formatDate(endDate),
        })
      }}
    </div>
    <div>
      <div class="border-bottom gl-mt-3 gl-mb-3"></div>
      <div class="gl-display-flex gl-justify-content-space-between gl-text-gray-500">
        <div>{{ $options.i18n.subtotal }}</div>
        <div class="js-total-ex-vat">{{ formatAmount(totalExVat, usersPresent) }}</div>
      </div>
      <div class="gl-display-flex gl-justify-content-space-between gl-text-gray-500">
        <div data-testid="tax-info-line">
          <gl-sprintf :message="taxLine">
            <template #link="{ content }">
              <gl-link
                class="gl-text-decoration-underline gl-text-gray-500"
                href="https://about.gitlab.com/handbook/tax/#indirect-taxes-management"
                target="_blank"
                data-testid="tax-help-link"
                >{{ content }}</gl-link
              >
            </template>
          </gl-sprintf>
        </div>
        <div class="js-vat">{{ taxAmount }}</div>
      </div>
    </div>
    <div class="gl-border-b-1 gl-border-b-gray-100 gl-border-b-solid gl-mt-3 gl-mb-3"></div>
    <div class="gl-display-flex gl-justify-content-space-between gl-font-lg gl-font-weight-bold">
      <div>{{ $options.i18n.total }}</div>
      <div class="js-total-amount">{{ formatAmount(totalAmount, usersPresent) }}</div>
    </div>
  </div>
</template>
