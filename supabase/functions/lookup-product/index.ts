import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};

const USDA_BASE_URL = 'https://api.nal.usda.gov/fdc/v1/foods/search';
const USDA_API_KEY = Deno.env.get('USDA_API_KEY') ?? '';

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

interface USDALabelNutrient {
  value?: number;
}

interface USDAFood {
  description: string;
  brandName?: string;
  brandOwner?: string;
  gtinUpc?: string;
  foodCategory?: string;
  householdServingFullText?: string;
  servingSize?: number;
  servingSizeUnit?: string;
  packageWeight?: string;
  labelNutrients?: {
    calories?: USDALabelNutrient;
    protein?: USDALabelNutrient;
    fat?: USDALabelNutrient;
    carbohydrates?: USDALabelNutrient;
    sodium?: USDALabelNutrient;
    [key: string]: USDALabelNutrient | undefined;
  };
  foodNutrients?: Array<{
    nutrientId: number;
    nutrientName: string;
    unitName: string;
    value: number;
  }>;
}

interface USDAResponse {
  foods?: USDAFood[];
  totalHits?: number;
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

    let productData: any = null;
    let source: 'barcode' | 'open_food_facts_id' | '' = '';
    let cleanedProduct: any = null;

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
    if (productData) {
      cleanedProduct = transformOpenFoodFactsProduct(productData, requestData);
    }

    if (!cleanedProduct) {
      console.log('ℹ️ Lookup Product - Attempting USDA fallback');

      const fallbackCandidates: Array<{ value?: string; type: 'barcode' | 'open_food_facts_id' }> = [
        { value: requestData.barcode, type: 'barcode' },
        { value: requestData.open_food_facts_id, type: 'open_food_facts_id' }
      ];

      for (const candidate of fallbackCandidates) {
        if (!candidate.value) {
          continue;
        }

        const usdaResult = await lookupUSDAProduct(candidate.value);
        if (usdaResult) {
          cleanedProduct = usdaResult;
          if (!source) {
            source = candidate.type;
          }
          console.log('✅ Lookup Product - Found via USDA fallback');
          break;
        }
      }
    }

