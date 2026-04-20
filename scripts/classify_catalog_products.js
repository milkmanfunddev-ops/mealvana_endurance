#!/usr/bin/env node
"use strict";

/**
 * Classify Catalog Products
 *
 * Reads the catalog export JSON, deduplicates to unique products,
 * and classifies each with:
 *   - product_type_id (gel, bar, chew, etc.)
 *   - categories (before_run, during_run, after_run)
 *   - is_electrolyte
 *   - is_liquid
 *   - allergens (if ingredients available)
 *   - excluded_diets (if ingredients available)
 *
 * Uses automated heuristics first (brand + product type + title keywords),
 * then flags unclassified products for manual review.
 *
 * Usage:
 *   node scripts/classify_catalog_products.js
 *
 * Input:
 *   scripts/data/catalog_items_export.json
 *
 * Output:
 *   scripts/data/catalog_classifications.json
 */

const fs = require("fs");
const path = require("path");

const INPUT_FILE = path.join(__dirname, "data", "catalog_items_export.json");
const OUTPUT_FILE = path.join(__dirname, "data", "catalog_classifications.json");

// ---------------------------------------------------------------------------
// Category inference from product_type_id
// (matches Flutter _inferCategoriesFromProductType logic exactly)
// ---------------------------------------------------------------------------

function inferCategories(productTypeId) {
  switch (productTypeId) {
    case "gel":
    case "chew":
    case "drink_mix":
    case "sports_drink":
    case "hydration_with_carbs":
      return ["during_run"];
    case "bar":
    case "waffle":
    case "solid_carb_snacks":
      return ["before_run", "during_run"];
    case "real_food":
    case "real_food_carbs":
      return ["before_run", "after_run"];
    case "recovery_shake":
    case "protein_recovery":
      return ["after_run"];
    case "electrolyte_only":
    case "electrolytes_fluids":
    case "capsule":
      return ["during_run"];
    default:
      return ["before_run", "during_run", "after_run"];
  }
}

// ---------------------------------------------------------------------------
// Product type detection
// (mirrors lookup-product detectProductType logic)
// ---------------------------------------------------------------------------

