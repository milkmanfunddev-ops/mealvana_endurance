/**
 * Search Nutrition Products Edge Function — the EXTERNAL food tier.
 *
 * This is "the world" (USDA + Open Food Facts), as opposed to `search-catalog`,
 * which is our curated Feed. The two are deliberately separate functions: they
 * are different corpora with different ranking, and the client renders them as
 * distinct sections ("Catalog & Suggestions" vs "More Results").
 *
 * Cascade (2026-07-16). Local Drift and the Feed catalog are already exhausted
 * by the client before it calls this at all — see
 * FoodSearchController._maybeAutoSearchNutritionProducts, which only fires when
 * local + catalog < 5. So we never touch an external API before our own data:
 *
 *   1. nutrition_products cache      (our DB, tokenized)
 *   2. live USDA ∥ live OFF          (only if the cache is still thin)
 *   3. write-through into the cache  (so tier 1 answers it next time)
 *
 * USDA and OFF run in PARALLEL and are MERGED — not a fallback chain. They are
 * complementary and neither wins (measured 2026-07-16):
 *   walnuts        USDA ✓            OFF "Walnusskerne" ✗
 *   vitamin water  USDA "chocolate milk" ✗   OFF ✓
 *   clif bloks     USDA "Clif Z bar" ✗       OFF ✓
 * It also means an OFF outage (observed: both OFF endpoints 502 on 2026-07-16)
 * degrades to USDA-only instead of failing.
 *
 * Ranking is ours, not theirs: USDA's native relevance is poor (`vitamin water`
 * → "Milk, chocolate, lowfat, with added vitamin A"). We re-score every result
 * with the same rule as search_catalog_ranked — 2x brand-token hits + 1x
 * name-token hits — so all surfaces agree on what "relevant" means.
 *
 * Licensing: the response mixes CC0 (usda_fdc) and ODbL (open_food_facts) rows
 * for in-app display, which ODbL permits as a "Produced Work" (attribution, no
 * share-alike). A future PAID API must filter to resale_ok = true instead;
 * that column is generated from `source`, so it stays correct automatically.
 *
 * Request:  { query: string, limit?: number }
 * Response: { success: true, results: [...], total: number }
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { searchUsda, type NutritionProductLike } from '../_shared/food_sources/usda_search.ts';
import { searchOpenFoodFacts } from '../_shared/food_sources/off_search.ts';
import { bg } from '../_shared/food_sources/runtime.ts';
// Pure matching rules (tokenize / score / threshold / dedupe) live in the
// shared module so index.test.ts imports the REAL implementation instead of a
// mirror that could silently drift. See that file for the full semantics.
import {
  tokenize,
  scoreResult,
  passesThreshold,
  dedupeByBarcode,
} from '../_shared/food_sources/search_matching.ts';

initSentry();

/**
 * Below this many cache hits we go out to USDA + OFF.
 *
 * Mirrors the client's own _kFewLocalResultsThreshold. Keep it low: USDA allows
 * only 1,000 req/hour PER IP and every user shares this function's IP.
 */
const FEW_CACHE_HITS = 5;

Deno.serve(withSentry(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const { query, limit = 20 } = await req.json();

    if (!query || typeof query !== 'string' || query.trim().length === 0) {
      return errorResponse('query is required and must be a non-empty string');
    }

    const trimmed = query.trim();
    const tokens = tokenize(trimmed);
    if (tokens.length === 0) {
      return jsonResponse({ success: true, results: [], total: 0 });
    }
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

    // ── Tier 1: our own cache ────────────────────────────────────────────────
    // Tokenized: each token must match product_name OR brand_name. Chained
    // .or() calls are implicitly ANDed, so this is "every token appears
    // somewhere". The previous single whole-phrase ILIKE could not match
    // 'coca cola' against USDA's comma-inverted "COCA-COLA, COLA", nor
    // 'pringles original' against "Pringles Crisps Original 5.2oz".
    let cacheQuery = supabase.from('nutrition_products').select(columns);
    for (const t of tokens) {
      const safe = t.replace(/[,()%*]/g, '');
      if (!safe) continue;
      cacheQuery = cacheQuery.or(
        `product_name.ilike.%${safe}%,brand_name.ilike.%${safe}%`,
      );
    }
    const { data: cacheRows, error } = await cacheQuery
      .order('hit_count', { ascending: false })
      .limit(maxLimit);

    if (error) {
      console.error('⚠️ nutrition_products cache query error:', error);
      // Not fatal — fall through to the live tier rather than fail the search.
    }

    const cached = (cacheRows ?? []) as NutritionProductLike[];

    // ── Tier 2: live USDA ∥ OFF, only when the cache is thin ─────────────────
    let live: NutritionProductLike[] = [];
    if (cached.length < FEW_CACHE_HITS) {
      // Parallel, not sequential: they are complementary corpora, and one being
      // down or slow must not gate the other. Both resolve to [] on failure.
      const [usda, off] = await Promise.all([
        searchUsda(trimmed, maxLimit),
        searchOpenFoodFacts(trimmed, maxLimit),
      ]);
      live = [...usda, ...off];

      // Write through so tier 1 answers this next time. Fire-and-forget: adds
      // no latency to this response. Guarded to the two external sources —
      // never rewrite a 'user' or 'usda_bulk' row from here.
      if (live.length > 0) {
        const now = new Date().toISOString();
        const rows = dedupeByBarcode(live)
          .filter((r) => r.source === 'usda_fdc' || r.source === 'open_food_facts')
          .map((r) => ({ ...r, last_seen_at: now, updated_at: now }));
        if (rows.length > 0) {
          // onConflict: 'barcode' — the table's real unique key. Never use a
          // partial-index column here (PostgREST throws 42P10).
          // hit_count / first_cached_at are omitted so existing values survive.
          bg(
            supabase
              .from('nutrition_products')
              .upsert(rows, { onConflict: 'barcode' }),
          );
        }
      }
    }

    // ── Merge + rank ─────────────────────────────────────────────────────────
    const merged = dedupeByBarcode([...cached, ...live])
      .filter((r) => passesThreshold(r, tokens))
      .map((r) => ({ r, score: scoreResult(r, tokens) }))
      .sort((a, b) =>
        b.score - a.score ||
        (b.r.confidence_score ?? 0) - (a.r.confidence_score ?? 0),
      )
      .slice(0, maxLimit)
      .map(({ r }) => r);

    return jsonResponse({
      success: true,
      results: merged,
      total: merged.length,
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
