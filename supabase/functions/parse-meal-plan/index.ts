/**
 * parse-meal-plan Edge Function
 *
 * Accepts the already-extracted plain text of a meal plan (the client pulls
 * text from the user's PDF/DOCX/TXT on-device — nothing is uploaded or stored)
 * and sends it to Claude via the Vercel AI Gateway to extract a structured list
 * of meals.
 *
 * POST /functions/v1/parse-meal-plan
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Request body:
 *   { plan_text: string }
 *
 * Response (200): MealPlan JSON (see _shared/meal_plan/schema.ts)
 *
 * Error responses:
 *   400 — missing/invalid body or empty text
 *   401 — missing or invalid JWT
 *   402 — insufficient AI credits
 *   413 — text too large
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
import { MealPlanSchema } from '../_shared/meal_plan/schema.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import {
  ensureAndCheckCredits,
  debitForUsage,
  insufficientCreditsBody,
} from '../_shared/ai/credits.ts';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/** Upper bound on accepted plan text (~200k chars ≈ a very long document). */
const MAX_TEXT_CHARS = 200_000;

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
    console.error('[parse-meal-plan] Auth error:', error);
    return {
      user: null,
      response: errorResponse('Invalid or expired authentication token', 401),
    };
  }

  return { user, response: null };
}

const PROMPT = `You are a sports nutrition assistant importing an endurance athlete's meal plan.

Below is the plain text extracted from a meal plan document. Extract EVERY distinct meal into a structured list.

INSTRUCTIONS:
- Return one entry per MEAL (e.g. "Breakfast", "Pre-run snack", "Dinner"), not one entry per food. A meal's individual foods go in its "items" array.
- For each meal, set "day_label" to the day it appears under if the plan is organized by day (e.g. "Day 1", "Monday", "Race Day"). Omit it if the plan is a single day or not day-organized.
- For each item, provide realistic macros for an adult endurance athlete: calories (kcal), carbohydrates (g), protein (g), fat (g), and sodium (mg). These must be non-null for every item. If the plan already lists macros, use those; otherwise estimate from the food and portion.
- Do NOT underestimate portions. If a portion is not specified, estimate a realistic athlete portion and mention it in the meal's "notes".
- Compute accurate "totals" summing all items in each meal.
- Suggest a slot (breakfast, lunch, dinner, snack) for each meal from its name/contents.
- Set each meal's "confidence": "low" if the meal or its portions are ambiguous, "medium" if listed but portions are uncertain, "high" if clearly specified with quantities.
- Set "plan_title" from the document's title if present.
- Extract meals in the order they appear.
- The text may contain page numbers, headers/footers, or extraction artifacts — ignore anything that is not part of a meal.

MEAL PLAN TEXT:
`;

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

initSentry();

serve(withSentry(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed. Use POST.', 405);
  }

  const aiGatewayApiKey = Deno.env.get('AI_GATEWAY_API_KEY');
  if (!aiGatewayApiKey) {
    console.error('[parse-meal-plan] AI_GATEWAY_API_KEY secret is not set');
    return errorResponse('AI service is not configured. Please contact support.', 500);
  }

  try {
    const { user, response: authResponse } = await requireUser(req);
    if (authResponse) return authResponse;
    if (!user) return errorResponse('Invalid authentication state', 401);

    let body: { plan_text?: unknown };
    try {
      body = await req.json();
    } catch {
      return validationError('Invalid JSON body');
    }

    const planText = body.plan_text;
    if (typeof planText !== 'string' || planText.trim().length === 0) {
      return validationError('plan_text is required and must be a non-empty string');
    }
    if (planText.length > MAX_TEXT_CHARS) {
      return errorResponse('The document text is too large to process.', 413);
    }

    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // ── Credit check ─────────────────────────────────────────────────────────
    const credit = await ensureAndCheckCredits(serviceClient, user.id, 'parse-meal-plan');
    if (!credit.allowed) {
      return jsonResponse(insufficientCreditsBody(credit), 402);
    }

    console.log(
      `[parse-meal-plan] Parsing ${planText.length} chars for user ${user.id}, model: ${JADE_MODEL}`,
    );

    const result = await generateObject({
      model: JADE_MODEL as Parameters<typeof generateObject>[0]['model'],
      schema: MealPlanSchema,
      messages: [
        {
          role: 'user',
          content: `${PROMPT}${planText}`,
        },
      ],
    });

    const plan = result.object;
    const usage = result.usage;

    // Usage ledgers (fire-and-forget; survive isolate shutdown via waitUntil).
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      serviceClient
        .from('jade_calls')
        .insert({
          user_id: user.id,
          conversation_id: null,
          function_name: 'parse-meal-plan',
          model: JADE_MODEL,
          input_tokens: usage?.inputTokens ?? 0,
          output_tokens: usage?.outputTokens ?? 0,
        })
        .then(({ error: logError }) => {
          if (logError) {
            console.error('[parse-meal-plan] Failed to log jade_call:', logError);
          }
        }),
    );
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      logAiUsage(serviceClient, {
        userId: user.id,
        functionName: 'parse-meal-plan',
        model: JADE_MODEL,
        inputTokens: usage?.inputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
      }),
    );
    // deno-lint-ignore no-explicit-any
    (globalThis as any).EdgeRuntime?.waitUntil?.(
      debitForUsage(serviceClient, user.id, 'parse-meal-plan'),
    );

    console.log(
      `[parse-meal-plan] Success for user ${user.id}: ` +
        `"${plan.plan_title ?? 'untitled'}", ${plan.meals.length} meals`,
    );

    return jsonResponse(plan);
  } catch (error) {
    console.error('[parse-meal-plan] Fatal error:', error);
    return serverError(error);
  }
}));
