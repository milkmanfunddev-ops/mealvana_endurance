/**
 * Pre-workout Algorithm C Constants
 *
 * Extracted from pre-workout.ts for maintainability.
 * Contains thresholds, mappings, and utility functions for food selection.
 */

// ============================================================================
// Algorithm Tuning Constants
// ============================================================================

export const ADDON_GAP_THRESHOLD = 10;  // Only add banana/drink if gap > 10g
export const STACK_THRESHOLD = 0.20;    // Stack second formula if >20% short AND >20g gap
export const DIVERSITY_BAND = 0.15;     // Pick among formulas within 15% of best carb gap
export const DIVERSITY_FLOOR = 8;       // Minimum absolute carb gap for diversity band
export const RANDOM_PICK_MARGIN = 0.08; // Keep slight variety among near-equal safe candidates
export const RANDOM_PICK_LIMIT = 3;     // Avoid broad randomness that can drift output

// ============================================================================
// Cross-Phase Food Exemptions
// ============================================================================

/**
 * Foods that may appear across multiple sub-phases without feeling repetitive
 * (e.g., water and sports drinks are expected to appear in multiple phases)
 */
export const CROSS_PHASE_EXEMPT_FOODS = new Set([
  'water', 'sports_drink', 'sports_drink_mix',
  'electrolyte_tablet', 'electrolyte_drink_mix',
]);

// ============================================================================
// Allergen Normalization
// ============================================================================

/**
 * Maps common allergen name variations to canonical forms.
 * Used for consistent allergen filtering across user input and template data.
 */
export const ALLERGEN_ALIASES: Record<string, string> = {
  peanut: 'peanut',
  peanuts: 'peanut',
  tree_nut: 'tree_nuts',
  tree_nuts: 'tree_nuts',
  tree_nuts_allergy: 'tree_nuts',
  dairy: 'dairy',
  milk: 'dairy',
  eggs: 'eggs',
  egg: 'eggs',
  gluten: 'gluten',
  soy: 'soy',
};

/**
 * Hints for inferring allergens from component food names when
 * template allergen data is incomplete.
 */
export const COMPONENT_ALLERGEN_HINTS: Record<string, string[]> = {
  oatmeal: ['gluten'],
  toast: ['gluten'],
  bagel: ['gluten'],
  cereal: ['gluten'],
  granola: ['gluten'],
  granola_bar: ['gluten'],
  pancake: ['gluten', 'eggs', 'dairy'],
  toaster_waffle: ['gluten', 'eggs', 'dairy'],
  graham_crackers: ['gluten'],
  fig_bar: ['gluten'],
  stroopwafel: ['gluten', 'dairy'],
  pretzels: ['gluten'],
  milk: ['dairy'],
  yogurt: ['dairy'],
  cream_cheese: ['dairy'],
  cheese_slice: ['dairy'],
  butter: ['dairy'],
  protein_shake: ['dairy'],
  protein_powder: ['dairy'],
  peanut_butter: ['peanut'],
  almond_butter: ['tree_nuts'],
  trail_mix: ['tree_nuts', 'peanut'],
  egg: ['eggs'],
  soy_sauce: ['soy', 'gluten'],
  teriyaki_sauce: ['soy', 'gluten'],
};

// ============================================================================
// Token Normalization Utilities
// ============================================================================

/**
 * Normalize a food/allergen name token to snake_case lowercase for consistent matching.
 * Handles various separators and special characters.
 *
 * Strips parenthetical qualifiers (e.g. "Oatmeal (½ cup dry)" → "oatmeal") and
 * trailing brand variant suffixes after a comma (e.g. "Gatorade, Orange" → "gatorade")
 * so that user-facing display strings match canonical snake_case tokens stored
 * on templates.
 */
export function normalizeToken(value: string): string {
  return value
    .toLowerCase()
    .replace(/\([^)]*\)/g, '') // strip parenthetical qualifiers: "(½ cup dry)"
    .replace(/,.*$/, '')        // strip trailing brand variants: ", Orange"
    .trim()
    .replace(/[+]/g, ' ')
    .replace(/[-/]/g, ' ')
    .replace(/\s+/g, '_');
}
