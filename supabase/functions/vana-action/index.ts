/**
 * vana-action Edge Function — model-free plan edits and reads (Pro feature).
 *
 * POST /functions/v1/vana-action      Auth: Supabase user JWT
 * Body: { type: UiAction['type'], payload: {...} }   (02-contract.md §4; camelCase or snake_case payload keys)
 * Response 200: { parts: VanaPart[], ...extras }. The client folds any `batch` part into its plan state.
 *   `confirm_plan` is a remote-ack write: the shopping list is built here, then ONE SQL transaction
 *   (`confirm_meal_plan`) confirms the plan and archives the week's other plans; day notes regenerate afterwards
 *   through `vana-day-notes` under EdgeRuntime.waitUntil (never awaited by the client).
 * Errors: 401 {error:'unauthenticated'} · 403 {error:'pro_required'} · 400 {error:<message>} · 429 {error:'rate_limited'}.
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { authenticate } from '../_shared/vana/auth.ts';
import { requirePro } from '../_shared/vana/entitlement.ts';
import { runAction, extraAction } from '../_shared/vana/actions.ts';
import { RateLimitedError } from '../_shared/vana/rate-limit.ts';
import type { UiAction } from '../_shared/vana/contracts.ts';

initSentry();

serve(withSentry(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return errorResponse('Method not allowed. Use POST.', 405);

  const auth = await authenticate(req);
  if (!auth.ok) return jsonResponse({ error: auth.error }, auth.status);
  const v = auth.v;

  let body: UiAction;
  try { body = (await req.json()) as UiAction; } catch { return jsonResponse({ error: 'invalid_body' }, 400); }
  if (!body || typeof body.type !== 'string') return jsonResponse({ error: 'invalid_body', details: 'type is required' }, 400);

  const pro = await requirePro(v.admin, v.userId);
  if (!pro.ok) return jsonResponse({ error: pro.reason }, 403);

  const started = Date.now();
  try {
    const payload = (body.payload ?? {}) as Record<string, unknown>;
    const result = (await extraAction(v, body.type, payload)) ?? (await runAction(v, { type: body.type, payload }));
    console.log(`[vana-action] user=${v.userId} type=${body.type} parts=${result.parts.map((p) => p.kind).join(',') || '-'} ${Date.now() - started}ms`);
    return jsonResponse(result);
  } catch (e) {
    if (e instanceof RateLimitedError) return jsonResponse({ error: 'rate_limited', retry_after_seconds: e.retryAfterSeconds }, 429);
    console.error(`[vana-action] ${body.type} failed:`, (e as Error).message);
    return jsonResponse({ error: (e as Error).message }, 400);
  }
}));
