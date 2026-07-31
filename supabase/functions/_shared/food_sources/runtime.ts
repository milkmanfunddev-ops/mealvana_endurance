/**
 * Edge-runtime helpers. Extracted from lookup-product/index.ts (2026-07-16).
 */
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';


/**
 * Run a task after the response is sent (no added latency); never throws.
 * Accepts a Promise OR a thenable query builder — `Promise.resolve` coerces it
 * to a real promise so `.catch` always exists (Supabase builders lack `.catch`).
 */
function bg(task: Promise<unknown> | PromiseLike<unknown>): void {
  const p = Promise.resolve(task).catch((e) => console.error('bg task failed:', e));
  try {
    // @ts-ignore EdgeRuntime is a Supabase edge-runtime global
    if (typeof EdgeRuntime !== 'undefined' && EdgeRuntime.waitUntil) {
      // @ts-ignore
      EdgeRuntime.waitUntil(p);
    }
  } catch (_) { /* p already swallows its own errors */ }
}

function serviceClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
}

/**
 * Priority 0.5 lookup: a product we've already fetched from USDA/OFF before.
 * Returns the cleanedProduct shape (api_source preserved) or null. Bumps
 * hit_count / last_seen_at in the background so reads add no latency.
 */

export { bg, serviceClient };
