import { shouldQrtlyReconciliationMount } from 'ee/billings/qrtly_reconciliation';
import initSubscriptions from 'ee/billings/subscriptions';
import { shouldExtendReactivateTrialButtonMount } from 'ee/trials/extend_reactivate_trial';
import { shouldHandRaiseLeadButtonMount } from 'ee/hand_raise_leads/hand_raise_lead';
import PersistentUserCallout from '~/persistent_user_callout';

PersistentUserCallout.factory(document.querySelector('.js-gold-trial-callout'));
initSubscriptions();
shouldExtendReactivateTrialButtonMount();
shouldHandRaiseLeadButtonMount();
shouldQrtlyReconciliationMount();
