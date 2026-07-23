/**
 * Shared AI model configuration for Jade edge functions.
 *
 * Model string is passed directly to the Vercel AI SDK's `generateObject`.
 * The SDK routes any "provider/model" string through the Vercel AI Gateway
 * when AI_GATEWAY_API_KEY is present in the environment — no provider SDK
 * import needed.
 *
 * Override at deploy time with the JADE_MODEL secret if a different model
 * checkpoint should be used (e.g. for cost/latency trade-offs):
 *   supabase secrets set JADE_MODEL=anthropic/claude-haiku-4 ...
 */
export const JADE_MODEL: string =
  Deno.env.get('JADE_MODEL') ?? 'anthropic/claude-sonnet-4.6';

/**
 * Per-modality models for meal analysis. Both are structured-extraction tasks
 * (generateObject against MealAnalysisSchema), which Haiku handles at ~1/3 the
 * cost of Sonnet. Raise back to JADE_MODEL via the env override if extraction
 * quality regresses.
 */
export const DESCRIBE_MEAL_MODEL: string =
  Deno.env.get('DESCRIBE_MEAL_MODEL') ?? 'anthropic/claude-haiku-4.5';

export const ANALYZE_MEAL_PHOTO_MODEL: string =
  Deno.env.get('ANALYZE_MEAL_PHOTO_MODEL') ?? 'anthropic/claude-haiku-4.5';

/**
 * Model for short, latency-sensitive, low-stakes copy — currently the Formula
 * Kit coach-insight one-liner (`ai-coach`). Haiku keeps it fast and cheap; the
 * output is ~15-28 words so a frontier model would be wasted spend.
 *
 * Override at deploy time with the COACH_INSIGHT_MODEL secret:
 *   supabase secrets set COACH_INSIGHT_MODEL=anthropic/claude-haiku-4 ...
 */
export const COACH_INSIGHT_MODEL: string =
  Deno.env.get('COACH_INSIGHT_MODEL') ?? 'anthropic/claude-haiku-4.5';
