/**
 * Before Phase V3 — Algorithm C Transformation Layer
 *
 * Calls V4's Algorithm C (selectPreWorkoutFoods) for food selection,
 * then transforms the output into V2's BeforePhaseResult shape so that
 * during/after phases and the Dart client remain unchanged.
 *
 * V4 output: PreWorkoutPhaseResult[] (primary/stack/drink/electrolyte/add_ons)
 * V2 output: BeforePhaseResult { meal?, snack?, top_up? } with SubPhaseResult { foods: FoodResult[] }
 */

import { createServiceClient } from '../_shared/supabase-client.ts';

import {
  type PreWorkoutTemplate,
  type PreWorkoutPhaseResult,
  type TemplateSelection,
  type AddOn,
  type SubPhaseType,
} from '../generate-macros-v4/types.ts';

import {
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
  getActiveSubPhases,
  splitTargets,
} from '../generate-macros-v4/pre-workout.ts';

import {
  type FoodResult,
} from '../_shared/nutrition/types.ts';

import {
  type BeforePhaseResult,
  type SubPhaseResult,
  type SubPhaseTargets,
} from '../_shared/nutrition/templates/types.ts';

import {
  getSubPhaseTimingLabel,
} from '../_shared/nutrition/templates/pre-workout-targets.ts';

// ============================================================================
// Database Queries
// ============================================================================

async function fetchPreWorkoutTemplates(
  supabase: ReturnType<typeof createServiceClient>,
  templateType: string,
): Promise<PreWorkoutTemplate[]> {
  const { data, error } = await supabase
    .from('pre_workout_templates')
    .select('*')
    .eq('is_active', true)
    .eq('template_type', templateType);

  if (error) throw new Error(`Failed to fetch pre_workout_templates (${templateType}): ${error.message}`);

  return (data ?? []).map((row: Record<string, unknown>) => ({
    ...row,
    allergens: row.allergens ?? [],
  })) as PreWorkoutTemplate[];
}

// ============================================================================
// Template Foods Lookup (for component explosion)
// ============================================================================

interface TemplateFoodRow {
  name: string;
  display_name: string | null;
  display_name_plural: string | null;
  serving_size: string | null;
  serving_unit: string | null;
  serving_amount: number | null;
  serving_qualifier: string | null;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  is_liquid: boolean;
  is_electrolyte: boolean;
}

/** Fetches template_foods rows for the given food names (keyed by name). */
async function fetchTemplateFoodsByName(
  supabase: ReturnType<typeof createServiceClient>,
  names: string[],
): Promise<Map<string, TemplateFoodRow>> {
  if (names.length === 0) return new Map();

  const { data, error } = await supabase
    .from('template_foods')
    .select('name, display_name, display_name_plural, serving_size, serving_unit, serving_amount, serving_qualifier, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml, is_liquid, is_electrolyte')
    .in('name', names)
    .eq('is_active', true);

  if (error) {
    console.warn(`[PLAN-V3] Failed to fetch template_foods: ${error.message}`);
    return new Map();
  }

  const map = new Map<string, TemplateFoodRow>();
  for (const row of (data ?? [])) {
    map.set(row.name as string, row as TemplateFoodRow);
  }
  return map;
}

// ============================================================================
// V4 → V2 Transformation
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
function selectionToFoodResults(
  selection: TemplateSelection,
  timing: string,
  isDrink: boolean,
  isElectrolyte: boolean,
  templateFoodsMap: Map<string, TemplateFoodRow>,
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
        console.warn(`[PLAN-V3] Component '${compName}' not found in template_foods, skipping`);
        continue;
      }

      // Per-serving proportion of this component within 1 serving of the template
      const proportion = componentQty[compName] ?? 1;
      // Total servings of this component = proportion * template servings
      const compServings = proportion * servings;

      // Scale nutrition by component servings
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

    if (results.length > 0) return results;
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
    calories: Math.round((selection.carbs_g * 4) + (selection.protein_g * 4) + (selection.fat_g * 9)),
    display_name: selection.name,
    serving_size: selection.serving_unit,
    timing,
    is_drink: isDrink,
    is_electrolyte: isElectrolyte,
  }];
}

function addOnToFoodResult(addOn: AddOn, timing: string): FoodResult {
  const isBanana = addOn.type === 'banana';
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
    display_name: isBanana ? 'Banana' : 'Sports Drink',
    display_name_plural: isBanana ? 'Bananas' : 'cups Sports Drink',
    serving_size: isBanana ? '1 medium' : '1 cup (8 oz)',
    timing,
    is_drink: !isBanana,
  };
}

