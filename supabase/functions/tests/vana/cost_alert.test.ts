/**
 * The daily cost alert reports and refuses nothing (ai-cost ticket 05, mp-470 criterion 4).
 *
 * The SQL side (the `vana_calls_cost_alert` trigger and `vana_cost_crossed`) never fails the write it rides on and is verified on
 * dev — see the ticket. This covers the edge function's one decision: which Sentry events an alert body raises, and
 * how they are fingerprinted, so a week of the same athlete running hot is a week of issues and not one issue with
 * seven events.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { alertEvents } from '../../ai-cost-alert/alert.ts';

const account = (id: string, cost: number | string) => ({ user_id: id, cost_usd: cost, calls: 12, costed_calls: 12 });

Deno.test('one event per account over the threshold, fingerprinted on the account and the day', () => {
  const events = alertEvents({ day: '2026-10-04', threshold_usd: 1.5, accounts: [account('u-1', 1.8123), account('u-2', '2.5')] });
  assertEquals(events.length, 2);
  assertEquals(events[0].message, 'AI cost: account u-1 cost $1.8123 on 2026-10-04');
  assertEquals(events[0].fingerprint, ['ai-cost-daily', 'u-1', '2026-10-04']);
  assertEquals(events[1].message, 'AI cost: account u-2 cost $2.5000 on 2026-10-04');
  // The same athlete tomorrow is a different issue: the number is a new thing to decide about.
  assertEquals(alertEvents({ day: '2026-10-05', accounts: [account('u-1', 1.8123)] })[0].fingerprint,
    ['ai-cost-daily', 'u-1', '2026-10-05']);
});

Deno.test('a body with nothing in it raises nothing', () => {
  assertEquals(alertEvents({}), []);
  assertEquals(alertEvents({ day: '2026-10-04', accounts: [] }), []);
  // deno-lint-ignore no-explicit-any
  assertEquals(alertEvents({ day: '2026-10-04', accounts: 'oops' as any }), []);
  // deno-lint-ignore no-explicit-any
  assertEquals(alertEvents({ day: '2026-10-04', accounts: [{ cost_usd: 9 } as any] }), []);
});
