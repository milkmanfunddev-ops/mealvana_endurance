/**
 * describe-meal Edge Function
 *
 * Accepts a free-text meal description and returns structured macro estimates
 * via Claude through the Vercel AI Gateway.
 *
 * POST /functions/v1/describe-meal
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Request body:
 *   { description: string }  — e.g. "two eggs on toast with butter and OJ"
 *
 * Response (200):
 *   MealAnalysis JSON (see _shared/meal_analysis/schema.ts)
 *
 * Error responses:
 *   400 — missing/invalid body or description too long
 *   422 — {error:'not_food'}: the description is not food. One short line in the app, from
 *         the content system; no invented macros (mp-473).
 *   401 — missing or invalid JWT
 *   403 — {error:'pro_required'}: no active subscription (checked right after auth, same refusal as vana-chat)
 *   503 — {error:'ai_unavailable'}: the AI Gateway refused US (key budget hard-stopped, key
 *         missing/revoked). Never a 402: the athlete's wallet is fine, so the top-up sheet
 *         would be a lie (mp-437). The app shows "Vana is unavailable right now".
 *   500 — missing AI_GATEWAY_API_KEY secret or unexpected server error
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { generateObject } from "npm:ai@6.0.277";
import { handleCors } from "../_shared/cors.ts";
import {
  errorResponse,
  jsonResponse,
  serverError,
  validationError,
} from "../_shared/responses.ts";
import { DESCRIBE_MEAL_MODEL } from "../_shared/ai/model.ts";
import { gatewayCostUsd, logAiUsage } from "../_shared/ai/usage.ts";
import { gatewayRefusalResponse } from "../_shared/ai/gateway_error.ts";
import { MealAnalysisRequestSchema } from "../_shared/meal_analysis/schema.ts";
import {
  finalizeAnalysis,
  NOT_FOOD_BODY,
  NOT_FOOD_STATUS,
} from "../_shared/meal_analysis/finalize.ts";
import { describeMealPrompt } from "../_shared/meal_analysis/prompt.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { refuseUnlessPro } from "../_shared/vana/entitlement.ts";
import {
  debitForUsage,
  ensureAndCheckCredits,
  insufficientCreditsBody,
} from "../_shared/ai/credits.ts";
import {
  completeCall,
  reserveCall,
} from "../_shared/vana/rate-limit.ts";
import { callMetrics } from "../_shared/vana/log.ts";
import { subscriberState } from "../_shared/vana/subscriber.ts";

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

/** Maximum description length — prevents token abuse */
const MAX_DESCRIPTION_LENGTH = 2000;

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
    console.error("[describe-meal] Auth error:", error);
    return {
      user: null,
      response: errorResponse("Invalid or expired authentication token", 401),
    };
  }

  return { user, response: null };
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

  // Validate AI Gateway key is configured before doing any real work
  const aiGatewayApiKey = Deno.env.get("AI_GATEWAY_API_KEY");
  if (!aiGatewayApiKey) {
    console.error("[describe-meal] AI_GATEWAY_API_KEY secret is not set");
    return errorResponse(
      "AI service is not configured. Please contact support.",
      500,
    );
  }

  try {
    // Authenticate caller
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse("Invalid authentication state", 401);

    // Subscription gate (mp-429 clause 11): bought credits alone never open an AI function.
    const refusal = await refuseUnlessPro(
      createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY),
      user.id,
    );
    if (refusal) return refusal;

    // Parse body
    let body: { description?: unknown };
    try {
      body = await req.json();
    } catch {
      return validationError("Invalid JSON body");
    }

    const description = body.description;
    if (typeof description !== "string" || description.trim().length === 0) {
      return validationError(
        "description is required and must be a non-empty string",
      );
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return validationError(
        `description is too long (max ${MAX_DESCRIPTION_LENGTH} characters)`,
      );
    }

    console.log(
      `[describe-meal] Processing description for user ${user.id}, ` +
        `length: ${description.length} chars, model: ${DESCRIBE_MEAL_MODEL}`,
    );

    // ── Service-role client (reused for credits + jade_calls/ai_usage logging) ─
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Credit check ─────────────────────────────────────────────────────────
    const credit = await ensureAndCheckCredits(
      serviceClient,
      user.id,
      "describe-meal",
    );
    if (!credit.allowed) {
      return jsonResponse(insufficientCreditsBody(credit), 402);
    }

    // ── Rate limit ───────────────────────────────────────────────────────────
    // The same shared Vana limiter as chat, on the server (mp-469 criterion 3): the row is written before the
    // model runs, so descriptions fired in parallel cannot race past the window. The refusal carries a code,
    // never prose — the app's line comes from the content system.
    const reserved = await reserveCall(
      serviceClient,
      user.id,
      "vana.describe_meal",
      { model: DESCRIBE_MEAL_MODEL },
    );
    if (!reserved.allowed) {
      return jsonResponse(
        { error: "rate_limited", retry_after_seconds: reserved.retryAfterSeconds },
        429,
      );
    }

    // Call Claude via Vercel AI Gateway.
    // The fixed instructions go first in their own system message with a one-hour cache
    // marker; the athlete's words go last, on their own (ai-cost ticket 08, mp-473).
    const result = await generateObject({
      model: DESCRIBE_MEAL_MODEL as Parameters<typeof generateObject>[0]["model"],
      schema: MealAnalysisRequestSchema,
      maxOutputTokens: 1000,
      ...describeMealPrompt(description),
      allowSystemInMessages: false,
      providerOptions: {
        gateway: {
          user: user.id,
          tags: [
            "feature:meal-analyze",
            "modality:text",
            "function:describe-meal",
          ],
        },
      },
    });

    // The totals are ours, not the model's, and "not food" is an answer rather than a
    // parse failure (ai-cost ticket 08, mp-473).
    const finalized = finalizeAnalysis(result.object);
    const usage = result.usage;
    const costUsd = gatewayCostUsd(result.providerMetadata);

    // Log usage to jade_calls (fire-and-forget)
    // Register with waitUntil so the insert survives isolate shutdown
    // after the response is returned.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      serviceClient
        .from("jade_calls")
        .insert({
          user_id: user.id,
          conversation_id: null,
          function_name: "describe-meal",
          model: DESCRIBE_MEAL_MODEL,
          input_tokens: usage?.inputTokens ?? 0,
          output_tokens: usage?.outputTokens ?? 0,
        })
        .then(({ error: logError }) => {
          if (logError) {
            console.error("[describe-meal] Failed to log ai usage:", logError);
          }
        }),
    );
    // The reservation IS this call's row in the Vana call log: its tokens land on it.
    // The same shape as a chat turn (ai-cost ticket 05): the gateway's charge, cached tokens,
    // one step, the fact that this call drew the athlete's budget, and the subscriber's plan
    // state, read on the background task so "cost per athlete by plan" counts logged meals too.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      (async () => {
        const sub = await subscriberState(serviceClient, user.id);
        await completeCall(serviceClient, reserved.callId, {
          inputTokens: usage?.inputTokens ?? 0,
          outputTokens: usage?.outputTokens ?? 0,
          ...callMetrics([{ usage, providerMetadata: result.providerMetadata }], usage),
          debited: true,
          subscriberPeriodType: sub.periodType,
          subscriberActiveUntil: sub.activeUntil,
        });
      })(),
    );
    // Also record in the canonical, prod-safe ai_usage ledger (used for
    // per-user token visibility + future throttling).
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      logAiUsage(serviceClient, {
        userId: user.id,
        functionName: "describe-meal",
        model: DESCRIBE_MEAL_MODEL,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
        costUsd,
      }),
    );
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      debitForUsage(serviceClient, user.id, "describe-meal"),
    );

    // A description that is not food: one answer, no invented macros. The call still
    // cost us a model turn, so it is logged and debited above like any other.
    if (finalized.notFood) {
      console.log(`[describe-meal] Not food for user ${user.id}`);
      return jsonResponse(NOT_FOOD_BODY, NOT_FOOD_STATUS);
    }

    const analysis = finalized.analysis;
    console.log(
      `[describe-meal] Success for user ${user.id}: "${analysis.name}", ` +
        `${analysis.items.length} items, confidence=${analysis.confidence}`,
    );

    return jsonResponse({
      ...analysis,
      _usage: {
        input_tokens: usage?.inputTokens ?? 0,
        output_tokens: usage?.outputTokens ?? 0,
        model: DESCRIBE_MEAL_MODEL,
        cost_usd: costUsd,
      },
    });
  } catch (error) {
    // The gateway refusing US (budget hard-stop, dead key) is not the athlete's problem and not their
    // wallet: a distinct code, never a 402 (mp-437). Nothing was debited — `debitForUsage` only runs
    // after a successful generation.
    const refused = gatewayRefusalResponse(error, "describe-meal");
    if (refused) return refused;
    console.error("[describe-meal] Fatal error:", error);
    return serverError(error);
  }
}));
