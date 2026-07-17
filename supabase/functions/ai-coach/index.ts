/**
 * ai-coach Edge Function
 *
 * Multi-mode AI helper for Formula Kit. Today it serves `mode: "insight"` — a
 * short coach-tone one-liner about a draft personal formula. The envelope keeps
 * `mode` + `tools` so future surfaces (e.g. a chat mode) can reuse the function
 * without restructuring.
 *
 * POST /functions/v1/ai-coach
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Request body:
 *   {
 *     "mode": "insight",                 // only mode supported today
 *     "context": {                       // InsightContext (see _shared/coach_insight/insight.ts)
 *       "phase": "before" | "during" | "after",
 *       "sub_phase": "meal" | "snack" | "top_up" | null,   // before
 *       "durations": ["60_90", ...] | null,                // during
 *       "activities": ["run", ...] | null,
 *       "name": "Pre-long-run oatmeal" | null,
 *       "components": [ { food_name, quantity, carbs_per_serving, ... }, ... ]
 *     },
 *     "stale_marker": "..." | null,      // opaque; echoed back so the client can pair it
 *     "tools": []                        // reserved; unused in insight mode
 *   }
 *
 * Response (200):
 *   {
 *     "insight": "<15-28 word string>",
 *     "stale_marker": "<echoed or null>",
 *     "usage": { "input_tokens": <int>, "output_tokens": <int>, "model": "<string>" }
 *   }
 *
 * Token usage is RETURNED to the client (the client logs it to Mixpanel as
 * `coach_insight_generated`) rather than written to a DB table — the prod
 * project has no Jade/usage tables, and Mixpanel is the app's analytics sink.
 *
 * Error responses:
 *   400 — missing/invalid body, unknown mode, or empty components
 *   401 — missing or invalid JWT
 *   500 — missing AI_GATEWAY_API_KEY secret or unexpected server error
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { generateText } from "npm:ai@6";
import { handleCors } from "../_shared/cors.ts";
import {
  errorResponse,
  jsonResponse,
  serverError,
  validationError,
} from "../_shared/responses.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { COACH_INSIGHT_MODEL } from "../_shared/ai/model.ts";
import { gatewayCostUsd, logAiUsage } from "../_shared/ai/usage.ts";
import {
  buildDeterministicInsight,
  buildInsightUserMessage,
  COACH_INSIGHT_SYSTEM_PROMPT,
  computeNutritionState,
  type InsightComponent,
  type InsightContext,
  type InsightPhase,
} from "../_shared/coach_insight/insight.ts";
import {
  debitForUsage,
  ensureAndCheckCredits,
  insufficientCreditsBody,
} from "../_shared/ai/credits.ts";

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

/** Cap component count to bound prompt size / token abuse. */
const MAX_COMPONENTS = 30;

const VALID_PHASES: ReadonlySet<string> = new Set<InsightPhase>([
  "before",
  "during",
  "after",
]);

// ---------------------------------------------------------------------------
// Auth helper
// ---------------------------------------------------------------------------

async function requireUser(req: Request) {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) {
    return {
      user: null,
      response: errorResponse("Missing authorization header", 401),
    };
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error } = await adminClient.auth.getUser(token);

  if (error || !user) {
    console.error("[ai-coach] Auth error:", error);
    return {
      user: null,
      response: errorResponse("Invalid or expired authentication token", 401),
    };
  }

  return { user, response: null };
}

// ---------------------------------------------------------------------------
// Context parsing / validation
// ---------------------------------------------------------------------------

// deno-lint-ignore no-explicit-any
function parseComponents(raw: any): InsightComponent[] | null {
  if (!Array.isArray(raw)) return null;
  const out: InsightComponent[] = [];
  for (const item of raw) {
    if (typeof item !== "object" || item === null) continue;
    const name = item.food_name;
    if (typeof name !== "string" || name.trim().length === 0) continue;
    out.push({
      food_name: name,
      quantity: typeof item.quantity === "number" ? item.quantity : 1,
      carbs_per_serving: numOrUndef(item.carbs_per_serving),
      protein_per_serving: numOrUndef(item.protein_per_serving),
      fat_per_serving: numOrUndef(item.fat_per_serving),
      sodium_mg: numOrUndef(item.sodium_mg),
      fluid_ml_per_serving: numOrUndef(item.fluid_ml_per_serving),
      calories_per_serving: numOrUndef(item.calories_per_serving),
    });
  }
  return out;
}

// deno-lint-ignore no-explicit-any
function numOrUndef(v: any): number | undefined {
  return typeof v === "number" && Number.isFinite(v) ? v : undefined;
}

