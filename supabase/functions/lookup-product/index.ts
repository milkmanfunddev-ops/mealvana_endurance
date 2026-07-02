import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { initSentry, withSentry } from "../_shared/sentry.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

// ============================================================================
// Product Type Detection from OFF data
// ============================================================================

/**
 * Detect our app's product_type from OpenFoodFacts data using a 3-stage
 * strategy: taxonomy tags → brand + name heuristics → name keywords.
 *
 * Returns a product_type_enum value or null if we can't determine it.
 */
function detectProductType(
  categoryTags: string[] | null,
  brandsTags: string[] | null,
  productName: string | null,
  genericName: string | null,
): string | null {
  const tags = new Set((categoryTags ?? []).map(t => t.toLowerCase()));
  const brands = new Set((brandsTags ?? []).map(b => b.toLowerCase()));
  const name = (productName ?? '').toLowerCase();
  const generic = (genericName ?? '').toLowerCase();
  const nameAndGeneric = `${name} ${generic}`;

  // ── Stage 1: OFF taxonomy tag matching ──
  // These are real tags observed in OFF API responses

  // Energy gels (en:energy-gel, en:energy-gels, plus localized variants)
  if (tags.has('en:energy-gel') || tags.has('en:energy-gels')
      || tags.has('de:energiegel') || tags.has('de:sportgel')
      || tags.has('fr:gel')) {
    return 'gel';
  }

  // Energy/protein bars
  if (tags.has('en:energy-bars') || tags.has('en:protein-energy-bars')) return 'bar';
  if (tags.has('en:protein-bars') || tags.has('en:cereal-bars')) return 'bar';

  // Protein powders / recovery
  if (tags.has('en:protein-powders')) return 'recovery_shake';

  // Sports drinks (specific tags)
  if (tags.has('en:sports-drink') || tags.has('en:sports-drinks')
      || tags.has('en:dietary-drink-for-sport')) {
    return 'sports_drink';
  }

  // Electrolyte-specific drinks
  if (tags.has('en:electrolyte-drink') || tags.has('en:electrolyte-drink-mix')
      || tags.has('en:electrolytes')) {
    return 'electrolyte_only';
  }

  // Sports nutrition (ambiguous - needs brand/name context in stage 2)
  const isSportsNutrition = tags.has('en:sports-nutrition');

  // Dehydrated beverages (drink mixes, but broad - needs context)
  const isDehydratedBev = tags.has('en:dehydrated-beverages')
    || tags.has('en:dried-products-to-be-rehydrated');

  // Waffles (could be regular or sports - needs context)
  const isWaffle = tags.has('en:waffles') || tags.has('en:stuffed-waffles')
    || tags.has('en:stuffed-wafers') || tags.has('en:caramel-stuffed-wafers');

  // ── Stage 2: Brand-aware detection ──
  // Known sports nutrition brands where product type can be inferred

  // GU Energy
  if (brands.has('gu') || brands.has('gu-energy') || brands.has('gu-energy-stroopwafel')) {
    if (nameAndGeneric.includes('stroopwafel') || nameAndGeneric.includes('waffle')) return 'waffle';
    if (nameAndGeneric.includes('chew') || nameAndGeneric.includes('chews')) return 'chew';
    if (nameAndGeneric.includes('drink mix') || nameAndGeneric.includes('roctane drink')) return 'drink_mix';
    return 'gel'; // GU's primary product
  }

  // Maurten
  if (brands.has('maurten')) {
    if (nameAndGeneric.includes('drink mix')) return 'drink_mix';
    return 'gel';
  }

  // SIS (Science in Sport)
  if (brands.has('sis') || brands.has('si-s') || brands.has('science-in-sport')) {
    if (nameAndGeneric.includes('hydro') || nameAndGeneric.includes('electrolyte')) return 'electrolyte_only';
    if (nameAndGeneric.includes('drink') || nameAndGeneric.includes('powder')) return 'drink_mix';
    return 'gel';
  }

  // Clif
  if (brands.has('clif') || brands.has('clif-bar') || brands.has('clif-bar-and-company')) {
    if (nameAndGeneric.includes('bloks') || nameAndGeneric.includes('blok')
        || nameAndGeneric.includes('chew') || nameAndGeneric.includes('shot')) return 'chew';
    return 'bar';
  }

  // Honey Stinger
  if (brands.has('honey-stinger')) {
    if (nameAndGeneric.includes('waffle') || nameAndGeneric.includes('stroopwafel')) return 'waffle';
    if (nameAndGeneric.includes('gel')) return 'gel';
    if (nameAndGeneric.includes('chew')) return 'chew';
    return 'bar'; // default for their bars
  }

  // Electrolyte brands (all products are electrolytes)
  if (brands.has('nuun') || brands.has('saltstick') || brands.has('saltstick-fastchews')
      || brands.has('lmnt')) {
    return 'electrolyte_only';
  }

  // Drink mix brands
  if (brands.has('tailwind')) return 'drink_mix';
  if (brands.has('skratch-labs')) {
    if (nameAndGeneric.includes('chew')) return 'chew';
    if (nameAndGeneric.includes('bar') || nameAndGeneric.includes('cookie')) return 'bar';
    return 'drink_mix';
  }
  if (brands.has('liquid-iv') || brands.has('liquid-i-v')) return 'drink_mix';
  if (brands.has('drip-drop') || brands.has('drip-drop-hydration-inc')) return 'drink_mix';

  // Sports drink brands
  if (brands.has('gatorade') || brands.has('powerade')) {
    if (nameAndGeneric.includes('chew')) return 'chew';
    if (nameAndGeneric.includes('powder') || nameAndGeneric.includes('mix')) return 'drink_mix';
    return 'sports_drink';
  }

  // Recovery/protein brands
  if (brands.has('optimum-nutrition') || brands.has('vega') || brands.has('orgain')
      || brands.has('garden-of-life')) {
    return 'recovery_shake';
  }

  // Spring Energy
  if (brands.has('spring-energy')) return 'gel';

  // Now resolve ambiguous tags with name context
  if (isSportsNutrition) {
    if (nameAndGeneric.includes('gel')) return 'gel';
    if (nameAndGeneric.includes('bar')) return 'bar';
    if (nameAndGeneric.includes('drink') || nameAndGeneric.includes('mix')) return 'drink_mix';
    if (nameAndGeneric.includes('chew')) return 'chew';
  }

  if (isDehydratedBev) {
    if (nameAndGeneric.includes('electrolyte') || nameAndGeneric.includes('hydration')) return 'drink_mix';
    if (nameAndGeneric.includes('sport') || nameAndGeneric.includes('endurance')) return 'drink_mix';
  }

  if (isWaffle) {
    if (nameAndGeneric.includes('energy') || nameAndGeneric.includes('stroopwafel')) return 'waffle';
    // Regular waffles - don't assign a sports type
  }

  // ── Stage 3: Product name keyword fallback ──
  // Catches unbranded or untagged products

  const KEYWORD_MAP: Array<{ keywords: string[]; type: string }> = [
    { keywords: ['energy gel', 'gel pack', 'energy gel with'], type: 'gel' },
    { keywords: ['energy chew', 'shot bloks', 'energy chews', 'fuel chews'], type: 'chew' },
    { keywords: ['stroopwafel', 'energy waffle'], type: 'waffle' },
    { keywords: ['drink mix', 'endurance fuel', 'hydration mix', 'sport drink mix', 'electrolyte powder'], type: 'drink_mix' },
    { keywords: ['electrolyte tablet', 'hydration tablet', 'effervescent electrolyte'], type: 'electrolyte_only' },
    { keywords: ['recovery shake', 'protein shake', 'whey protein', 'protein powder'], type: 'recovery_shake' },
    { keywords: ['energy bar', 'protein bar', 'fuel bar'], type: 'bar' },
    { keywords: ['sports drink', 'isotonic drink', 'thirst quencher'], type: 'sports_drink' },
  ];

  for (const { keywords, type } of KEYWORD_MAP) {
    if (keywords.some(kw => nameAndGeneric.includes(kw))) return type;
  }

  return null; // Can't determine - user picks from dropdown, defaults to 'import'
}

