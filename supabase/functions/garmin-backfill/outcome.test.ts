/**
 * classifyBackfillFailure: which answer garmin-backfill gives when Garmin
 * queued nothing (ticket 19, Sentry MEALVANA-ENDURANCE-AA / AB).
 *
 * The status maps below are the ones the prod function logs recorded on
 * 2026-09-27 and 2026-10-02, per summary type, in request order.
 *
 * Run: deno test --allow-all --allow-sys supabase/functions/garmin-backfill/
 */

import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';

import { classifyBackfillFailure } from './outcome.ts';

Deno.test('a queued type means success: no failure answer', () => {
  assertEquals(
    classifyBackfillFailure({
      body_composition: 202,
      user_metrics: 429,
      activities: 502,
    }),
    null,
  );
});

Deno.test(
  'dead token (refresh invalid_grant, then 401 Token is not active) asks for a reconnect, not a 502',
  () => {
    // 2026-10-02 19:51 / 21:09: body_composition 401, the rest throttled.
    const failure = classifyBackfillFailure({
      body_composition: 401,
      user_metrics: 429,
      activities: 429,
    });
    assertEquals(failure?.status, 409);
    assertEquals(failure?.code, 'garmin_reauth_required');
  },
);

Deno.test('every type throttled answers 429', () => {
  // 2026-09-27 14:27:09: all three types 429.
  const failure = classifyBackfillFailure({
    body_composition: 429,
    user_metrics: 429,
    activities: 429,
  });
  assertEquals(failure?.status, 429);
  assertEquals(failure?.code, 'garmin_rate_limited');
});

Deno.test('a Garmin outage mixed with throttling stays a 502', () => {
  // 2026-10-02 22:30: body_composition got Garmin's Cloudflare 502 page.
  const failure = classifyBackfillFailure({
    body_composition: 502,
    user_metrics: 429,
    activities: 429,
  });
  assertEquals(failure?.status, 502);
  assertEquals(failure?.code, 'garmin_unavailable');
});

Deno.test('every fetch threw (nothing recorded) is an outage', () => {
  const failure = classifyBackfillFailure({});
  assertEquals(failure?.status, 502);
  assertEquals(failure?.code, 'garmin_unavailable');
});
