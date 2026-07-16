/**
 * nutrition_products write-through cache. Extracted from lookup-product/index.ts
 * (2026-07-16). Behaviour unchanged — a pure move.
 *
 * nutrition_products is the canonical product master, not a throwaway cache: it
 * is also the future bulk-ingest target and the source for any licensed API. It
 * is keyed by barcode and RLS-locked (service-role only).
 *
 * LICENSING: resale_ok is a GENERATED column — source IN
 * ('usda_fdc','usda_bulk','user'). Writing an OFF row with the correct source
 * automatically excludes it from resale. Do not launder OFF data through
 * another source value.
 *
 * As of 2026-07-16 this table holds 2 rows on prod / 28 on dev — it fills
 * organically from barcode scans; a bulk USDA backfill was explicitly rejected.
 */
import { toGtin14 } from './gtin.ts';
import { bg, serviceClient } from './runtime.ts';

/**
 * Priority 0.5 lookup: a product we've already fetched from USDA/OFF before.
 * Returns the cleanedProduct shape (api_source preserved) or null. Bumps
 * hit_count / last_seen_at in the background so reads add no latency.
 */
async function lookupNutritionCache(
  barcode: string,
): Promise<{ product: Record<string, unknown>; source: string } | null> {
  try {
    const supabase = serviceClient();
    const gtin = toGtin14(barcode);
    const { data, error } = await supabase
      .from('nutrition_products')
      .select('*')
      .eq('barcode', gtin)
      .maybeSingle();
    if (error || !data) return null;

    bg(
      supabase
        .from('nutrition_products')
        .update({ hit_count: (data.hit_count ?? 0) + 1, last_seen_at: new Date().toISOString() })
        .eq('id', data.id),
    );

    const product = {
      barcode: data.barcode,
      product_name: data.product_name,
      brand_name: data.brand_name,
      image_url: data.image_url,
      serving_size: data.serving_size,
      serving_grams: data.serving_grams,
      calories_per_100g: data.calories_per_100g,
      carbohydrates_per_100g: data.carbohydrates_per_100g,
      protein_per_100g: data.protein_per_100g,
      fat_per_100g: data.fat_per_100g,
      sodium_mg_per_100g: data.sodium_mg_per_100g,
      calories_per_serving: data.calories_per_serving,
      carbohydrates_per_serving: data.carbohydrates_per_serving,
      protein_per_serving: data.protein_per_serving,
      fat_per_serving: data.fat_per_serving,
      sodium_mg_per_serving: data.sodium_mg_per_serving,
      categories: data.categories,
      suggested_product_type: data.suggested_product_type,
      nutrition_data_per: data.nutrition_data_per,
      api_source: data.source,
      confidence_score: data.confidence_score,
    };
    return { product, source: 'cache' };
  } catch (e) {
    console.error('⚠️ nutrition_products cache lookup error:', e);
    return null;
  }
}

/**
 * Write-through: persist an external (USDA/OFF) hit into nutrition_products so
 * the next scan of this barcode is served from cache with zero external calls.
 * Fire-and-forget (background). Only caches external sources; catalog/cache hits
 * are already stored. On conflict, refreshes data but preserves hit_count and
 * first_cached_at (omitted from the payload).
 */
function cacheNutritionProduct(product: any, source: string, barcode: string): void {
  if (source !== 'usda_fdc' && source !== 'open_food_facts') return;
  bg((async () => {
    const supabase = serviceClient();
    const now = new Date().toISOString();
    await supabase.from('nutrition_products').upsert(
      {
        barcode: toGtin14(barcode),
        product_name: product.product_name ?? null,
        brand_name: product.brand_name ?? null,
        image_url: product.image_url ?? null,
        serving_size: product.serving_size ?? null,
        serving_grams: product.serving_grams ?? null,
        calories_per_100g: product.calories_per_100g ?? null,
        carbohydrates_per_100g: product.carbohydrates_per_100g ?? null,
        protein_per_100g: product.protein_per_100g ?? null,
        fat_per_100g: product.fat_per_100g ?? null,
        sodium_mg_per_100g: product.sodium_mg_per_100g ?? null,
        calories_per_serving: product.calories_per_serving ?? null,
        carbohydrates_per_serving: product.carbohydrates_per_serving ?? null,
        protein_per_serving: product.protein_per_serving ?? null,
        fat_per_serving: product.fat_per_serving ?? null,
        sodium_mg_per_serving: product.sodium_mg_per_serving ?? null,
        categories: product.categories ?? null,
        suggested_product_type: product.suggested_product_type ?? null,
        nutrition_data_per: product.nutrition_data_per ?? null,
        source,
        confidence_score: product.confidence_score ?? null,
        raw_payload: product,
        last_seen_at: now,
        updated_at: now,
      },
      { onConflict: 'barcode' },
    );
  })());
}

export { lookupNutritionCache, cacheNutritionProduct };
