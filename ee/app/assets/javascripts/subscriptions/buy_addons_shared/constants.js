import { s__, n__ } from '~/locale';

/* eslint-disable @gitlab/require-i18n-strings */
export const planTags = {
  CI_1000_MINUTES_PLAN: 'CI_1000_MINUTES_PLAN',
  STORAGE_PLAN: 'STORAGE_PLAN',
};
/* eslint-enable @gitlab/require-i18n-strings */
export const CUSTOMERSDOT_CLIENT = 'customersDotClient';
export const GITLAB_CLIENT = 'gitlabClient';
export const CUSTOMER_TYPE = 'Customer';
export const SUBSCRIPTION_TYPE = 'Subscription';
export const NAMESPACE_TYPE = 'Namespace';
export const PAYMENT_METHOD_TYPE = 'PaymentMethod';
export const PLAN_TYPE = 'Plan';

export const CI_MINUTES_PER_PACK = 1000;
export const STORAGE_PER_PACK = 10;

export const I18N_CI_MINUTES_PRODUCT_LABEL = s__('Checkout|CI minute pack');
export const I18N_CI_MINUTES_PRODUCT_UNIT = s__('Checkout|minutes');
export const I18N_CI_MINUTES_FORMULA_TOTAL = s__('Checkout|%{totalCiMinutes} CI minutes');
export const i18nCIMinutesSummaryTitle = (quantity) =>
  n__('Checkout|%d CI minute pack', 'Checkout|%d CI minute packs', quantity);
export const I18N_CI_MINUTES_SUMMARY_TOTAL = s__('Checkout|Total minutes: %{quantity}');
export const I18N_CI_MINUTES_ALERT_TEXT = s__(
  "Checkout|CI minute packs are only used after you've used your subscription's monthly quota. The additional minutes will roll over month to month and are valid for one year.",
);
export const I18N_CI_MINUTES_PRICE_PRE_UNIT = s__(
  'Checkout|$%{selectedPlanPrice} per pack of 1,000 minutes',
);
export const I18N_CI_MINUTES_TITLE = s__("Checkout|%{name}'s CI minutes");

export const I18N_STORAGE_PRODUCT_LABEL = s__('Checkout|Storage packs');
export const I18N_STORAGE_PRODUCT_UNIT = s__('Checkout|GB');
export const I18N_STORAGE_FORMULA_TOTAL = s__('Checkout|%{quantity} GB of storage');
export const i18nStorageSummaryTitle = (quantity) =>
  n__('Checkout|%{quantity} storage pack', 'Checkout|%{quantity} storage packs', quantity);
export const I18N_STORAGE_SUMMARY_TOTAL = s__('Checkout|Total storage: %{quantity} GB');
export const I18N_STORAGE_PRICE_PRE_UNIT = s__(
  'Checkout|$%{selectedPlanPrice} per 10 GB storage per pack',
);
export const I18N_STORAGE_TITLE = s__("Checkout|%{name}'s storage subscription");
export const I18N_STORAGE_TOOLTIP_NOTE = s__(
  'Checkout|Your storage subscription has the same term as your main subscription, and the price is prorated accordingly.',
);

export const I18N_DETAILS_STEP_TITLE = s__('Checkout|Purchase details');
export const I18N_DETAILS_NEXT_STEP_BUTTON_TEXT = s__('Checkout|Continue to billing');
export const I18N_DETAILS_INVALID_QUANTITY_MESSAGE = s__('Checkout|Enter a number greater than 0');
export const I18N_DETAILS_FORMULA = s__('Checkout|x %{quantity} %{units} per pack =');
export const I18N_DETAILS_FORMULA_WITH_ALERT = s__('Checkout|x %{quantity} %{units} per pack');

export const I18N_SUMMARY_QUANTITY = s__('Checkout|(x%{quantity})');
export const I18N_SUMMARY_DATES = s__('Checkout|%{startDate} - %{endDate}');
export const I18N_SUMMARY_SUBTOTAL = s__('Checkout|Subtotal');
export const I18N_SUMMARY_TAX = s__('Checkout|Tax');
export const I18N_SUMMARY_TAX_NOTE = s__(
  'Checkout|(may be %{linkStart}charged upon purchase%{linkEnd})',
);
export const I18N_SUMMARY_TOTAL = s__('Checkout|Total');
