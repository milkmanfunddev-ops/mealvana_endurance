/**
 * search-nutrition-products — tokenization / ranking / merge contract.
 *
 * Imports the REAL pure logic from _shared/food_sources/search_matching.ts
 * (extracted precisely so tests need no mirror and cannot drift; importing
 * index.ts itself would execute Deno.serve()). Every named regression below
 * was measured against prod during the 2026-07-15/16 food-DB audit — see
 * docs/architecture/food-search-scan-audit-2026-07-16.md §9c.
 *
 * These rules matter beyond the current cache: this function fronts the
 * planned 1.9M-row USDA Branded backfill, whose names are comma-inverted
 * all-caps ("COCA-COLA, COLA") — unreachable by whole-phrase ilike.
 *
 * Run: deno test --allow-all supabase/functions/search-nutrition-products/
 */
import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  describe,
  it,
} from 'https://deno.land/std@0.168.0/testing/bdd.ts';
import {
  tokenize,
  scoreResult,
  passesThreshold,
  dedupeByBarcode,
} from '../_shared/food_sources/search_matching.ts';
import type { NutritionProductLike } from '../_shared/food_sources/usda_search.ts';

// ── test-row factory ─────────────────────────────────────────────────────────

function row(
  partial: Pick<NutritionProductLike, 'barcode' | 'product_name' | 'brand_name' | 'source'> &
    Partial<NutritionProductLike>,
): NutritionProductLike {
  return {
    image_url: null,
    serving_size: null,
    serving_grams: null,
    calories_per_100g: null,
    carbohydrates_per_100g: null,
    protein_per_100g: null,
    fat_per_100g: null,
    sodium_mg_per_100g: null,
    calories_per_serving: null,
    carbohydrates_per_serving: null,
    protein_per_serving: null,
    fat_per_serving: null,
    sodium_mg_per_serving: null,
    categories: null,
    suggested_product_type: null,
    nutrition_data_per: '100g',
    confidence_score: 0.5,
    ...partial,
  };
}

// ── tests ───────────────────────────────────────────────────────────────────

describe('tokenization — must match the SQL + Dart tokenizers', () => {
  it('splits on whitespace', () => {
    assertEquals(tokenize('pringles original'), ['pringles', 'original']);
  });

  it('splits on hyphens too, so "coca-cola" and "coca cola" tokenize identically', () => {
    // Every non-alphanumeric run is a separator. Normalizing the QUERY this
    // way (plus substring matching against the raw target) is what makes
    // punctuation differences non-blocking in both directions.
    assertEquals(tokenize('coca-cola'), ['coca', 'cola']);
    assertEquals(tokenize('coca cola'), ['coca', 'cola']);
  });

  it('collapses repeated separators', () => {
    assertEquals(tokenize('  clif   bar '), ['clif', 'bar']);
  });

  it('single-word query yields one token (single-token behaviour unchanged)', () => {
    assertEquals(tokenize('pringles'), ['pringles']);
  });
});

