/**
 * USDA FoodData Central client. Extracted from lookup-product/index.ts
 * (2026-07-16). Behaviour unchanged — a pure move.
 *
 * USDA data is CC0 (public domain): no attribution, no share-alike, safe to
 * resell — which is why it is preferred over OFF for nutrition.
 *
 * Rate limit is 1,000 req/hour PER IP, and an edge function puts every user
 * behind a single IP. Cache aggressively; gate calls behind thin local results.
 */
import { toGtin14 } from './gtin.ts';
import { detectProductType } from './product_type.ts';

/**
 * Look up a branded product by barcode in USDA FoodData Central.
 *
 * Fallback layer used only when the product catalog and Open Food Facts both
 * miss. Single call: search by barcode, match on GTIN, and read per-100g
 * nutrition straight from the search result's foodNutrients (deriving
 * per-serving from serving grams). Returns a cleanedProduct in the same shape
 * as the OFF response so the Flutter client needs zero changes. Requires the
 * USDA_API_KEY secret; returns null if unset.
 */
async function lookupUsda(barcode: string): Promise<{ product: Record<string, unknown>; source: string } | null> {
  const apiKey = Deno.env.get('USDA_API_KEY');
  if (!apiKey) {
    console.log('ℹ️ Lookup Product - USDA_API_KEY not set, skipping USDA fallback');
    return null;
  }

  // USDA stores GTINs zero-padded to 14 digits; scans are usually 12 (UPC-A) or
  // 13 (EAN-13). Compare in canonical GTIN-14 form (digits only, left-padded to
  // 14) so equivalent codes match exactly without empty-string collisions.
  const target = toGtin14(barcode);
  // Reject empty / all-zero barcodes (would false-match junk USDA records).
  if (/^0+$/.test(target)) {
    console.log('ℹ️ Lookup Product - Skipping USDA for degenerate barcode:', barcode);
    return null;
  }

  try {
    // USDA indexes GTINs inconsistently (some stored 12-digit, some 14-digit
    // zero-padded) and its search matches exact tokens, so a single query form
    // misses items we actually cover. Try a few forms until one GTIN-14 matches.
    const digits = barcode.replace(/\D/g, '');
    // Two forms cover USDA's inconsistent storage: as-scanned and GTIN-14 padded.
    const variants = [...new Set([digits, target])].filter((v) => v.length >= 6);
    let match: any = null;
    for (const v of variants) {
      const searchResp = await fetch(
        `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${apiKey}` +
          `&query=${encodeURIComponent(v)}&dataType=Branded&pageSize=10`,
      );
      if (!searchResp.ok) {
        console.error('⚠️ USDA search failed:', searchResp.status);
        continue;
      }
      const searchData = await searchResp.json();
      match = (searchData.foods ?? []).find(
        (f: any) => f.gtinUpc && toGtin14(String(f.gtinUpc)) === target,
      );
      if (match) break;
    }
    if (!match) {
      console.log('ℹ️ Lookup Product - No USDA gtinUpc match for', barcode);
      return null;
    }

    // Search results already carry per-100g foodNutrients + serving size, so we
    // read nutrition straight from `match` — no second (detail) API call needed.
    const description = match.description || 'Unknown Product';
    const brand = match.brandName || match.brandOwner || null;

    // Per-100g values by USDA nutrientNumber (stable across responses).
    const per100 = (num: string): number | null => {
      const n = (match.foodNutrients ?? []).find(
        (x: any) => String(x.nutrientNumber) === num,
      );
      return n && typeof n.value === 'number' ? n.value : null;
    };
    const cal100 = per100('208');    // Energy (kcal)
    const carb100 = per100('205');   // Carbohydrate, by difference (g)
    const prot100 = per100('203');   // Protein (g)
    const fat100 = per100('204');    // Total lipid / fat (g)
    const sodium100 = per100('307'); // Sodium, Na (mg)

    // servingSize is grams only when the unit is a gram variant.
    const gramsFrom = (size: unknown, u: unknown): number | null => {
      const uu = String(u || '').toUpperCase();
      return typeof size === 'number' && (uu === 'GRM' || uu === 'G') ? size : null;
    };
    let servingGrams = gramsFrom(match.servingSize, match.servingSizeUnit);
    let servingText = match.householdServingFullText || null;

    // Per-serving values. Common case: derive from per-100g using serving grams
    // (matches USDA's printed label) — no extra call. Only when the search
    // result lacks a gram serving do we make ONE detail call for labelNutrients.
    let calS: number | null, carbS: number | null, protS: number | null,
        fatS: number | null, sodiumS: number | null;
    if (servingGrams != null) {
      const per = (v: number | null) =>
        v != null ? Math.round(v * servingGrams!) / 100 : null;
      calS = per(cal100); carbS = per(carb100); protS = per(prot100);
      fatS = per(fat100); sodiumS = per(sodium100);
    } else {
      calS = carbS = protS = fatS = sodiumS = null;
      try {
        const detailResp = await fetch(
          `https://api.nal.usda.gov/fdc/v1/food/${match.fdcId}?api_key=${apiKey}`,
        );
        if (detailResp.ok) {
          const food = await detailResp.json();
          const ln = food.labelNutrients ?? {};
          const lv = (k: string): number | null =>
            ln[k] && typeof ln[k].value === 'number' ? ln[k].value : null;
          calS = lv('calories'); carbS = lv('carbohydrates'); protS = lv('protein');
          fatS = lv('fat'); sodiumS = lv('sodium');
          servingText = food.householdServingFullText || servingText;
          servingGrams = gramsFrom(food.servingSize, food.servingSizeUnit);
        }
      } catch (e) {
        console.error('⚠️ USDA detail fallback failed:', e);
      }
    }
    const hasServing = calS != null || carbS != null;

    const cleanedProduct = {
      barcode: match.gtinUpc || barcode,
      product_name: description,
      brand_name: brand,
      image_url: null,
      // Serving information
      serving_size: servingText,
      serving_grams: servingGrams,
      // Per-100g nutrition (from search foodNutrients)
      calories_per_100g: cal100,
      carbohydrates_per_100g: carb100,
      protein_per_100g: prot100,
      fat_per_100g: fat100,
      sodium_mg_per_100g: sodium100,
      // Per-serving nutrition (derived, or from labelNutrients on fallback)
      calories_per_serving: calS,
      carbohydrates_per_serving: carbS,
      protein_per_serving: protS,
      fat_per_serving: fatS,
      sodium_mg_per_serving: sodiumS,
      // Additional fields
      categories: match.brandedFoodCategory || null,
      serving_quantity: servingGrams,
      serving_quantity_unit: servingGrams ? 'g' : null,
      product_quantity: null,
      product_quantity_unit: null,
      // Best-effort product type from brand + name (no OFF taxonomy from USDA)
      suggested_product_type: detectProductType(null, null, description, null),
      // Metadata
      api_source: 'usda_fdc',
      confidence_score: 0.8,
      nutrition_data_per: hasServing ? 'serving' : '100g',
    };

    return { product: cleanedProduct, source: 'usda_barcode' };
  } catch (e) {
    console.error('⚠️ USDA lookup error:', e);
    return null;
  }
}

export { lookupUsda };