/**
 * Look up a catalog variant by barcode using the catalog_items view
 * (JOINs catalog_products + catalog_variants).
 * Returns a cleanedProduct in the same shape as the OFF response so the
 * Flutter client needs zero changes.
 */
async function lookupCatalog(barcode: string): Promise<{ product: Record<string, unknown>; source: string } | null> {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Select only needed columns (excludes raw_payload, tags, ingredients, etc.)
    const columns = `
      id, title, variant_title, brand, product_type, barcode,
      image_url, product_url, price_cents, currency_code, available_for_sale,
      calories_per_serving, carbs_g, protein_g, fat_g, sodium_mg,
      serving_size, serving_grams, caffeine_mg,
      nutrition_source, nutrition_confidence,
      product_type_id, categories, is_electrolyte, is_liquid,
      allergens, excluded_diets
    `;

    const { data, error } = await supabase
      .from('catalog_items')
      .select(columns)
      .eq('barcode', barcode)
      .eq('available_for_sale', true)
      .limit(1)
      .maybeSingle();

    if (error || !data) return null;

    // Map catalog row → cleanedProduct (same shape as OFF response)
    const cleanedProduct = {
      barcode: data.barcode || barcode,
      product_name: data.variant_title
        ? `${data.title} — ${data.variant_title}`
        : data.title,
      brand_name: data.brand || null,
      image_url: data.image_url || null,
      // Serving information
      serving_size: data.serving_size || null,
      serving_grams: data.serving_grams || null,
      // Per-100g (null — catalog stores per-serving only)
      calories_per_100g: null,
      carbohydrates_per_100g: null,
      protein_per_100g: null,
      fat_per_100g: null,
      sodium_mg_per_100g: null,
      // Per-serving nutrition
      calories_per_serving: data.calories_per_serving || null,
      carbohydrates_per_serving: data.carbs_g || null,
      protein_per_serving: data.protein_g || null,
      fat_per_serving: data.fat_g || null,
      sodium_mg_per_serving: data.sodium_mg || null,
      // Additional fields
      categories: data.product_type || null,
      serving_quantity: data.serving_grams || null,
      serving_quantity_unit: data.serving_grams ? 'g' : null,
      product_quantity: null,
      product_quantity_unit: null,
      // Product type detection — use classified product_type_id from catalog
      suggested_product_type: data.product_type_id || null,
      // Metadata — non-breaking additions
      api_source: 'catalog_thefeed',
      confidence_score: data.nutrition_confidence || (data.calories_per_serving ? 0.9 : 0.5),
      nutrition_data_per: data.calories_per_serving ? 'serving' : '100g',
      // Extra catalog metadata
      catalog_id: data.id,
      product_url: data.product_url || null,
      caffeine_mg: data.caffeine_mg || null,
      // Classification fields (new)
      product_type_id: data.product_type_id || null,
      product_categories: data.categories || null,
      is_electrolyte: data.is_electrolyte || false,
      is_liquid: data.is_liquid || false,
      allergens: data.allergens || [],
      excluded_diets: data.excluded_diets || [],
    };

    return { product: cleanedProduct, source: 'catalog_barcode' };
  } catch (e) {
    console.error('⚠️ Catalog lookup error:', e);
    return null;
  }
}

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
  const gtin14 = (s: string) => s.replace(/\D/g, '').padStart(14, '0').slice(-14);
  const target = gtin14(barcode);
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
        (f: any) => f.gtinUpc && gtin14(String(f.gtinUpc)) === target,
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