describe('threshold — regression for the real prod misses', () => {
  const cocaCola = row({
    barcode: '00000004963406',
    product_name: 'COCA-COLA, COLA',
    brand_name: 'COCA-COLA',
    source: 'usda_fdc',
  });
  const pringles = row({
    barcode: '00038000138416',
    product_name: 'Pringles Crisps Original 5.2oz',
    brand_name: 'Pringles',
    source: 'usda_fdc',
  });

  it('"coca cola" matches "COCA-COLA, COLA" (whole-phrase ilike returned 0)', () => {
    // USDA Branded names are comma-inverted all-caps; the whole 1.9M-row
    // backfill looks like this row.
    assert(passesThreshold(cocaCola, tokenize('coca cola')));
  });

  it('"rx bar" matches "RXBAR Protein Bar" — spacing difference, not just ordering', () => {
    // Tokenization ALONE (word-boundary matching) would NOT fix this: no word
    // of "RXBAR Protein Bar" equals "rx". It works because each token matches
    // by SUBSTRING (ilike %token%): 'rx' and 'bar' are both substrings of
    // 'rxbar'. That is the deliberate design choice — no concatenated-token
    // fallback is needed. (Known limit, accepted: the REVERSE spacing query
    // 'rxbar' vs a row literally spelled "RX Bar" would not match; brands
    // write the solid form, so this has not been observed in the corpus.)
    const rxbar = row({
      barcode: '00857777004003',
      product_name: 'RXBAR Protein Bar',
      brand_name: 'RXBAR',
      source: 'usda_fdc',
    });
    assert(passesThreshold(rxbar, tokenize('rx bar')));
    // Both tokens hit brand (2x each) and name (1x each) = 2*2 + 2 = 6.
    assertEquals(scoreResult(rxbar, tokenize('rx bar')), 6);
  });

  it('"breast chicken" matches "Chicken Breast" — token matching is order-independent', () => {
    const chicken = row({
      barcode: '1',
      product_name: 'Chicken Breast',
      brand_name: null,
      source: 'usda_fdc',
    });
    assert(passesThreshold(chicken, tokenize('breast chicken')));
  });

  it('"pringles original" matches "Pringles Crisps Original 5.2oz" (was 0)', () => {
    assert(passesThreshold(pringles, tokenize('pringles original')));
  });

  it('single-token query is not filtered out (ceil(1/2)=1 — behaviour unchanged)', () => {
    assert(passesThreshold(pringles, tokenize('pringles')));
  });

  it('single token still requires a match — no loosening for one-word queries', () => {
    assert(!passesThreshold(pringles, tokenize('banana')));
  });

  it('does NOT require every token — half is enough', () => {
    // 'nuun electrolyte tablets' vs a name with no "electrolyte" in it: a
    // tokenized-AND rule returns nothing here, which is why we use half.
    const nuun = row({
      barcode: '1',
      product_name: 'Nuun Zero Sugar Hydration (Tablets)',
      brand_name: 'Nuun',
      source: 'open_food_facts',
    });
    assert(passesThreshold(nuun, tokenize('nuun electrolyte tablets')));
  });

  it('rejects a row sharing no tokens', () => {
    assert(!passesThreshold(pringles, tokenize('banana bread')));
  });
});

describe('scoring — brand weighted 2x', () => {
  it('brand match outranks an incidental name match', () => {
    const toks = tokenize('pringles');
    const real = row({
      barcode: '1',
      product_name: 'Pringles Crisps Original',
      brand_name: 'Pringles',
      source: 'usda_fdc',
    });
    const incidental = row({
      barcode: '2',
      product_name: 'Pringles-style Snack',
      brand_name: 'Generic',
      source: 'usda_fdc',
    });
    assert(scoreResult(real, toks) > scoreResult(incidental, toks));
  });

  it('scores every matching token', () => {
    // brand "Pringles" hits 'pringles' (x2) + name hits both tokens
    assertEquals(
      scoreResult(
        row({
          barcode: '1',
          product_name: 'Pringles Crisps Original 5.2oz',
          brand_name: 'Pringles',
          source: 'usda_fdc',
        }),
        tokenize('pringles original'),
      ),
      4,
    );
  });
});

describe('dedupe — USDA wins ties (CC0 + label-derived; OFF is ODbL + crowd-sourced)', () => {
  it('keeps the USDA row when both sources have the barcode', () => {
    const merged = dedupeByBarcode([
      row({ barcode: '123', product_name: 'X', brand_name: 'B', source: 'open_food_facts' }),
      row({ barcode: '123', product_name: 'X', brand_name: 'B', source: 'usda_fdc' }),
    ]);
    assertEquals(merged.length, 1);
    assertEquals(merged[0].source, 'usda_fdc');
  });

  it('order does not matter', () => {
    const merged = dedupeByBarcode([
      row({ barcode: '123', product_name: 'X', brand_name: 'B', source: 'usda_fdc' }),
      row({ barcode: '123', product_name: 'X', brand_name: 'B', source: 'open_food_facts' }),
    ]);
    assertEquals(merged[0].source, 'usda_fdc');
  });

  it('keeps an OFF row when USDA has no such barcode (complementary corpora)', () => {
    // e.g. 'vitamin water' / 'clif bloks' — OFF has them, USDA does not.
    const merged = dedupeByBarcode([
      row({ barcode: '1', product_name: 'Vitamin Water', brand_name: 'Glaceau', source: 'open_food_facts' }),
      row({ barcode: '2', product_name: 'WALNUTS', brand_name: null, source: 'usda_fdc' }),
    ]);
    assertEquals(merged.length, 2);
  });

  it('drops rows with no barcode (nutrition_products is barcode-keyed)', () => {
    assertEquals(
      dedupeByBarcode([row({ barcode: '', product_name: 'X', brand_name: null, source: 'usda_fdc' })]).length,
      0,
    );
  });
});
