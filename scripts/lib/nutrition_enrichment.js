"use strict";

/**
 * Shared Nutrition Enrichment Module
 *
 * Provides enrichment functions used by both:
 *   - scripts/update_catalog.js  (future imports)
 *   - scripts/enrich_catalog_nutrition.js  (retroactive enrichment)
 *
 * Data sources (priority order):
 *   1. Shopify PIM metafields (sync, from GraphQL response)
 *   2. Web scrape PIM from thefeed.com product page
 *   3. OpenFoodFacts barcode lookup
 *   4. FDA FoodData Central barcode lookup
 *   5. Algolia search index
 */

// ---------------------------------------------------------------------------
// Config (set by init())
// ---------------------------------------------------------------------------

let _config = {
  FDA_API_KEY: null,
  ALGOLIA_APP_ID: null,
  ALGOLIA_SEARCH_KEY: null,
};

/**
 * Initialize module config. Call once before using enrichment functions.
 */
function init(config) {
  _config = { ..._config, ...config };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Parse a numeric value from a metafield string. Returns null if not a number.
 */
function parseNum(val) {
  if (val == null) return null;
  const n = parseFloat(val);
  return isNaN(n) ? null : n;
}

/**
 * Parse an integer value from a metafield string. Returns null if not a number.
 */
function parseInt2(val) {
  if (val == null) return null;
  const n = parseInt(val, 10);
  return isNaN(n) ? null : n;
}

// ---------------------------------------------------------------------------
// Source 1: Shopify PIM Metafields (sync — no API call)
// ---------------------------------------------------------------------------

/**
 * The PIM metafield keys we request from Shopify GraphQL.
 * Used by both update_catalog.js (in GraphQL query) and the enrichment script.
 */
const PIM_METAFIELD_IDENTIFIERS = [
  { namespace: "pim", key: "calories" },
  { namespace: "pim", key: "carbohydrates" },
  { namespace: "pim", key: "protein" },
  { namespace: "pim", key: "total_fat" },
  { namespace: "pim", key: "sodium" },
  { namespace: "pim", key: "caffeine" },
  { namespace: "pim", key: "sugar" },
  { namespace: "pim", key: "dietary_fiber" },
  { namespace: "pim", key: "serving_size" },
  { namespace: "pim", key: "grams_per_serving" },
  { namespace: "pim", key: "servings_per_container" },
  { namespace: "pim", key: "ingredients" },
];

/**
 * Build the GraphQL fragment for metafield identifiers.
 * Returns a string like: metafields(identifiers: [{namespace: "pim", key: "calories"}, ...]) { key value }
 */
function buildMetafieldsGraphQL() {
  const ids = PIM_METAFIELD_IDENTIFIERS.map(
    (m) => `{namespace: "${m.namespace}", key: "${m.key}"}`,
  ).join(", ");
  return `metafields(identifiers: [${ids}]) { key value }`;
}

/**
 * Enrich from Shopify PIM metafields already fetched via GraphQL.
 *
 * @param {Object} variant - Must have `_metafields` array (from GraphQL response)
 * @returns {Object|null} Nutrition data or null
 */
function enrichFromProductMetafields(variant) {
  const metafields = variant._metafields;
  if (!metafields || !Array.isArray(metafields) || metafields.length === 0) {
    return null;
  }

  // Build key→value map (filter out null metafield entries)
  const mf = {};
  for (const m of metafields) {
    if (m && m.key && m.value != null) {
      mf[m.key] = m.value;
    }
  }

  const calories = parseNum(mf.calories);
  const carbs = parseNum(mf.carbohydrates);
  const sodium = parseInt2(mf.sodium);

  // Accept products with calories, carbs, OR sodium (electrolyte products have 0 cal/0 carbs)
  if (!calories && !carbs && !sodium) return null;

  return {
    calories_per_serving: calories ? Math.round(calories) : null,
    carbs_g: carbs,
    protein_g: parseNum(mf.protein),
    fat_g: parseNum(mf.total_fat),
    sodium_mg: parseInt2(mf.sodium),
    serving_size: mf.serving_size || null,
    serving_grams: parseNum(mf.grams_per_serving),
    caffeine_mg: parseInt2(mf.caffeine),
    sugar_g: parseNum(mf.sugar),
    fiber_g: parseNum(mf.dietary_fiber),
    ingredients: mf.ingredients || null,
    servings_per_container: parseNum(mf.servings_per_container),
    nutrition_source: "shopify_metafields",
    nutrition_confidence: 0.95,
  };
}

// ---------------------------------------------------------------------------
// Source 2: Web Scrape PIM from thefeed.com
// ---------------------------------------------------------------------------

/**
 * Extract PIM nutrition data from The Feed product page HTML.
 *
 * The Feed embeds PIM data in page JavaScript as metafield values.
 * We look for patterns like: "pim.calories":"200"
 *
 * @param {string} html - Raw HTML of the product page
 * @returns {Object|null} Nutrition data or null
 */
function extractPIMFromHTML(html) {
  try {
    const pimData = {};

    // Primary pattern: {"key":"pim.calories","namespace":"pim","value":"100.0"}
    // This is the actual format used by The Feed's Shopify theme.
    const metafieldPattern =
      /"key"\s*:\s*"pim\.(\w+)"\s*,\s*"namespace"\s*:\s*"pim"\s*,\s*"value"\s*:\s*"([^"]*)"/g;
    let match;
    while ((match = metafieldPattern.exec(html)) !== null) {
      pimData[match[1]] = match[2];
    }

    const calories = parseNum(pimData.calories);
    const carbs = parseNum(pimData.carbohydrates);
    const sodium = parseInt2(pimData.sodium);

    // Accept products with calories, carbs, OR sodium (electrolyte products have 0 cal/0 carbs)
    if (!calories && !carbs && !sodium) return null;

    return {
      calories_per_serving: calories ? Math.round(calories) : null,
      carbs_g: carbs,
      protein_g: parseNum(pimData.protein),
      fat_g: parseNum(pimData.total_fat || pimData.fat),
      sodium_mg: sodium,
      serving_size: pimData.serving_size || null,
      serving_grams: parseNum(pimData.grams_per_serving),
      caffeine_mg: parseInt2(pimData.caffeine),
      sugar_g: parseNum(pimData.sugar || pimData.added_sugars),
      fiber_g: parseNum(pimData.dietary_fiber),
      ingredients: pimData.ingredients || null,
      servings_per_container: parseNum(pimData.servings_per_container),
      nutrition_source: "web_scrape_pim",
      nutrition_confidence: 0.9,
    };
  } catch {
    return null;
  }
}

