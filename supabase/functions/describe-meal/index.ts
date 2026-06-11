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
 *   401 — missing or invalid JWT
 *   500 — missing AI_GATEWAY_API_KEY secret or unexpected server error
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { generateObject } from 'npm:ai';
import { handleCors } from '../_shared/cors.ts';
import {
  errorResponse,
  jsonResponse,
  serverError,
  validationError,
} from '../_shared/responses.ts';
import { JADE_MODEL } from '../_shared/ai/model.ts';
import { MealAnalysisSchema } from '../_shared/meal_analysis/schema.ts';

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/** Maximum description length — prevents token abuse */
const MAX_DESCRIPTION_LENGTH = 2000;

// ---------------------------------------------------------------------------
// Auth helper
// ---------------------------------------------------------------------------

async function requireUser(req: Request) {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) {
    return { user: null, response: errorResponse('Missing authorization header', 401) };
  }

  const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: { user }, error } = await adminClient.auth.getUser(token);

  if (error || !user) {
    console.error('[describe-meal] Auth error:', error);
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

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  if (req.method !== 'POST') {
    return errorResponse('Method not allowed. Use POST.', 405);
  }

  // Validate AI Gateway key is configured before doing any real work
  const aiGatewayApiKey = Deno.env.get('AI_GATEWAY_API_KEY');
  if (!aiGatewayApiKey) {
    console.error('[describe-meal] AI_GATEWAY_API_KEY secret is not set');
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
    let body: { description?: unknown };
    try {
      body = await req.json();
    } catch {
      return validationError('Invalid JSON body');
    }

    const description = body.description;
    if (typeof description !== 'string' || description.trim().length === 0) {
      return validationError('description is required and must be a non-empty string');
    }

    if (description.length > MAX_DESCRIPTION_LENGTH) {
      return validationError(
        `description is too long (max ${MAX_DESCRIPTION_LENGTH} characters)`,
      );
    }

    console.log(
      `[describe-meal] Processing description for user ${user.id}, ` +
        `length: ${description.length} chars, model: ${JADE_MODEL}`,
    );

    // Call Claude via Vercel AI Gateway
    const result = await generateObject({
      model: JADE_MODEL as Parameters<typeof generateObject>[0]['model'],
      apiKey: aiGatewayApiKey,
      schema: MealAnalysisSchema,
      messages: [
        {
          role: 'user',
          content: `You are a sports nutrition assistant helping an endurance athlete log their meals accurately.

The athlete described this meal: "${description.trim()}"

INSTRUCTIONS:
- Parse the description into individual food items.
- If a quantity is mentioned (e.g. "two eggs", "large OJ"), use it; otherwise assume a single, realistic serving for an adult endurance athlete.
- Do NOT underestimate portions — athletes eat meaningfully sized meals.
- Provide per-item macros: calories (kcal), carbohydrates (g), protein (g), fat (g), and sodium (mg).
- Compute accurate totals across all items.
- Suggest the meal slot (breakfast, lunch, dinner, snack) based on the foods described.
- Set confidence to "high" if the description is precise (weights, brand names, counts); "medium" if typical portions can be inferred; "low" if too vague to estimate reliably.
- If the description clearly does not describe food (e.g. a movie title, a random sentence), set confidence to "low", return a single placeholder item, and set notes to explain.

Return your answer as structured JSON matching the requested schema.`,
        },
      ],
    });

    const analysis = result.object;
    const usage = result.usage;

    // Log usage to jade_calls (fire-and-forget)
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    serviceClient
      .from('jade_calls')
      .insert({
        user_id: user.id,
        conversation_id: null,
        function_name: 'describe-meal',
        model: JADE_MODEL,
        input_tokens: usage?.promptTokens ?? 0,
        output_tokens: usage?.completionTokens ?? 0,
      })
      .then(({ error: logError }) => {
        if (logError) {
          console.error('[describe-meal] Failed to log jade_call:', logError);
        }
      });

    console.log(
      `[describe-meal] Success for user ${user.id}: "${analysis.name}", ` +
        `${analysis.items.length} items, confidence=${analysis.confidence}`,
    );

    return jsonResponse(analysis);
  } catch (error) {
    console.error('[describe-meal] Fatal error:', error);
    return serverError(error);
  }
});
