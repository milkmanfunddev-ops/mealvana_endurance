#!/usr/bin/env node
"use strict";

/**
 * Product Catalog Import Script
 *
 * Pipeline:
 *   A. Fetch products + variants from Shopify Storefront GraphQL
 *   B. Filter to food-only products (by productType + tags)
 *   C. Enrich each variant with nutrition (Algolia → FDA → OFF)
 *   D. Upsert into catalog_items via Supabase JS client
 *   E. Log sync run to catalog_sync_runs
 *
 * Usage:
 *   node scripts/update_catalog.js
 *
 * Required env vars:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional env vars:
 *   FDA_API_KEY (for FoodData Central enrichment)
 *   THEFEED_STOREFRONT_ENDPOINT, THEFEED_STOREFRONT_TOKEN
 *   THEFEED_ALGOLIA_APP_ID, THEFEED_ALGOLIA_SEARCH_KEY
 */

const SCRIPT_VERSION = "1.0.0";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const SHOPIFY_ENDPOINT =
  process.env.THEFEED_STOREFRONT_ENDPOINT ||
  "https://thefeed.myshopify.com/api/2024-10/graphql.json";
const SHOPIFY_TOKEN =
  process.env.THEFEED_STOREFRONT_TOKEN ||
  "ee5c8524ec06e62d02701486c1b3a1f3";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const FDA_API_KEY = process.env.FDA_API_KEY || process.env.USDA_API_KEY || null;
const ALGOLIA_APP_ID = process.env.THEFEED_ALGOLIA_APP_ID || null;
const ALGOLIA_SEARCH_KEY = process.env.THEFEED_ALGOLIA_SEARCH_KEY || null;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.",
  );
  process.exit(1);
}

// Food-only product types (case-insensitive)
const FOOD_PRODUCT_TYPES = new Set(
  [
    "gels",
    "bars",
    "hydration",
    "protein",
    "recovery",
    "chews",
    "drink mix",
    "electrolytes",
    "snacks",
    "energy",
    "waffles",
    "chews & gummies",
    "drink mixes",
    "meal replacement",
  ].map((t) => t.toLowerCase()),
);

// Tag prefix that also qualifies a product as food
const NUTRITION_TAG_PREFIX = "category:nutrition";

// ---------------------------------------------------------------------------
// Supabase client (lightweight REST wrapper — no npm dependency required)
// ---------------------------------------------------------------------------