/**
 * Extract JSON-LD NutritionInformation from product page HTML.
 *
 * Looks for <script type="application/ld+json"> with schema.org Product
 * that contains nutrition information.
 *
 * @param {string} html - Raw HTML of the product page
 * @returns {Object|null} Nutrition data or null
 */
function extractJSONLDFromHTML(html) {
  try {
    // Find all JSON-LD script blocks
    const ldPattern =
      /<script[^>]*type\s*=\s*["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
    let match;

    while ((match = ldPattern.exec(html)) !== null) {
      try {
        const data = JSON.parse(match[1]);

        // Handle @graph array or direct object
        const items = Array.isArray(data["@graph"])
          ? data["@graph"]
          : Array.isArray(data)
            ? data
            : [data];

        for (const item of items) {
          const nutrition = item.nutrition || item.nutritionInformation;
          if (!nutrition) continue;

          const calories = parseNum(
            nutrition.calories?.replace(/[^\d.]/g, ""),
          );
          const carbs = parseNum(
            (
              nutrition.carbohydrateContent || nutrition.carbs
            )?.replace?.(/[^\d.]/g, ""),
          );
          const sodiumLD = parseInt2(
            nutrition.sodiumContent?.replace?.(/[^\d.]/g, ""),
          );

          if (!calories && !carbs && !sodiumLD) continue;

          return {
            calories_per_serving: calories ? Math.round(calories) : null,
            carbs_g: carbs,
            protein_g: parseNum(
              nutrition.proteinContent?.replace?.(/[^\d.]/g, ""),
            ),
            fat_g: parseNum(nutrition.fatContent?.replace?.(/[^\d.]/g, "")),
            sodium_mg: parseInt2(
              nutrition.sodiumContent?.replace?.(/[^\d.]/g, ""),
            ),
            serving_size: nutrition.servingSize || null,
            serving_grams: null,
            caffeine_mg: null,
            sugar_g: parseNum(
              nutrition.sugarContent?.replace?.(/[^\d.]/g, ""),
            ),
            fiber_g: parseNum(
              nutrition.fiberContent?.replace?.(/[^\d.]/g, ""),
            ),
            ingredients: null,
            servings_per_container: null,
            nutrition_source: "json_ld",
            nutrition_confidence: 0.9,
          };
        }
      } catch {
        // Invalid JSON in this script block — continue to next
      }
    }

    return null;
  } catch {
    return null;
  }
}

/**
 * Fetch a product page from thefeed.com and extract nutrition via PIM + JSON-LD.
 *
 * @param {string} handle - Shopify product handle (URL slug)
 * @returns {Object|null} Nutrition data or null
 */
async function enrichFromWebScrape(handle) {
  if (!handle) return null;

  try {
    await sleep(200); // Rate limit

    const url = `https://thefeed.com/products/${handle}`;
    const res = await fetch(url, {
      headers: {
        "User-Agent":
          "MealvanaEndurance/1.0 (support@mealvana.com) NutritionEnrichment",
        Accept: "text/html",
      },
      redirect: "follow",
    });

    if (!res.ok) return null;

    const html = await res.text();

    // Try PIM extraction first (higher confidence)
    const pimResult = extractPIMFromHTML(html);
    if (pimResult) return pimResult;

    // Fall back to JSON-LD
    const jsonLdResult = extractJSONLDFromHTML(html);
    if (jsonLdResult) return jsonLdResult;

    return null;
  } catch (e) {
    console.error(`    [web_scrape] Error for ${handle}: ${e.message}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Source 3: OpenFoodFacts (barcode)
// ---------------------------------------------------------------------------

let offConsecutiveFailures = 0;
const OFF_FAILURE_THRESHOLD = 5;

/**
 * Reset the OFF circuit breaker (useful between runs or phases).
 */
function resetOFFCircuitBreaker() {
  offConsecutiveFailures = 0;
}

/**
 * Attempt OpenFoodFacts enrichment by barcode.
 */
async function enrichFromOFF(variant) {
  if (!variant.barcode) return null;
  if (offConsecutiveFailures >= OFF_FAILURE_THRESHOLD) return null;

  try {
    await sleep(700); // Rate limit for OFF

    const res = await fetch(
      `https://world.openfoodfacts.org/api/v0/product/${variant.barcode}.json`,
      {
        headers: {
          "User-Agent": "MealvanaEndurance/1.0 (support@mealvana.com)",
        },
      },
    );

    if (!res.ok) return null;

    const data = await res.json();
    if (data.status !== 1 || !data.product) return null;

    const n = data.product.nutriments || {};
    const calories =
      n["energy-kcal_serving"] || n["energy-kcal_100g"] || null;
    const carbs = n.carbohydrates_serving || n.carbohydrates_100g || null;
    const protein = n.proteins_serving || n.proteins_100g || null;
    const fat = n.fat_serving || n.fat_100g || null;
    const sodium = n.sodium_serving
      ? n.sodium_serving * 1000
      : n.sodium_100g
        ? n.sodium_100g * 1000
        : null;

    if (!calories && !carbs && !sodium) return null;

    offConsecutiveFailures = 0;
    return {
      calories_per_serving: calories ? Math.round(calories) : null,
      carbs_g: carbs,
      protein_g: protein,
      fat_g: fat,
      sodium_mg: sodium ? Math.round(sodium) : null,
      serving_size: data.product.serving_size || null,
      serving_grams: data.product.serving_quantity
        ? parseFloat(data.product.serving_quantity)
        : null,
      caffeine_mg: null,
      sugar_g: n.sugars_serving || n.sugars_100g || null,
      fiber_g: n.fiber_serving || n.fiber_100g || null,
      ingredients: data.product.ingredients_text_en || data.product.ingredients_text || null,
      servings_per_container: null,
      nutrition_source: "openfoodfacts",
      nutrition_confidence: data.product.completeness || 0.6,
    };
  } catch (e) {
    offConsecutiveFailures++;
    if (offConsecutiveFailures === OFF_FAILURE_THRESHOLD) {
      console.error(
        `    [OFF] ${OFF_FAILURE_THRESHOLD} consecutive failures — disabling for this run`,
      );
    } else {
      console.error(`    [OFF] Error: ${e.message}`);
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Source 4: FDA FoodData Central (barcode)
// ---------------------------------------------------------------------------

/**
 * Attempt FDA FoodData Central enrichment by barcode.
 */
async function enrichFromFDA(variant) {
  if (!_config.FDA_API_KEY || !variant.barcode) return null;

  try {
    await sleep(100); // Rate limit: ~1K req/hr

    const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(variant.barcode)}&dataType=Branded&pageSize=1&api_key=${_config.FDA_API_KEY}`;
    const res = await fetch(url);

    if (!res.ok) return null;

    const data = await res.json();
    const food = data.foods?.[0];
    if (!food) return null;

    const nutrients = {};
    for (const n of food.foodNutrients || []) {
      nutrients[n.nutrientId] = n.value;
    }

    // Common FDA nutrient IDs
    const calories = nutrients[1008] || null; // Energy (kcal)
    const carbs = nutrients[1005] || null; // Carbohydrate
    const protein = nutrients[1003] || null; // Protein
    const fat = nutrients[1004] || null; // Total fat
    const sodium = nutrients[1093] || null; // Sodium (mg)

    if (!calories && !carbs && !sodium) return null;

    return {
      calories_per_serving: calories ? Math.round(calories) : null,
      carbs_g: carbs,
      protein_g: protein,
      fat_g: fat,
      sodium_mg: sodium ? Math.round(sodium) : null,
      serving_size: food.servingSize
        ? `${food.servingSize}${food.servingSizeUnit || "g"}`
        : null,
      serving_grams: food.servingSize || null,
      caffeine_mg: nutrients[1057] ? Math.round(nutrients[1057]) : null,
      sugar_g: nutrients[2000] || null, // Total Sugars
      fiber_g: nutrients[1079] || null, // Dietary Fiber
      ingredients: food.ingredients || null,
      servings_per_container: null,
      nutrition_source: "fda",
      nutrition_confidence: 0.85,
    };
  } catch (e) {
    console.error(`    [FDA] Error: ${e.message}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Source 5: Algolia (text search)
// ---------------------------------------------------------------------------

/**
 * Attempt Algolia enrichment (The Feed's search index).
 */
async function enrichFromAlgolia(variant) {
  if (!_config.ALGOLIA_APP_ID || !_config.ALGOLIA_SEARCH_KEY) return null;

  try {
    const query = [variant.title, variant.variant_title, variant.brand]
      .filter(Boolean)
      .join(" ");

    const res = await fetch(
      `https://${_config.ALGOLIA_APP_ID}-dsn.algolia.net/1/indexes/shopify_products/query`,
      {
        method: "POST",
        headers: {
          "X-Algolia-API-Key": _config.ALGOLIA_SEARCH_KEY,
          "X-Algolia-Application-Id": _config.ALGOLIA_APP_ID,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          query,
          hitsPerPage: 1,
        }),
      },
    );

    if (!res.ok) return null;

    const data = await res.json();
    const hit = data.hits?.[0];
    if (!hit) return null;

    // Look for nutrition in meta.pim or other known fields
    const pim = hit.meta?.pim || {};
    const calories = parseNum(pim.calories);
    const carbs = parseNum(pim.carbs || pim.carbohydrates);
    const sodium = parseInt2(pim.sodium);

    if (!calories && !carbs && !sodium) return null;

    return {
      calories_per_serving: calories ? Math.round(calories) : null,
      carbs_g: carbs,
      protein_g: parseNum(pim.protein),
      fat_g: parseNum(pim.fat),
      sodium_mg: parseInt2(pim.sodium),
      serving_size: pim.serving_size || null,
      serving_grams: parseNum(pim.serving_grams),
      caffeine_mg: parseInt2(pim.caffeine),
      sugar_g: parseNum(pim.sugar),
      fiber_g: parseNum(pim.dietary_fiber || pim.fiber),
      ingredients: null,
      servings_per_container: null,
      nutrition_source: "algolia",
      nutrition_confidence: 0.7,
    };
  } catch (e) {
    console.error(`    [Algolia] Error: ${e.message}`);
    return null;
  }
}

// ---------------------------------------------------------------------------
// Waterfall orchestrator
// ---------------------------------------------------------------------------

/**
 * Run the full nutrition enrichment waterfall for a single variant.
 *
 * Order: metafields → algolia → web scrape → OFF → FDA
 *
 * For update_catalog.js (future imports), metafields come from GraphQL.
 * For enrich_catalog_nutrition.js (retroactive), metafields come from bulk query.
 *
 * @param {Object} variant - The variant object
 * @param {Object} [options]
 * @param {boolean} [options.skipMetafields=false] - Skip metafield check
 * @param {boolean} [options.skipWebScrape=false] - Skip web scrape
 * @returns {Object|null} Nutrition data or null
 */
async function enrichNutrition(variant, options = {}) {
  // 1. Shopify PIM metafields (sync — no API call)
  if (!options.skipMetafields) {
    const metafieldResult = enrichFromProductMetafields(variant);
    if (metafieldResult) return metafieldResult;
  }

  // 2. Algolia
  const algoliaResult = await enrichFromAlgolia(variant);
  if (algoliaResult) return algoliaResult;

  // 3. Web scrape PIM + JSON-LD
  if (!options.skipWebScrape) {
    const webResult = await enrichFromWebScrape(variant.handle);
    if (webResult) return webResult;
  }

  // 4. OpenFoodFacts
  const offResult = await enrichFromOFF(variant);
  if (offResult) return offResult;

  // 5. FDA FoodData Central
  const fdaResult = await enrichFromFDA(variant);
  if (fdaResult) return fdaResult;

  return null;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

module.exports = {
  init,
  sleep,

  // Constants
  PIM_METAFIELD_IDENTIFIERS,
  buildMetafieldsGraphQL,

  // Enrichment sources
  enrichFromProductMetafields,
  enrichFromWebScrape,
  enrichFromOFF,
  enrichFromFDA,
  enrichFromAlgolia,

  // HTML parsers
  extractPIMFromHTML,
  extractJSONLDFromHTML,

  // Circuit breaker
  resetOFFCircuitBreaker,

  // Full waterfall
  enrichNutrition,
};
