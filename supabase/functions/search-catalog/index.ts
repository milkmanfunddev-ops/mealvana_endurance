/**
 * Search Catalog Edge Function
 *
 * Text search against catalog_products + catalog_variants using pg_trgm
 * trigram indexes. Returns available variants with inline nutrition data
 * and product classification fields.
 *
 * Queries the backward-compatible catalog_items_v view which JOINs
 * catalog_products and catalog_variants.
 *
 * Request:  { query: string, limit?: number, product_type?: string, product_type_id?: string }
 * Response: { success: true, results: [...], total: number }
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError } from '../_shared/responses.ts';

serve(async (req) => {
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

    // Build search using ilike with wildcards (leverages pg_trgm GIN indexes)
    const pattern = `%${trimmedQuery}%`;

    let queryBuilder = supabase
      .from('catalog_items_v')
      .select('*', { count: 'exact' })
      .eq('available_for_sale', true)
      .or(`title.ilike.${pattern},brand.ilike.${pattern},variant_title.ilike.${pattern}`)
      .limit(maxLimit)
      .order('nutrition_confidence', { ascending: false, nullsFirst: false });

    // Filter by Shopify product_type (legacy)
    if (product_type && typeof product_type === 'string') {
      queryBuilder = queryBuilder.eq('product_type', product_type);
    }

    // Filter by our classified product_type_id (new)
    if (product_type_id && typeof product_type_id === 'string') {
      queryBuilder = queryBuilder.eq('product_type_id', product_type_id);
    }

    const { data, error, count } = await queryBuilder;

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
      total: count ?? results.length,
      query: trimmedQuery,
    });
  } catch (e) {
    return serverError(e);
  }
});
