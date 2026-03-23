#!/usr/bin/env node
"use strict";

/**
 * Export Catalog Items
 *
 * Exports all rows from catalog_items to a JSON file for migration
 * to the new catalog_products + catalog_variants schema.
 *
 * Usage:
 *   node scripts/export_catalog.js
 *
 * Output:
 *   scripts/data/catalog_items_export.json
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

const OUTPUT_FILE = path.join(__dirname, "data", "catalog_items_export.json");
const PAGE_SIZE = 1000;

async function fetchPage(offset) {
  const params = new URLSearchParams({
    select: "*",
    order: "created_at.asc",
    offset: String(offset),
    limit: String(PAGE_SIZE),
  });

  const res = await fetch(`${SUPABASE_URL}/rest/v1/catalog_items?${params}`, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "count=exact",
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase GET catalog_items: ${res.status} — ${text}`);
  }

  const totalCount = res.headers.get("content-range");
  const data = await res.json();
  return { data, totalCount };
}

async function main() {
  console.log("📦 Exporting catalog_items...");
  console.log(`   Supabase: ${SUPABASE_URL}`);

  const allRows = [];
  let offset = 0;

  while (true) {
    const { data, totalCount } = await fetchPage(offset);
    allRows.push(...data);
    console.log(`   Fetched ${allRows.length} rows (page offset ${offset})...`);

    if (data.length < PAGE_SIZE) break;
    offset += PAGE_SIZE;
  }

  console.log(`\n   Total rows exported: ${allRows.length}`);

  // Write to file
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(allRows, null, 2));
  console.log(`   Written to: ${OUTPUT_FILE}`);

  // Summary stats
  const uniqueProducts = new Set(allRows.map((r) => r.shopify_product_id));
  const withNutrition = allRows.filter((r) => r.calories_per_serving || r.carbs_g);
  const withBarcode = allRows.filter((r) => r.barcode);

  console.log(`\n📊 Summary:`);
  console.log(`   Unique products (shopify_product_id): ${uniqueProducts.size}`);
  console.log(`   Variants with nutrition: ${withNutrition.length}`);
  console.log(`   Variants with barcode: ${withBarcode.length}`);
  console.log(`\n✅ Export complete!`);
}

main().catch((err) => {
  console.error("❌ Fatal:", err.message || err);
  process.exit(1);
});
