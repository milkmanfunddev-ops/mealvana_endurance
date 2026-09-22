/**
 * ai-cost-alert — the Sentry leg of the daily AI cost check (ai-cost ticket 05, mp-420 clause 6).
 *
 * Called by the database itself: the pg_cron job `ai-cost-daily-alert` runs `public.vana_daily_cost_alert()`, which
 * posts here via pg_net ONLY when an account's logged gateway charge for the day is over the threshold ($1.50).
 * This function reports and nothing else — it refuses no call, touches no wallet and writes no row. The refusing is
 * the monthly budget's job (mp-430); this exists so Lee hears it the same day instead of from an invoice.
 *
 * Auth: pg_net cannot mint Supabase JWTs, so the gateway check is off (config.toml verify_jwt=false, the same as
 * raw-retention-alert) and the caller presents a shared secret in `x-alert-token`, checked against the
 * AI_COST_ALERT_TOKEN function secret. The token also lives in Vault so the SQL wrapper can send it.
 *
 * One Sentry event PER ACCOUNT, fingerprinted on the account and the day: a week of the same athlete running hot is a
 * week of issues, not one issue with 7 events, because each day's number is a separate thing to decide about. The
 * account id is the user id — the same identifier every other event in this project carries, and not an email.
 *
 * Secrets:
 *   AI_COST_ALERT_TOKEN  shared secret matched against the x-alert-token header
 *   SENTRY_DSN           as everywhere else; absent, initSentry is a no-op and the accounts are logged instead
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import * as Sentry from 'https://esm.sh/@sentry/deno@8.53.0';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { alertEvents, type AlertBody } from './alert.ts';

const ALERT_TOKEN = Deno.env.get('AI_COST_ALERT_TOKEN') ?? '';

initSentry();

serve(withSentry(async (req) => {
  if (req.method !== 'POST') return new Response('method not allowed', { status: 405 });
  if (!ALERT_TOKEN || req.headers.get('x-alert-token') !== ALERT_TOKEN) return new Response('unauthorized', { status: 401 });

  let body: AlertBody;
  try { body = (await req.json()) as AlertBody; } catch { return new Response(JSON.stringify({ success: false, error: 'invalid body' }), { status: 400, headers: { 'Content-Type': 'application/json' } }); }

  const env = Deno.env.get('SUPABASE_URL')?.includes('vlmtsdzpnjnavdgytcmi') ? 'DEV' : 'PROD';
  const threshold = Number(body.threshold_usd ?? 1.5);
  const events = alertEvents(body);

  for (const e of events) {
    console.warn(`[ai-cost-alert] ${env} ${e.message} (${e.account.calls} calls, ${e.account.costed_calls} with a gateway charge)`);
    Sentry.captureMessage(e.message, {
      level: 'warning',
      tags: { component: 'ai_cost', environment_label: env, day: e.day },
      // One issue per account per day: the same athlete tomorrow is a new number to decide about.
      fingerprint: e.fingerprint,
      extra: {
        user_id: e.account.user_id,
        day: e.day,
        cost_usd: Number(e.account.cost_usd),
        threshold_usd: threshold,
        calls: e.account.calls,
        calls_with_a_gateway_charge: e.account.costed_calls,
        view: 'public.vana_weekly_cost / public.vana_daily_cost_offenders',
      },
    });
  }
  if (events.length) await Sentry.flush(2000);

  return new Response(JSON.stringify({ success: true, reported: events.length }), { headers: { 'Content-Type': 'application/json' } });
}));
