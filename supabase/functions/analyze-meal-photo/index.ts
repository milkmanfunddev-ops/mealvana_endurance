/**
 * analyze-meal-photo Edge Function
 *
 * Accepts a reference to a photo stored in the private `meal-photos` bucket,
 * downloads the image via the service-role client, and sends it to Claude via
 * the Vercel AI Gateway for food identification and macro estimation.
 *
 * POST /functions/v1/analyze-meal-photo
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Request body:
 *   { photo_path: string, description?: string }
 *   — photo_path e.g. "{userId}/{uuid}.jpg"; description is optional typed
 *     text analyzed together with the photo as one meal
 *
 * Response (200):
 *   MealAnalysis JSON (see _shared/meal_analysis/schema.ts)
 *
 * Error responses:
 *   400 — missing/invalid body
 *   401 — missing or invalid JWT
 *   403 — {error:'pro_required'}: no active subscription (checked right after auth, same refusal as vana-chat)
 *   403 — photo_path does not start with caller's user id
 *   422 — {error:'not_food'}: the image is not food. One short line in the app, from the
 *         content system; no invented macros (mp-473).
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
import { ANALYZE_MEAL_PHOTO_MODEL } from "../_shared/ai/model.ts";
import { gatewayCostUsd, logAiUsage } from "../_shared/ai/usage.ts";
import { gatewayRefusalResponse } from "../_shared/ai/gateway_error.ts";
import { MealAnalysisRequestSchema } from "../_shared/meal_analysis/schema.ts";
import {
  finalizeAnalysis,
  NOT_FOOD_BODY,
  NOT_FOOD_STATUS,
} from "../_shared/meal_analysis/finalize.ts";
import { mealPhotoPrompt } from "../_shared/meal_analysis/prompt.ts";
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

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  "";

// ---------------------------------------------------------------------------
// Auth helper — validates caller JWT via service-role admin client
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
    console.error("[analyze-meal-photo] Auth error:", error);
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
    console.error("[analyze-meal-photo] AI_GATEWAY_API_KEY secret is not set");
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
    let body: { photo_path?: unknown; description?: unknown };
    try {
      body = await req.json();
    } catch {
      return validationError("Invalid JSON body");
    }

    const photoPath = body.photo_path;
    if (typeof photoPath !== "string" || photoPath.trim().length === 0) {
      return validationError(
        "photo_path is required and must be a non-empty string",
      );
    }

    // Optional typed description, analyzed together with the photo. Capped so
    // a runaway client can't inflate the prompt.
    const description = typeof body.description === "string"
      ? body.description.trim().slice(0, 2000)
      : "";

    // Authorization: photo must belong to the calling user
    if (!photoPath.startsWith(`${user.id}/`)) {
      console.warn(
        `[analyze-meal-photo] User ${user.id} attempted to access photo at path: ${photoPath}`,
      );
      return errorResponse(
        "Access denied: photo does not belong to this user",
        403,
      );
    }

    // Download image from private storage using service-role client
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Credit check ─────────────────────────────────────────────────────────
    const credit = await ensureAndCheckCredits(
      serviceClient,
      user.id,
      "analyze-meal-photo",
    );
    if (!credit.allowed) {
      return jsonResponse(insufficientCreditsBody(credit), 402);
    }

    // ── Rate limit ───────────────────────────────────────────────────────────
    // The same shared Vana limiter as chat, on the server (mp-469 criterion 3): the row is written before the
    // model runs, so photos fired in parallel cannot race past the window. The refusal carries a code, never
    // prose — the app's line comes from the content system.
    const reserved = await reserveCall(
      serviceClient,
      user.id,
      "vana.meal_photo",
      { model: ANALYZE_MEAL_PHOTO_MODEL },
    );
    if (!reserved.allowed) {
      return jsonResponse(
        { error: "rate_limited", retry_after_seconds: reserved.retryAfterSeconds },
        429,
      );
    }

    const { data: imageData, error: storageError } = await serviceClient.storage
      .from("meal-photos")
      .download(photoPath);

    if (storageError || !imageData) {
      console.error(
        "[analyze-meal-photo] Storage download error:",
        storageError,
      );
      return errorResponse(
        `Could not retrieve photo: ${storageError?.message ?? "unknown error"}`,
        500,
      );
    }

    // Convert Blob to base64 for the vision message part. Chunked encoding:
    // spreading the whole array into String.fromCharCode blows the call stack
    // for images over ~1MB.
    const arrayBuffer = await imageData.arrayBuffer();
    const uint8 = new Uint8Array(arrayBuffer);
    let binary = "";
    const chunkSize = 8192;
    for (let i = 0; i < uint8.length; i += chunkSize) {
      binary += String.fromCharCode(...uint8.subarray(i, i + chunkSize));
    }
    const base64Image = btoa(binary);

    // Determine MIME type from path extension (default to JPEG)
    const ext = photoPath.split(".").pop()?.toLowerCase();
    const mimeType = ext === "png"
      ? "image/png"
      : ext === "webp"
      ? "image/webp"
      : ext === "gif"
      ? "image/gif"
      : "image/jpeg";

    console.log(
      `[analyze-meal-photo] Analyzing photo for user ${user.id}, path: ${photoPath}, model: ${ANALYZE_MEAL_PHOTO_MODEL}`,
    );

    // Call Claude via Vercel AI Gateway.
    // The fixed instructions go first in their own system message with a one-hour cache
    // marker; the photo and any words typed with it go last (ai-cost ticket 08, mp-473).
    let result;
    try {
      result = await generateObject({
        model: ANALYZE_MEAL_PHOTO_MODEL as Parameters<typeof generateObject>[0]["model"],
        schema: MealAnalysisRequestSchema,
        maxOutputTokens: 1000,
        ...mealPhotoPrompt({ base64Image, mediaType: mimeType, description }),
        allowSystemInMessages: false,
        providerOptions: {
          gateway: {
            user: user.id,
            tags: [
              "feature:meal-analyze",
              description ? "modality:photo_text" : "modality:photo",
              "function:analyze-meal-photo",
            ],
          },
        },
      });
    } catch (aiError) {
      // `not_food` is part of the schema now, so this arm is only for a model that
      // answers with the bare flag and fails the parse. Same code, same status.
      const errStr = String(aiError);
      if (
        errStr.includes("not_food") || errStr.toLowerCase().includes("not food")
      ) {
        return jsonResponse(NOT_FOOD_BODY, NOT_FOOD_STATUS);
      }
      throw aiError;
    }

    // The totals are ours, not the model's, and "not food" is an answer rather than a
    // parse failure (ai-cost ticket 08, mp-473).
    const finalized = finalizeAnalysis(result.object);
    const usage = result.usage;
    const costUsd = gatewayCostUsd(result.providerMetadata);

    // Log usage to jade_calls table (fire-and-forget; never fail the request)
    // Register with waitUntil so the insert survives isolate shutdown
    // after the response is returned.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      serviceClient
        .from("jade_calls")
        .insert({
          user_id: user.id,
          conversation_id: null,
          function_name: "analyze-meal-photo",
          model: ANALYZE_MEAL_PHOTO_MODEL,
          input_tokens: usage?.inputTokens ?? 0,
          output_tokens: usage?.outputTokens ?? 0,
        })
        .then(({ error: logError }) => {
          if (logError) {
            console.error(
              "[analyze-meal-photo] Failed to log ai usage:",
              logError,
            );
          }
        }),
    );
    // The reservation IS this call's row in the Vana call log: its tokens land on it.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      completeCall(serviceClient, reserved.callId, {
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
      }),
    );
    // Also record in the canonical, prod-safe ai_usage ledger (used for
    // per-user token visibility + future throttling).
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      logAiUsage(serviceClient, {
        userId: user.id,
        functionName: "analyze-meal-photo",
        model: ANALYZE_MEAL_PHOTO_MODEL,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
        costUsd,
      }),
    );
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      debitForUsage(serviceClient, user.id, "analyze-meal-photo"),
    );

    // A photo that is not food: one answer, no invented macros. The call still cost us a
    // model turn, so it is logged and debited above like any other.
    if (finalized.notFood) {
      console.log(`[analyze-meal-photo] Not food for user ${user.id}`);
      return jsonResponse(NOT_FOOD_BODY, NOT_FOOD_STATUS);
    }

    const analysis = finalized.analysis;
    console.log(
      `[analyze-meal-photo] Success for user ${user.id}: "${analysis.name}", ` +
        `${analysis.items.length} items, confidence=${analysis.confidence}`,
    );

    return jsonResponse({
      ...analysis,
      _usage: {
        input_tokens: usage?.inputTokens ?? 0,
        output_tokens: usage?.outputTokens ?? 0,
        model: ANALYZE_MEAL_PHOTO_MODEL,
        cost_usd: costUsd,
      },
    });
  } catch (error) {
    // The gateway refusing US (budget hard-stop, dead key) is not the athlete's problem and not their
    // wallet: a distinct code, never a 402 (mp-437). Nothing was debited — `debitForUsage` only runs
    // after a successful generation.
    const refused = gatewayRefusalResponse(error, "analyze-meal-photo");
    if (refused) return refused;
    console.error("[analyze-meal-photo] Fatal error:", error);
    return serverError(error);
  }
}));
