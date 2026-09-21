/**
 * Shared AI model configuration for Mealvana AI edge functions.
 *
 * Model string is passed directly to the Vercel AI SDK's `generateObject`.
 * The SDK routes any "provider/model" string through the Vercel AI Gateway
 * when AI_GATEWAY_API_KEY is present in the environment — no provider SDK
 * import needed.
 *
 * Override at deploy time with the AI_COACH_MODEL secret if a different model
 * checkpoint should be used (e.g. for cost/latency trade-offs):
 *   supabase secrets set AI_COACH_MODEL=anthropic/claude-haiku-4 ...
 *
 * `JADE_MODEL` is the old name for the same secret and is still honoured, so
 * a project that already has it set keeps working. Prefer AI_COACH_MODEL.
 *
 * NOTE (ai-cost ticket 14, 2026-09-21): nothing imports `AI_COACH_MODEL` any
 * more. Jade's chat goes through `_shared/vana/chat.ts`, which reads
 * `VANA_CHAT_MODEL`. It is left here rather than deleted because it is
 * Jade-facing and mp-465 only approved removing the coach insight; deleting it
 * is a separate call.
 */
export const AI_COACH_MODEL: string =
  Deno.env.get('AI_COACH_MODEL') ??
  Deno.env.get('JADE_MODEL') ??
  'anthropic/claude-sonnet-4.6';

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

// `COACH_INSIGHT_MODEL` stood here for the Formula Kit coach-insight one-liner. The app stopped
// calling it and the `ai-coach` route is gone with it (mp-465 clause 4), so the setting is gone too.
// The `COACH_INSIGHT_MODEL` secret, if a project still has one, is now read by nothing.
