/**
 * search-nutrition-products — ranking / merge contract.
 *
 * The pure rules are mirrored here rather than imported, because importing
 * index.ts would execute Deno.serve(). Every expectation below was measured
 * against the live APIs on 2026-07-16 — see
 * docs/architecture/food-search-scan-audit-2026-07-16.md §9c.
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

// ── mirrors of the pure logic in index.ts ────────────────────────────────────

interface Row {
  barcode: string;
  product_name: string;
  brand_name: string | null;
  source: string;
  confidence_score?: number;
}

function tokenize(q: string): string[] {
  return q.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim().split(' ').filter((t) => t.length > 0);
}

function scoreResult(r: Row, tokens: string[]): number {
  const brand = (r.brand_name ?? '').toLowerCase();
  const name = (r.product_name ?? '').toLowerCase();
  const hits = (hay: string) => tokens.filter((t) => hay.includes(t)).length;
  return 2 * hits(brand) + hits(name);
}

function passesThreshold(r: Row, tokens: string[]): boolean {
  if (tokens.length === 0) return true;
  const hay = `${r.brand_name ?? ''} ${r.product_name ?? ''}`.toLowerCase();
  const matched = tokens.filter((t) => hay.includes(t)).length;
  return matched > 0 && matched >= Math.ceil(tokens.length / 2);
}

function dedupeByBarcode(rows: Row[]): Row[] {
  const byCode = new Map<string, Row>();
  for (const r of rows) {
    if (!r.barcode) continue;
    const existing = byCode.get(r.barcode);
    if (!existing) { byCode.set(r.barcode, r); continue; }
    const rank = (x: Row) => (x.source === 'usda_fdc' || x.source === 'usda_bulk' ? 2 : 1);
    if (rank(r) > rank(existing)) byCode.set(r.barcode, r);
  }
  return [...byCode.values()];
}

// ── tests ───────────────────────────────────────────────────────────────────

describe('tokenization — must match the SQL + Dart tokenizers', () => {
  it('splits on whitespace', () => {
    assertEquals(tokenize('pringles original'), ['pringles', 'original']);
  });

  it('strips punctuation so "coca cola" can reach USDA\'s "COCA-COLA, COLA"', () => {
    // The real prod row is literally named "COCA-COLA, COLA". A whole-phrase
    // ilike returned 0 for 'coca cola'; tokenizing is what fixes it.
    assertEquals(tokenize('coca-cola'), ['coca', 'cola']);
  });

  it('collapses repeated separators', () => {
    assertEquals(tokenize('  clif   bar '), ['clif', 'bar']);
  });
});

describe('threshold — regression for the real prod misses', () => {
  const cocaCola: Row = {
    barcode: '00000004963406',
    product_name: 'COCA-COLA, COLA',
    brand_name: 'COCA-COLA',
    source: 'usda_fdc',
  };
  const pringles: Row = {
    barcode: '00038000138416',
    product_name: 'Pringles Crisps Original 5.2oz',
    brand_name: 'Pringles',
    source: 'usda_fdc',
  };

  it('"coca cola" matches "COCA-COLA, COLA" (whole-phrase ilike returned 0)', () => {
    assert(passesThreshold(cocaCola, tokenize('coca cola')));
  });

  it('"pringles original" matches "Pringles Crisps Original 5.2oz" (was 0)', () => {
    assert(passesThreshold(pringles, tokenize('pringles original')));
  });

  it('single-token query is not filtered out', () => {
    assert(passesThreshold(pringles, tokenize('pringles')));
  });

  it('does NOT require every token — half is enough', () => {
    // 'nuun electrolyte tablets' vs a name with no "electrolyte" in it: a
    // tokenized-AND rule returns nothing here, which is why we use half.
    const nuun: Row = {
      barcode: '1', product_name: 'Nuun Zero Sugar Hydration (Tablets)',
      brand_name: 'Nuun', source: 'open_food_facts',
    };
    assert(passesThreshold(nuun, tokenize('nuun electrolyte tablets')));
  });

  it('rejects a row sharing no tokens', () => {
    assert(!passesThreshold(pringles, tokenize('banana bread')));
  });
});

describe('scoring — brand weighted 2x', () => {
  it('brand match outranks an incidental name match', () => {
    const toks = tokenize('pringles');
    const real: Row = {
      barcode: '1', product_name: 'Pringles Crisps Original',
      brand_name: 'Pringles', source: 'usda_fdc',
    };
    const incidental: Row = {
      barcode: '2', product_name: 'Pringles-style Snack',
      brand_name: 'Generic', source: 'usda_fdc',
    };
    assert(scoreResult(real, toks) > scoreResult(incidental, toks));
  });

  it('scores every matching token', () => {
    // brand "Pringles" hits 'pringles' (x2) + name hits both tokens
    assertEquals(
      scoreResult(
        { barcode: '1', product_name: 'Pringles Crisps Original 5.2oz', brand_name: 'Pringles', source: 'usda_fdc' },
        tokenize('pringles original'),
      ),
      4,
    );
  });
});

describe('dedupe — USDA wins ties (CC0 + label-derived; OFF is ODbL + crowd-sourced)', () => {
  it('keeps the USDA row when both sources have the barcode', () => {
    const merged = dedupeByBarcode([
      { barcode: '123', product_name: 'X', brand_name: 'B', source: 'open_food_facts' },
      { barcode: '123', product_name: 'X', brand_name: 'B', source: 'usda_fdc' },
    ]);
    assertEquals(merged.length, 1);
    assertEquals(merged[0].source, 'usda_fdc');
  });

  it('order does not matter', () => {
    const merged = dedupeByBarcode([
      { barcode: '123', product_name: 'X', brand_name: 'B', source: 'usda_fdc' },
      { barcode: '123', product_name: 'X', brand_name: 'B', source: 'open_food_facts' },
    ]);
    assertEquals(merged[0].source, 'usda_fdc');
  });

  it('keeps an OFF row when USDA has no such barcode (complementary corpora)', () => {
    // e.g. 'vitamin water' / 'clif bloks' — OFF has them, USDA does not.
    const merged = dedupeByBarcode([
      { barcode: '1', product_name: 'Vitamin Water', brand_name: 'Glaceau', source: 'open_food_facts' },
      { barcode: '2', product_name: 'WALNUTS', brand_name: null, source: 'usda_fdc' },
    ]);
    assertEquals(merged.length, 2);
  });

  it('drops rows with no barcode (nutrition_products is barcode-keyed)', () => {
    assertEquals(
      dedupeByBarcode([{ barcode: '', product_name: 'X', brand_name: null, source: 'usda_fdc' }]).length,
      0,
    );
  });
});
