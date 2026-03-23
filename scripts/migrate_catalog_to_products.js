#!/usr/bin/env node
"use strict";

/**
 * Migrate catalog_items → catalog_products + catalog_variants
 *
 * Reads the exported catalog_items JSON, groups by shopify_product_id,
 * and inserts into the new normalized tables.
 *
 * Usage:
 *   node scripts/migrate_catalog_to_products.js
 *
 * Prerequisites:
 *   1. Run the SQL migration (20260323100000_catalog_products_variants.sql)
 *   2. Run export_catalog.js to create scripts/data/catalog_items_export.json
 *
 * Required env vars:
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 */

const fs = require("fs");
const path = require("path");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set.");
  process.exit(1);
}

const INPUT_FILE = path.join(__dirname, "data", "catalog_items_export.json");
const BATCH_SIZE = 50;

// ---------------------------------------------------------------------------
// Supabase REST helper
// ---------------------------------------------------------------------------

async function supabaseRequest(table, { method = "GET", body, query, prefer } = {}) {
  let url = `${SUPABASE_URL}/rest/v1/${table}`;
  if (query) {
    const params = new URLSearchParams(query);
    url += `?${params.toString()}`;
  }

  const headers = {
    apikey: SUPABASE_SERVICE_ROLE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
    Prefer: prefer || (method === "POST" ? "return=representation" : ""),
  };

  const res = await fetch(url, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase ${method} ${table}: ${res.status} — ${text}`);
  }

  const contentType = res.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return res.json();
  }
  return null;
}

// ---------------------------------------------------------------------------
// Group catalog_items by product
// ---------------------------------------------------------------------------

function groupByProduct(items) {
  const groups = new Map();

  for (const item of items) {
    const productId = item.shopify_product_id;
    if (!groups.has(productId)) {
      groups.set(productId, {
        // Product-level fields (same across all variants)
        shopify_product_id: productId,
        handle: item.handle,
        title: item.title,
        brand: item.brand || null,
        shopify_product_type: item.product_type || null,
        tags: item.tags || [],
        image_url: item.image_url || null,
        product_url: item.product_url || null,
        ingredients: item.ingredients || null,
        shopify_updated_at: item.shopify_updated_at || null,
        variants: [],
      });
    }

    const group = groups.get(productId);

    // Collect variant
    group.variants.push({
      shopify_variant_id: item.shopify_variant_id || null,
      variant_title: item.variant_title || null,
      barcode: item.barcode || null,
      sku: item.sku || null,
      price_cents: item.price_cents ?? null,
      currency_code: item.currency_code || "USD",
      available_for_sale: item.available_for_sale ?? true,
      image_url: item.image_url || null,
      calories_per_serving: item.calories_per_serving ?? null,
      carbs_g: item.carbs_g ?? null,
      protein_g: item.protein_g ?? null,
      fat_g: item.fat_g ?? null,
      sodium_mg: item.sodium_mg ?? null,
      serving_size: item.serving_size || null,
      serving_grams: item.serving_grams ?? null,
      caffeine_mg: item.caffeine_mg ?? null,
      sugar_g: item.sugar_g ?? null,
      fiber_g: item.fiber_g ?? null,
      servings_per_container: item.servings_per_container ?? null,
      nutrition_source: item.nutrition_source || null,
      nutrition_confidence: item.nutrition_confidence ?? null,
      nutrition_enriched_at: item.nutrition_enriched_at || null,
      raw_payload: item.raw_payload || null,
      shopify_updated_at: item.shopify_updated_at || null,
    });

    // Merge product-level fields (prefer non-null values)
    if (!group.ingredients && item.ingredients) {
      group.ingredients = item.ingredients;
    }
    if (!group.image_url && item.image_url) {
      group.image_url = item.image_url;
    }
    if (!group.product_url && item.product_url) {
      group.product_url = item.product_url;
    }
    // Use the latest shopify_updated_at
    if (item.shopify_updated_at && (!group.shopify_updated_at || item.shopify_updated_at > group.shopify_updated_at)) {
      group.shopify_updated_at = item.shopify_updated_at;
    }
  }

  return Array.from(groups.values());
}

// ---------------------------------------------------------------------------
// Insert products + variants
// ---------------------------------------------------------------------------

async function insertProducts(products) {
  let totalProducts = 0;
  let totalVariants = 0;
  let errors = 0;

  // Process in batches
  for (let i = 0; i < products.length; i += BATCH_SIZE) {
    const batch = products.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(products.length / BATCH_SIZE);

    // Insert product rows
    const productRows = batch.map((p) => ({
      shopify_product_id: p.shopify_product_id,
      handle: p.handle,
      title: p.title,
      brand: p.brand,
      shopify_product_type: p.shopify_product_type,
      tags: p.tags,
      image_url: p.image_url,
      product_url: p.product_url,
      ingredients: p.ingredients,
      shopify_updated_at: p.shopify_updated_at,
    }));

    let insertedProducts;
    try {
      insertedProducts = await supabaseRequest("catalog_products", {
        method: "POST",
        body: productRows,
        prefer: "return=representation",
      });
    } catch (e) {
      console.error(`  ❌ Batch ${batchNum}: Product insert failed: ${e.message}`);
      errors += batch.length;
      continue;
    }

    totalProducts += insertedProducts.length;

    // Build product ID lookup
    const productIdMap = new Map();
    for (const row of insertedProducts) {
      productIdMap.set(row.shopify_product_id, row.id);
    }

    // Insert variant rows for this batch
    const variantRows = [];
    for (const product of batch) {
      const catalogProductId = productIdMap.get(product.shopify_product_id);
      if (!catalogProductId) continue;

      for (const variant of product.variants) {
        variantRows.push({
          catalog_product_id: catalogProductId,
          ...variant,
        });
      }
    }

    if (variantRows.length > 0) {
      try {
        await supabaseRequest("catalog_variants", {
          method: "POST",
          body: variantRows,
          prefer: "return=minimal",
        });
        totalVariants += variantRows.length;
      } catch (e) {
        console.error(`  ❌ Batch ${batchNum}: Variant insert failed: ${e.message}`);
        errors += variantRows.length;
      }
    }

    console.log(`  Batch ${batchNum}/${totalBatches}: ${insertedProducts.length} products, ${variantRows.length} variants`);
  }

  return { totalProducts, totalVariants, errors };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("🔄 Migrating catalog_items → catalog_products + catalog_variants");
  console.log(`   Supabase: ${SUPABASE_URL}`);
  console.log(`   Input: ${INPUT_FILE}`);

  // Read export
  if (!fs.existsSync(INPUT_FILE)) {
    console.error(`\n❌ Export file not found: ${INPUT_FILE}`);
    console.error("   Run 'node scripts/export_catalog.js' first.");
    process.exit(1);
  }

  const items = JSON.parse(fs.readFileSync(INPUT_FILE, "utf8"));
  console.log(`   Loaded ${items.length} catalog_items`);

  // Group by product
  const products = groupByProduct(items);
  console.log(`   Grouped into ${products.length} unique products`);

  // Variant count check
  const totalVariantCount = products.reduce((sum, p) => sum + p.variants.length, 0);
  console.log(`   Total variants: ${totalVariantCount}`);

  if (totalVariantCount !== items.length) {
    console.warn(`   ⚠️  Variant count (${totalVariantCount}) != item count (${items.length})`);
  }

  // Insert into new tables
  console.log(`\n📤 Inserting into catalog_products + catalog_variants...`);
  const result = await insertProducts(products);

  console.log(`\n✅ Migration complete!`);
  console.log(`   Products inserted: ${result.totalProducts}`);
  console.log(`   Variants inserted: ${result.totalVariants}`);
  if (result.errors > 0) {
    console.log(`   Errors: ${result.errors}`);
  }

  // Write a summary for verification
  const summary = {
    migrated_at: new Date().toISOString(),
    source_items: items.length,
    unique_products: products.length,
    products_inserted: result.totalProducts,
    variants_inserted: result.totalVariants,
    errors: result.errors,
  };
  const summaryFile = path.join(__dirname, "data", "migration_summary.json");
  fs.writeFileSync(summaryFile, JSON.stringify(summary, null, 2));
  console.log(`   Summary written to: ${summaryFile}`);
}

main().catch((err) => {
  console.error("❌ Fatal:", err.message || err);
  process.exit(1);
});
