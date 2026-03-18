#!/usr/bin/env node
"use strict";

/**
 * Catalog Nutrition Enrichment Script
 *
 * Retroactively enriches existing catalog_items that have no nutrition data.
 *
 * Pipeline:
 *   Phase 1: Shopify PIM metafields (bulk GraphQL — highest confidence, free)
 *   Phase 2: Per-product waterfall for remaining items:
 *            web scrape PIM → OFF → FDA
 *
 * Usage:
 *   node scripts/enrich_catalog_nutrition.js
 *
 * Required env vars:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *
 * Optional env vars:
 *   FDA_API_KEY
 *   THEFEED_STOREFRONT_ENDPOINT, THEFEED_STOREFRONT_TOKEN
 *   THEFEED_ALGOLIA_APP_ID, THEFEED_ALGOLIA_SEARCH_KEY
 */

const {
  init,
  sleep,
  PIM_METAFIELD_IDENTIFIERS,
  enrichFromProductMetafields,
  enrichFromWebScrape,
  enrichFromOFF,
  enrichFromFDA,
  resetOFFCircuitBreaker,
} = require("./lib/nutrition_enrichment.js");

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

// Initialize shared module
init({
  FDA_API_KEY,
  ALGOLIA_APP_ID,
  ALGOLIA_SEARCH_KEY,
});

// ---------------------------------------------------------------------------
// Supabase helpers
// ---------------------------------------------------------------------------

async function supabaseRequest(path, { method = "GET", body, headers: extraHeaders } = {}) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
    ...extraHeaders,
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

/**
 * Fetch all un-enriched catalog items, grouped by shopify_product_id.
 * Returns Map<shopify_product_id, Array<item>>
 */
async function fetchUnEnrichedItems() {
  // PostgREST: select items where nutrition_source is null
  // Paginate with Range header to handle large result sets
  const items = [];
  let offset = 0;
  const pageSize = 1000;

  while (true) {
    const page = await supabaseRequest(
      "catalog_items?nutrition_source=is.null&select=id,shopify_product_id,shopify_variant_id,handle,title,variant_title,brand,barcode&order=shopify_product_id",
      {
        headers: {
          Range: `${offset}-${offset + pageSize - 1}`,
          Prefer: "count=exact",
        },
      },
    );

    if (!page || page.length === 0) break;
    items.push(...page);

    if (page.length < pageSize) break;
    offset += pageSize;
  }

  // Group by shopify_product_id
  const grouped = new Map();
  for (const item of items) {
    const key = item.shopify_product_id;
    if (!grouped.has(key)) {
      grouped.set(key, []);
    }
    grouped.get(key).push(item);
  }

  return grouped;
}

/**
 * Update nutrition data for all variants of a product.
 */
async function patchProductNutrition(variantIds, nutrition) {
  if (variantIds.length === 0) return;

  const idList = variantIds.map((id) => `"${id}"`).join(",");

  const updatePayload = {
    calories_per_serving: nutrition.calories_per_serving ?? null,
    carbs_g: nutrition.carbs_g ?? null,
    protein_g: nutrition.protein_g ?? null,
    fat_g: nutrition.fat_g ?? null,
    sodium_mg: nutrition.sodium_mg ?? null,
    serving_size: nutrition.serving_size ?? null,
    serving_grams: nutrition.serving_grams ?? null,
    caffeine_mg: nutrition.caffeine_mg ?? null,
    sugar_g: nutrition.sugar_g ?? null,
    fiber_g: nutrition.fiber_g ?? null,
    ingredients: nutrition.ingredients ?? null,
    servings_per_container: nutrition.servings_per_container ?? null,
    nutrition_source: nutrition.nutrition_source,
    nutrition_confidence: nutrition.nutrition_confidence,
    nutrition_enriched_at: new Date().toISOString(),
  };

  await supabaseRequest(`catalog_items?id=in.(${idList})`, {
    method: "PATCH",
    body: updatePayload,
  });
}

