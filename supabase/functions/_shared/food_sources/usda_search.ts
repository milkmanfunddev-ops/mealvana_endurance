/**
 * USDA FoodData Central — TEXT search (as opposed to the barcode lookup in
 * usda.ts).
 *
 * Added 2026-07-16. Before this, text search could only ever see USDA rows that
 * some earlier *barcode scan* had happened to cache, so the "FDA tier" was
 * really "a cache of what somebody already scanned" — 2 rows on prod. A bulk
 * 1.9M-row backfill was explicitly rejected, which makes a live call the only
 * way FDA data reaches text search.
 *
 * Licensing: USDA is CC0 (public domain) — no attribution, no share-alike, safe
 * to resell. Rows written from here keep source = 'usda_fdc', which makes
 * nutrition_products.resale_ok true.
 *
 * ⚠️ RATE LIMIT: 1,000 requests/hour PER IP, and an edge function puts every
 * user behind one IP. Callers MUST gate this behind thin local results and rely
 * on the write-through cache. On 429 USDA blocks the key for an hour.
 */
import { detectProductType } from './product_type.ts';
import { toGtin14 } from './gtin.ts';

/** The projection shape `nutrition_products` rows are returned in. */
export interface NutritionProductLike {
  barcode: string;
  product_name: string;
  brand_name: string | null;
  image_url: string | null;
  serving_size: string | null;
  serving_grams: number | null;
  calories_per_100g: number | null;
  carbohydrates_per_100g: number | null;
  protein_per_100g: number | null;
  fat_per_100g: number | null;
  sodium_mg_per_100g: number | null;
  calories_per_serving: number | null;
  carbohydrates_per_serving: number | null;
  protein_per_serving: number | null;
  fat_per_serving: number | null;
  sodium_mg_per_serving: number | null;
  categories: string | null;
  suggested_product_type: string | null;
  nutrition_data_per: string;
  source: string;
  confidence_score: number;
}

/**
 * Live text search against USDA.
 *
 * ONE call: /foods/search already returns `foodNutrients` (per-100g), so there
 * is no need for the /food/{fdcId} detail call that the barcode path sometimes
 * makes — that one is only required for `labelNutrients`. Halves our budget
 * against the per-IP rate limit.
 *
 * dataType priority: Branded first (it is the only set with UPCs, and it is
 * what a consumer food-logging query usually means). Survey/SR-Legacy carry
 * generic foods but have no barcode, and nutrition_products is barcode-keyed,
 * so they are skipped here rather than synthesising fake keys.
 *
 * Never throws — returns [] on any error, since this is a supplementary tier.
 */
export async function searchUsda(
  query: string,
  limit: number,
  timeoutMs = 4000,
): Promise<NutritionProductLike[]> {
  const apiKey = Deno.env.get('USDA_API_KEY');
  if (!apiKey) {
    console.log('ℹ️ search-foods - USDA_API_KEY not set, skipping USDA tier');
    return [];
  }

  const q = query.trim();
  if (!q) return [];

  try {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), timeoutMs);
    let resp: Response;
    try {
      resp = await fetch(
        `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${apiKey}` +
          `&query=${encodeURIComponent(q)}&dataType=Branded` +
          `&pageSize=${Math.min(Math.max(1, limit), 25)}`,
        { signal: ctl.signal },
      );
    } finally {
      clearTimeout(timer);
    }

    if (!resp.ok) {
      // 429 means the per-IP hourly budget is gone and the key is blocked for
      // an hour — worth shouting about, it is not a normal miss.
      console.error(
        resp.status === 429
          ? '🚨 USDA rate limit hit (1000/hr per IP) — key blocked for 1h'
          : `⚠️ USDA search failed: ${resp.status}`,
      );
      return [];
    }

    const data = await resp.json();
    const foods: any[] = data.foods ?? [];

    return foods
      // nutrition_products is keyed by barcode; a row without a GTIN has no key.
      .filter((f) => f.gtinUpc)
      .map((f) => mapUsdaFood(f));
  } catch (e) {
    // AbortError included: a slow USDA must never stall the whole search.
    console.error('⚠️ USDA search error:', e instanceof Error ? e.message : e);
    return [];
  }
}

/** Map one USDA `/foods/search` hit into the nutrition_products projection. */
function mapUsdaFood(f: any): NutritionProductLike {
  const per100 = (num: string): number | null => {
    const n = (f.foodNutrients ?? []).find(
      (x: any) => String(x.nutrientNumber) === num,
    );
    return n && typeof n.value === 'number' ? n.value : null;
  };
  const cal100 = per100('208');
  const carb100 = per100('205');
  const prot100 = per100('203');
  const fat100 = per100('204');
  const sodium100 = per100('307');

  // servingSize is grams only when the unit says so.
  const unit = String(f.servingSizeUnit || '').toUpperCase();
  const servingGrams =
    typeof f.servingSize === 'number' && (unit === 'GRM' || unit === 'G')
      ? f.servingSize
      : null;

  // Derive per-serving from per-100g when we know the serving weight. This
  // matches the printed label and avoids the /food/{fdcId} detail call.
  const per = (v: number | null) =>
    v != null && servingGrams != null
      ? Math.round(v * servingGrams) / 100
      : null;

  const description = f.description || 'Unknown Product';
  const calS = per(cal100);
  const carbS = per(carb100);

  return {
    barcode: toGtin14(String(f.gtinUpc)),
    product_name: description,
    brand_name: f.brandName || f.brandOwner || null,
    image_url: null, // USDA has no images (the barcode path borrows OFF's).
    serving_size: f.householdServingFullText || null,
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
    categories: f.brandedFoodCategory || null,
    suggested_product_type: detectProductType(null, null, description, null),
    nutrition_data_per: calS != null || carbS != null ? 'serving' : '100g',
    source: 'usda_fdc',
    confidence_score: 0.8,
  };
}