async function supabaseRequest(path, { method = "GET", body, query } = {}) {
  let url = `${SUPABASE_URL}/rest/v1/${path}`;
  if (query) {
    const params = new URLSearchParams(query);
    url += `?${params.toString()}`;
  }

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
    Prefer: method === "POST" ? "return=minimal" : "",
  };

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase ${method} ${path}: ${res.status} — ${text}`);
  }

  const contentType = res.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return res.json();
  }
  return null;
}

// ---------------------------------------------------------------------------
// A. Shopify GraphQL — fetch products + variants
// ---------------------------------------------------------------------------

const PRODUCTS_QUERY = `
  query ProductsPage($first: Int!, $after: String) {
    products(first: $first, after: $after, sortKey: ID) {
      edges {
        cursor
        node {
          id
          handle
          title
          vendor
          productType
          tags
          availableForSale
          onlineStoreUrl
          updatedAt
          featuredImage {
            url
          }
          variants(first: 100) {
            edges {
              node {
                id
                title
                sku
                barcode
                availableForSale
                price {
                  amount
                  currencyCode
                }
                image {
                  url
                }
              }
            }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
`;

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function graphqlRequest(query, variables, attempt = 0) {
  const res = await fetch(SHOPIFY_ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-shopify-storefront-access-token": SHOPIFY_TOKEN,
    },
    body: JSON.stringify({ query, variables }),
  });

  const json = await res.json();

  if (!res.ok || json.errors) {
    const errors = json.errors || [{ message: `HTTP ${res.status}` }];
    const throttled = errors.some(
      (e) =>
        typeof e.message === "string" &&
        e.message.toLowerCase().includes("throttle"),
    );

    if (throttled && attempt < 6) {
      const waitMs = 500 * (attempt + 1);
      console.error(`  ⏳ Throttled — retrying in ${waitMs}ms...`);
      await sleep(waitMs);
      return graphqlRequest(query, variables, attempt + 1);
    }

    throw new Error(`GraphQL request failed: ${JSON.stringify(errors)}`);
  }

  return json;
}

async function fetchAllProducts() {
  const products = [];
  let after = null;
  let page = 0;

  while (true) {
    const response = await graphqlRequest(PRODUCTS_QUERY, {
      first: 250,
      after,
    });

    const connection = response.data.products;
    const edges = connection.edges || [];
    const pageInfo = connection.pageInfo;
    const throttle = response.extensions?.cost?.throttleStatus;

    for (const edge of edges) {
      products.push(edge.node);
    }

    page += 1;
    console.error(
      `  Fetched page ${page}: +${edges.length} (total ${products.length})`,
    );

    if (!pageInfo.hasNextPage) break;
    after = pageInfo.endCursor;

    if (throttle && throttle.currentlyAvailable < 120) {
      await sleep(300);
    }
  }

  return products;
}

// ---------------------------------------------------------------------------
// B. Filter to food-only products
// ---------------------------------------------------------------------------

function isFoodProduct(product) {
  // Check productType
  if (
    product.productType &&
    FOOD_PRODUCT_TYPES.has(product.productType.toLowerCase())
  ) {
    return true;
  }

  // Check tags for Category:Nutrition prefix
  if (Array.isArray(product.tags)) {
    return product.tags.some(
      (tag) => typeof tag === "string" && tag.toLowerCase().startsWith(NUTRITION_TAG_PREFIX),
    );
  }

  return false;
}

function expandVariants(product) {
  const variants = product.variants?.edges?.map((e) => e.node) || [];

  // If no variants, create a single row from the product itself
  if (variants.length === 0) {
    return [
      {
        shopify_product_id: product.id,
        shopify_variant_id: null,
        handle: product.handle,
        title: product.title,
        variant_title: null,
        brand: product.vendor || null,
        product_type: product.productType || null,
        tags: product.tags || [],
        barcode: null,
        sku: null,
        price_cents: null,
        currency_code: "USD",
        available_for_sale: product.availableForSale ?? true,
        image_url: product.featuredImage?.url || null,
        product_url: product.onlineStoreUrl || null,
        shopify_updated_at: product.updatedAt || null,
      },
    ];
  }

  return variants.map((v) => ({
    shopify_product_id: product.id,
    shopify_variant_id: v.id,
    handle: product.handle,
    title: product.title,
    variant_title: v.title || null,
    brand: product.vendor || null,
    product_type: product.productType || null,
    tags: product.tags || [],
    barcode: v.barcode || null,
    sku: v.sku || null,
    price_cents: v.price?.amount
      ? Math.round(parseFloat(v.price.amount) * 100)
      : null,
    currency_code: v.price?.currencyCode || "USD",
    available_for_sale: v.availableForSale ?? true,
    image_url: v.image?.url || product.featuredImage?.url || null,
    product_url: product.onlineStoreUrl || null,
    shopify_updated_at: product.updatedAt || null,
  }));
}

// ---------------------------------------------------------------------------
// C. Nutrition enrichment waterfall: Algolia → FDA → OFF
// ---------------------------------------------------------------------------

/**
 * Attempt Algolia enrichment (The Feed's search index)
 */
async function enrichFromAlgolia(variant) {
  if (!ALGOLIA_APP_ID || !ALGOLIA_SEARCH_KEY) return null;

  try {
    const query = [variant.title, variant.variant_title, variant.brand]
      .filter(Boolean)
      .join(" ");

    const res = await fetch(
      `https://${ALGOLIA_APP_ID}-dsn.algolia.net/1/indexes/shopify_products/query`,
      {
        method: "POST",
        headers: {
          "X-Algolia-API-Key": ALGOLIA_SEARCH_KEY,
          "X-Algolia-Application-Id": ALGOLIA_APP_ID,
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
    const calories = parseFloat(pim.calories) || null;
    const carbs = parseFloat(pim.carbs || pim.carbohydrates) || null;
    const protein = parseFloat(pim.protein) || null;
    const fat = parseFloat(pim.fat) || null;
    const sodium = parseInt(pim.sodium, 10) || null;

    if (!calories && !carbs) return null; // No useful nutrition data

    return {
      calories_per_serving: calories ? Math.round(calories) : null,
      carbs_g: carbs,
      protein_g: protein,
      fat_g: fat,
      sodium_mg: sodium,
      serving_size: pim.serving_size || null,
      serving_grams: parseFloat(pim.serving_grams) || null,
      caffeine_mg: parseInt(pim.caffeine, 10) || null,
      nutrition_source: "algolia",
      nutrition_confidence: 0.7,
    };
  } catch (e) {
    console.error(`    ⚠ Algolia error: ${e.message}`);
    return null;
  }
}

/**
 * Attempt FDA FoodData Central enrichment (by barcode)
 */
async function enrichFromFDA(variant) {
  if (!FDA_API_KEY || !variant.barcode) return null;

  try {
    await sleep(100); // Rate limit: ~1K req/hr

    const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(variant.barcode)}&dataType=Branded&pageSize=1&api_key=${FDA_API_KEY}`;
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

    if (!calories && !carbs) return null;

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
      nutrition_source: "fda",
      nutrition_confidence: 0.85,
    };
  } catch (e) {
    console.error(`    ⚠ FDA error: ${e.message}`);
    return null;
  }
}

// Circuit breaker for OFF — skip after consecutive failures
let offConsecutiveFailures = 0;
const OFF_FAILURE_THRESHOLD = 5;

/**
 * Attempt OpenFoodFacts enrichment (by barcode)
 */
async function enrichFromOFF(variant) {
  if (!variant.barcode) return null;
  if (offConsecutiveFailures >= OFF_FAILURE_THRESHOLD) return null; // Circuit breaker

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

    if (!calories && !carbs) return null;

    offConsecutiveFailures = 0; // Reset on success
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
      nutrition_source: "openfoodfacts",
      nutrition_confidence: data.product.completeness || 0.6,
    };
  } catch (e) {
    offConsecutiveFailures++;
    if (offConsecutiveFailures === OFF_FAILURE_THRESHOLD) {
      console.error(`    ⚠ OFF: ${OFF_FAILURE_THRESHOLD} consecutive failures — disabling for this run`);
    } else {
      console.error(`    ⚠ OFF error: ${e.message}`);
    }
    return null;
  }
}

/**
 * Run the nutrition enrichment waterfall for a single variant
 */
async function enrichNutrition(variant) {
  // 1. Algolia
  const algoliaResult = await enrichFromAlgolia(variant);
  if (algoliaResult) return algoliaResult;

  // 2. FDA FoodData Central
  const fdaResult = await enrichFromFDA(variant);
  if (fdaResult) return fdaResult;

  // 3. OpenFoodFacts
  const offResult = await enrichFromOFF(variant);
  if (offResult) return offResult;

  return null; // No nutrition data found
}

// ---------------------------------------------------------------------------
// D. Upsert into catalog_items
// ---------------------------------------------------------------------------

async function upsertBatch(rows, globalSeenBarcodes) {
  // IMPORTANT: PostgREST cannot use partial unique indexes for ON CONFLICT
  // (42P10 error). Use primary key 'id' for re-runs after initial import.
  // For initial import (no existing rows), plain INSERT works fine.
  // For idempotent re-runs, we DELETE existing rows by shopify_variant_id first.
  const variantIds = rows
    .map((r) => r.shopify_variant_id)
    .filter(Boolean);

  // Delete existing rows with matching variant IDs (idempotent re-run support)
  if (variantIds.length > 0) {
    try {
      await fetch(
        `${SUPABASE_URL}/rest/v1/catalog_items?shopify_variant_id=in.(${variantIds.map((id) => `"${id}"`).join(",")})`,
        {
          method: "DELETE",
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );
    } catch (_) {
      // Ignore delete errors — rows may not exist yet
    }
  }

  // Deduplicate barcodes across entire import run — Shopify variants can share
  // barcodes (e.g. 12-pack and 24-pack of same product). Keep first, null out dupes.
  for (const row of rows) {
    if (row.barcode) {
      if (globalSeenBarcodes.has(row.barcode)) {
        row.barcode = null; // Clear duplicate barcode
      } else {
        globalSeenBarcodes.add(row.barcode);
      }
    }
  }

  // Insert fresh rows
  await supabaseRequest("catalog_items", {
    method: "POST",
    body: rows,
  });
}

// ---------------------------------------------------------------------------
// E. Sync run logging
// ---------------------------------------------------------------------------

async function createSyncRun() {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/catalog_sync_runs`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify({
      status: "running",
      script_version: SCRIPT_VERSION,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Failed to create sync run: ${text}`);
  }

  const data = await res.json();
  return data[0];
}

async function updateSyncRun(id, updates) {
  await fetch(`${SUPABASE_URL}/rest/v1/catalog_sync_runs?id=eq.${id}`, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify(updates),
  });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("🚀 Product Catalog Import — starting...");
  console.log(`   Supabase: ${SUPABASE_URL}`);
  console.log(`   FDA API key: ${FDA_API_KEY ? "configured" : "not set"}`);
  console.log(`   Algolia: ${ALGOLIA_APP_ID ? "configured" : "not set"}`);

  // Create sync run record
  const syncRun = await createSyncRun();
  console.log(`   Sync run ID: ${syncRun.id}`);

  const stats = {
    total_products_fetched: 0,
    variants_imported: 0,
    variants_skipped: 0,
    nutrition_enriched: 0,
    nutrition_failed: 0,
  };
  const errors = [];

  try {
    // A. Fetch all products from Shopify
    console.log("\n📦 Fetching products from Shopify...");
    const allProducts = await fetchAllProducts();
    stats.total_products_fetched = allProducts.length;
    console.log(`   Total products: ${allProducts.length}`);

    // B. Filter to food products
    const foodProducts = allProducts.filter(isFoodProduct);
    const skippedProducts = allProducts.length - foodProducts.length;
    console.log(
      `   Food products: ${foodProducts.length} (skipped ${skippedProducts} non-food)`,
    );

    // Expand variants
    const allVariants = foodProducts.flatMap(expandVariants);
    console.log(`   Total variants: ${allVariants.length}`);

    // C. Enrich nutrition + D. Upsert in batches
    const BATCH_SIZE = 50;
    const batches = [];
    for (let i = 0; i < allVariants.length; i += BATCH_SIZE) {
      batches.push(allVariants.slice(i, i + BATCH_SIZE));
    }

    console.log(
      `\n🔬 Enriching nutrition & upserting (${batches.length} batches of ${BATCH_SIZE})...`,
    );

    // Track barcodes across entire run to prevent cross-batch duplicates
    const globalSeenBarcodes = new Set();

    for (let batchIdx = 0; batchIdx < batches.length; batchIdx++) {
      const batch = batches[batchIdx];
      const rows = [];

      for (const variant of batch) {
        try {
          // Enrich nutrition
          const nutrition = await enrichNutrition(variant);

          // IMPORTANT: All rows must have the exact same keys for PostgREST
          // batch upsert (PGRST102). Always include all nutrition columns.
          const row = {
            shopify_product_id: variant.shopify_product_id,
            shopify_variant_id: variant.shopify_variant_id,
            handle: variant.handle,
            title: variant.title,
            variant_title: variant.variant_title,
            brand: variant.brand,
            product_type: variant.product_type,
            tags: variant.tags,
            barcode: variant.barcode,
            sku: variant.sku,
            price_cents: variant.price_cents,
            currency_code: variant.currency_code,
            available_for_sale: variant.available_for_sale,
            image_url: variant.image_url,
            product_url: variant.product_url,
            shopify_updated_at: variant.shopify_updated_at,
            // Nutrition — always present (null if not enriched)
            calories_per_serving: nutrition?.calories_per_serving ?? null,
            carbs_g: nutrition?.carbs_g ?? null,
            protein_g: nutrition?.protein_g ?? null,
            fat_g: nutrition?.fat_g ?? null,
            sodium_mg: nutrition?.sodium_mg ?? null,
            serving_size: nutrition?.serving_size ?? null,
            serving_grams: nutrition?.serving_grams ?? null,
            caffeine_mg: nutrition?.caffeine_mg ?? null,
            nutrition_source: nutrition?.nutrition_source ?? null,
            nutrition_confidence: nutrition?.nutrition_confidence ?? null,
            nutrition_enriched_at: nutrition ? new Date().toISOString() : null,
            raw_payload: {
              shopify: variant,
              ...(nutrition
                ? { nutrition_source_data: nutrition.nutrition_source }
                : {}),
            },
          };

          rows.push(row);

          if (nutrition) {
            stats.nutrition_enriched++;
          } else {
            stats.nutrition_failed++;
          }

          stats.variants_imported++;
        } catch (e) {
          console.error(
            `    ❌ Error enriching ${variant.title} / ${variant.variant_title}: ${e.message}`,
          );
          errors.push({
            variant_id: variant.shopify_variant_id,
            title: variant.title,
            error: e.message,
          });
          stats.variants_skipped++;
        }
      }

      // Upsert batch
      if (rows.length > 0) {
        try {
          await upsertBatch(rows, globalSeenBarcodes);
        } catch (e) {
          console.error(
            `    ❌ Batch upsert error (batch ${batchIdx + 1}): ${e.message}`,
          );
          errors.push({
            batch: batchIdx + 1,
            error: e.message,
            variant_count: rows.length,
          });
        }
      }

      console.error(
        `   Batch ${batchIdx + 1}/${batches.length}: ${rows.length} upserted`,
      );
    }

    // E. Update sync run as completed
    await updateSyncRun(syncRun.id, {
      status: "completed",
      completed_at: new Date().toISOString(),
      ...stats,
      errors: errors.length > 0 ? errors : [],
    });

    console.log("\n✅ Import complete!");
    console.log(`   Products fetched: ${stats.total_products_fetched}`);
    console.log(`   Variants imported: ${stats.variants_imported}`);
    console.log(`   Variants skipped: ${stats.variants_skipped}`);
    console.log(`   Nutrition enriched: ${stats.nutrition_enriched}`);
    console.log(`   Nutrition failed: ${stats.nutrition_failed}`);
    console.log(`   Errors: ${errors.length}`);
  } catch (e) {
    console.error(`\n❌ Fatal error: ${e.message}`);
    errors.push({ fatal: true, error: e.message });

    await updateSyncRun(syncRun.id, {
      status: "failed",
      completed_at: new Date().toISOString(),
      ...stats,
      errors,
    });

    process.exit(1);
  }
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