// ---------------------------------------------------------------------------
// Shopify GraphQL helpers
// ---------------------------------------------------------------------------

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
      console.error(`  Throttled — retrying in ${waitMs}ms...`);
      await sleep(waitMs);
      return graphqlRequest(query, variables, attempt + 1);
    }

    throw new Error(`GraphQL request failed: ${JSON.stringify(errors)}`);
  }

  return json;
}

/**
 * Phase 1: Bulk-fetch PIM metafields from Shopify for a batch of product IDs.
 *
 * Uses Storefront API nodes() query to fetch multiple products by ID.
 *
 * @param {string[]} productIds - Array of Shopify product GIDs
 * @returns {Map<string, Object|null>} Map of productId → nutrition data (or null)
 */
async function fetchMetafieldsBatch(productIds) {
  const metafieldIds = PIM_METAFIELD_IDENTIFIERS.map(
    (m) => `{namespace: "${m.namespace}", key: "${m.key}"}`,
  ).join(", ");

  const query = `
    query FetchProductMetafields($ids: [ID!]!) {
      nodes(ids: $ids) {
        ... on Product {
          id
          metafields(identifiers: [${metafieldIds}]) {
            key
            value
          }
        }
      }
    }
  `;

  const response = await graphqlRequest(query, { ids: productIds });
  const nodes = response.data?.nodes || [];

  const results = new Map();
  for (const node of nodes) {
    if (!node || !node.id) continue;

    const variant = { _metafields: node.metafields || [] };
    const nutrition = enrichFromProductMetafields(variant);
    results.set(node.id, nutrition);
  }

  return results;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("Catalog Nutrition Enrichment — starting...");
  console.log(`  Supabase: ${SUPABASE_URL}`);
  console.log(`  FDA API key: ${FDA_API_KEY ? "configured" : "not set"}`);
  console.log(`  Algolia: ${ALGOLIA_APP_ID ? "configured" : "not set"}`);

  const stats = {
    total_unenriched: 0,
    total_products: 0,
    enriched_metafields: 0,
    enriched_web_scrape: 0,
    enriched_off: 0,
    enriched_fda: 0,
    enriched_json_ld: 0,
    still_missing: 0,
    errors: 0,
  };

  // Fetch un-enriched items grouped by product
  console.log("\nFetching un-enriched catalog items...");
  const productGroups = await fetchUnEnrichedItems();
  stats.total_products = productGroups.size;

  let totalItems = 0;
  for (const items of productGroups.values()) {
    totalItems += items.length;
  }
  stats.total_unenriched = totalItems;

  console.log(
    `  Found ${totalItems} un-enriched items across ${productGroups.size} products`,
  );

  if (productGroups.size === 0) {
    console.log("\nNo items to enrich. Done!");
    return;
  }

  // -----------------------------------------------------------------------
  // Phase 1: Shopify PIM Metafields (bulk GraphQL)
  // -----------------------------------------------------------------------
  console.log("\n--- Phase 1: Shopify PIM Metafields ---");

  const allProductIds = [...productGroups.keys()];
  const METAFIELD_BATCH_SIZE = 50;
  let metafieldSkippedAll = false;
  let phase1Count = 0;

  for (let i = 0; i < allProductIds.length; i += METAFIELD_BATCH_SIZE) {
    if (metafieldSkippedAll) break;

    const batchIds = allProductIds.slice(i, i + METAFIELD_BATCH_SIZE);
    const batchNum = Math.floor(i / METAFIELD_BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(allProductIds.length / METAFIELD_BATCH_SIZE);

    try {
      const results = await fetchMetafieldsBatch(batchIds);

      // If first batch returns all nulls, metafields likely not exposed — skip
      if (i === 0) {
        const anyFound = [...results.values()].some((v) => v !== null);
        if (!anyFound) {
          console.log(
            "  First batch returned no metafield data — skipping this source",
          );
          metafieldSkippedAll = true;
          continue;
        }
      }

      let batchEnriched = 0;
      for (const [productId, nutrition] of results) {
        if (!nutrition) continue;

        const items = productGroups.get(productId);
        if (!items) continue;

        const variantIds = items.map((it) => it.id);
        await patchProductNutrition(variantIds, nutrition);
        productGroups.delete(productId); // Remove from remaining work
        batchEnriched++;
        stats.enriched_metafields++;
      }

      phase1Count += batchEnriched;
      console.log(
        `  Batch ${batchNum}/${totalBatches}: ${batchEnriched} products enriched`,
      );
    } catch (e) {
      console.error(
        `  Batch ${batchNum} error: ${e.message}`,
      );
      stats.errors++;
    }

    // Small delay between batches
    if (i + METAFIELD_BATCH_SIZE < allProductIds.length) {
      await sleep(100);
    }
  }

  console.log(`  Phase 1 total: ${phase1Count} products enriched via metafields`);

  // -----------------------------------------------------------------------
  // Phase 2: Per-product waterfall for remaining items
  // -----------------------------------------------------------------------
  const remaining = [...productGroups.entries()];
  console.log(
    `\n--- Phase 2: Per-product waterfall (${remaining.length} products remaining) ---`,
  );

  resetOFFCircuitBreaker();

  for (let idx = 0; idx < remaining.length; idx++) {
    const [productId, items] = remaining[idx];
    const representative = items[0]; // Use first variant as representative
    const displayName = [representative.title, representative.variant_title]
      .filter(Boolean)
      .join(" / ");

    let nutrition = null;
    let source = null;

    try {
      // a. Web scrape PIM + JSON-LD
      nutrition = await enrichFromWebScrape(representative.handle);
      if (nutrition) {
        source = nutrition.nutrition_source;
      }

      // b. OFF barcode lookup
      if (!nutrition) {
        nutrition = await enrichFromOFF(representative);
        if (nutrition) source = "openfoodfacts";
      }

      // c. FDA barcode lookup
      if (!nutrition) {
        nutrition = await enrichFromFDA(representative);
        if (nutrition) source = "fda";
      }

      if (nutrition) {
        const variantIds = items.map((it) => it.id);
        await patchProductNutrition(variantIds, nutrition);

        // Track by source
        if (source === "web_scrape_pim") stats.enriched_web_scrape++;
        else if (source === "json_ld") stats.enriched_json_ld++;
        else if (source === "openfoodfacts") stats.enriched_off++;
        else if (source === "fda") stats.enriched_fda++;

        console.log(
          `  [${idx + 1}/${remaining.length}] ${displayName} (${source})`,
        );
      } else {
        stats.still_missing++;
        if ((idx + 1) % 50 === 0) {
          console.log(
            `  [${idx + 1}/${remaining.length}] Progress update — ${stats.still_missing} still missing`,
          );
        }
      }
    } catch (e) {
      console.error(
        `  [${idx + 1}/${remaining.length}] Error: ${displayName} — ${e.message}`,
      );
      stats.errors++;
    }
  }

  // -----------------------------------------------------------------------
  // Summary
  // -----------------------------------------------------------------------
  const totalEnriched =
    stats.enriched_metafields +
    stats.enriched_web_scrape +
    stats.enriched_json_ld +
    stats.enriched_off +
    stats.enriched_fda;

  console.log("\n=== Enrichment Summary ===");
  console.log(`  Total un-enriched items:   ${stats.total_unenriched}`);
  console.log(`  Total unique products:     ${stats.total_products}`);
  console.log(`  ---`);
  console.log(`  Shopify metafields:        ${stats.enriched_metafields}`);
  console.log(`  Web scrape (PIM):          ${stats.enriched_web_scrape}`);
  console.log(`  JSON-LD:                   ${stats.enriched_json_ld}`);
  console.log(`  OpenFoodFacts:             ${stats.enriched_off}`);
  console.log(`  FDA:                       ${stats.enriched_fda}`);
  console.log(`  ---`);
  console.log(`  Total enriched:            ${totalEnriched}`);
  console.log(`  Still missing:             ${stats.still_missing}`);
  console.log(`  Errors:                    ${stats.errors}`);
  console.log(
    `  Coverage:                  ${stats.total_products > 0 ? Math.round((totalEnriched / stats.total_products) * 100) : 0}%`,
  );
}

main().catch((err) => {
  console.error(`Fatal error: ${err.message || err}`);
  process.exit(1);
});
