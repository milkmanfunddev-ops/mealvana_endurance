import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { initSentry, withSentry } from "../_shared/sentry.ts";

// Shared food-source clients. These used to live inline in this file (806
// lines); they were extracted 2026-07-16 so the barcode path and the text-search
// path share one definition of each source instead of drifting apart.
import { detectProductType } from '../_shared/food_sources/product_type.ts';
import { lookupUsda } from '../_shared/food_sources/usda.ts';
import { fetchOffProduct, offImage } from '../_shared/food_sources/off.ts';
import {
  lookupNutritionCache,
  cacheNutritionProduct,
} from '../_shared/food_sources/cache.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};


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
      console.log('ℹ️ Lookup Product - Not in catalog, checking nutrition cache');
    }

    // ── Priority 0.5: nutrition_products cache (prior USDA/OFF hits) ──
    // Served from our own DB → zero external calls for anything scanned before.
    if (requestData.barcode) {
      const cacheResult = await lookupNutritionCache(requestData.barcode);
      if (cacheResult) {
        console.log('✅ Lookup Product - Cache hit (nutrition_products):', {
          product_name: (cacheResult.product as any).product_name,
          origin: (cacheResult.product as any).api_source,
        });
        return new Response(JSON.stringify({
          success: true,
          product: cacheResult.product,
          source: cacheResult.source,
          message: 'Product found via nutrition cache',
        }), {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      console.log('ℹ️ Lookup Product - Cache miss, falling through to USDA/OFF');
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
        cacheNutritionProduct(usdaResult.product, 'usda_fdc', requestData.barcode);
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
    if (cleanedProduct.barcode) {
      cacheNutritionProduct(cleanedProduct, 'open_food_facts', String(cleanedProduct.barcode));
    }
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
