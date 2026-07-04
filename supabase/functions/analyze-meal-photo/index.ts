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
 *   { photo_path: string }  — e.g. "{userId}/{uuid}.jpg"
 *
 * Response (200):
 *   MealAnalysis JSON (see _shared/meal_analysis/schema.ts)
 *
 * Error responses:
 *   400 — missing/invalid body
 *   401 — missing or invalid JWT
 *   403 — photo_path does not start with caller's user id
 *   422 — image is not food (model returned non-food flag)
 *   500 — missing AI_GATEWAY_API_KEY secret or unexpected server error
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { generateObject } from 'npm:ai@6';
import { handleCors } from '../_shared/cors.ts';
import {
  errorResponse,
  jsonResponse,
  serverError,
  validationError,
} from '../_shared/responses.ts';
import { JADE_MODEL } from '../_shared/ai/model.ts';
import { logAiUsage } from '../_shared/ai/usage.ts';
import { MealAnalysisSchema } from '../_shared/meal_analysis/schema.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { ensureAndCheckCredits, debitForUsage, insufficientCreditsBody } from '../_shared/ai/credits.ts';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

// ---------------------------------------------------------------------------
// Auth helper — validates caller JWT via service-role admin client
// ---------------------------------------------------------------------------

async function requireUser(req: Request) {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return { user: null, response: errorResponse('Missing authorization header', 401) };
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error } = await adminClient.auth.getUser(token);

  if (error || !user) {
    console.error('[analyze-meal-photo] Auth error:', error);
    return {
      user: null,
      response: errorResponse('Invalid or expired authentication token', 401),
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

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed. Use POST.', 405);
  }

  // Validate AI Gateway key is configured before doing any real work
  const aiGatewayApiKey = Deno.env.get('AI_GATEWAY_API_KEY');
  if (!aiGatewayApiKey) {
    console.error('[analyze-meal-photo] AI_GATEWAY_API_KEY secret is not set');
    return errorResponse(
      'AI service is not configured. Please contact support.',
      500,
    );
  }

  try {
    // Authenticate caller
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse('Invalid authentication state', 401);

    // Parse body
    let body: { photo_path?: unknown };
    try {
      body = await req.json();
    } catch {
      return validationError('Invalid JSON body');
    }

    const photoPath = body.photo_path;
    if (typeof photoPath !== 'string' || photoPath.trim().length === 0) {
      return validationError('photo_path is required and must be a non-empty string');
    }

    // Authorization: photo must belong to the calling user
    if (!photoPath.startsWith(`${user.id}/`)) {
      console.warn(
        `[analyze-meal-photo] User ${user.id} attempted to access photo at path: ${photoPath}`,
      );
      return errorResponse('Access denied: photo does not belong to this user', 403);
    }

    // Download image from private storage using service-role client
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Credit check ─────────────────────────────────────────────────────────
    const credit = await ensureAndCheckCredits(serviceClient, user.id, 'analyze-meal-photo');
    if (!credit.allowed) {
      return jsonResponse(insufficientCreditsBody(credit), 402);
    }

    const { data: imageData, error: storageError } = await serviceClient.storage
      .from('meal-photos')
      .download(photoPath);

    if (storageError || !imageData) {
      console.error('[analyze-meal-photo] Storage download error:', storageError);
      return errorResponse(
        `Could not retrieve photo: ${storageError?.message ?? 'unknown error'}`,
        500,
      );
    }

    // Convert Blob to base64 for the vision message part. Chunked encoding:
    // spreading the whole array into String.fromCharCode blows the call stack
    // for images over ~1MB.
    const arrayBuffer = await imageData.arrayBuffer();
    const uint8 = new Uint8Array(arrayBuffer);
    let binary = '';
    const chunkSize = 8192;
    for (let i = 0; i < uint8.length; i += chunkSize) {
      binary += String.fromCharCode(...uint8.subarray(i, i + chunkSize));
    }
    const base64Image = btoa(binary);

    // Determine MIME type from path extension (default to JPEG)
    const ext = photoPath.split('.').pop()?.toLowerCase();
    const mimeType =
      ext === 'png' ? 'image/png'
      : ext === 'webp' ? 'image/webp'
      : ext === 'gif' ? 'image/gif'
      : 'image/jpeg';

    console.log(
      `[analyze-meal-photo] Analyzing photo for user ${user.id}, path: ${photoPath}, model: ${JADE_MODEL}`,
    );

    // Call Claude via Vercel AI Gateway
    let result;
    try {
      result = await generateObject({
        model: JADE_MODEL as Parameters<typeof generateObject>[0]['model'],
        schema: MealAnalysisSchema,
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'image',
                image: base64Image,
                mediaType: mimeType,
              },
              {
                type: 'text',
                text: `You are a sports nutrition assistant helping an endurance athlete log their meals accurately.

Analyze this food photo and return a structured meal breakdown.

INSTRUCTIONS:
- Group what you see into items the way a person logging their own plate
  would think about it — one item per DISH, not one item per raw
  ingredient. For example: a plate of "spaghetti and meatballs" is ONE
  item (its sauce, pasta, and meatballs summed into one entry), while a
  side of "broccoli" on the same plate is a SEPARATE item because it's a
  distinct component of the meal. Only split into multiple items when the
  foods are genuinely separate parts of the plate (a side dish, a drink, a
  dessert) — never split a single dish's own ingredients apart.
- Each item's macros must be the SUM across everything that makes up that
  dish (e.g. the meatballs' and sauce's calories/carbs/protein/fat/sodium
  are combined into the "spaghetti and meatballs" item, not reported
  separately).
- Estimate realistic portions for an adult endurance athlete — do NOT underestimate. If there is a full plate of pasta, estimate the full plate, not a small serving.
- Provide per-item macros: calories (kcal), carbohydrates (g), protein (g), fat (g), and sodium (mg). These must be non-null for every item.
- Compute accurate totals across all items.
- Suggest the meal slot (breakfast, lunch, dinner, snack) based on the foods visible.
- Set confidence to "low" if the image is blurry, partially visible, or ambiguous; "medium" if items are visible but portions are uncertain; "high" if clear and well-portioned.
- If the image clearly does not contain food (e.g. a landscape, a person's face, a document), do NOT return a meal analysis — instead return a JSON object with a single field: { "not_food": true }.

Return your answer as structured JSON matching the requested schema.`,
              },
            ],
          },
        ],
      });
    } catch (aiError) {
      // The model returned { not_food: true } — this will cause a zod parse
      // failure. We catch it and check if the raw text signals non-food.
      const errStr = String(aiError);
      if (errStr.includes('not_food') || errStr.toLowerCase().includes('not food')) {
        return errorResponse(
          "The photo doesn't appear to contain food. Please try a different image.",
          422,
        );
      }
      throw aiError;
    }

    const analysis = result.object;
    const usage = result.usage;

    // Log usage to jade_calls table (fire-and-forget; never fail the request)
    // Register with waitUntil so the insert survives isolate shutdown
    // after the response is returned.
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      serviceClient
        .from('jade_calls')
        .insert({
          user_id: user.id,
          conversation_id: null,
          function_name: 'analyze-meal-photo',
          model: JADE_MODEL,
          input_tokens: usage?.inputTokens ?? 0,
          output_tokens: usage?.outputTokens ?? 0,
        })
        .then(({ error: logError }) => {
          if (logError) {
            console.error('[analyze-meal-photo] Failed to log jade_call:', logError);
          }
        }),
    );
    // Also record in the canonical, prod-safe ai_usage ledger (used for
    // per-user token visibility + future throttling).
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      logAiUsage(serviceClient, {
        userId: user.id,
        functionName: 'analyze-meal-photo',
        model: JADE_MODEL,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
      }),
    );
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(debitForUsage(serviceClient, user.id, 'analyze-meal-photo'));

    console.log(
      `[analyze-meal-photo] Success for user ${user.id}: "${analysis.name}", ` +
        `${analysis.items.length} items, confidence=${analysis.confidence}`,
    );

    return jsonResponse(analysis);
  } catch (error) {
    console.error('[analyze-meal-photo] Fatal error:', error);
    return serverError(error);
  }
}));
