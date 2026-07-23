/**
 * Product-type detection from Open Food Facts data.
 *
 * Extracted verbatim from lookup-product/index.ts (2026-07-16) so the barcode
 * path and the text-search path share one definition instead of drifting.
 * Behaviour is unchanged — this was a pure move.
 */

// ============================================================================
// Product Type Detection from OFF data
// ============================================================================

/**
 * Detect our app's product_type from OpenFoodFacts data using a 3-stage
 * strategy: taxonomy tags → brand + name heuristics → name keywords.
 *
 * Returns a product_type_enum value or null if we can't determine it.
 */
function detectProductType(
  categoryTags: string[] | null,
  brandsTags: string[] | null,
  productName: string | null,
  genericName: string | null,
): string | null {
  const tags = new Set((categoryTags ?? []).map(t => t.toLowerCase()));
  const brands = new Set((brandsTags ?? []).map(b => b.toLowerCase()));
  const name = (productName ?? '').toLowerCase();
  const generic = (genericName ?? '').toLowerCase();
  const nameAndGeneric = `${name} ${generic}`;

  // ── Stage 1: OFF taxonomy tag matching ──
  // These are real tags observed in OFF API responses

  // Energy gels (en:energy-gel, en:energy-gels, plus localized variants)
  if (tags.has('en:energy-gel') || tags.has('en:energy-gels')
      || tags.has('de:energiegel') || tags.has('de:sportgel')
      || tags.has('fr:gel')) {
    return 'gel';
  }

  // Energy/protein bars
  if (tags.has('en:energy-bars') || tags.has('en:protein-energy-bars')) return 'bar';
  if (tags.has('en:protein-bars') || tags.has('en:cereal-bars')) return 'bar';

  // Protein powders / recovery
  if (tags.has('en:protein-powders')) return 'recovery_shake';

  // Sports drinks (specific tags)
  if (tags.has('en:sports-drink') || tags.has('en:sports-drinks')
      || tags.has('en:dietary-drink-for-sport')) {
    return 'sports_drink';
  }

  // Electrolyte-specific drinks
  if (tags.has('en:electrolyte-drink') || tags.has('en:electrolyte-drink-mix')
      || tags.has('en:electrolytes')) {
    return 'electrolyte_only';
  }

  // Sports nutrition (ambiguous - needs brand/name context in stage 2)
  const isSportsNutrition = tags.has('en:sports-nutrition');

  // Dehydrated beverages (drink mixes, but broad - needs context)
  const isDehydratedBev = tags.has('en:dehydrated-beverages')
    || tags.has('en:dried-products-to-be-rehydrated');

  // Waffles (could be regular or sports - needs context)
  const isWaffle = tags.has('en:waffles') || tags.has('en:stuffed-waffles')
    || tags.has('en:stuffed-wafers') || tags.has('en:caramel-stuffed-wafers');

  // ── Stage 2: Brand-aware detection ──
  // Known sports nutrition brands where product type can be inferred

  // GU Energy
  if (brands.has('gu') || brands.has('gu-energy') || brands.has('gu-energy-stroopwafel')) {
    if (nameAndGeneric.includes('stroopwafel') || nameAndGeneric.includes('waffle')) return 'waffle';
    if (nameAndGeneric.includes('chew') || nameAndGeneric.includes('chews')) return 'chew';
    if (nameAndGeneric.includes('drink mix') || nameAndGeneric.includes('roctane drink')) return 'drink_mix';
    return 'gel'; // GU's primary product
  }

  // Maurten
  if (brands.has('maurten')) {
    if (nameAndGeneric.includes('drink mix')) return 'drink_mix';
    return 'gel';
  }

  // SIS (Science in Sport)
  if (brands.has('sis') || brands.has('si-s') || brands.has('science-in-sport')) {
    if (nameAndGeneric.includes('hydro') || nameAndGeneric.includes('electrolyte')) return 'electrolyte_only';
    if (nameAndGeneric.includes('drink') || nameAndGeneric.includes('powder')) return 'drink_mix';
    return 'gel';
  }

  // Clif
  if (brands.has('clif') || brands.has('clif-bar') || brands.has('clif-bar-and-company')) {
    if (nameAndGeneric.includes('bloks') || nameAndGeneric.includes('blok')
        || nameAndGeneric.includes('chew') || nameAndGeneric.includes('shot')) return 'chew';
    return 'bar';
  }

  // Honey Stinger
  if (brands.has('honey-stinger')) {
    if (nameAndGeneric.includes('waffle') || nameAndGeneric.includes('stroopwafel')) return 'waffle';
    if (nameAndGeneric.includes('gel')) return 'gel';
    if (nameAndGeneric.includes('chew')) return 'chew';
    return 'bar'; // default for their bars
  }

  // Electrolyte brands (all products are electrolytes)
  if (brands.has('nuun') || brands.has('saltstick') || brands.has('saltstick-fastchews')
      || brands.has('lmnt')) {
    return 'electrolyte_only';
  }

  // Drink mix brands
  if (brands.has('tailwind')) return 'drink_mix';
  if (brands.has('skratch-labs')) {
    if (nameAndGeneric.includes('chew')) return 'chew';
    if (nameAndGeneric.includes('bar') || nameAndGeneric.includes('cookie')) return 'bar';
    return 'drink_mix';
  }
  if (brands.has('liquid-iv') || brands.has('liquid-i-v')) return 'drink_mix';
  if (brands.has('drip-drop') || brands.has('drip-drop-hydration-inc')) return 'drink_mix';

  // Sports drink brands
  if (brands.has('gatorade') || brands.has('powerade')) {
    if (nameAndGeneric.includes('chew')) return 'chew';
    if (nameAndGeneric.includes('powder') || nameAndGeneric.includes('mix')) return 'drink_mix';
    return 'sports_drink';
  }

  // Recovery/protein brands
  if (brands.has('optimum-nutrition') || brands.has('vega') || brands.has('orgain')
      || brands.has('garden-of-life')) {
    return 'recovery_shake';
  }

  // Spring Energy
  if (brands.has('spring-energy')) return 'gel';

  // Now resolve ambiguous tags with name context
  if (isSportsNutrition) {
    if (nameAndGeneric.includes('gel')) return 'gel';
    if (nameAndGeneric.includes('bar')) return 'bar';
    if (nameAndGeneric.includes('drink') || nameAndGeneric.includes('mix')) return 'drink_mix';
    if (nameAndGeneric.includes('chew')) return 'chew';
  }

  if (isDehydratedBev) {
    if (nameAndGeneric.includes('electrolyte') || nameAndGeneric.includes('hydration')) return 'drink_mix';
    if (nameAndGeneric.includes('sport') || nameAndGeneric.includes('endurance')) return 'drink_mix';
  }

  if (isWaffle) {
    if (nameAndGeneric.includes('energy') || nameAndGeneric.includes('stroopwafel')) return 'waffle';
    // Regular waffles - don't assign a sports type
  }

  // ── Stage 3: Product name keyword fallback ──
  // Catches unbranded or untagged products

  const KEYWORD_MAP: Array<{ keywords: string[]; type: string }> = [
    { keywords: ['energy gel', 'gel pack', 'energy gel with'], type: 'gel' },
    { keywords: ['energy chew', 'shot bloks', 'energy chews', 'fuel chews'], type: 'chew' },
    { keywords: ['stroopwafel', 'energy waffle'], type: 'waffle' },
    { keywords: ['drink mix', 'endurance fuel', 'hydration mix', 'sport drink mix', 'electrolyte powder'], type: 'drink_mix' },
    { keywords: ['electrolyte tablet', 'hydration tablet', 'effervescent electrolyte'], type: 'electrolyte_only' },
    { keywords: ['recovery shake', 'protein shake', 'whey protein', 'protein powder'], type: 'recovery_shake' },
    { keywords: ['energy bar', 'protein bar', 'fuel bar'], type: 'bar' },
    { keywords: ['sports drink', 'isotonic drink', 'thirst quencher'], type: 'sports_drink' },
  ];

  for (const { keywords, type } of KEYWORD_MAP) {
    if (keywords.some(kw => nameAndGeneric.includes(kw))) return type;
  }

  return null; // Can't determine - user picks from dropdown, defaults to 'import'
}

/**
 * Look up a catalog variant by barcode using the catalog_items view
 * (JOINs catalog_products + catalog_variants).
 * Returns a cleanedProduct in the same shape as the OFF response so the
 * Flutter client needs zero changes.
 */

export { detectProductType };
