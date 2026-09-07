/**
 * jade-chat Edge Function — the shipped (≤1.23.x) route for the in-app AI chat, now a thin alias of
 * `vana-chat` with kind = 'general' (docs/implement_mealplanning/03-backend.md §2.6).
 *
 * Kept for clients that still invoke `jade-chat`; the 1.24 client repoints to `vana-chat`. Retire once
 * `min_app_version` moves past 1.24.
 *
 * POST /functions/v1/jade-chat        Auth: Supabase user JWT (Authorization: Bearer ...)
 * Request body (unchanged):
 *   { message: string, conversation_id?: string, timezone?: string, location?: {latitude, longitude}, opener?: boolean }
 * Response (unchanged envelope): application/x-ndjson, header x-conversation-id; lines text · ui · done · error, plus
 *   the two additions the shipped parser ignores (`status`, `done.usage`) — see _shared/vana/stream.ts.
 *
 * What changed under the hood (2026-09-01):
 *   - Persona: the Vana GENERAL_PROMPT + general tool set (askChoice, searchMeals, dayGuidance, getProfile, …) replaces
 *     the ai_coach persona/tools. The shipped client renders `choices`; other Vana part kinds are dropped by its
 *     forward-compat parser (`AiCoachUiPart.fromJson` → null for unknown kinds).
 *   - Storage: reads/writes `vana_conversations` / `vana_messages` directly through the caller's JWT client (RLS); the
 *     `jade_*` compatibility views still serve reads. `vana_calls` + `ai_usage` per model call.
 *   - Opener: still ephemeral (no conversation row, nothing persisted, x-conversation-id empty).
 *   - Credits: UNCHANGED — ensureAndCheckCredits before the call (402 when out), debitForUsage after. Pro users are
 *     free via the credit module's own rules; the Vana paths (`vana-chat`) never debit.
 *   - No Pro gate here: this route serves free-tier clients (03-backend.md §3).
 *   - `location` is accepted and ignored (the Vana tools take a place name via getWeather).
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { errorResponse, jsonResponse, validationError, serverError } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { ensureAndCheckCredits, debitForUsage, insufficientCreditsBody } from '../_shared/ai/credits.ts';
import { authenticate } from '../_shared/vana/auth.ts';
import { runChat } from '../_shared/vana/chat.ts';
import { RateLimitedError } from '../_shared/vana/rate-limit.ts';

/** Maximum user-message length to prevent token abuse */
const MAX_MESSAGE_LENGTH = 4000;

const chatCorsHeaders: Record<string, string> = { ...corsHeaders, 'Access-Control-Expose-Headers': 'x-conversation-id, x-vana-kind' };

initSentry();

serve(withSentry(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: chatCorsHeaders });
  if (req.method !== 'POST') return errorResponse('Method not allowed. Use POST.', 405);
  if (!Deno.env.get('AI_GATEWAY_API_KEY')) { console.error('[jade-chat] AI_GATEWAY_API_KEY secret is not set'); return errorResponse('AI service is not configured. Please contact support.', 500); }

  try {
    // ── Authenticate ────────────────────────────────────────────────────────
    const auth = await authenticate(req);
    if (!auth.ok) return errorResponse('Missing or invalid authentication token', 401);
    const v = auth.v;

    // ── Parse body ──────────────────────────────────────────────────────────
    let body: { message?: unknown; conversation_id?: unknown; timezone?: unknown; opener?: unknown };
    try { body = await req.json(); } catch { return validationError('Invalid JSON body'); }

    // Opener mode: the assistant proactively greets the athlete before they type. Ephemeral — nothing is persisted.
    const isOpener = body.opener === true;
    let message = '';
    if (!isOpener) {
      const raw = body.message;
      if (typeof raw !== 'string' || raw.trim().length === 0) return validationError('message is required and must be a non-empty string');
      if (raw.length > MAX_MESSAGE_LENGTH) return validationError(`message is too long (max ${MAX_MESSAGE_LENGTH} characters)`);
      message = raw.trim();
    }
    const conversationId = typeof body.conversation_id === 'string' && body.conversation_id.trim().length > 0 ? body.conversation_id.trim() : null;
    const timezone = typeof body.timezone === 'string' && body.timezone.trim().length > 0 ? body.timezone.trim() : 'UTC';

    // ── Credit check (unchanged) ────────────────────────────────────────────
    const credit = await ensureAndCheckCredits(v.admin, v.userId, 'jade-chat');
    if (!credit.allowed) return jsonResponse(insufficientCreditsBody(credit), 402);

    // ── Run the Vana general chat ───────────────────────────────────────────
    const run = await runChat(v, { kind: 'general', message: isOpener ? undefined : message, conversation_id: conversationId, timezone, opener: isOpener }, {
      functionName: 'jade-chat',
      persist: !isOpener,
      // Debit credits for the successful AI call (opener included — same as before).
      afterFinish: async () => { await debitForUsage(v.admin, v.userId, 'jade-chat'); },
    });
    if (!run.ok) {
      if (run.status === 429) return jsonResponse(run.body, 429);
      return validationError(String(run.body.error ?? 'invalid request'));
    }
    return run.response;
  } catch (error) {
    if (error instanceof RateLimitedError) return jsonResponse({ error: 'rate_limited', retry_after_seconds: error.retryAfterSeconds }, 429);
    console.error('[jade-chat] Fatal error:', error);
    return serverError(error);
  }
}));
