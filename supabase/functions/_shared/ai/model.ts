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
 * (generateObject against MealAnalysisSchema). These ran on Haiku 4.5 from
 * 2026-07-23 for cost; reverted to Sonnet on 2026-07-30 because extraction
 * quality mattered more than the ~3x saving. Drop back to
 * `anthropic/claude-haiku-4.5` via the env override if spend becomes the
 * binding constraint again — the photo downscale (1000px) is independent of
 * this and stays either way.
 */
export const DESCRIBE_MEAL_MODEL: string =
  Deno.env.get('DESCRIBE_MEAL_MODEL') ?? 'anthropic/claude-sonnet-4.6';

export const ANALYZE_MEAL_PHOTO_MODEL: string =
  Deno.env.get('ANALYZE_MEAL_PHOTO_MODEL') ?? 'anthropic/claude-sonnet-4.6';

/**
 * Model for short, latency-sensitive copy — currently the Formula Kit
 * coach-insight one-liner (`ai-coach`). Also reverted from Haiku 4.5 to Sonnet
 * on 2026-07-30: the output is only ~15-28 words, but it is athlete-facing
 * coaching language where phrasing quality is the whole product.
 *
 * Override at deploy time with the COACH_INSIGHT_MODEL secret:
 *   supabase secrets set COACH_INSIGHT_MODEL=anthropic/claude-haiku-4.5 ...
 */
export const COACH_INSIGHT_MODEL: string =
  Deno.env.get('COACH_INSIGHT_MODEL') ?? 'anthropic/claude-sonnet-4.6';
