/**
 * Per-user AI token usage ledger.
 *
 * Every AI model invocation (jade-chat, describe-meal, analyze-meal-photo,
 * ai-coach) writes one row to `public.ai_usage` via the service role. This is
 * the canonical, prod-safe, server-side record of how many tokens each user
 * consumes — it cannot be spoofed by the client (unlike Mixpanel events) and it
 * exists in BOTH dev and prod (the older `jade_calls` table is dev-only and only
 * covers the AI coach functions).
 *
 * This ledger is a record, not the limit: the monthly budget is enforced by
 * the wallet (credits.ts, mp-430), which settles each call to the REAL cost
 * computed here — the gateway's own charge, or the logged tokens priced from
 * the one table below when the gateway reports none (mp-436).
 *
 * Always fire-and-forget: call inside `EdgeRuntime.waitUntil(...)` and never let
 * a logging failure fail the user's request.
 */

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

export interface AiUsageRow {
  /** auth.users id of the caller. */
  userId: string;
  /** 'jade-chat' | 'describe-meal' | 'analyze-meal-photo' | 'ai-coach' */
  functionName: string;
  /** provider/model string actually used (e.g. anthropic/claude-haiku-4.5). */
  model: string;
  inputTokens: number;
  outputTokens: number;
  /** Actual USD charge reported by the AI Gateway (null when unavailable). */
  costUsd?: number | null;
}

/**
 * Read the actual USD charge reported by Vercel AI Gateway.
 *
 * Gateway returns cost as a decimal string in provider metadata. Keep this
 * parser defensive because direct-provider calls and older SDK responses may
 * omit the gateway block entirely.
 */
export function gatewayCostUsd(providerMetadata: unknown): number | null {
  if (typeof providerMetadata !== "object" || providerMetadata === null) {
    return null;
  }
  const gateway = (providerMetadata as Record<string, unknown>).gateway;
  if (typeof gateway !== "object" || gateway === null) return null;
  const raw = (gateway as Record<string, unknown>).cost;
  const parsed = typeof raw === "number"
    ? raw
    : typeof raw === "string"
    ? Number.parseFloat(raw)
    : Number.NaN;
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

/**
 * Insert one AI usage row. Never throws — errors are logged and swallowed so the
 * caller's response is unaffected. Returns a Promise so it can be handed
 * directly to `EdgeRuntime.waitUntil`.
 */
export async function logAiUsage(
  // deno-lint-ignore no-explicit-any
  client: SupabaseClient<any, any, any>,
  row: AiUsageRow,
): Promise<void> {
  try {
    const { error } = await client.from("ai_usage").insert({
      user_id: row.userId,
      function_name: row.functionName,
      model: row.model,
      input_tokens: row.inputTokens ?? 0,
      output_tokens: row.outputTokens ?? 0,
      cost_usd: row.costUsd ?? null,
    });
    if (error) {
      console.error(
        `[ai_usage] log error (${row.functionName}):`,
        error.message,
      );
    }
  } catch (e) {
    console.error(`[ai_usage] log exception (${row.functionName}):`, e);
  }
}

// ---------------------------------------------------------------------------
// Real cost (mp-436): the gateway's charge, else tokens priced from ONE table
// ---------------------------------------------------------------------------

/** A dollar in the wallet's unit. */
const USD_MICRO = 1_000_000;

/** Price per MILLION tokens, in USD, per model id as the gateway spells it. */
interface ModelPrice {
  input: number;
  output: number;
  /** Prompt-cache read: 0.1× input on every model here. */
  cacheRead: number;
  /** Prompt-cache write at the one-hour lifetime (2× input), the marker the meal-logging prompts and the chat's
   *  shared prefix ask for. The SDK does not say which lifetime a write had, so the dearer one is assumed. */
  cacheWrite: number;
}

/**
 * The one price table (mp-436). Anthropic first-party rates, read from the
 * claude-api skill's model table on 2026-09-22; the gateway bills the same
 * rates. A model missing here prices as null, and the reservation's estimate
 * stands — add the row rather than guess. Nothing asserts these numbers.
 */
export const MODEL_PRICES_USD_PER_MTOK: Record<string, ModelPrice> = {
  'anthropic/claude-haiku-4.5': { input: 1.0, output: 5.0, cacheRead: 0.1, cacheWrite: 2.0 },
  'anthropic/claude-sonnet-4.6': { input: 3.0, output: 15.0, cacheRead: 0.3, cacheWrite: 6.0 },
  'anthropic/claude-sonnet-4-6': { input: 3.0, output: 15.0, cacheRead: 0.3, cacheWrite: 6.0 },
  'anthropic/claude-haiku-4-5': { input: 1.0, output: 5.0, cacheRead: 0.1, cacheWrite: 2.0 },
};

/** What a finished call reports about itself, in the shape the SDK hands back (never this module's own output). */
export interface RealCostInput {
  /** `providerMetadata.gateway.cost` parsed by `gatewayCostUsd`, or the sum over steps (`callMetrics`). */
  gatewayCostUsd?: number | null;
  /** The model the call ran on, as the gateway spells it. */
  model?: string | null;
  /** Prompt tokens NOT served from cache (the SDK's `inputTokens` already excludes cache reads on Anthropic). */
  inputTokens?: number | null;
  outputTokens?: number | null;
  cacheReadTokens?: number | null;
  cacheWriteTokens?: number | null;
}

/** Price logged tokens from the table, in micro-dollars; null when the model has no row or no token count was reported
 *  at all (a call that ran but told us nothing is not a free call). */
export function pricedTokensMicro(c: RealCostInput): number | null {
  const price = c.model ? MODEL_PRICES_USD_PER_MTOK[c.model] : undefined;
  if (!price) return null;
  if ([c.inputTokens, c.outputTokens, c.cacheReadTokens, c.cacheWriteTokens].every((v) => typeof v !== 'number')) return null;
  const n = (v: number | null | undefined) => (typeof v === 'number' && Number.isFinite(v) && v > 0 ? v : 0);
  const usd = (n(c.inputTokens) * price.input + n(c.outputTokens) * price.output +
    n(c.cacheReadTokens) * price.cacheRead + n(c.cacheWriteTokens) * price.cacheWrite) / 1_000_000;
  return Math.ceil(usd * USD_MICRO);
}

/**
 * The real cost of a call in micro-dollars: the gateway's own charge when it
 * reported one, else the logged tokens priced from the table, else null
 * (the caller settles at its estimate). Rounded UP to the next micro-dollar,
 * so the athlete is never charged less than we were.
 */
export function realCostMicro(c: RealCostInput): number | null {
  if (typeof c.gatewayCostUsd === 'number' && Number.isFinite(c.gatewayCostUsd) && c.gatewayCostUsd >= 0) {
    return Math.ceil(c.gatewayCostUsd * USD_MICRO);
  }
  return pricedTokensMicro(c);
}
