/**
 * Search Catalog Edge Function
 *
 * Relevance-ranked text search over catalog_products + catalog_variants,
 * delegated to the `search_catalog_ranked` RPC (see migration
 * 20260716120000_search_catalog_ranked.sql for the full rationale).
 *
 * Request:  { query: string, limit?: number, product_type?: string, product_type_id?: string }
 * Response: { success: true, results: [...], total: number }
 *
 * DO NOT revert this to a PostgREST `.or(...ilike...)` chain. Two reasons, both
 * measured (docs/architecture/food-search-scan-audit-2026-07-16.md §9c):
 *
 *  1. A single whole-phrase pattern returns 0 for any multi-word query whose
 *     tokens span columns — 'rx bar' -> 0 while 'rxbar' -> 13, because
 *     brand='RXBAR' and title='Protein Bar'. Chaining .or() per token instead
 *     ANDs them, which still returns 0 for 'nuun electrolyte tablets' (that
 *     product's name contains no word "electrolyte").
 *  2. PostgREST cannot rank. Results were previously ordered by
 *     nutrition_confidence — data quality, not relevance.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { query, limit = 20, product_type, product_type_id } = await req.json();

    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return errorResponse('query is required and must be a non-empty string');
    }

    const trimmedQuery = query.trim();
    const maxLimit = Math.min(Math.max(1, limit), 50);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: {
            Authorization: req.headers.get('Authorization') ?? '',
          },
        },
      }
    );

    // Tokenization, scoring, thresholding and ranking all live in the RPC so
    // there is exactly one definition of "what matches" (and PostgREST cannot
    // express any of it). The RPC clamps `lim` itself; maxLimit is passed for
    // clarity and to keep the contract explicit at this boundary.
    const { data, error } = await supabase.rpc('search_catalog_ranked', {
      q: trimmedQuery,
      lim: maxLimit,
      p_product_type: typeof product_type === 'string' && product_type ? product_type : null,
      p_product_type_id:
        typeof product_type_id === 'string' && product_type_id ? product_type_id : null,
    });

    if (error) {
      console.error('Catalog search error:', error);
      return errorResponse('Search failed', 500, error.message);
    }

    // Map rows to response shape
    const results = (data || []).map((item: Record<string, unknown>) => ({
      id: item.id,
      title: item.title,
      variant_title: item.variant_title,
      brand: item.brand,
      product_type: item.product_type,
      barcode: item.barcode,
      image_url: item.image_url,
      product_url: item.product_url,
      price_cents: item.price_cents,
      currency_code: item.currency_code,
      // Nutrition inline
      calories_per_serving: item.calories_per_serving,
      carbs_g: item.carbs_g,
      protein_g: item.protein_g,
      fat_g: item.fat_g,
      sodium_mg: item.sodium_mg,
      serving_size: item.serving_size,
      serving_grams: item.serving_grams,
      caffeine_mg: item.caffeine_mg,
      nutrition_source: item.nutrition_source,
      nutrition_confidence: item.nutrition_confidence,
      has_nutrition: !!(item.calories_per_serving || item.carbs_g),
      // Relevance score from search_catalog_ranked (2x brand + 1x title token
      // hits). Results arrive already ordered by it; exposed for debugging and
      // so callers can merge these with other sources without re-scoring.
      score: item.score,
      // Classification fields (new)
      product_type_id: item.product_type_id,
      categories: item.categories,
      is_electrolyte: item.is_electrolyte,
      is_liquid: item.is_liquid,
      allergens: item.allergens,
      excluded_diets: item.excluded_diets,
    }));

    return jsonResponse({
      success: true,
      results,
      total: results.length,
      query: trimmedQuery,
    });
  } catch (e) {
    return serverError(e);
  }
}));