/**
 * Best-effort fetch of the raw Open Food Facts product by barcode. Serves two
 * roles: the image for a USDA hit (USDA has no images), and the full nutrition
 * fallback when USDA misses. Never throws — returns null on any miss/error.
 */
async function fetchOffProduct(barcode: string): Promise<any | null> {
  try {
    const resp = await fetch(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`);
    if (!resp.ok) return null;
    const data = await resp.json();
    if (data.status === 1 && data.product) return data.product;
  } catch (e) {
    console.error('⚠️ OFF fetch failed:', e);
  }
  return null;
}

/** Extract the best available image URL from a raw OFF product. */
function offImage(offProduct: any | null): string | null {
  if (!offProduct) return null;
  return offProduct.image_url || offProduct.image_front_url || null;
}

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

Deno.serve(withSentry(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const requestData = await req.json();
    console.log('🔄 Lookup Product - Request received:', {
      barcode: requestData.barcode,
      open_food_facts_id: requestData.open_food_facts_id
    });
    // Validate that we have at least one identifier
    if (!requestData.barcode && !requestData.open_food_facts_id) {
      console.error('❌ Lookup Product - Missing identifiers');
      return new Response(JSON.stringify({
        success: false,
        error: 'Either barcode or open_food_facts_id must be provided'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }

    // ── Priority 0: Check product catalog by barcode ──
    if (requestData.barcode) {
      console.log('🔍 Lookup Product - Checking product catalog:', requestData.barcode);
      const catalogResult = await lookupCatalog(requestData.barcode);
      if (catalogResult) {
        console.log('✅ Lookup Product - Found in catalog:', {
          product_name: (catalogResult.product as any).product_name,
          has_nutrition: !!(catalogResult.product as any).calories_per_serving,
        });
        return new Response(JSON.stringify({
          success: true,
          product: catalogResult.product,
          source: catalogResult.source,
          message: `Product found via product catalog`,
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      console.log('ℹ️ Lookup Product - Not in catalog, falling through to USDA');
    }

    let productData = null;
    let source = '';

    // ── Priority 1: barcode → USDA + Open Food Facts IN PARALLEL ──
    // USDA (public-domain, resale-safe) is preferred for nutrition; OFF is both
    // the nutrition fallback and the image source (USDA has no images). We need
    // the OFF result either way, so fire both concurrently to cut latency — same
    // number of calls, less wall-clock than doing them one after the other.
    if (requestData.barcode) {
      console.log('🔍 Lookup Product - Parallel USDA + OFF lookup:', requestData.barcode);
      const [usdaResult, offProduct] = await Promise.all([
        lookupUsda(requestData.barcode),
        fetchOffProduct(requestData.barcode),
      ]);

      // Prefer USDA nutrition; borrow the product image from OFF.
      if (usdaResult) {
        (usdaResult.product as any).image_url = offImage(offProduct);
        console.log('✅ Lookup Product - Found via USDA FDC:', {
          product_name: (usdaResult.product as any).product_name,
          has_nutrition: !!(usdaResult.product as any).calories_per_serving,
          has_image: !!(usdaResult.product as any).image_url,
        });
        return new Response(JSON.stringify({
          success: true,
          product: usdaResult.product,
          source: usdaResult.source,
          message: 'Product found via USDA FoodData Central',
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // USDA miss → fall back to the OFF product we already fetched in parallel.
      if (offProduct) {
        productData = offProduct;
        source = 'barcode';
        console.log('✅ Lookup Product - Found via OFF (USDA miss)');
      }
    }
    // Priority 2: Open Food Facts ID (only when no barcode was provided)
    if (!productData && requestData.open_food_facts_id) {
      console.log('🔍 Lookup Product - Attempting Open Food Facts ID lookup:', requestData.open_food_facts_id);
      try {
        // Open Food Facts ID is typically the barcode, but let's be explicit
        const offResponse = await fetch(`https://world.openfoodfacts.org/api/v0/product/${requestData.open_food_facts_id}.json`);
        if (offResponse.ok) {
          const offData = await offResponse.json();
          if (offData.status === 1 && offData.product) {
            productData = offData.product;
            source = 'open_food_facts_id';
            console.log('✅ Lookup Product - Found via Open Food Facts ID');
          }
        }
      } catch (error) {
        console.error('⚠️ Lookup Product - Open Food Facts ID lookup failed:', error);
      }
    }
    // If no product found with either method
    if (!productData) {
      console.log('❌ Lookup Product - No product found');
      return new Response(JSON.stringify({
        success: false,
        error: 'Product not found in Open Food Facts database',
        message: 'Unable to find product details. Please try a different product or scan a barcode.'
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Process and clean the product data
    const cleanedProduct = {
      // Basic info
      barcode: productData.code || requestData.barcode || requestData.open_food_facts_id,
      product_name: productData.product_name || productData.product_name_en || 'Unknown Product',
      brand_name: productData.brands || null,
      image_url: productData.image_url || productData.image_front_url || null,
      // Serving information
      serving_size: productData.serving_size || null,
      serving_grams: productData.serving_quantity ? parseFloat(productData.serving_quantity) : null,
      // Nutritional information per 100g
      calories_per_100g: productData.nutriments?.['energy-kcal_100g'] || null,
      carbohydrates_per_100g: productData.nutriments?.carbohydrates_100g || null,
      protein_per_100g: productData.nutriments?.proteins_100g || null,
      fat_per_100g: productData.nutriments?.fat_100g || null,
      sodium_mg_per_100g: productData.nutriments?.sodium_100g ? productData.nutriments.sodium_100g * 1000 : null,
      // Per-serving nutrition (if available)
      calories_per_serving: productData.nutriments?.['energy-kcal_serving'] || null,
      carbohydrates_per_serving: productData.nutriments?.carbohydrates_serving || null,
      protein_per_serving: productData.nutriments?.proteins_serving || null,
      fat_per_serving: productData.nutriments?.fat_serving || null,
      sodium_mg_per_serving: productData.nutriments?.sodium_serving ? productData.nutriments.sodium_serving * 1000 : null,
      // Additional fields for beverage detection
      categories: productData.categories || null,
      categories_tags: productData.categories_tags || null,
      brands_tags: productData.brands_tags || null,
      serving_quantity: productData.serving_quantity || null,
      serving_quantity_unit: productData.serving_quantity_unit || null,
      product_quantity: productData.quantity || null,
      product_quantity_unit: productData.quantity ? 'g' : null,
      // Product type detection from OFF taxonomy + brand + name heuristics
      suggested_product_type: detectProductType(
        productData.categories_tags,
        productData.brands_tags,
        productData.product_name || productData.product_name_en,
        productData.generic_name || productData.generic_name_en,
      ),
      // Metadata
      api_source: 'open_food_facts',
      confidence_score: productData.completeness || 0.7,
      nutrition_data_per: productData.nutriments?.['energy-kcal_serving'] ? 'serving' : '100g'
    };
    console.log('✅ Lookup Product - Successfully processed:', {
      product_name: cleanedProduct.product_name,
      source: source,
      has_nutrition: !!(cleanedProduct.calories_per_100g || cleanedProduct.calories_per_serving)
    });
    return new Response(JSON.stringify({
      success: true,
      product: cleanedProduct,
      source: source,
      message: `Product found via ${source}`
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('❌ Lookup Product - Unexpected error:', error);
    return new Response(JSON.stringify({
      success: false,
      error: 'Internal server error',
      message: 'An unexpected error occurred while looking up the product',
      details: error instanceof Error ? error.message : 'Unknown error'
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
}));