// deno-lint-ignore no-explicit-any
function stringListOrNull(v: any): string[] | null {
  if (!Array.isArray(v)) return null;
  const out = v.filter((e): e is string => typeof e === "string");
  return out.length > 0 ? out : null;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== "POST") {
    return errorResponse("Method not allowed. Use POST.", 405);
  }

  // Validate AI Gateway key is configured before doing any real work.
  const aiGatewayApiKey = Deno.env.get("AI_GATEWAY_API_KEY");
  if (!aiGatewayApiKey) {
    console.error("[ai-coach] AI_GATEWAY_API_KEY secret is not set");
    return errorResponse(
      "AI service is not configured. Please contact support.",
      500,
    );
  }

  try {
    // ── Authenticate ────────────────────────────────────────────────────────
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse("Invalid authentication state", 401);

    // ── Parse body ──────────────────────────────────────────────────────────
    let body: {
      mode?: unknown;
      context?: unknown;
      stale_marker?: unknown;
    };
    try {
      body = await req.json();
    } catch {
      return validationError("Invalid JSON body");
    }

    const mode = body.mode;
    if (mode !== "insight") {
      return validationError("Unsupported mode. Only 'insight' is supported.");
    }

    const rawContext = body.context;
    if (typeof rawContext !== "object" || rawContext === null) {
      return validationError("context is required and must be an object");
    }
    // deno-lint-ignore no-explicit-any
    const ctx = rawContext as Record<string, any>;

    const phase = ctx.phase;
    if (typeof phase !== "string" || !VALID_PHASES.has(phase)) {
      return validationError(
        "context.phase must be one of 'before' | 'during' | 'after'",
      );
    }

    const components = parseComponents(ctx.components);
    if (components === null) {
      return validationError("context.components must be an array");
    }
    if (components.length === 0) {
      return validationError(
        "context.components must contain at least one component",
      );
    }
    if (components.length > MAX_COMPONENTS) {
      return validationError(
        `context.components exceeds the maximum of ${MAX_COMPONENTS}`,
      );
    }

    const staleMarker =
      typeof body.stale_marker === "string" && body.stale_marker.length > 0
        ? body.stale_marker
        : null;

    const context: InsightContext = {
      phase: phase as InsightPhase,
      sub_phase: typeof ctx.sub_phase === "string" ? ctx.sub_phase : null,
      durations: stringListOrNull(ctx.durations),
      activities: stringListOrNull(ctx.activities),
      name: typeof ctx.name === "string" ? ctx.name : null,
      components,
    };

    // ── Compute structured nutrition state + prompt ──────────────────────────
    const state = computeNutritionState(context);
    const userMessage = buildInsightUserMessage(context, state);
    const deterministicInsight = buildDeterministicInsight(context, state);

    console.log(
      `[ai-coach] user=${user.id} mode=insight phase=${context.phase} ` +
        `components=${components.length} carbs=${state.carbsG} model=${COACH_INSIGHT_MODEL}`,
    );

    // ── Service-role client (reused for credits + ai_usage logging) ──────────
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Obvious nutrition gaps do not need a probabilistic model. This path is
    // faster, costs nothing, and guarantees that a fuel shortfall is not
    // answered with generic hydration advice.
    if (deterministicInsight !== null) {
      return jsonResponse({
        insight: deterministicInsight,
        stale_marker: staleMarker,
        usage: {
          input_tokens: 0,
          output_tokens: 0,
          model: "rules/pre-workout-v1",
          cost_usd: 0,
          source: "rules",
        },
      });
    }

    // ── Credit check ─────────────────────────────────────────────────────────
    const credit = await ensureAndCheckCredits(
      serviceClient,
      user.id,
      "ai-coach",
    );
    if (!credit.allowed) {
      return jsonResponse(insufficientCreditsBody(credit), 402);
    }

    // ── Call the model via Vercel AI Gateway ─────────────────────────────────
    const result = await generateText({
      model: COACH_INSIGHT_MODEL as Parameters<typeof generateText>[0]["model"],
      system: COACH_INSIGHT_SYSTEM_PROMPT,
      messages: [{ role: "user", content: userMessage }],
      // The output is one or two sentences; cap tokens so a runaway generation
      // can't blow the latency budget.
      maxOutputTokens: 120,
      temperature: 0.5,
      providerOptions: {
        gateway: {
          user: user.id,
          tags: ["feature:coach-insight", "function:ai-coach"],
        },
      },
    });

    const insight = result.text.trim();
    const usage = result.usage;
    const costUsd = gatewayCostUsd(result.providerMetadata);

    if (insight.length === 0) {
      console.error("[ai-coach] Model returned empty insight");
      return serverError(new Error("Empty insight returned"));
    }

    console.log(
      `[ai-coach] Success user=${user.id} in=${usage?.inputTokens ?? 0} ` +
        `out=${usage?.outputTokens ?? 0} chars=${insight.length}`,
    );

    // Record per-user token usage in the canonical ai_usage ledger
    // (fire-and-forget; never fail the request). The client also logs this to
    // Mixpanel as `coach_insight_generated`, but ai_usage is the prod-safe,
    // server-side source of truth used for future throttling.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      logAiUsage(serviceClient, {
        userId: user.id,
        functionName: "ai-coach",
        model: COACH_INSIGHT_MODEL,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
      }),
    );
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      debitForUsage(serviceClient, user.id, "ai-coach"),
    );

    return jsonResponse({
      insight,
      stale_marker: staleMarker,
      usage: {
        input_tokens: usage?.inputTokens ?? 0,
        output_tokens: usage?.outputTokens ?? 0,
        model: COACH_INSIGHT_MODEL,
        cost_usd: costUsd,
        source: "model",
      },
    });
  } catch (error) {
    console.error("[ai-coach] Fatal error:", error);
    return serverError(error);
  }
}));