function phaseResultToSubPhaseResult(
  phaseResult: PreWorkoutPhaseResult,
  phaseTargets: SubPhaseTargets,
  hoursBefore: number,
  templateFoodsMap: Map<string, TemplateFoodRow>,
): SubPhaseResult {
  const timing = getSubPhaseTimingLabel(phaseResult.phase, hoursBefore);
  const foods: FoodResult[] = [];

  // Primary food (exploded into components)
  if (phaseResult.primary) {
    foods.push(...selectionToFoodResults(phaseResult.primary, timing, false, false, templateFoodsMap));
  }

  // Stacked food (exploded into components)
  if (phaseResult.stack) {
    foods.push(...selectionToFoodResults(phaseResult.stack, timing, false, false, templateFoodsMap));
  }

  // Add-ons (banana, sports drink) — not composites, keep as-is
  for (const addOn of phaseResult.add_ons) {
    foods.push(addOnToFoodResult(addOn, timing));
  }

  // Standalone drink (exploded — usually single-component)
  if (phaseResult.drink) {
    foods.push(...selectionToFoodResults(phaseResult.drink, timing, true, false, templateFoodsMap));
  }

  // Electrolyte supplement (exploded — usually single-component)
  if (phaseResult.electrolyte) {
    foods.push(...selectionToFoodResults(phaseResult.electrolyte, timing, false, true, templateFoodsMap));
  }

  return {
    sub_phase_type: phaseResult.phase,
    targets: phaseTargets,
    foods,
  };
}

// ============================================================================
// Main Entry Point
// ============================================================================

interface BeforePhaseInput {
  hours_before: number;
  weight_kg: number;
  macro_targets: {
    pre_run: {
      carbs_g: number;
      protein_g?: number;
      fat_g?: number;
      sodium_mg: number;
      water_ml: number;
    };
  };
  dietary_preference?: string;
}

export async function generateBeforePhaseV3(
  supabase: ReturnType<typeof createServiceClient>,
  input: BeforePhaseInput,
): Promise<BeforePhaseResult> {
  console.log(`[PLAN-V3] Generating before phase with Algorithm C (hours_before=${input.hours_before})`);

  // 0. Handle fasted state
  const preTargets = input.macro_targets.pre_run;
  if ((preTargets.carbs_g ?? 0) <= 0 && (preTargets.water_ml ?? 0) <= 0) {
    console.log('[PLAN-V3] Fasted state detected, skipping before phase');
    return {};
  }

  // 1. Fetch pre_workout_templates (3 types in parallel)
  const [foodTemplates, drinkTemplates, electrolyteTemplates] = await Promise.all([
    fetchPreWorkoutTemplates(supabase, 'food'),
    fetchPreWorkoutTemplates(supabase, 'drink'),
    fetchPreWorkoutTemplates(supabase, 'electrolyte'),
  ]);

  console.log(`[PLAN-V3] Fetched templates: ${foodTemplates.length} food, ${drinkTemplates.length} drink, ${electrolyteTemplates.length} electrolyte`);

  // 2. Calculate targets using Algorithm C
  const isFasted = (preTargets.carbs_g ?? 0) <= 0 && (preTargets.water_ml ?? 0) <= 0;
  const targets = calculatePreWorkoutTargets(
    input.weight_kg,
    input.hours_before,
    isFasted,
    'medium',   // V3 doesn't carry sweat data — safe default
    'moderate',  // V3 doesn't carry env data — safe default
  );

  console.log(`[PLAN-V3] Algorithm C targets: carbs=${targets.carbs_g}g, protein=${targets.protein_g}g, sodium=${targets.sodium_mg}mg, water=${targets.water_ml}ml, type=${targets.meal_type}`);

  // 3. Run Algorithm C food selection
  const diet = input.dietary_preference ?? 'none';
  const phaseResults = selectPreWorkoutFoods(
    targets,
    input.hours_before,
    diet,
    foodTemplates,
    drinkTemplates,
    electrolyteTemplates,
  );

  if (phaseResults.length === 0) {
    console.log('[PLAN-V3] Algorithm C returned no phases (fasted)');
    return {};
  }

  // 4. Collect all unique component food names from selected templates
  //    so we can batch-fetch template_foods for the explosion
  const allComponentNames = new Set<string>();
  for (const pr of phaseResults) {
    for (const sel of [pr.primary, pr.stack, pr.drink, pr.electrolyte]) {
      if (sel?.component_food_names) {
        for (const name of sel.component_food_names) allComponentNames.add(name);
      }
    }
  }

  // 5. Fetch template_foods for components
  const templateFoodsMap = await fetchTemplateFoodsByName(
    supabase,
    Array.from(allComponentNames),
  );
  console.log(`[PLAN-V3] Fetched ${templateFoodsMap.size} template_foods for ${allComponentNames.size} component names`);

  // 6. Get phase targets for the SubPhaseResult shape
  const phaseTargetsMap = splitTargets(targets, input.hours_before);

  // 7. Transform V4 → V2 (exploding composites into individual FoodResults)
  const beforeResult: BeforePhaseResult = {};

  for (const phaseResult of phaseResults) {
    const phaseTargets = phaseTargetsMap.get(phaseResult.phase) ?? {
      carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0,
    };

    const subPhaseResult = phaseResultToSubPhaseResult(
      phaseResult,
      phaseTargets,
      input.hours_before,
      templateFoodsMap,
    );

    console.log(`[PLAN-V3] ${phaseResult.phase}: ${subPhaseResult.foods.length} foods (exploded), carbs=${phaseResult.total_carbs_g}g`);

    if (phaseResult.phase === 'meal') beforeResult.meal = subPhaseResult;
    else if (phaseResult.phase === 'snack') beforeResult.snack = subPhaseResult;
    else if (phaseResult.phase === 'top_up') beforeResult.top_up = subPhaseResult;
  }

  return beforeResult;
}
