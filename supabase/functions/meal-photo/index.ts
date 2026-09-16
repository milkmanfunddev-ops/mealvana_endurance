/**
 * meal-photo Edge Function — a Tester maintains a Meal's Dish photo (ADR 0003).
 *
 * POST /functions/v1/meal-photo     Auth: Supabase user JWT
 * Body: { action, meal_id, ... }
 *   add_address  { url, credit?, credit_url? } → { photo }
 *   history      { }                           → { photo, history: [...] }
 *
 * Errors: 401 {error:'unauthenticated'} · 403 {error:'not_tester'} ·
 *         400 {error:'invalid_input'|'not_an_image'} · 404 {error:'meal_not_found'} ·
 *         500 {error:'server_error'}.
 *
 * The 403 is the real gate. The app hides the entry point behind the 7-tap
 * "Mark this device as internal" switch, but hiding a button protects nothing:
 * every action here re-reads `users.is_internal` for the caller (story 45).
 *
 * All the logic lives in handler.ts, which takes an authenticated caller and an
 * injected image probe, so it is tested with a fake database and no network.
 *
 * Deploy: ./scripts/deploy_dev.sh meal-photo
 */
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { jsonResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { authenticate } from '../_shared/vana/auth.ts';
import { handleMealPhoto, probeImageOverNetwork } from './handler.ts';

initSentry();

serve(withSentry(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405);

  const auth = await authenticate(req);
  if (!auth.ok) return jsonResponse({ error: auth.error }, auth.status);

  let body: Record<string, unknown>;
  try {
    body = (await req.json()) as Record<string, unknown>;
  } catch {
    return jsonResponse({ error: 'invalid_input', details: 'body is not JSON' }, 400);
  }

  const started = Date.now();
  const result = await handleMealPhoto(body ?? {}, {
    admin: auth.v.admin,
    userId: auth.v.userId,
    probeImage: probeImageOverNetwork,
  });

  console.log(
    `[meal-photo] user=${auth.v.userId} action=${body?.action ?? '-'} meal=${body?.meal_id ?? '-'} ` +
      `→ ${result.status} ${Date.now() - started}ms`,
  );
  return jsonResponse(result.body, result.status);
}));