    if (!cleanedProduct) {
      console.log('❌ Lookup Product - No product found in any source');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Product not found in Open Food Facts or USDA database',
          message: 'Unable to find product details. Please try a different product or scan a barcode.'
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    if (!source) {
      source = requestData.barcode ? 'barcode' : 'open_food_facts_id';
    }

    console.log('✅ Lookup Product - Successfully processed:', {
      product_name: cleanedProduct.product_name,
      source: source,
      has_nutrition: !!(cleanedProduct.calories_per_100g || cleanedProduct.calories_per_serving),
      api_source: cleanedProduct.api_source,
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

function transformOpenFoodFactsProduct(productData: any, requestData: LookupProductRequest) {
  const nutriments = productData.nutriments || {};

  return {
    // Basic info
    barcode: productData.code || requestData.barcode || requestData.open_food_facts_id,
    product_name: productData.product_name || productData.product_name_en || 'Unknown Product',
    brand_name: productData.brands || null,
    image_url: productData.image_url || productData.image_front_url || null,

    // Serving information
    serving_size: productData.serving_size || null,
    serving_grams: productData.serving_quantity ? parseFloat(productData.serving_quantity) : null,

    // Nutritional information per 100g
    calories_per_100g: nutriments['energy-kcal_100g'] ?? null,
    carbohydrates_per_100g: nutriments.carbohydrates_100g ?? null,
    protein_per_100g: nutriments.proteins_100g ?? null,
    fat_per_100g: nutriments.fat_100g ?? null,
    sodium_mg_per_100g: nutriments.sodium_100g ? nutriments.sodium_100g * 1000 : null,

    // Per-serving nutrition (if available)
    calories_per_serving: nutriments['energy-kcal_serving'] ?? null,
    carbohydrates_per_serving: nutriments.carbohydrates_serving ?? null,
    protein_per_serving: nutriments.proteins_serving ?? null,
    fat_per_serving: nutriments.fat_serving ?? null,
    sodium_mg_per_serving: nutriments.sodium_serving ? nutriments.sodium_serving * 1000 : null,

    // Additional fields for beverage detection
    categories: productData.categories || null,
    serving_quantity: productData.serving_quantity || null,
    serving_quantity_unit: productData.serving_quantity_unit || null,
    product_quantity: productData.quantity || null,
    product_quantity_unit: productData.quantity ? 'g' : null, // Default assumption

    // Metadata
    api_source: 'open_food_facts',
    confidence_score: productData.completeness || 0.7,
    nutrition_data_per: nutriments['energy-kcal_serving'] ? 'serving' : '100g',
  };
}

async function lookupUSDAProduct(identifier: string): Promise<any | null> {
  const trimmedIdentifier = identifier?.toString().trim();

  if (!trimmedIdentifier) {
    return null;
  }

  const searchParams = new URLSearchParams({
    query: trimmedIdentifier,
    dataType: 'Branded',
    pageSize: '5',
    pageNumber: '1',
    sortBy: 'dataType.keyword',
    sortOrder: 'asc',
  });

  if (USDA_API_KEY) {
    searchParams.append('api_key', USDA_API_KEY);
  }

  try {
    const response = await fetch(`${USDA_BASE_URL}?${searchParams.toString()}`, {
      headers: {
        'User-Agent': 'Mealvana-Endurance/1.0 (https://mealvana.com)'
      }
    });

    if (!response.ok) {
      console.error(`⚠️ Lookup Product - USDA response error: ${response.status} ${response.statusText}`);
      return null;
    }

    const data: USDAResponse = await response.json();

    if (!data.foods || data.foods.length === 0) {
      console.log('ℹ️ Lookup Product - USDA returned no matches');
      return null;
    }

    const sanitizedIdentifier = trimmedIdentifier.replace(/\D/g, '');

    const matchByBarcode = data.foods.find((food) => food.gtinUpc?.replace(/\D/g, '') === sanitizedIdentifier);
    const selectedFood = matchByBarcode || data.foods[0];

    if (!selectedFood) {
      return null;
    }

    const exactMatch = Boolean(matchByBarcode);

    return transformUSDAFood(selectedFood, {
      identifier: sanitizedIdentifier || trimmedIdentifier,
      originalIdentifier: trimmedIdentifier,
      exactMatch,
    });
  } catch (error) {
    console.error('⚠️ Lookup Product - USDA lookup failed:', error);
    return null;
  }
}

function transformUSDAFood(
  food: USDAFood,
  context: { identifier: string; originalIdentifier: string; exactMatch: boolean }
) {
  const labelNutrients = food.labelNutrients || {};
  const foodNutrients = food.foodNutrients || [];

  const servingSize = typeof food.servingSize === 'number' ? food.servingSize : null;
  const servingSizeUnitRaw = food.servingSizeUnit || null;
  const servingSizeUnitNormalized = servingSizeUnitRaw ? servingSizeUnitRaw.toLowerCase() : null;
  const servingIsGrams = servingSizeUnitNormalized ? ['g', 'gram', 'grams'].includes(servingSizeUnitNormalized) : false;
  const servingGrams = servingIsGrams && servingSize ? servingSize : null;

  const servingSizeParts: string[] = [];
  if (servingSize !== null && servingSizeUnitRaw) {
    servingSizeParts.push(String(servingSize));
    servingSizeParts.push(servingSizeUnitRaw);
  }

  const servingSizeText = servingSizeParts.length > 0
    ? servingSizeParts.join(' ')
    : food.householdServingFullText || null;

  const getLabelValue = (key: string): number | null => {
    const value = labelNutrients[key]?.value;
    return typeof value === 'number' ? value : null;
  };

  const caloriesPerServing = getLabelValue('calories');
  const carbsPerServing = getLabelValue('carbohydrates');
  const proteinPerServing = getLabelValue('protein');
  const fatPerServing = getLabelValue('fat');
  const sodiumPerServingMg = getLabelValue('sodium');

  const per100gFromServing = (value: number | null): number | null => {
    if (value === null || value === undefined) {
      return null;
    }
    if (!servingGrams || servingGrams === 0) {
      return null;
    }
    return (value / servingGrams) * 100;
  };

  const getFoodNutrientValue = (ids: number[]): number | null => {
    for (const id of ids) {
      const nutrient = foodNutrients.find((item) => item.nutrientId === id && typeof item.value === 'number');
      if (!nutrient) {
        continue;
      }

      let value = nutrient.value;
      const unit = nutrient.unitName?.toLowerCase() ?? '';

      if (id === 1008) {
        // Energy may be recorded in kJ. Convert to kcal when needed.
        if (unit === 'kj') {
          value = value / 4.184;
        }
      }

      if (id === 1093) {
        if (unit === 'g') {
          value = value * 1000;
        }
      }

      return value;
    }
    return null;
  };

  const caloriesPer100g = per100gFromServing(caloriesPerServing) ?? getFoodNutrientValue([1008]);
  const carbsPer100g = per100gFromServing(carbsPerServing) ?? getFoodNutrientValue([1005]);
  const proteinPer100g = per100gFromServing(proteinPerServing) ?? getFoodNutrientValue([1003]);
  const fatPer100g = per100gFromServing(fatPerServing) ?? getFoodNutrientValue([1004]);
  const sodiumPer100g = per100gFromServing(sodiumPerServingMg) ?? getFoodNutrientValue([1093]);

  const normalizeNumber = (value: number | null | undefined): number | null => {
    if (value === null || value === undefined || Number.isNaN(value)) {
      return null;
    }
    return Math.round(value * 100) / 100;
  };

  return {
    barcode: food.gtinUpc || context.identifier || context.originalIdentifier,
    product_name: food.description || 'Unknown Product',
    brand_name: food.brandName || food.brandOwner || null,
    image_url: null,

    serving_size: servingSizeText,
    serving_grams: servingGrams,

    calories_per_100g: normalizeNumber(caloriesPer100g),
    carbohydrates_per_100g: normalizeNumber(carbsPer100g),
    protein_per_100g: normalizeNumber(proteinPer100g),
    fat_per_100g: normalizeNumber(fatPer100g),
    sodium_mg_per_100g: normalizeNumber(sodiumPer100g),

    calories_per_serving: normalizeNumber(caloriesPerServing),
    carbohydrates_per_serving: normalizeNumber(carbsPerServing),
    protein_per_serving: normalizeNumber(proteinPerServing),
    fat_per_serving: normalizeNumber(fatPerServing),
    sodium_mg_per_serving: normalizeNumber(sodiumPerServingMg),

    categories: food.foodCategory || null,
    serving_quantity: servingSize !== null ? String(servingSize) : null,
    serving_quantity_unit: servingSizeUnitRaw || null,
    product_quantity: food.packageWeight || null,
    product_quantity_unit: null,

    api_source: 'usda',
    confidence_score: context.exactMatch ? 0.6 : 0.5,
    nutrition_data_per: caloriesPerServing !== null || carbsPerServing !== null || proteinPerServing !== null ? 'serving' : '100g',
  };
}