function detectProductType(shopifyProductType, brand, title, tags, ingredients) {
  const titleLower = (title || "").toLowerCase();
  const brandLower = (brand || "").toLowerCase();
  const shopifyTypeLower = (shopifyProductType || "").toLowerCase();
  const tagsLower = (tags || []).map((t) => t.toLowerCase());
  const ingredientsLower = (ingredients || "").toLowerCase();

  // ── Stage 1: Shopify product_type mapping ──
  // These are the "product_type" values from The Feed's Shopify store
  const SHOPIFY_TYPE_MAP = {
    gels: "gel",
    bars: "bar",
    chews: "chew",
    "chews & gummies": "chew",
    waffles: "waffle",
    hydration: "drink_mix",
    "drink mix": "drink_mix",
    "drink mixes": "drink_mix",
    electrolytes: "electrolyte_only",
    protein: "recovery_shake",
    recovery: "recovery_shake",
    "meal replacement": "recovery_shake",
    snacks: "bar", // default snacks to bar
    energy: null,  // too ambiguous — needs brand/name context
  };

  const mappedType = SHOPIFY_TYPE_MAP[shopifyTypeLower];
  if (mappedType) return mappedType;

  // ── Stage 2: Brand-aware detection ──
  // Known sports nutrition brands where product type can be inferred

  // GU Energy
  if (brandLower.includes("gu energy") || brandLower === "gu") {
    if (titleLower.includes("stroopwafel") || titleLower.includes("waffle")) return "waffle";
    if (titleLower.includes("chew")) return "chew";
    if (titleLower.includes("drink mix") || titleLower.includes("roctane drink")) return "drink_mix";
    if (titleLower.includes("capsule") || titleLower.includes("electrolyte capsule")) return "capsule";
    return "gel";
  }

  // Maurten
  if (brandLower.includes("maurten")) {
    if (titleLower.includes("drink mix")) return "drink_mix";
    if (titleLower.includes("solid")) return "bar";
    if (titleLower.includes("bicarb")) return "capsule";
    return "gel";
  }

  // SIS (Science in Sport)
  if (brandLower.includes("sis") || brandLower.includes("science in sport")) {
    if (titleLower.includes("hydro") || titleLower.includes("electrolyte")) return "electrolyte_only";
    if (titleLower.includes("drink") || titleLower.includes("powder")) return "drink_mix";
    if (titleLower.includes("bar")) return "bar";
    return "gel";
  }

  // Clif
  if (brandLower.includes("clif")) {
    if (titleLower.includes("bloks") || titleLower.includes("blok") || titleLower.includes("chew") || titleLower.includes("shot")) return "chew";
    return "bar";
  }

  // Honey Stinger
  if (brandLower.includes("honey stinger")) {
    if (titleLower.includes("waffle") || titleLower.includes("stroopwafel")) return "waffle";
    if (titleLower.includes("gel")) return "gel";
    if (titleLower.includes("chew")) return "chew";
    return "bar";
  }

  // Electrolyte brands (all products are electrolytes)
  if (["nuun", "saltstick", "lmnt", "biosteel"].some((b) => brandLower.includes(b))) {
    if (titleLower.includes("capsule") || titleLower.includes("cap")) return "capsule";
    return "electrolyte_only";
  }

  // Tailwind
  if (brandLower.includes("tailwind")) {
    if (titleLower.includes("recovery")) return "recovery_shake";
    return "drink_mix";
  }

  // Skratch Labs
  if (brandLower.includes("skratch")) {
    if (titleLower.includes("chew")) return "chew";
    if (titleLower.includes("bar") || titleLower.includes("cookie") || titleLower.includes("crispy")) return "bar";
    if (titleLower.includes("recovery")) return "recovery_shake";
    return "drink_mix";
  }

  // Liquid IV / DripDrop
  if (brandLower.includes("liquid iv") || brandLower.includes("liquid i.v") || brandLower.includes("drip drop")) {
    return "drink_mix";
  }

  // Gatorade / Powerade
  if (brandLower.includes("gatorade") || brandLower.includes("powerade")) {
    if (titleLower.includes("chew")) return "chew";
    if (titleLower.includes("powder") || titleLower.includes("mix")) return "drink_mix";
    if (titleLower.includes("bar")) return "bar";
    return "sports_drink";
  }

  // Recovery/protein brands
  if (["optimum nutrition", "vega", "orgain", "garden of life"].some((b) => brandLower.includes(b))) {
    return "recovery_shake";
  }

  // Spring Energy
  if (brandLower.includes("spring energy")) {
    return "gel";
  }

  // UnTapped
  if (brandLower.includes("untapped")) {
    if (titleLower.includes("waffle")) return "waffle";
    return "gel";
  }

  // Precision Fuel & Hydration / Precision Hydration
  if (brandLower.includes("precision") && (brandLower.includes("fuel") || brandLower.includes("hydration"))) {
    if (titleLower.includes("gel")) return "gel";
    if (titleLower.includes("chew")) return "chew";
    if (titleLower.includes("bar")) return "bar";
    return "drink_mix";
  }

  // Näak
  if (brandLower.includes("naak") || brandLower.includes("näak")) {
    if (titleLower.includes("bar")) return "bar";
    if (titleLower.includes("waffle")) return "waffle";
    if (titleLower.includes("drink")) return "drink_mix";
    return "bar";
  }

  // Hammer Nutrition
  if (brandLower.includes("hammer")) {
    if (titleLower.includes("gel")) return "gel";
    if (titleLower.includes("bar")) return "bar";
    if (titleLower.includes("electrolyte") || titleLower.includes("endurolyte")) return "capsule";
    if (titleLower.includes("perpetuem") || titleLower.includes("heed") || titleLower.includes("fizz")) return "drink_mix";
    if (titleLower.includes("recoverite")) return "recovery_shake";
    return "drink_mix";
  }

  // Endure IQ / SFuels
  if (brandLower.includes("sfuels") || brandLower.includes("endure iq")) {
    if (titleLower.includes("bar")) return "bar";
    return "drink_mix";
  }

  // Sword Performance
  if (brandLower.includes("sword")) {
    return "drink_mix";
  }

  // Muir Energy
  if (brandLower.includes("muir")) {
    return "gel";
  }

  // Huma
  if (brandLower.includes("huma")) {
    if (titleLower.includes("gel") || titleLower.includes("chia")) return "gel";
    if (titleLower.includes("hydration")) return "drink_mix";
    return "gel";
  }

  // Bonk Breaker
  if (brandLower.includes("bonk breaker")) {
    return "bar";
  }

  // Laird Superfood
  if (brandLower.includes("laird")) {
    if (titleLower.includes("bar")) return "bar";
    if (titleLower.includes("hydration")) return "drink_mix";
    return "drink_mix";
  }

  // Gnarly
  if (brandLower.includes("gnarly")) {
    if (titleLower.includes("electrolyte")) return "electrolyte_only";
    if (titleLower.includes("hydration")) return "drink_mix";
    if (titleLower.includes("recovery") || titleLower.includes("protein") || titleLower.includes("whey")) return "recovery_shake";
    return "drink_mix";
  }

  // Picky Bars
  if (brandLower.includes("picky")) {
    return "bar";
  }

  // PROBAR
  if (brandLower.includes("probar")) {
    return "bar";
  }

  // Bobo's
  if (brandLower.includes("bobo")) {
    return "bar";
  }

  // Kate's Real Food
  if (brandLower.includes("kate's") || brandLower.includes("kates real food")) {
    return "bar";
  }

  // Scratch (not Skratch)
  if (brandLower === "scratch" || brandLower.includes("scratch labs")) {
    if (titleLower.includes("chew")) return "chew";
    return "drink_mix";
  }

  // Nunbell / Näak / other bar brands
  if (brandLower.includes("rxbar") || brandLower.includes("kind") || brandLower.includes("larabar")) {
    return "bar";
  }

  // ── Stage 3: Title keyword fallback ──
  const KEYWORD_MAP = [
    { keywords: ["energy gel", "gel pack", "nutrition gel", "fuel gel"], type: "gel" },
    { keywords: ["energy chew", "shot bloks", "energy chews", "fuel chews", "gummy", "gummies"], type: "chew" },
    { keywords: ["stroopwafel", "energy waffle", "stroopwaffle"], type: "waffle" },
    { keywords: ["drink mix", "endurance fuel", "hydration mix", "sport drink mix", "electrolyte powder"], type: "drink_mix" },
    { keywords: ["electrolyte tablet", "hydration tablet", "effervescent electrolyte", "electrolyte capsule", "salt capsule", "salt cap"], type: "electrolyte_only" },
    { keywords: ["recovery shake", "protein shake", "whey protein", "protein powder", "recovery mix"], type: "recovery_shake" },
    { keywords: ["energy bar", "protein bar", "fuel bar", "nutrition bar", "granola bar", "oat bar"], type: "bar" },
    { keywords: ["sports drink", "isotonic drink", "thirst quencher"], type: "sports_drink" },
    { keywords: ["capsule", "salt tab"], type: "capsule" },
  ];

  for (const { keywords, type } of KEYWORD_MAP) {
    if (keywords.some((kw) => titleLower.includes(kw))) return type;
  }

  // ── Stage 4: Shopify product_type "energy" disambiguation ──
  if (shopifyTypeLower === "energy") {
    if (titleLower.includes("gel")) return "gel";
    if (titleLower.includes("chew")) return "chew";
    if (titleLower.includes("bar")) return "bar";
    if (titleLower.includes("waffle")) return "waffle";
    if (titleLower.includes("drink") || titleLower.includes("mix")) return "drink_mix";
  }

  return null; // Could not classify
}

