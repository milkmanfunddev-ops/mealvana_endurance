import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

interface LookupProductRequest {
  barcode?: string;
  open_food_facts_id?: string;
}

interface ProductResponse {
  success: boolean;
  product?: any;
  error?: string;
  source?: 'barcode' | 'open_food_facts_id';
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const requestData: LookupProductRequest = await req.json();

    console.log('🔄 Lookup Product - Request received:', {
      barcode: requestData.barcode,
      open_food_facts_id: requestData.open_food_facts_id,
    });

    // Validate that we have at least one identifier
    if (!requestData.barcode && !requestData.open_food_facts_id) {
      console.error('❌ Lookup Product - Missing identifiers');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Either barcode or open_food_facts_id must be provided'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    let productData = null;
    let source = '';

    // Priority 1: Try barcode lookup if available
    if (requestData.barcode) {
      console.log('🔍 Lookup Product - Attempting barcode lookup:', requestData.barcode);

      try {
        const barcodeResponse = await fetch(
          `https://world.openfoodfacts.org/api/v0/product/${requestData.barcode}.json`
        );

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
        const offResponse = await fetch(
          `https://world.openfoodfacts.org/api/v0/product/${requestData.open_food_facts_id}.json`
        );

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
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Product not found in Open Food Facts database',
          message: 'Unable to find product details. Please try a different product or scan a barcode.'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
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
      serving_quantity: productData.serving_quantity || null,
      serving_quantity_unit: productData.serving_quantity_unit || null,
      product_quantity: productData.quantity || null,
      product_quantity_unit: productData.quantity ? 'g' : null, // Default assumption

      // Metadata
      api_source: 'open_food_facts',
      confidence_score: productData.completeness || 0.7,
      nutrition_data_per: productData.nutriments?.['energy-kcal_serving'] ? 'serving' : '100g',
    };

    console.log('✅ Lookup Product - Successfully processed:', {
      product_name: cleanedProduct.product_name,
      source: source,
      has_nutrition: !!(cleanedProduct.calories_per_100g || cleanedProduct.calories_per_serving),
    });

    return new Response(
      JSON.stringify({
        success: true,
        product: cleanedProduct,
        source: source,
        message: `Product found via ${source}`
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('❌ Lookup Product - Unexpected error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: 'Internal server error',
        message: 'An unexpected error occurred while looking up the product',
        details: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});