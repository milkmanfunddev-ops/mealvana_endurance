/**
 * Before Phase — Component Explosion
 *
 * Transforms V4 TemplateSelection objects into individual FoodResult items —
 * one per component food — using template_foods lookup data and user food substitutions.
 */

import type {
  AddOn,
  PreWorkoutPhaseResult,
  TemplateSelection,
} from "../generate-macros-v4/types.ts";
import type { FoodResult } from "../_shared/nutrition/types.ts";
import type { SubPhaseResult, SubPhaseTargets } from "../_shared/nutrition/templates/types.ts";
import { getSubPhaseTimingLabel } from "../_shared/nutrition/templates/pre-workout-targets.ts";
import type { TemplateFoodRow } from "./before-phase-db.ts";
import { isLiquidProductType, type UserFoodForSubstitution } from "./before-phase-substitution.ts";

// ============================================================================
// Selection → FoodResult Explosion
// ============================================================================

/**
 * Explode a TemplateSelection into individual FoodResult items — one per
 * component food — using template_foods lookup data.
 *
 * For single-component templates (e.g. "Oatmeal"), produces 1 FoodResult
 * enriched with display_name/plural from template_foods.
 *
 * For multi-component templates (e.g. "Toast + PB + Jam"), produces N
 * FoodResult items, each with its own nutrition proportional to the
 * composite's total servings.
 */
export function selectionToFoodResults(
  selection: TemplateSelection,
  timing: string,
  isDrink: boolean,
  isElectrolyte: boolean,
  templateFoodsMap: Map<string, TemplateFoodRow>,
  substitutions?: Map<string, UserFoodForSubstitution>,
): FoodResult[] {
  const componentNames = selection.component_food_names ?? [];
  const componentQty = selection.component_quantities ?? {};
  const servings = selection.servings;

  // If we have component data AND template_foods lookup, explode
  if (componentNames.length > 0 && templateFoodsMap.size > 0) {
    const results: FoodResult[] = [];

    for (const compName of componentNames) {
      const tf = templateFoodsMap.get(compName);
      if (!tf) {
        console.warn(
          `[PLAN-V3] Component '${compName}' not found in template_foods, skipping`,
        );
        continue;
      }

      const proportion = componentQty[compName] ?? 1;
      const compServings = proportion * servings;

      // Check for user food substitution
      const userSub = substitutions?.get(compName);
      if (userSub) {
        const carbs =
          Math.round(userSub.carbs_per_serving * compServings * 10) / 10;
        const protein =
          Math.round(userSub.protein_per_serving * compServings * 10) / 10;
        const fat = Math.round(userSub.fat_per_serving * compServings * 10) /
          10;
        const sodium = Math.round(userSub.sodium_mg * compServings * 10) / 10;
        const fluid =
          Math.round(userSub.fluid_ml_per_serving * compServings * 10) / 10;
        const calories = Math.round((carbs * 4) + (protein * 4) + (fat * 9));

        results.push({
          food_id: userSub.id,
          quantity: compServings,
          carbs_grams: carbs,
          protein_grams: protein,
          fat_grams: fat,
          sodium_mg: sodium,
          fluids_ml: fluid,
          calories,
          display_name: userSub.display_name ?? userSub.name,
          display_name_plural: userSub.display_name_plural ?? undefined,
          serving_size: userSub.serving_size ?? undefined,
          serving_unit: userSub.serving_unit ?? undefined,
          timing,
          is_drink: isLiquidProductType(userSub.product_type),
          is_electrolyte: userSub.is_electrolyte,
          is_user_food: true,
          product_type: userSub.product_type,
        });
        continue;
      }

      // Scale nutrition by component servings (original template food)
      const carbs = Math.round(tf.carbs_g * compServings * 10) / 10;
      const protein = Math.round(tf.protein_g * compServings * 10) / 10;
      const fat = Math.round(tf.fat_g * compServings * 10) / 10;
      const sodium = Math.round(tf.sodium_mg * compServings * 10) / 10;
      const fluid = Math.round(tf.fluid_ml * compServings * 10) / 10;
      const calories = Math.round((carbs * 4) + (protein * 4) + (fat * 9));

      results.push({
        food_id: compName,
        quantity: compServings,
        carbs_grams: carbs,
        protein_grams: protein,
        fat_grams: fat,
        sodium_mg: sodium,
        fluids_ml: fluid,
        calories,
        display_name: tf.display_name ?? compName,
        display_name_plural: tf.display_name_plural ?? undefined,
        serving_size: tf.serving_size ?? undefined,
        serving_unit: tf.serving_unit ?? undefined,
        serving_qualifier: tf.serving_qualifier ?? undefined,
        timing,
        is_drink: tf.is_liquid ?? isDrink,
        is_electrolyte: tf.is_electrolyte ?? isElectrolyte,
      });
    }

    if (results.length > 0) {
      normalizeExplosionMacros(results, selection);
      return results;
    }
    // Fall through to legacy path if all components failed lookup
  }

  // Legacy / fallback: return single FoodResult for the whole template
  return [{
    food_id: selection.id,
    quantity: selection.servings,
    carbs_grams: selection.carbs_g,
    protein_grams: selection.protein_g,
    fat_grams: selection.fat_g,
    sodium_mg: selection.sodium_mg,
    fluids_ml: selection.fluid_ml,
    calories: Math.round(
      (selection.carbs_g * 4) + (selection.protein_g * 4) +
        (selection.fat_g * 9),
    ),
    display_name: selection.name,
    serving_size: selection.serving_unit,
    timing,
    is_drink: isDrink,
    is_electrolyte: isElectrolyte,
  }];
}

