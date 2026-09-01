/**
 * vana-day-notes Edge Function — regenerate a plan's per-day Vana notes (one Haiku call for the week).
 *
 * POST /functions/v1/vana-day-notes   Auth: Supabase user JWT (the plan owner's — `vana-action` / `vana-chat` forward it)
 * Body: { plan_id: uuid, anchor_date?: 'YYYY-MM-DD' }
 * Response 200: { plan_id, notes: {date → text}, stale: boolean }
 * Clients never await this: it is invoked under EdgeRuntime.waitUntil after confirm / edits, and by `get_home` when a
 * stale note is being shown. Rate-limited (vana.daynotes) — over the bucket it returns the existing notes unchanged.
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { authenticate } from '../_shared/vana/auth.ts';
import { requirePro } from '../_shared/vana/entitlement.ts';
import { getPlanById } from '../_shared/vana/plan.ts';
import { generateDayNotes } from '../_shared/vana/daynotes.ts';
import { today } from '../_shared/vana/env.ts';

initSentry();

serve(withSentry(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return errorResponse('Method not allowed. Use POST.', 405);
  if (!Deno.env.get('AI_GATEWAY_API_KEY')) return errorResponse('AI service is not configured. Please contact support.', 500);

  const auth = await authenticate(req);
  if (!auth.ok) return jsonResponse({ error: auth.error }, auth.status);
  const v = auth.v;

  let body: { plan_id?: unknown; anchor_date?: unknown };
  try { body = await req.json(); } catch { return jsonResponse({ error: 'invalid_body' }, 400); }
  if (typeof body.plan_id !== 'string' || !body.plan_id) return jsonResponse({ error: 'invalid_body', details: 'plan_id is required' }, 400);
  const anchorDate = typeof body.anchor_date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(body.anchor_date) ? body.anchor_date : today();

  const pro = await requirePro(v.admin, v.userId);
  if (!pro.ok) return jsonResponse({ error: pro.reason }, 403);

  const plan = await getPlanById(v, body.plan_id);
  if (!plan) return jsonResponse({ error: 'plan not found' }, 404);
  try {
    const notes = await generateDayNotes(v, plan, anchorDate);
    return jsonResponse({ plan_id: plan.id, notes, stale: false });
  } catch (e) {
    console.error('[vana-day-notes] failed:', (e as Error).message);
    return jsonResponse({ plan_id: plan.id, notes: plan.dayNotes, stale: true, error: (e as Error).message }, 500);
  }
}));
