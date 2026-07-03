/**
 * Search Nutrition Products Edge Function
 *
 * Text search against the `nutrition_products` master (the barcode->nutrition
 * cache + future bulk-USDA-ingest DB) using pg_trgm trigram indexes on
 * product_name / brand_name. Ranked by hit_count (popularity).
 *
 * The table is RLS-locked (service-role only), so this function reads it with
 * the service-role key and returns a curated projection to the client. It
 * intentionally returns all sources (usda_fdc + open_food_facts) for in-app
 * search — a future PAID API would filter to resale_ok = true instead.
 *
 * Request:  { query: string, limit?: number }
 * Response: { success: true, results: [...], total: number }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

Deno.serve(withSentry(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { query, limit = 20 } = await req.json();

    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return errorResponse('query is required and must be a non-empty string');
    }

    // Sanitize for the PostgREST `.or()` filter: strip characters that would
    // break the comma/paren-delimited filter grammar. Food names don't need them.
    const safe = query.trim().replace(/[,()%*]/g, ' ').trim();
    if (safe.length === 0) {
      return jsonResponse({ success: true, results: [], total: 0 });
    }
    const pattern = `%${safe}%`;
    const maxLimit = Math.min(Math.max(1, limit), 50);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const columns = `
      barcode, product_name, brand_name, image_url,
      serving_size, serving_grams,
      calories_per_100g, carbohydrates_per_100g, protein_per_100g, fat_per_100g, sodium_mg_per_100g,
      calories_per_serving, carbohydrates_per_serving, protein_per_serving, fat_per_serving, sodium_mg_per_serving,
      categories, suggested_product_type, nutrition_data_per, source, confidence_score
    `;

    const { data, error } = await supabase
      .from('nutrition_products')
      .select(columns)
      .or(`product_name.ilike.${pattern},brand_name.ilike.${pattern}`)
      .order('hit_count', { ascending: false })
      .limit(maxLimit);

    if (error) {
      console.error('⚠️ search-nutrition-products query error:', error);
      return errorResponse('Search failed', 500, error.message);
    }

    return jsonResponse({
      success: true,
      results: data ?? [],
      total: (data ?? []).length,
    });
  } catch (e) {
    console.error('❌ search-nutrition-products unexpected error:', e);
    return errorResponse(
      'Internal server error',
      500,
      e instanceof Error ? e.message : 'Unknown error',
    );
  }
}));