/**
 * Normalize macro sums so exploded components match the template selection contract exactly.
 * Prevents component drift from rounding errors during explosion.
 */
function normalizeExplosionMacros(
  results: FoodResult[],
  selection: TemplateSelection,
): void {
  const rawTotals = results.reduce((acc, row) => ({
    carbs: acc.carbs + row.carbs_grams,
    protein: acc.protein + row.protein_grams,
    fat: acc.fat + row.fat_grams,
    sodium: acc.sodium + row.sodium_mg,
    fluid: acc.fluid + row.fluids_ml,
  }), { carbs: 0, protein: 0, fat: 0, sodium: 0, fluid: 0 });

  const carbScale = rawTotals.carbs > 0 ? selection.carbs_g / rawTotals.carbs : 1;
  const proteinScale = rawTotals.protein > 0 ? selection.protein_g / rawTotals.protein : 1;
  const fatScale = rawTotals.fat > 0 ? selection.fat_g / rawTotals.fat : 1;
  const sodiumScale = rawTotals.sodium > 0 ? selection.sodium_mg / rawTotals.sodium : 1;
  const fluidScale = rawTotals.fluid > 0 ? selection.fluid_ml / rawTotals.fluid : 1;

  for (const row of results) {
    row.carbs_grams = Math.round(row.carbs_grams * carbScale * 10) / 10;
    row.protein_grams = Math.round(row.protein_grams * proteinScale * 10) / 10;
    row.fat_grams = Math.round(row.fat_grams * fatScale * 10) / 10;
    row.sodium_mg = Math.round(row.sodium_mg * sodiumScale * 10) / 10;
    row.fluids_ml = Math.round(row.fluids_ml * fluidScale * 10) / 10;
    row.calories = Math.round(
      (row.carbs_grams * 4) + (row.protein_grams * 4) + (row.fat_grams * 9),
    );
  }

  // Fix residual rounding drift on first component
  const normalizedTotals = results.reduce((acc, row) => ({
    carbs: acc.carbs + row.carbs_grams,
    protein: acc.protein + row.protein_grams,
    fat: acc.fat + row.fat_grams,
    sodium: acc.sodium + row.sodium_mg,
    fluid: acc.fluid + row.fluids_ml,
  }), { carbs: 0, protein: 0, fat: 0, sodium: 0, fluid: 0 });

  const first = results[0];
  if (first) {
    first.carbs_grams = Math.round(
      (first.carbs_grams + (selection.carbs_g - normalizedTotals.carbs)) * 10,
    ) / 10;
    first.protein_grams = Math.round(
      (first.protein_grams + (selection.protein_g - normalizedTotals.protein)) * 10,
    ) / 10;
    first.fat_grams = Math.round(
      (first.fat_grams + (selection.fat_g - normalizedTotals.fat)) * 10,
    ) / 10;
    first.sodium_mg = Math.round(
      (first.sodium_mg + (selection.sodium_mg - normalizedTotals.sodium)) * 10,
    ) / 10;
    first.fluids_ml = Math.round(
      (first.fluids_ml + (selection.fluid_ml - normalizedTotals.fluid)) * 10,
    ) / 10;
    first.calories = Math.round(
      (first.carbs_grams * 4) + (first.protein_grams * 4) + (first.fat_grams * 9),
    );
  }
}

