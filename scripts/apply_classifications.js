#!/usr/bin/env node
"use strict";

/**
 * Apply Catalog Classifications
 *
 * Reads catalog_classifications.json and updates catalog_products
 * in Supabase with product_type_id, categories, allergens, etc.
 *
 * Usage:
 *   node scripts/apply_classifications.js
 *
 * Prerequisites:
 *   1. Run the SQL migration
 *   2. Run migrate_catalog_to_products.js (populates catalog_products)
 *   3. Run classify_catalog_products.js (creates catalog_classifications.json)
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

const INPUT_FILE = path.join(__dirname, "data", "catalog_classifications.json");
const BATCH_SIZE = 50;

// ---------------------------------------------------------------------------
// Supabase REST helper
// ---------------------------------------------------------------------------

async function supabasePatch(shopifyProductId, updates) {
  const url = `${SUPABASE_URL}/rest/v1/catalog_products?shopify_product_id=eq.${encodeURIComponent(shopifyProductId)}`;

  const res = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify(updates),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`PATCH catalog_products: ${res.status} — ${text}`);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("🏷️  Applying classifications to catalog_products...");
  console.log(`   Supabase: ${SUPABASE_URL}`);

  if (!fs.existsSync(INPUT_FILE)) {
    console.error(`❌ Classifications file not found: ${INPUT_FILE}`);
    console.error("   Run 'node scripts/classify_catalog_products.js' first.");
    process.exit(1);
  }

  const classifications = JSON.parse(fs.readFileSync(INPUT_FILE, "utf8"));
  console.log(`   Loaded ${classifications.length} classifications`);

  let updated = 0;
  let skipped = 0;
  let errors = 0;

  for (let i = 0; i < classifications.length; i++) {
    const c = classifications[i];

    // Only update products that have a classification
    if (!c.product_type_id) {
      skipped++;
      continue;
    }

    const updates = {
      product_type_id: c.product_type_id,
      categories: c.categories,
      is_electrolyte: c.is_electrolyte,
      is_liquid: c.is_liquid,
      allergens: c.allergens,
      excluded_diets: c.excluded_diets,
      classification_source: c.classification_source || "auto",
      classification_confidence: c.classification_confidence || 0.85,
      classified_at: new Date().toISOString(),
    };

    try {
      await supabasePatch(c.shopify_product_id, updates);
      updated++;
    } catch (e) {
      console.error(`  ❌ Failed to update "${c.title}": ${e.message}`);
      errors++;
    }

    // Progress logging every 100 items
    if ((i + 1) % 100 === 0 || i === classifications.length - 1) {
      console.log(`   Progress: ${i + 1}/${classifications.length} (updated: ${updated}, skipped: ${skipped}, errors: ${errors})`);
    }
  }

  console.log(`\n✅ Classification applied!`);
  console.log(`   Updated: ${updated}`);
  console.log(`   Skipped (no classification): ${skipped}`);
  console.log(`   Errors: ${errors}`);
}

main().catch((err) => {
  console.error("❌ Fatal:", err.message || err);
  process.exit(1);
});