// ---------------------------------------------------------------------------
// Electrolyte detection
// ---------------------------------------------------------------------------

function detectIsElectrolyte(productTypeId, title, shopifyProductType) {
  if (productTypeId === "electrolyte_only" || productTypeId === "capsule") return true;
  const lower = (title || "").toLowerCase();
  if (lower.includes("electrolyte") && !lower.includes("with carb")) return true;
  if ((shopifyProductType || "").toLowerCase() === "electrolytes") return true;
  return false;
}

// ---------------------------------------------------------------------------
// Liquid detection
// ---------------------------------------------------------------------------

function detectIsLiquid(productTypeId, title) {
  if (["drink_mix", "sports_drink", "recovery_shake", "hydration_with_carbs"].includes(productTypeId)) return true;
  const lower = (title || "").toLowerCase();
  if (lower.includes("drink") || lower.includes("beverage") || lower.includes("juice")) return true;
  return false;
}

// ---------------------------------------------------------------------------
// Allergen detection from ingredients
// ---------------------------------------------------------------------------

function detectAllergens(ingredients) {
  if (!ingredients) return [];
  const lower = ingredients.toLowerCase();
  const allergens = [];

  // Common allergen patterns in ingredient lists
  if (/\b(milk|whey|casein|lactose|cream|butter|cheese|yogurt)\b/.test(lower)) allergens.push("dairy");
  if (/\b(wheat|gluten|barley|rye|spelt|kamut)\b/.test(lower)) allergens.push("gluten");
  if (/\b(soy|soya|soybean|soy lecithin)\b/.test(lower)) allergens.push("soy");
  if (/\b(tree nut|almond|cashew|walnut|pecan|pistachio|macadamia|hazelnut|brazil nut)\b/.test(lower)) allergens.push("tree_nuts");
  if (/\b(peanut|peanuts|peanut butter)\b/.test(lower)) allergens.push("peanuts");
  if (/\b(egg|eggs|egg white|albumin)\b/.test(lower)) allergens.push("eggs");
  if (/\b(shellfish|shrimp|crab|lobster)\b/.test(lower)) allergens.push("shellfish");
  if (/\b(fish|anchov|sardine|tuna|salmon)\b/.test(lower)) allergens.push("fish");
  if (/\b(sesame)\b/.test(lower)) allergens.push("sesame");
  if (/\b(coconut)\b/.test(lower)) allergens.push("coconut");

  return allergens;
}

// ---------------------------------------------------------------------------
// Excluded diets detection from ingredients
// ---------------------------------------------------------------------------

