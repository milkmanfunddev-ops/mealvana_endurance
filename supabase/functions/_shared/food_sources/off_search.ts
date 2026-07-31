/**
 * Open Food Facts — TEXT search via **Search-a-licious**.
 *
 * Added 2026-07-16. Search-a-licious (search.openfoodfacts.org) is OFF's own
 * Elasticsearch service and their official replacement for the legacy Perl
 * `cgi/search.pl`. It is NOT a different data source — it indexes the same OFF
 * database, so it adds reliability and quality, not coverage.
 *
 * Why it over the legacy CGI:
 *   - full `nutriments` in the SAME call (the legacy path needs a second fetch)
 *   - real relevance (`_score`), Lucene query syntax, a `fields` allowlist
 *   - when both are healthy, it sustained ~3x the request rate
 *
 * ⚠️ IT IS BETA (self-reports version 0.1.0) AND IT DOES GO DOWN. Measured
 * 2026-07-16: 10/10 OK in the morning, then 0/10 (all HTTP 502) a few hours
 * later — while the legacy endpoint was ALSO 0/5. Both share OFF infra, which
 * is exactly why there is no legacy fallback here: same corpus, same outage,
 * and the legacy endpoint is the flakier of the two. This tier must therefore
 * fail soft and never block a search. USDA runs in parallel and carries the
 * load when OFF is down.
 *
 * ⚠️ LICENSING — ODbL (share-alike). Rows from here MUST keep
 * source = 'open_food_facts' so nutrition_products.resale_ok (generated:
 * source IN ('usda_fdc','usda_bulk','user')) excludes them from any resold
 * tier. Do not launder OFF data through another source value.
 *
 * Rate limit: undocumented for Search-a-licious (the published 10 req/min is
 * for the legacy endpoints). Self-throttle: this is gated behind thin local
 * results and has a hard timeout.
 */
import { detectProductType } from './product_type.ts';
import { toGtin14 } from './gtin.ts';
import type { NutritionProductLike } from './usda_search.ts';

const SEARCH_A_LICIOUS = 'https://search.openfoodfacts.org/search';

/**
 * Live text search against Open Food Facts.
 *
 * Never throws — returns [] on any error. This is a supplementary tier; an OFF
 * outage must degrade to "USDA + catalog only", never to a failed search.
 */
export async function searchOpenFoodFacts(
  query: string,
  limit: number,
  timeoutMs = 4000,
): Promise<NutritionProductLike[]> {
  const q = query.trim();
  if (!q) return [];

  // Only the fields we map — keeps the payload small and the contract explicit.
  const fields = [
    'code',
    'product_name',
    'brands',
    'image_url',
    'serving_size',
    'serving_quantity',
    'nutriments',
    'categories_tags',
    'brands_tags',
  ].join(',');

  try {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    let resp: Response;
    try {
      resp = await fetch(
        `${SEARCH_A_LICIOUS}?q=${encodeURIComponent(q)}` +
          `&page_size=${Math.min(Math.max(1, limit), 25)}&fields=${fields}`,
        { signal: ctl.signal, headers: { 'User-Agent': OFF_USER_AGENT } },
      );
    } finally {
      clearTimeout(timer);
    }

    if (!resp.ok) {
      console.error(`⚠️ Search-a-licious failed: ${resp.status} (OFF tier skipped)`);
      return [];
    }

    // Beta service: complex Lucene can 500 with a non-JSON body, so never
    // assume the response parses.
    let data: any;
    try {
      data = await resp.json();
    } catch {
      console.error('⚠️ Search-a-licious returned non-JSON (OFF tier skipped)');
      return [];
    }

    const hits: any[] = data?.hits ?? [];
    return hits
      // nutrition_products is barcode-keyed; a hit without `code` has no key.
      .filter((h) => h?.code)
      .map(mapOffHit)
      // A hit with no usable nutrition is noise in a food-logging list.
      .filter((r) => r.calories_per_100g != null || r.carbohydrates_per_100g != null);
  } catch (e) {
    // AbortError included — a slow OFF must not stall the search.
    console.error('⚠️ Search-a-licious error:', e instanceof Error ? e.message : e);
    return [];
  }
}

/** OFF asks that API consumers identify themselves. */
const OFF_USER_AGENT = 'MealvanaEndurance/1.0 (support@mealvana.com)';

/** Map one Search-a-licious hit into the nutrition_products projection. */
function mapOffHit(h: any): NutritionProductLike {
  const n = h.nutriments ?? {};
  const num = (v: unknown): number | null =>
    typeof v === 'number' && Number.isFinite(v) ? v : null;

  const cal100 = num(n['energy-kcal_100g']);
  const carb100 = num(n['carbohydrates_100g']);
  const prot100 = num(n['proteins_100g']);
  const fat100 = num(n['fat_100g']);
  // OFF reports sodium in GRAMS per 100g; our column is milligrams.
  const sodiumG = num(n['sodium_100g']);
  const sodium100 = sodiumG != null ? Math.round(sodiumG * 1000) : null;

  // `brands` comes back as an array on Search-a-licious (the legacy CGI sent a
  // comma-joined string) — handle both rather than assume.
  const brand = Array.isArray(h.brands)
    ? (h.brands[0] ?? null)
    : (typeof h.brands === 'string' ? h.brands.split(',')[0].trim() : null);

  const servingGrams = num(h.serving_quantity);
  const per = (v: number | null) =>
    v != null && servingGrams != null ? Math.round(v * servingGrams) / 100 : null;

  const name = h.product_name || 'Unknown Product';
  const calS = per(cal100);
  const carbS = per(carb100);

  return {
    barcode: toGtin14(String(h.code)),
    product_name: name,
    brand_name: brand,
    image_url: h.image_url || null,
    serving_size: h.serving_size || null,
    serving_grams: servingGrams,
    calories_per_100g: cal100,
    carbohydrates_per_100g: carb100,
    protein_per_100g: prot100,
    fat_per_100g: fat100,
    sodium_mg_per_100g: sodium100,
    calories_per_serving: calS,
    carbohydrates_per_serving: carbS,
    protein_per_serving: per(prot100),
    fat_per_serving: per(fat100),
    sodium_mg_per_serving: per(sodium100),
    categories: Array.isArray(h.categories_tags)
      ? h.categories_tags.join(',')
      : (h.categories_tags ?? null),
    // OFF gives us real taxonomy tags, so detectProductType can use its best
    // (3-stage) path here rather than the name-only heuristic USDA gets.
    suggested_product_type: detectProductType(
      h.categories_tags ?? null,
      h.brands_tags ?? null,
      name,
      null,
    ),
    nutrition_data_per: calS != null || carbS != null ? 'serving' : '100g',
    source: 'open_food_facts',
    confidence_score: 0.6,
  };
}
