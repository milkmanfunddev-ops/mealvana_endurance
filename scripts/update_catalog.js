#!/usr/bin/env node
"use strict";

/**
 * Product Catalog Import Script (v2 — catalog_products + catalog_variants)
 *
 * Pipeline:
 *   A. Fetch products + variants (with PIM metafields) from Shopify Storefront GraphQL
 *   B. Filter to food-only products (by productType + tags)
 *   C. Enrich each variant with nutrition (metafields → Algolia → web scrape → OFF → FDA)
 *   D. Upsert into catalog_products + catalog_variants via Supabase REST
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

const {
  init: initEnrichment,
  sleep,
  buildMetafieldsGraphQL,
  enrichNutrition,
} = require("./lib/nutrition_enrichment.js");

const SCRIPT_VERSION = "2.0.0";

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

// Initialize shared enrichment module
initEnrichment({
  FDA_API_KEY,
  ALGOLIA_APP_ID,
  ALGOLIA_SEARCH_KEY,
});

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

async function supabaseRequest(path, { method = "GET", body, query, prefer } = {}) {
  let url = `${SUPABASE_URL}/rest/v1/${path}`;
  if (query) {
    const params = new URLSearchParams(query);
    url += `?${params.toString()}`;
  }

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
    Prefer: prefer || (method === "POST" ? "return=minimal" : ""),
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
          ${buildMetafieldsGraphQL()}
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

// ---------------------------------------------------------------------------
// C. Expand products into product + variant structure
// ---------------------------------------------------------------------------

function expandProduct(product) {
  const variants = product.variants?.edges?.map((e) => e.node) || [];
  const metafields = product.metafields || [];

  const productData = {
    shopify_product_id: product.id,
    handle: product.handle,
    title: product.title,
    brand: product.vendor || null,
    shopify_product_type: product.productType || null,
    tags: product.tags || [],
    image_url: product.featuredImage?.url || null,
    product_url: product.onlineStoreUrl || null,
    shopify_updated_at: product.updatedAt || null,
    _metafields: metafields,
  };

  const variantData = variants.length > 0
    ? variants.map((v) => ({
        shopify_variant_id: v.id,
        variant_title: v.title || null,
        barcode: v.barcode || null,
        sku: v.sku || null,
        price_cents: v.price?.amount
          ? Math.round(parseFloat(v.price.amount) * 100)
          : null,
        currency_code: v.price?.currencyCode || "USD",
        available_for_sale: v.availableForSale ?? true,
        image_url: v.image?.url || null,
        shopify_updated_at: product.updatedAt || null,
        // Attach metafields for enrichment (will be stripped before DB insert)
        _metafields: metafields,
        _product_title: product.title,
        _product_handle: product.handle,
      }))
    : [{
        shopify_variant_id: null,
        variant_title: null,
        barcode: null,
        sku: null,
        price_cents: null,
        currency_code: "USD",
        available_for_sale: product.availableForSale ?? true,
        image_url: null,
        shopify_updated_at: product.updatedAt || null,
        _metafields: metafields,
        _product_title: product.title,
        _product_handle: product.handle,
      }];

  return { productData, variantData };
}

// ---------------------------------------------------------------------------
// D. Upsert into catalog_products + catalog_variants
// ---------------------------------------------------------------------------

async function upsertProductBatch(products, enrichedVariants, globalSeenBarcodes) {
  // Step 1: UPSERT product rows on shopify_product_id (NON-DESTRUCTIVE).
  // Only Shopify-sourced columns are written, so classification columns
  // (product_type_id, categories, allergens, is_electrolyte, activity_types,
  // classification_source/_confidence) are PRESERVED across refreshes.
  // Previously this delete+reinserted each product, which wiped all
  // classification on every run (had to be re-applied by a separate script).
  // Non-destructive upsert lets a scheduled refresh classify only NEW products.
  const nowIso = new Date().toISOString();

  const productRows = products.map((p) => ({
    shopify_product_id: p.shopify_product_id,
    handle: p.handle,
    title: p.title,
    brand: p.brand,
    shopify_product_type: p.shopify_product_type,
    tags: p.tags,
    image_url: p.image_url,
    product_url: p.product_url,
    shopify_updated_at: p.shopify_updated_at,
    // Ingredients will be set from enrichment if available
    ingredients: p._ingredients || null,
    updated_at: nowIso,
  }));

  const insertedProducts = await supabaseRequest("catalog_products", {
    method: "POST",
    body: productRows,
    query: { on_conflict: "shopify_product_id" },
    prefer: "resolution=merge-duplicates,return=representation",
  });

  // Build product ID lookup
  const productIdMap = new Map();
  for (const row of insertedProducts) {
    productIdMap.set(row.shopify_product_id, row.id);
  }

  // Step 2: UPSERT variant rows on shopify_variant_id (NON-DESTRUCTIVE).
  // Split into two writes:
  //   2a) base/Shopify columns — ALWAYS upserted (title, price, availability...).
  //       Nutrition columns are intentionally EXCLUDED here so a run with no
  //       fresh nutrition (e.g. FDA_API_KEY unset, or an enrichment miss) does
  //       NOT null out previously-enriched nutrition.
  //   2b) nutrition columns — upserted ONLY for variants this run actually
  //       enriched (nutrition_source present).
  const baseVariantRows = [];
  const nutritionRows = [];
  for (const variant of enrichedVariants) {
    const catalogProductId = productIdMap.get(variant._shopify_product_id);
    if (!catalogProductId) continue;

    // Deduplicate barcodes (within this run)
    if (variant.barcode) {
      if (globalSeenBarcodes.has(variant.barcode)) {
        variant.barcode = null;
      } else {
        globalSeenBarcodes.add(variant.barcode);
      }
    }

    baseVariantRows.push({
      catalog_product_id: catalogProductId,
      shopify_variant_id: variant.shopify_variant_id,
      variant_title: variant.variant_title,
      barcode: variant.barcode,
      sku: variant.sku,
      price_cents: variant.price_cents,
      currency_code: variant.currency_code,
      available_for_sale: variant.available_for_sale,
      image_url: variant.image_url,
      shopify_updated_at: variant.shopify_updated_at,
      raw_payload: variant.raw_payload ?? null,
      updated_at: nowIso,
    });

    // Only write nutrition when this run produced it — preserves existing
    // nutrition otherwise.
    if (variant.nutrition_source) {
      nutritionRows.push({
        catalog_product_id: catalogProductId,
        shopify_variant_id: variant.shopify_variant_id,
        calories_per_serving: variant.calories_per_serving ?? null,
        carbs_g: variant.carbs_g ?? null,
        protein_g: variant.protein_g ?? null,
        fat_g: variant.fat_g ?? null,
        sodium_mg: variant.sodium_mg ?? null,
        serving_size: variant.serving_size ?? null,
        serving_grams: variant.serving_grams ?? null,
        caffeine_mg: variant.caffeine_mg ?? null,
        sugar_g: variant.sugar_g ?? null,
        fiber_g: variant.fiber_g ?? null,
        servings_per_container: variant.servings_per_container ?? null,
        nutrition_source: variant.nutrition_source,
        nutrition_confidence: variant.nutrition_confidence ?? null,
        nutrition_enriched_at: variant.nutrition_enriched_at ?? null,
      });
    }
  }

  // 2a) Base columns — always (preserves nutrition + any future variant-level flags).
  if (baseVariantRows.length > 0) {
    await supabaseRequest("catalog_variants", {
      method: "POST",
      body: baseVariantRows,
      query: { on_conflict: "shopify_variant_id" },
      prefer: "resolution=merge-duplicates",
    });
  }

  // 2b) Nutrition columns — only for variants enriched this run.
  if (nutritionRows.length > 0) {
    await supabaseRequest("catalog_variants", {
      method: "POST",
      body: nutritionRows,
      query: { on_conflict: "shopify_variant_id" },
      prefer: "resolution=merge-duplicates",
    });
  }

  return {
    productsInserted: insertedProducts.length,
    variantsInserted: baseVariantRows.length,
  };
}

// ---------------------------------------------------------------------------
// D2. Deactivate products no longer in the feed (B1)
// ---------------------------------------------------------------------------

// Fraction of the catalog that, if "not seen" in a run, is treated as a bad or
// partial fetch rather than genuine removals — deactivation is skipped above it.
const ANTI_WIPEOUT_PCT = 0.1;

// Marks variants of products NOT seen in this run as unavailable, so items that
// left TheFeed stop surfacing. Returns counts for logging (kept OUT of `stats`,
// which is spread into catalog_sync_runs and must only contain known columns).
async function deactivateRemovedProducts(seenProductIds) {
  const existing = await supabaseRequest("catalog_products", {
    query: { select: "id,shopify_product_id" },
  });
  if (!Array.isArray(existing) || existing.length === 0) {
    return { detected: 0, deactivated: 0, skipped: 0 };
  }

  const removed = existing.filter(
    (p) => !seenProductIds.has(p.shopify_product_id),
  );
  if (removed.length === 0) {
    console.log("   Removed products: none");
    return { detected: 0, deactivated: 0, skipped: 0 };
  }

  const pct = removed.length / existing.length;
  if (pct > ANTI_WIPEOUT_PCT) {
    console.error(
      `   ⚠️  ANTI-WIPEOUT: ${removed.length}/${existing.length} (${(pct * 100).toFixed(1)}%) products not seen this run — exceeds ${(ANTI_WIPEOUT_PCT * 100).toFixed(0)}% threshold. Skipping deactivation (likely a bad/partial fetch).`,
    );
    return { detected: removed.length, deactivated: 0, skipped: removed.length };
  }

  const removedIds = removed.map((p) => p.id);
  const CHUNK = 50;
  for (let i = 0; i < removedIds.length; i += CHUNK) {
    const chunk = removedIds.slice(i, i + CHUNK);
    await supabaseRequest("catalog_variants", {
      method: "PATCH",
      query: { catalog_product_id: `in.(${chunk.join(",")})` },
      body: { available_for_sale: false, updated_at: new Date().toISOString() },
      prefer: "return=minimal",
    });
  }
  console.log(`   Removed products deactivated: ${removed.length}`);
  return { detected: removed.length, deactivated: removed.length, skipped: 0 };
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
  console.log("🚀 Product Catalog Import v2 — starting...");
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

    // C. Expand into product + variant structure
    const expanded = foodProducts.map(expandProduct);
    const totalVariants = expanded.reduce((sum, e) => sum + e.variantData.length, 0);
    console.log(`   Total variants: ${totalVariants}`);

    // Set of products present in THIS fetch — used by B1 to deactivate the rest.
    const seenProductIds = new Set(
      expanded.map((e) => e.productData.shopify_product_id),
    );

    // D. Enrich nutrition + upsert in batches
    const BATCH_SIZE = 20; // Products per batch (smaller because each has multiple variants)
    const batches = [];
    for (let i = 0; i < expanded.length; i += BATCH_SIZE) {
      batches.push(expanded.slice(i, i + BATCH_SIZE));
    }

    console.log(
      `\n🔬 Enriching nutrition & upserting (${batches.length} batches of ${BATCH_SIZE} products)...`,
    );

    const globalSeenBarcodes = new Set();

    for (let batchIdx = 0; batchIdx < batches.length; batchIdx++) {
      const batch = batches[batchIdx];
      const batchProducts = [];
      const batchVariants = [];

      for (const { productData, variantData } of batch) {
        let productIngredients = null;

        for (const variant of variantData) {
          try {
            // Build enrichment input (same shape as old expandVariants output)
            const enrichmentInput = {
              ...variant,
              shopify_product_id: productData.shopify_product_id,
              handle: productData.handle,
              title: productData.title,
              brand: productData.brand,
              product_type: productData.shopify_product_type,
              tags: productData.tags,
              product_url: productData.product_url,
            };

            const nutrition = await enrichNutrition(enrichmentInput);

            // Capture ingredients at product level (shared across variants)
            if (nutrition?.ingredients && !productIngredients) {
              productIngredients = nutrition.ingredients;
            }

            const { _metafields, _product_title, _product_handle, ...cleanVariant } = variant;

            batchVariants.push({
              ...cleanVariant,
              _shopify_product_id: productData.shopify_product_id,
              calories_per_serving: nutrition?.calories_per_serving ?? null,
              carbs_g: nutrition?.carbs_g ?? null,
              protein_g: nutrition?.protein_g ?? null,
              fat_g: nutrition?.fat_g ?? null,
              sodium_mg: nutrition?.sodium_mg ?? null,
              serving_size: nutrition?.serving_size ?? null,
              serving_grams: nutrition?.serving_grams ?? null,
              caffeine_mg: nutrition?.caffeine_mg ?? null,
              sugar_g: nutrition?.sugar_g ?? null,
              fiber_g: nutrition?.fiber_g ?? null,
              servings_per_container: nutrition?.servings_per_container ?? null,
              nutrition_source: nutrition?.nutrition_source ?? null,
              nutrition_confidence: nutrition?.nutrition_confidence ?? null,
              nutrition_enriched_at: nutrition ? new Date().toISOString() : null,
              raw_payload: {
                shopify: cleanVariant,
                ...(nutrition ? { nutrition_source_data: nutrition.nutrition_source } : {}),
              },
            });

            if (nutrition) {
              stats.nutrition_enriched++;
            } else {
              stats.nutrition_failed++;
            }
            stats.variants_imported++;
          } catch (e) {
            console.error(
              `    ❌ Error enriching ${productData.title} / ${variant.variant_title}: ${e.message}`,
            );
            errors.push({
              variant_id: variant.shopify_variant_id,
              title: productData.title,
              error: e.message,
            });
            stats.variants_skipped++;
          }
        }

        // Set product-level ingredients from enrichment
        productData._ingredients = productIngredients;
        batchProducts.push(productData);
      }

      // Upsert batch
      if (batchProducts.length > 0) {
        try {
          const result = await upsertProductBatch(batchProducts, batchVariants, globalSeenBarcodes);
          console.error(
            `   Batch ${batchIdx + 1}/${batches.length}: ${result.productsInserted} products, ${result.variantsInserted} variants`,
          );
        } catch (e) {
          console.error(
            `    ❌ Batch upsert error (batch ${batchIdx + 1}): ${e.message}`,
          );
          errors.push({
            batch: batchIdx + 1,
            error: e.message,
            product_count: batchProducts.length,
          });
        }
      }
    }

    // D2. Deactivate products that are no longer in the feed (B1).
    console.log("\n🧹 Checking for removed products...");
    const removal = await deactivateRemovedProducts(seenProductIds);

    // E. Update sync run as completed
    await updateSyncRun(syncRun.id, {
      status: "completed",
      completed_at: new Date().toISOString(),
      ...stats,
      errors: errors.length > 0 ? errors : [],
    });

    console.log("\n✅ Import complete!");
    console.log(
      `   Removed products: detected ${removal.detected}, deactivated ${removal.deactivated}, skipped ${removal.skipped}`,
    );
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