// ============================================================================
// Add-on → FoodResult
// ============================================================================

export function addOnToFoodResult(addOn: AddOn, timing: string): FoodResult {
  const isBanana = addOn.type === "banana";
  const servings = addOn.servings ?? 1;
  return {
    food_id: `addon_${addOn.type}`,
    quantity: servings,
    carbs_grams: addOn.carbs_g,
    protein_grams: 0,
    fat_grams: 0,
    sodium_mg: addOn.sodium_mg,
    fluids_ml: addOn.fluid_ml,
    calories: Math.round(addOn.carbs_g * 4),
    display_name: isBanana ? "Banana" : "Sports Drink",
    display_name_plural: isBanana ? "Bananas" : "cups Sports Drink",
    serving_size: isBanana ? "1 medium" : "1 cup (8 oz)",
    timing,
    is_drink: !isBanana,
  };
}

// ============================================================================
// Phase Result → SubPhaseResult
// ============================================================================

export function phaseResultToSubPhaseResult(
  phaseResult: PreWorkoutPhaseResult,
  phaseTargets: SubPhaseTargets,
  hoursBefore: number,
  templateFoodsMap: Map<string, TemplateFoodRow>,
  substitutions?: Map<string, UserFoodForSubstitution>,
): SubPhaseResult {
  const timing = getSubPhaseTimingLabel(phaseResult.phase, hoursBefore);
  const foods: FoodResult[] = [];

  // Primary food (exploded into components, with user food substitutions)
  if (phaseResult.primary) {
    foods.push(
      ...selectionToFoodResults(
        phaseResult.primary,
        timing,
        false,
        false,
        templateFoodsMap,
        substitutions,
      ),
    );
  }

  // Stacked food (exploded into components, with user food substitutions)
  if (phaseResult.stack) {
    foods.push(
      ...selectionToFoodResults(
        phaseResult.stack,
        timing,
        false,
        false,
        templateFoodsMap,
        substitutions,
      ),
    );
  }

  // Add-ons (banana, sports drink) — not composites, keep as-is
  for (const addOn of phaseResult.add_ons) {
    foods.push(addOnToFoodResult(addOn, timing));
  }

  // Standalone drink (exploded — usually single-component, with substitutions)
  if (phaseResult.drink) {
    foods.push(
      ...selectionToFoodResults(
        phaseResult.drink,
        timing,
        true,
        false,
        templateFoodsMap,
        substitutions,
      ),
    );
  }

  // Electrolyte supplement (exploded — usually single-component, with substitutions)
  if (phaseResult.electrolyte) {
    foods.push(
      ...selectionToFoodResults(
        phaseResult.electrolyte,
        timing,
        false,
        true,
        templateFoodsMap,
        substitutions,
      ),
    );
  }

  return {
    sub_phase_type: phaseResult.phase,
    targets: phaseTargets,
    foods,
    ...(phaseResult.shortfalls && phaseResult.shortfalls.length > 0 && {
      shortfalls: phaseResult.shortfalls,
    }),
    ...(phaseResult.pin_decision && {
      pin_decision: phaseResult.pin_decision,
    }),
  };
}
