/**
 * BARCODE LOOKUP EDGE FUNCTION
 * Handles barcode scanning with sequential API fallback:
 * 1. Open Food Facts API (primary, free)
 * 2. USDA FoodData Central API (fallback, free with limits)
 * 3. Structured error response for manual entry
 */ import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
// ---------------- CORS ----------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
// ---------------- Config ----------------
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// API Configuration
const OPEN_FOOD_FACTS_BASE_URL = "https://world.openfoodfacts.org/api/v2/product";
const USDA_BASE_URL = "https://api.nal.usda.gov/fdc/v1/foods/search";
const USDA_API_KEY = Deno.env.get("USDA_API_KEY") ?? ""; // Optional, has demo key
// Cache configuration (in-memory for this instance)
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
const barcodeCache = new Map();
// Helper function to validate barcode format
function validateBarcode(barcode) {
  // Support common barcode formats: UPC-A (12), EAN-13 (13), EAN-8 (8)
  const cleanBarcode = barcode.replace(/\D/g, ''); // Remove non-digits
  return [
    8,
    12,
    13
  ].includes(cleanBarcode.length);
}
// Helper function to check cache
function getCachedResult(barcode) {
  const cached = barcodeCache.get(barcode);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return cached.data;
  }
  if (cached) {
    barcodeCache.delete(barcode); // Remove expired cache
  }
  return null;
}
// Helper function to cache result
function cacheResult(barcode, data) {
  barcodeCache.set(barcode, {
    data,
    timestamp: Date.now()
  });
}
// Open Food Facts API integration
async function lookupOpenFoodFacts(barcode) {
  try {
    console.log(`Attempting Open Food Facts lookup for barcode: ${barcode}`);
    const response = await fetch(`${OPEN_FOOD_FACTS_BASE_URL}/${barcode}.json`, {
      headers: {
        'User-Agent': 'Mealvana-Endurance/1.0 (https://mealvana.com)'
      }
    });
    if (!response.ok) {
      console.log(`Open Food Facts API error: ${response.status}`);
      return null;
    }
    const data = await response.json();
    if (data.status !== 1 || !data.product) {
      console.log("Product not found in Open Food Facts");
      return null;
    }
    const product = data.product;
    const nutriments = product.nutriments || {};
    // Convert sodium from mg to mg (some APIs return in grams)
    let sodium_mg_per_100g = nutriments.sodium_100g;
    if (nutriments.salt_100g && !sodium_mg_per_100g) {
      // Convert salt to sodium (salt = sodium * 2.5 approximately)
      sodium_mg_per_100g = nutriments.salt_100g * 1000 / 2.5;
    }
    if (sodium_mg_per_100g && sodium_mg_per_100g < 1) {
      // Likely in grams, convert to mg
      sodium_mg_per_100g *= 1000;
    }
    // Get the best available image URL
    const imageUrl = product.image_front_url || product.image_url || product.image_front_small_url;
    // DEBUG: Log raw API data for serving size analysis
    console.log(`🔍 DEBUG - Raw Open Food Facts data for ${barcode}:`);
    console.log(`  Product name: ${product.product_name}`);
    console.log(`  Serving size: ${product.serving_size}`);
    console.log(`  Serving quantity: ${product.serving_quantity}`);
    console.log(`  Package quantity: ${product.quantity}`);
    console.log(`  Nutrition data per: ${product.nutrition_data_per || '100g (default)'}`);
    console.log(`  Raw calories per 100g: ${nutriments["energy-kcal_100g"]}`);
    console.log(`  Raw carbs per 100g: ${nutriments["carbohydrates_100g"]}`);
    console.log(`  Raw calories per serving: ${nutriments["energy-kcal_serving"]}`);
    console.log(`  Raw carbs per serving: ${nutriments["carbohydrates_serving"]}`);
    console.log(`  Raw protein per serving: ${nutriments["proteins_serving"]}`);
    console.log(`  Image URL: ${imageUrl}`);
    // Parse serving quantity from serving_quantity field or serving_size
    let servingGrams = parseFloat(product.serving_quantity || "0");
    // If serving_quantity is not available, try to parse from serving_size
    if (!servingGrams && product.serving_size) {
      const match = product.serving_size.match(/\(?\s*(\d+(?:\.\d+)?)\s*g\s*\)?/i);
      if (match) {
        servingGrams = parseFloat(match[1]);
      }
    }
    console.log(`📊 Detected serving size: ${servingGrams}g`);
    // Prefer per-serving values when available, fall back to per-100g
    const hasPerServingData = nutriments["energy-kcal_serving"] !== undefined;
    const normalized = {
      barcode,
      product_name: product.product_name || "Unknown Product",
      brand_name: product.brands,
      image_url: imageUrl,
      serving_size: product.serving_size || product.quantity,
      // Always include per-100g values for consistency
      calories_per_100g: nutriments["energy-kcal_100g"],
      carbohydrates_per_100g: nutriments["carbohydrates_100g"],
      protein_per_100g: nutriments["proteins_100g"],
      fat_per_100g: nutriments["fat_100g"],
      sodium_mg_per_100g: sodium_mg_per_100g,
      saturated_fat_per_100g: nutriments["saturated-fat_100g"],
      sugars_per_100g: nutriments["sugars_100g"],
      fiber_per_100g: nutriments["fiber_100g"],
      // Use _serving suffix keys from Open Food Facts API
      calories_per_serving: nutriments["energy-kcal_serving"],
      carbohydrates_per_serving: nutriments["carbohydrates_serving"],
      protein_per_serving: nutriments["proteins_serving"],
      fat_per_serving: nutriments["fat_serving"],
      sodium_mg_per_serving: nutriments["sodium_serving"] ? Math.round(nutriments["sodium_serving"] * 1000) : undefined,
      saturated_fat_per_serving: nutriments["saturated-fat_serving"],
      sugars_per_serving: nutriments["sugars_serving"],
      fiber_per_serving: nutriments["fiber_serving"],
      serving_grams: servingGrams > 0 ? servingGrams : undefined,
      // Data format indicator - mark as "serving" if we have per-serving data
      nutrition_data_per: hasPerServingData ? "serving" : "100g",
      api_source: "open_food_facts",
      confidence_score: hasPerServingData ? 0.9 : 0.7
    };
    console.log(`📦 DEBUG - Normalized response:`, JSON.stringify(normalized, null, 2));
    console.log("Successfully found product in Open Food Facts");
    return normalized;
  } catch (error) {
    console.error("Open Food Facts API error:", error);
    return null;
  }
}
// USDA FoodData Central API integration
async function lookupUSDA(barcode) {
  try {
    console.log(`Attempting USDA lookup for barcode: ${barcode}`);
    // USDA API requires searching by UPC/GTIN
    const searchParams = new URLSearchParams({
      query: barcode,
      dataType: [
        "Branded"
      ].join(","),
      pageSize: "5",
      pageNumber: "1",
      sortBy: "dataType.keyword",
      sortOrder: "asc"
    });
    if (USDA_API_KEY) {
      searchParams.append("api_key", USDA_API_KEY);
    }
    const response = await fetch(`${USDA_BASE_URL}?${searchParams.toString()}`, {
      headers: {
        'User-Agent': 'Mealvana-Endurance/1.0 (https://mealvana.com)'
      }
    });
    if (!response.ok) {
      console.log(`USDA API error: ${response.status}`);
      return null;
    }
    const data = await response.json();
    if (!data.foods || data.foods.length === 0) {
      console.log("Product not found in USDA database");
      return null;
    }
    // Find the best match (exact barcode match preferred)
    const exactMatch = data.foods.find((food)=>food.gtinUpc === barcode);
    const food = exactMatch || data.foods[0];
    // Extract nutritional information
    const nutrients = food.foodNutrients || [];
    const getNutrientValue = (name)=>{
      const nutrient = nutrients.find((n)=>n.nutrientName.toLowerCase().includes(name.toLowerCase()));
      return nutrient?.value;
    };
    const normalized = {
      barcode,
      product_name: food.description || "Unknown Product",
      brand_name: food.brandName,
      image_url: undefined,
      serving_size: undefined,
      calories_per_100g: getNutrientValue("Energy"),
      carbohydrates_per_100g: getNutrientValue("Carbohydrate"),
      protein_per_100g: getNutrientValue("Protein"),
      fat_per_100g: getNutrientValue("Total lipid"),
      sodium_mg_per_100g: getNutrientValue("Sodium"),
      api_source: "usda",
      confidence_score: exactMatch ? 0.7 : 0.5
    };
    console.log("Successfully found product in USDA database");
    return normalized;
  } catch (error) {
    console.error("USDA API error:", error);
    return null;
  }
}
// Main barcode lookup with sequential fallback
async function lookupBarcode(barcode) {
  // Check cache first
  const cached = getCachedResult(barcode);
  if (cached) {
    console.log("Returning cached result");
    return cached;
  }
  // Try Open Food Facts first (primary)
  let result = await lookupOpenFoodFacts(barcode);
  if (result) {
    cacheResult(barcode, result);
    return result;
  }
  // Fallback to USDA
  result = await lookupUSDA(barcode);
  if (result) {
    cacheResult(barcode, result);
    return result;
  }
  console.log("Product not found in any API");
  return null;
}
// Main request handler
serve(async (req)=>{
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    // Validate request method
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({
        error: "Method not allowed"
      }), {
        status: 405,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Parse request body
    const { barcode } = await req.json();
    // Validate barcode
    if (!barcode || typeof barcode !== 'string') {
      return new Response(JSON.stringify({
        error: "Invalid request",
        message: "Barcode is required and must be a string"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const cleanBarcode = barcode.replace(/\D/g, '');
    if (!validateBarcode(cleanBarcode)) {
      return new Response(JSON.stringify({
        error: "Invalid barcode format",
        message: "Barcode must be 8, 12, or 13 digits"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Attempt barcode lookup
    const result = await lookupBarcode(cleanBarcode);
    if (result) {
      return new Response(JSON.stringify({
        success: true,
        data: result
      }), {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    } else {
      return new Response(JSON.stringify({
        success: false,
        error: "Product not found",
        message: "This product was not found in our nutrition databases. Please try manual entry.",
        barcode: cleanBarcode
      }), {
        status: 404,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
  } catch (error) {
    console.error("Edge function error:", error);
    return new Response(JSON.stringify({
      success: false,
      error: "Internal server error",
      message: "An error occurred while processing your request. Please try again."
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