function detectExcludedDiets(ingredients, allergens) {
  if (!ingredients) return [];
  const excluded = [];

  // If it contains dairy, eggs, or animal products → not vegan
  if (allergens.includes("dairy") || allergens.includes("eggs")) {
    excluded.push("vegan");
  }
  const lower = ingredients.toLowerCase();
  if (/\b(honey|beeswax|gelatin|collagen|bone broth|whey|casein)\b/.test(lower)) {
    if (!excluded.includes("vegan")) excluded.push("vegan");
  }

  // If it contains meat/fish → not vegetarian
  if (allergens.includes("fish") || allergens.includes("shellfish")) {
    excluded.push("vegetarian");
  }
  if (/\b(gelatin|bone broth|collagen)\b/.test(lower)) {
    if (!excluded.includes("vegetarian")) excluded.push("vegetarian");
  }

  return excluded;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  console.log("🏷️  Classifying catalog products...");

  if (!fs.existsSync(INPUT_FILE)) {
    console.error(`❌ Export file not found: ${INPUT_FILE}`);
    console.error("   Run 'node scripts/export_catalog.js' first.");
    process.exit(1);
  }

  const items = JSON.parse(fs.readFileSync(INPUT_FILE, "utf8"));
  console.log(`   Loaded ${items.length} catalog_items`);

  // Deduplicate to unique products
  const productMap = new Map();
  for (const item of items) {
    const pid = item.shopify_product_id;
    if (!productMap.has(pid)) {
      productMap.set(pid, {
        shopify_product_id: pid,
        title: item.title,
        brand: item.brand,
        shopify_product_type: item.product_type,
        tags: item.tags || [],
        ingredients: item.ingredients || null,
        handle: item.handle,
      });
    }
    // Merge ingredients if available
    const existing = productMap.get(pid);
    if (!existing.ingredients && item.ingredients) {
      existing.ingredients = item.ingredients;
    }
  }

  const products = Array.from(productMap.values());
  console.log(`   Unique products: ${products.length}`);

  // Classify each product
  const classifications = [];
  let classified = 0;
  let unclassified = 0;

  for (const product of products) {
    const productTypeId = detectProductType(
      product.shopify_product_type,
      product.brand,
      product.title,
      product.tags,
      product.ingredients
    );

    const isElectrolyte = detectIsElectrolyte(productTypeId, product.title, product.shopify_product_type);
    const isLiquid = detectIsLiquid(productTypeId, product.title);
    const allergens = detectAllergens(product.ingredients);
    const excludedDiets = detectExcludedDiets(product.ingredients, allergens);
    const categories = productTypeId ? inferCategories(productTypeId) : ["before_run", "during_run", "after_run"];

    if (productTypeId) {
      classified++;
    } else {
      unclassified++;
    }

    classifications.push({
      shopify_product_id: product.shopify_product_id,
      title: product.title,
      brand: product.brand,
      shopify_product_type: product.shopify_product_type,
      // Classification results
      product_type_id: productTypeId,
      categories,
      is_electrolyte: isElectrolyte,
      is_liquid: isLiquid,
      allergens,
      excluded_diets: excludedDiets,
      classification_source: productTypeId ? "auto" : null,
      classification_confidence: productTypeId ? 0.85 : null,
      // Debug info (not uploaded)
      _debug: {
        had_ingredients: !!product.ingredients,
        handle: product.handle,
        tags: product.tags,
      },
    });
  }

  // Write classifications
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(classifications, null, 2));

  // Summary
  console.log(`\n📊 Classification Summary:`);
  console.log(`   Classified: ${classified} (${((classified / products.length) * 100).toFixed(1)}%)`);
  console.log(`   Unclassified: ${unclassified}`);

  // Breakdown by type
  const typeCounts = {};
  for (const c of classifications) {
    const type = c.product_type_id || "(unclassified)";
    typeCounts[type] = (typeCounts[type] || 0) + 1;
  }

  console.log(`\n   Product type breakdown:`);
  const sorted = Object.entries(typeCounts).sort((a, b) => b[1] - a[1]);
  for (const [type, count] of sorted) {
    console.log(`     ${type}: ${count}`);
  }

  // List unclassified products
  const unclassifiedProducts = classifications.filter((c) => !c.product_type_id);
  if (unclassifiedProducts.length > 0) {
    console.log(`\n⚠️  Unclassified products (need manual review):`);
    for (const p of unclassifiedProducts) {
      console.log(`   - "${p.title}" (${p.brand || "no brand"}) [Shopify type: ${p.shopify_product_type || "none"}]`);
    }
  }

  console.log(`\n   Written to: ${OUTPUT_FILE}`);
  console.log(`\n✅ Classification complete!`);
}

main().catch((err) => {
  console.error("❌ Fatal:", err.message || err);
  process.exit(1);
});
