/**
 * CORS headers for Supabase Edge Functions
 * Shared across all functions for consistent cross-origin handling
 */

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  // Must include every header the Supabase client sends, or the browser's CORS
  // preflight blocks the real request with a "Failed to fetch" (web-only — CORS
  // does not exist on native, which is why mobile is unaffected). The Flutter/JS
  // SDKs add headers over time (x-region, x-supabase-api-version, …) that an
  // explicit allow-list keeps missing. Since responses are non-credentialed
  // (Allow-Origin: *), '*' is a valid wildcard matching ANY request header —
  // except `authorization`, which the spec requires be named explicitly even
  // alongside '*'. Future-proofs every functions.invoke() call on web.
  'Access-Control-Allow-Headers': 'authorization, *',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

/**
 * Handle OPTIONS preflight request
 */
export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  return null;
}
