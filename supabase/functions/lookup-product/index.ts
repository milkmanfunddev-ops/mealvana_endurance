import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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
 * Look up a catalog_items row by barcode.
 * Returns a cleanedProduct in the same shape as the OFF response so the
 * Flutter client needs zero changes.
 */
async function lookupCatalog(barcode: string): Promise<{ product: Record<string, unknown>; source: string } | null> {
  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const { data, error } = await supabase
      .from('catalog_items')
      .select('*')
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
      // Metadata — non-breaking additions
      api_source: 'catalog_thefeed',
      confidence_score: data.nutrition_confidence || (data.calories_per_serving ? 0.9 : 0.5),
      nutrition_data_per: data.calories_per_serving ? 'serving' : '100g',
      // Extra catalog metadata (ignored by existing Flutter parsers)
      catalog_id: data.id,
      product_url: data.product_url || null,
      caffeine_mg: data.caffeine_mg || null,
    };

    return { product: cleanedProduct, source: 'catalog_barcode' };
  } catch (e) {
    console.error('⚠️ Catalog lookup error:', e);
    return null;
  }
}

serve(async (req)=>{
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
      console.log('ℹ️ Lookup Product - Not in catalog, falling through to OFF');
    }

    let productData = null;
    let source = '';
    // Priority 1: Try barcode lookup if available
    if (requestData.barcode) {
      console.log('🔍 Lookup Product - Attempting barcode lookup:', requestData.barcode);
      try {
        const barcodeResponse = await fetch(`https://world.openfoodfacts.org/api/v0/product/${requestData.barcode}.json`);
        if (barcodeResponse.ok) {
          const barcodeData = await barcodeResponse.json();
          if (barcodeData.status === 1 && barcodeData.product) {
            productData = barcodeData.product;
            source = 'barcode';
            console.log('✅ Lookup Product - Found via barcode');
          }
        }
      } catch (error) {
        console.error('⚠️ Lookup Product - Barcode lookup failed:', error);
      // Continue to try Open Food Facts ID if available
      }
    }
    // Priority 2: Try Open Food Facts ID if barcode failed or not provided
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
});
