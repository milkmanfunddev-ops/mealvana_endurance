/**
 * Ingredient pools for pre-workout Pass 2 (pickDrink) / Pass 3 (pickElectrolyte).
 *
 * Sprint task 3b3e3fdb…7b9c8d (2026-08-06): repoint the drink and electrolyte
 * passes at `template_foods` — the ingredient catalog — instead of the
 * ingredient-shaped rows that used to live in `pre_workout_templates`
 * (Water / Sports Drink / Electrolyte Tablet / Electrolyte Packet /
 * Electrolyte Drink Mix). Those rows violated food-composition v3's H5
 * ("the top-off must deliver carbohydrate") and were held back from deletion
 * only because the two passes read them. With the passes repointed here, the
 * rows are dropped and H5 holds literally: `pre_workout_templates` contains
 * only real formulas.
 *
 * The pickers keep their exact selection semantics: they still operate on the
 * `PreWorkoutTemplate` shape, so `template_foods` rows are adapted via
 * `ingredientRowToTemplate`. Scoring, headroom caps, dislike/diet/allergen
 * filtering (component name + display name + base_category matching in
 * `getEligibleTemplates`) all behave as before.
 *
 * ELECTROLYTES — deliberately EMPTY (Lee ruling 2026-08-06 + sodium SSOT v3):
 * "The BEFORE algorithm should consider fluids but not electrolytes."
 * `pre-workout-sodium.md` v3 sets NO pre-workout sodium target ("null, not
 * 0"), and its food-selector contract says the per-tier engine action is
 * `none` — chasing the retired legacy sodium band with electrolyte add-ins
 * quantified exactly what the spec refuses to quantify. `pickElectrolyte`
 * itself stays exported and tested (it still serves fixtures/legacy paths and
 * may be reused by phases where sodium delivery IS spec'd), but the BEFORE
 * production pool is empty, so Pass 3 is inert.
 */

import { createServiceClient } from '../_shared/supabase-client.ts';
import type { PreWorkoutTemplate, TemplateType } from './types.ts';

/** The `template_foods` columns the drink/electrolyte pools read. */
export interface IngredientPoolRow {
  id: string;
  name: string;
  display_name: string | null;
  serving_size: string | null;
  serving_unit: string | null;
  carbs_g: number | null;
  protein_g: number | null;
  fat_g: number | null;
  sodium_mg: number | null;
  fluid_ml: number | null;
  allergens: string[] | null;
  excluded_diets: string[] | null;
  is_indivisible: boolean | null;
  max_servings_before: number | null;
  is_drink_pool: boolean | null;
  drink_pool_phases: string[] | null;
  is_electrolyte: boolean | null;
}

export const INGREDIENT_POOL_COLUMNS =
  'id, name, display_name, serving_size, serving_unit, carbs_g, protein_g, ' +
  'fat_g, sodium_mg, fluid_ml, allergens, excluded_diets, is_indivisible, ' +
  'max_servings_before, is_drink_pool, drink_pool_phases, is_electrolyte';

/**
 * Adapt a `template_foods` row to the `PreWorkoutTemplate` shape the pickers
 * consume. The row is pinned to the top-up sub-phase — Pass 2 and Pass 3 only
 * ever select for `top_up` — via BOTH `sub_phase` (category-first) and the
 * `'< 30 min'` window (pre-migration fallback), so `templatePhase` routes it
 * correctly on every catalog generation.
 *
 * Serving semantics: divisible ingredients (is_indivisible === false) start
 * at 0.5 servings and step by 0.5 (matching the retired Water / Sports Drink
 * rows); indivisible ones (tablets, capsules) start at 1 and step whole.
 * `max_servings_before` is the ingredient's before-phase cap — rows with a
 * cap of 0 are not offered in BEFORE at all and must be filtered out by the
 * loaders.
 */
export function ingredientRowToTemplate(
  row: IngredientPoolRow,
  templateType: Exclude<TemplateType, 'food'>,
): PreWorkoutTemplate {
  const indivisible = row.is_indivisible ?? true;
  return {
    id: row.id,
    name: row.display_name ?? row.name,
    base_category: templateType === 'drink' ? 'Hydration' : 'Electrolyte',
    time_window: '< 30 min',
    sub_phase: 'top_up',
    digestion_speed: 'Fast',
    allergens: row.allergens ?? [],
    excluded_diets: row.excluded_diets ?? [],
    serving_unit: row.serving_size ?? row.serving_unit ?? 'serving',
    min_servings: indivisible ? 1 : 0.5,
    max_servings: row.max_servings_before ?? 0,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: row.carbs_g ?? 0,
    protein_per_serving: row.protein_g ?? 0,
    fat_per_serving: row.fat_g ?? 0,
    sodium_mg: row.sodium_mg ?? 0,
    fluid_ml: row.fluid_ml ?? 0,
    template_type: templateType,
    is_active: true,
    // The ingredient IS its own single component, so dislike filtering keeps
    // matching on the machine name ('water', 'sports_drink', …) exactly as it
    // did against the retired pre_workout_templates rows.
    component_food_names: [row.name],
    component_quantities: { [row.name]: 1 },
    is_indivisible: indivisible,
  };
}

/**
 * BEFORE-phase drink pool: `template_foods` rows flagged `is_drink_pool`
 * whose `drink_pool_phases` includes `top_up` (Pass 2 only attaches drinks to
 * the top-up slot) and whose before-phase serving cap is positive.
 */
export async function loadPreWorkoutDrinkPool(
  // deno-lint-ignore no-explicit-any
  clientOverride?: any,
): Promise<PreWorkoutTemplate[]> {
  const supabase = clientOverride ?? createServiceClient();
  const { data, error } = await supabase
    .from('template_foods')
    .select(INGREDIENT_POOL_COLUMNS)
    .eq('is_active', true)
    .eq('is_drink_pool', true);

  if (error) {
    throw new Error(`Failed to load drink pool: ${error.message}`);
  }

  return ((data ?? []) as IngredientPoolRow[])
    .filter((row) =>
      (row.drink_pool_phases ?? []).includes('top_up') &&
      (row.max_servings_before ?? 0) > 0
    )
    .map((row) => ingredientRowToTemplate(row, 'drink'));
}

/**
 * BEFORE-phase electrolyte pool — EMPTY by ruling (see module doc). Kept as a
 * function (not an inlined `[]`) so the ruling has one named, documented home
 * and so reinstating a data-driven pool later is a one-body change.
 */
export function loadPreWorkoutElectrolytePool(): Promise<PreWorkoutTemplate[]> {
  return Promise.resolve([]);
}
