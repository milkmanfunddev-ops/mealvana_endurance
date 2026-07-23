/**
 * Pure search-matching rules shared by the food-search surfaces.
 *
 * Extracted from search-nutrition-products/index.ts so the logic is unit-
 * testable without executing Deno.serve() (importing an edge function's
 * index.ts starts the server). The same rules are implemented in SQL by
 * `search_catalog_ranked` (migration 20260716120000) and in Dart by
 * lib/shared/utils/search_token_matcher.dart — all three MUST stay in
 * agreement, and the tests in search-nutrition-products/index.test.ts and
 * search-catalog/index.test.ts pin that contract.
 *
 * MATCHING SEMANTICS (measured against prod, 2026-07-15/16 audit — see
 * docs/architecture/food-search-scan-audit-2026-07-16.md §9c):
 *
 *  * Tokenize on every non-alphanumeric run — whitespace AND hyphens/commas/
 *    punctuation are all separators. This is what lets 'coca cola' reach
 *    USDA's comma-inverted "COCA-COLA, COLA": both the query and (via
 *    substring ILIKE against the raw column) the target are compared
 *    punctuation-insensitively.
 *
 *  * Each token matches by SUBSTRING (ilike %token%), not word boundary.
 *    That is deliberately why 'rx bar' reaches 'RXBAR': the spacing
 *    difference needs no concatenated-token fallback because 'rx' and 'bar'
 *    are both substrings of 'rxbar'. (The reverse — query 'rxbar' vs a row
 *    literally spelled "RX Bar" — is NOT covered by substring matching; in
 *    practice brands write the solid form, so this has never been observed.)
 *
 *  * Substring-AND is order-independent, so 'breast chicken' matches
 *    "Chicken Breast".
 *
 *  * The threshold is "at least half the tokens", NOT all: requiring every
 *    token returns 0 for 'nuun electrolyte tablets' (no product name
 *    contains the word "electrolyte"). Single-token queries are unaffected
 *    (ceil(1/2) = 1 — the token must match, exactly as before).
 *
 *  * Ranking: 2x brand-token hits + 1x name-token hits.
 */

import type { NutritionProductLike } from './usda_search.ts';

/**
 * Tokenize a query. Mirrors search_catalog_ranked's SQL tokenizer and the Dart
 * `tokenizeSearchQuery`, so client and both edge functions agree.
 */
export function tokenize(q: string): string[] {
  return q
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim()
    .split(' ')
    .filter((t) => t.length > 0);
}

/**
 * Relevance score: 2x brand-token hits + 1x name-token hits.
 * Same rule as search_catalog_ranked — see that migration for why.
 */
export function scoreResult(r: NutritionProductLike, tokens: string[]): number {
  const brand = (r.brand_name ?? '').toLowerCase();
  const name = (r.product_name ?? '').toLowerCase();
  const hits = (hay: string) => tokens.filter((t) => hay.includes(t)).length;
  return 2 * hits(brand) + hits(name);
}

/** At least half the tokens must appear in brand||name. */
export function passesThreshold(r: NutritionProductLike, tokens: string[]): boolean {
  if (tokens.length === 0) return true;
  const hay = `${r.brand_name ?? ''} ${r.product_name ?? ''}`.toLowerCase();
  const matched = tokens.filter((t) => hay.includes(t)).length;
  return matched > 0 && matched >= Math.ceil(tokens.length / 2);
}

/**
 * Merge sources, preferring the higher-quality row per barcode.
 *
 * USDA wins ties: its data is CC0 (resale-safe) and lab/label-derived, whereas
 * OFF is crowd-sourced and ODbL. The barcode path makes the same call.
 */
export function dedupeByBarcode(rows: NutritionProductLike[]): NutritionProductLike[] {
  const byCode = new Map<string, NutritionProductLike>();
  for (const r of rows) {
    if (!r.barcode) continue;
    const existing = byCode.get(r.barcode);
    if (!existing) {
      byCode.set(r.barcode, r);
      continue;
    }
    const rank = (x: NutritionProductLike) =>
      x.source === 'usda_fdc' || x.source === 'usda_bulk' ? 2 : 1;
    if (rank(r) > rank(existing)) byCode.set(r.barcode, r);
  }
  return [...byCode.values()];
}
