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
 * Today this is a "track now, throttle later" ledger: nothing reads it back to
 * enforce limits yet. A future per-user throttle/cutoff queries this table
 * (e.g. `sum(input_tokens + output_tokens)` over a rolling window per user_id)
 * before invoking the model. The `ai_usage_user_created` index supports that
 * query.
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
