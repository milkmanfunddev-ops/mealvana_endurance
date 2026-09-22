/**
 * The monthly budget (mp-430, mp-436; ai-cost ticket 09): what a subscription
 * carries each month, what the trial week gets, what a pack adds, and when the
 * old free grant ends. One setting each, in whole MICRO-DOLLARS of model cost
 * ($4.00 = 4,000,000), granted into the same wallet the packs fill and spent
 * before them (the SQL in 20260916130000 and 20260922120000 keeps that rule).
 *
 * Pure — no Deno globals — so the revenuecat-webhook handler (which has its
 * env injected for the seam tests), credits.ts and ensure-credits read the
 * same numbers. Every figure here is the ruling in the record, not a price
 * derived from the models; the models' prices live in usage.ts.
 */

/** One dollar, in the wallet's unit. */
export const USD_MICRO = 1_000_000;

/** $4.00 of model cost a month, the same for monthly, annual and founding plans (mp-430 clause 2). */
export const DEFAULT_MONTHLY_BUDGET = 4 * USD_MICRO;

/** The trial week gets a quarter of the month (mp-430 clause 3, amending mp-281 clause 3). */
export const DEFAULT_TRIAL_BUDGET = DEFAULT_MONTHLY_BUDGET / 4;

/** The env key that overrides the monthly budget per project (micro-dollars). */
export const MONTHLY_BUDGET_ENV = 'AI_MONTHLY_BUDGET';
/** The env key that overrides the trial's budget per project (micro-dollars). */
export const TRIAL_BUDGET_ENV = 'AI_TRIAL_BUDGET';

/** Credits already in wallets convert once at 2 cents a credit (mp-436 clause 2). */
export const MICRO_PER_CREDIT = 20_000;

/**
 * The packs keep their prices and add budget, not credits (mp-430 clause 7):
 * $4.99 adds a quarter of a month ($1.00), $19.99 a month and a quarter
 * ($5.00). The same products under their prod `_prod` ids (Apple product ids
 * are team-unique), and the $0.99 pipeline-test pack at one old credit.
 */
export const DEFAULT_PRODUCT_BUDGET: Record<string, number> = {
  mealvana_credits_50: 1 * USD_MICRO,
  mealvana_credits_250: 5 * USD_MICRO,
  mealvana_credits_50_prod: 1 * USD_MICRO,
  mealvana_credits_250_prod: 5 * USD_MICRO,
  mealvana_credits_test_1: MICRO_PER_CREDIT,
  mealvana_credits_test_1_prod: MICRO_PER_CREDIT,
};
/** JSON `{ product_id: micro_dollars }` that replaces the map per project. */
export const PRODUCT_BUDGET_ENV = 'RC_PRODUCT_BUDGET';

/**
 * The paywall opens on this day (Xuan's RC spec, mp-429). The old free grant
 * of 20 credits a month ends here (mp-430 clause 10); free budget already in
 * wallets stays. One setting, never a scattered literal.
 */
export const PAYWALL_OPENS_AT = '2026-10-01T00:00:00Z';

/** What the free grant was, in the new unit: 20 credits at 2 cents. */
export const DEFAULT_FREE_MONTHLY_BUDGET = 20 * MICRO_PER_CREDIT;
/** Overrides the free grant per project (micro-dollars). Dev ran the credit
 *  version at 500 for a while; do not. */
export const FREE_MONTHLY_BUDGET_ENV = 'AI_FREE_MONTHLY_BUDGET';

type Env = (key: string) => string | undefined;

function positiveIntEnv(env: Env, key: string, fallback: number): number {
  const raw = env(key);
  if (raw == null || raw.trim() === '') return fallback;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : fallback;
}

/** The monthly budget for this project: the env override, else $4.00. */
export function monthlyBudget(env: Env): number {
  return positiveIntEnv(env, MONTHLY_BUDGET_ENV, DEFAULT_MONTHLY_BUDGET);
}

/** The trial week's budget: the env override, else a quarter of the month. */
export function trialBudget(env: Env): number {
  return positiveIntEnv(env, TRIAL_BUDGET_ENV, DEFAULT_TRIAL_BUDGET);
}

/**
 * The budget a subscription event grants: the trial's share for a TRIAL
 * period, the month for everything else (NORMAL, INTRO, PROMOTIONAL).
 */
export function grantFor(env: Env, periodType: string | null | undefined): number {
  return periodType === 'TRIAL' ? trialBudget(env) : monthlyBudget(env);
}

/**
 * The free monthly grant as of [now]: what it was until the paywall opens,
 * nothing from that day on (mp-430 clause 10).
 */
export function freeMonthlyBudget(env: Env, now: Date = new Date()): number {
  if (now.getTime() >= Date.parse(PAYWALL_OPENS_AT)) return 0;
  const raw = env(FREE_MONTHLY_BUDGET_ENV);
  if (raw == null || raw.trim() === '') return DEFAULT_FREE_MONTHLY_BUDGET;
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? Math.trunc(n) : DEFAULT_FREE_MONTHLY_BUDGET;
}

/** RC store product id → micro-dollars granted; the env's JSON replaces the map. */
export function productBudget(env: Env): Record<string, number> {
  const raw = env(PRODUCT_BUDGET_ENV);
  if (!raw) return DEFAULT_PRODUCT_BUDGET;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object') return parsed as Record<string, number>;
  } catch (e) {
    console.error(`[budget] bad ${PRODUCT_BUDGET_ENV} JSON, using defaults:`, e);
  }
  return DEFAULT_PRODUCT_BUDGET;
}

/** RevenueCat event types on which the webhook grants the allowance (mp-281 §2, §3). */
export const ALLOWANCE_GRANT_EVENT_TYPES: ReadonlySet<string> = new Set(['INITIAL_PURCHASE', 'RENEWAL']);

/** RevenueCat event types on which what is left of the allowance is forfeited (mp-281 §3). */
export const ALLOWANCE_FORFEIT_EVENT_TYPES: ReadonlySet<string> = new Set(['EXPIRATION']);

/** The wallet row's budget fields, as the SQL returns them (micro-dollars). */
export interface WalletBudgetRow {
  balance?: number | null;
  allowance?: number | null;
  allowance_monthly?: number | null;
  allowance_expires_at?: string | null;
}

/**
 * What the app is sent about the budget (mp-436 clause 3, mp-430 clause 8):
 * the share of the month used, when it refills, and any bought extra as a
 * share of a month. Never a dollar figure.
 */
export interface BudgetStatus {
  /** 0..1 of this period's allowance spent; null when no allowance window is open (never granted, or lapsed). */
  share_used: number | null;
  /** ISO end of the current allowance window; null when none is open. */
  refill_at: string | null;
  /** Unspent bought (and pre-paywall free) budget, as a share of a month: a $1.00 pack is 0.25. */
  bought_extra_share: number;
}

const share = (n: number) => Math.round(n * 100) / 100;

export function budgetStatus(row: WalletBudgetRow, monthly: number): BudgetStatus {
  const balance = Math.max(0, row.balance ?? 0);
  const allowance = Math.max(0, row.allowance ?? 0);
  const allowanceMonthly = row.allowance_monthly ?? 0;
  const windowOpen = allowanceMonthly > 0 && !!row.allowance_expires_at;
  const shareUsed = windowOpen ? share(Math.min(1, Math.max(0, 1 - allowance / allowanceMonthly))) : null;
  const bought = Math.max(0, balance - allowance);
  return {
    share_used: shareUsed,
    refill_at: row.allowance_expires_at ?? null,
    bought_extra_share: monthly > 0 ? share(bought / monthly) : 0,
  };
}
