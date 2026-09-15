/**
 * The monthly Allowance (mp-281): the credits a subscription carries each
 * month, granted into the same wallet the packs fill and spent before them.
 *
 * Pure — no Deno globals — so the revenuecat-webhook handler (which has its
 * env injected for the seam tests) and credits.ts read the same number.
 *
 * DEFAULT_MONTHLY_ALLOWANCE is set from the per-call cost log on dev
 * (ai_usage / vana_calls, read 2026-09-15; ticket 20):
 *   vana-chat turn        Haiku 4.5, ~14k in / ~165 out   ≈ $0.015 (less with the prompt cache)
 *   describe-meal         Sonnet 4.6, ~1.3k in / ~256 out ≈ $0.008
 *   analyze-meal-photo    Sonnet 4.6, ~2.9k in / ~290 out ≈ $0.013
 *   ai-coach insight      Sonnet 4.6, ~430 in / ~51 out   ≈ $0.002
 * The person mp-281 §5 names — plans a week (one planning conversation, p90
 * four turns, call it six), asks a few questions a day (3 × 30), logs a few
 * meals a day (up to 3 × 30) and gets a coach insight a day (30) — spends
 * 6 × 4.3 + 90 + 90 + 30 ≈ 236 credits a month. 300 leaves a quarter of
 * headroom; fully spent it costs ≈ $3.60 at the worst per-call price against
 * a $9.99 month. Override per project with AI_MONTHLY_ALLOWANCE.
 */

export const DEFAULT_MONTHLY_ALLOWANCE = 300;

/** The env key that overrides the allowance per project. */
export const MONTHLY_ALLOWANCE_ENV = 'AI_MONTHLY_ALLOWANCE';

/** The monthly allowance for this project: the env override, else the default. */
export function monthlyAllowance(env: (key: string) => string | undefined): number {
  const raw = env(MONTHLY_ALLOWANCE_ENV);
  if (raw == null || raw.trim() === '') return DEFAULT_MONTHLY_ALLOWANCE;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : DEFAULT_MONTHLY_ALLOWANCE;
}

/** RevenueCat event types on which the webhook grants the allowance (mp-281 §2, §3). */
export const ALLOWANCE_GRANT_EVENT_TYPES: ReadonlySet<string> = new Set(['INITIAL_PURCHASE', 'RENEWAL']);

/** RevenueCat event types on which what is left of the allowance is forfeited (mp-281 §3). */
export const ALLOWANCE_FORFEIT_EVENT_TYPES: ReadonlySet<string> = new Set(['EXPIRATION']);
