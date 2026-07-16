/**
 * GTIN normalisation. Extracted from lookup-product/index.ts (2026-07-16).
 *
 * USDA stores GTINs inconsistently (some 12-digit, some 14-digit zero-padded),
 * so every comparison must happen in canonical GTIN-14 form. Left-pad, don't
 * strip: stripping zeros produced an all-zeros -> empty-string false match.
 */

/** Canonical GTIN-14 form (digits only, left-padded to 14) for consistent keys. */
export function toGtin14(s: string): string {
  return s.replace(/\D/g, '').padStart(14, '0').slice(-14);
}
