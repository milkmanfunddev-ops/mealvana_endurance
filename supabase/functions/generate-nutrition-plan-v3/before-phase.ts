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
  product_type: string | null;
}

/** Fetches template_foods rows for the given food names (keyed by name). */
async function fetchTemplateFoodsByName(
  supabase: ReturnType<typeof createServiceClient>,
  names: string[],
): Promise<Map<string, TemplateFoodRow>> {
  if (names.length === 0) return new Map();

  const { data, error } = await supabase
    .from('template_foods')
    .select('name, display_name, display_name_plural, serving_size, serving_unit, serving_amount, serving_qualifier, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml, is_liquid, is_electrolyte, product_type')
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
// User Food Substitution for Before Phase
// ============================================================================

interface UserFoodForSubstitution {
  id: string;
  name: string;
  display_name: string | null;
  display_name_plural: string | null;
  carbs_per_serving: number;
  protein_per_serving: number;
  fat_per_serving: number;
  sodium_mg: number;
  fluid_ml_per_serving: number;
  calories_per_serving: number;
  serving_size: string | null;
  serving_unit: string | null;
  serving_amount: number | null;
  product_type: string;
  is_electrolyte: boolean;
}

/**
 * Product type matching: maps user food product_type → template component
 * product_types it can substitute for.
 */
const USER_TO_TEMPLATE_TYPE_MAP: Record<string, string[]> = {
  gel: ['energy_gel', 'gel'],
  chew: ['energy_chews', 'chew'],
  bar: ['granola_bar', 'bar', 'energy_bar', 'cereal_bar'],
  waffle: ['granola_bar', 'waffle', 'bar'], // similar solid snack
  sports_drink: ['sports_drink', 'sports_drink_mix', 'coconut_water'],
  drink_mix: ['sports_drink_mix', 'electrolyte_drink_mix', 'sports_drink'],
  electrolyte_only: ['electrolyte_tablet', 'electrolyte_drink_mix'],
  real_food: ['toast', 'bagel', 'oatmeal', 'cereal', 'rice_cake', 'yogurt',
              'banana', 'real_food', 'real_food_carbs'],
  real_food_carbs: ['toast', 'bagel', 'oatmeal', 'cereal', 'rice_cake', 'real_food_carbs'],
  solid_carb_snacks: ['granola_bar', 'bar', 'rice_cake'],
  recovery_shake: ['smoothie', 'recovery_shake', 'yogurt'],
};

/** Infer is_liquid from product_type */
function isLiquidProductType(productType: string): boolean {
  return ['sports_drink', 'drink_mix', 'recovery_shake',
          'electrolytes_fluids', 'hydration_with_carbs'].includes(productType);
}

/** Fetch user foods suitable for before phase substitution. */
async function fetchUserFoodsForBefore(
  supabase: ReturnType<typeof createServiceClient>,
  deviceId: string,
): Promise<UserFoodForSubstitution[]> {
  // Look up user_id from device_id
  const { data: userData } = await supabase
    .from('users')
    .select('id')
    .eq('device_id', deviceId)
    .single();

  const userId = userData?.id;
  if (!userId) {
    console.log('[PLAN-V3-SUBST] No user found for device_id, skipping substitution');
    return [];
  }

  // Fetch user foods that are:
  // - not deleted
  // - explicitly typed (product_type is not 'import' and not null)
  // - not excluded from solver
  // - suitable for before phase (categories contains 'before_run' OR empty/null)
  const { data: userFoods, error } = await supabase
    .from('user_foods')
    .select(`
      id, name, display_name, display_name_plural,
      carbs_per_serving, protein_per_serving, fat_per_serving,
      sodium_mg, fluid_ml_per_serving, calories_per_serving,
      serving_size, serving_unit, serving_amount,
      product_type, is_electrolyte, categories
    `)
    .eq('user_id', userId)
    .eq('is_deleted', false)
    .eq('to_exclude_from_solver', false)
    .not('product_type', 'is', null)
    .neq('product_type', 'import');

  if (error) {
    console.warn(`[PLAN-V3-SUBST] Failed to fetch user foods: ${error.message}`);
    return [];
  }

  // Filter: must be suitable for before phase
  const beforeFoods = (userFoods ?? []).filter((f: Record<string, unknown>) => {
    const categories = f.categories as string[] | null;
    // Empty/null categories = all phases
    if (!categories || categories.length === 0) return true;
    return categories.includes('before_run');
  });

  console.log(`[PLAN-V3-SUBST] Found ${beforeFoods.length} user foods for before-phase substitution`);

  return beforeFoods.map((f: Record<string, unknown>): UserFoodForSubstitution => ({
    id: f.id as string,
    name: f.name as string,
    display_name: (f.display_name as string) ?? null,
    display_name_plural: (f.display_name_plural as string) ?? null,
    carbs_per_serving: (f.carbs_per_serving as number) ?? 0,
    protein_per_serving: (f.protein_per_serving as number) ?? 0,
    fat_per_serving: (f.fat_per_serving as number) ?? 0,
    sodium_mg: (f.sodium_mg as number) ?? 0,
    fluid_ml_per_serving: (f.fluid_ml_per_serving as number) ?? 0,
    calories_per_serving: (f.calories_per_serving as number) ?? 0,
    serving_size: (f.serving_size as string) ?? null,
    serving_unit: (f.serving_unit as string) ?? null,
    serving_amount: (f.serving_amount as number) ?? null,
    product_type: f.product_type as string,
    is_electrolyte: (f.is_electrolyte as boolean) ?? false,
  }));
}

/**
 * Find user food substitutions for template components.
 * Returns a map of componentName → userFood that should replace it.
 *
 * Matching: user food product_type must map to the component's product_type,
 * and carbs per serving must be within 50% tolerance.
 * Never substitutes essential components (water).
 */
function findSubstitutions(
  phaseResults: PreWorkoutPhaseResult[],
  templateFoodsMap: Map<string, TemplateFoodRow>,
  userFoods: UserFoodForSubstitution[],
): Map<string, UserFoodForSubstitution> {
  if (userFoods.length === 0) return new Map();

  const substitutions = new Map<string, UserFoodForSubstitution>();
  // Track which user foods have been used to avoid double-assigning
  const usedUserFoods = new Set<string>();

  for (const pr of phaseResults) {
    for (const selection of [pr.primary, pr.stack, pr.drink, pr.electrolyte]) {
      if (!selection?.component_food_names) continue;

      for (const compName of selection.component_food_names) {
        const tf = templateFoodsMap.get(compName);
        if (!tf) continue;

        // Never substitute water or other essential liquids
        if (compName === 'water' || compName === 'plain_water') continue;

        const compProductType = tf.product_type ?? compName; // fallback to name as type hint

        // Find matching user foods
        const candidates = userFoods.filter(uf => {
          if (usedUserFoods.has(uf.id)) return false;

          // Check product type compatibility
          const allowedTypes = USER_TO_TEMPLATE_TYPE_MAP[uf.product_type] ?? [];
          if (!allowedTypes.includes(compProductType) && uf.product_type !== compProductType) {
            return false;
          }

          // Nutritional similarity: carbs within 50% tolerance
          const compCarbs = tf.carbs_g;
          if (compCarbs > 0) {
            const carbDiff = Math.abs(uf.carbs_per_serving - compCarbs);
            if (carbDiff / compCarbs > 0.5) return false;
          }

          return true;
        });

        if (candidates.length === 0) continue;

        // Pick the candidate with closest carb profile
        const best = candidates.reduce((a, b) => {
          const diffA = Math.abs(a.carbs_per_serving - tf.carbs_g);
          const diffB = Math.abs(b.carbs_per_serving - tf.carbs_g);
          return diffA <= diffB ? a : b;
        });

        substitutions.set(compName, best);
        usedUserFoods.add(best.id);
        console.log(`[PLAN-V3-SUBST] Substituting '${compName}' (${compProductType}) → user food '${best.name}' (${best.product_type})`);
      }
    }
  }

  return substitutions;
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
        console.warn(`[PLAN-V3] Component '${compName}' not found in template_foods, skipping`);
        continue;
      }

      // Per-serving proportion of this component within 1 serving of the template
      const proportion = componentQty[compName] ?? 1;
      // Total servings of this component = proportion * template servings
      const compServings = proportion * servings;

      // Check for user food substitution
      const userSub = substitutions?.get(compName);
      if (userSub) {
        // Use user food's nutrition data instead of template component
        const carbs = Math.round(userSub.carbs_per_serving * compServings * 10) / 10;
        const protein = Math.round(userSub.protein_per_serving * compServings * 10) / 10;
        const fat = Math.round(userSub.fat_per_serving * compServings * 10) / 10;
        const sodium = Math.round(userSub.sodium_mg * compServings * 10) / 10;
        const fluid = Math.round(userSub.fluid_ml_per_serving * compServings * 10) / 10;
        const calories = Math.round((carbs * 4) + (protein * 4) + (fat * 9));

        results.push({
          food_id: userSub.id, // User food UUID so Dart can resolve from user_foods table
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
  substitutions?: Map<string, UserFoodForSubstitution>,
): SubPhaseResult {
  const timing = getSubPhaseTimingLabel(phaseResult.phase, hoursBefore);
  const foods: FoodResult[] = [];

  // Primary food (exploded into components, with user food substitutions)
  if (phaseResult.primary) {
    foods.push(...selectionToFoodResults(phaseResult.primary, timing, false, false, templateFoodsMap, substitutions));
  }

  // Stacked food (exploded into components, with user food substitutions)
  if (phaseResult.stack) {
    foods.push(...selectionToFoodResults(phaseResult.stack, timing, false, false, templateFoodsMap, substitutions));
  }

  // Add-ons (banana, sports drink) — not composites, keep as-is
  for (const addOn of phaseResult.add_ons) {
    foods.push(addOnToFoodResult(addOn, timing));
  }

  // Standalone drink (exploded — usually single-component, with substitutions)
  if (phaseResult.drink) {
    foods.push(...selectionToFoodResults(phaseResult.drink, timing, true, false, templateFoodsMap, substitutions));
  }

  // Electrolyte supplement (exploded — usually single-component, with substitutions)
  if (phaseResult.electrolyte) {
    foods.push(...selectionToFoodResults(phaseResult.electrolyte, timing, false, true, templateFoodsMap, substitutions));
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
  liked_foods?: string[];
  disliked_foods?: string[];
  willing_to_try_foods?: string[];
  allergies?: string[];
  device_id?: string;
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
    input.liked_foods ?? [],
    input.disliked_foods ?? [],
    input.allergies,
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

  // 5.5. Fetch user foods and find substitutions for before-phase components
  let substitutions = new Map<string, UserFoodForSubstitution>();
  if (input.device_id) {
    const userFoods = await fetchUserFoodsForBefore(supabase, input.device_id);
    if (userFoods.length > 0) {
      substitutions = findSubstitutions(phaseResults, templateFoodsMap, userFoods);
      console.log(`[PLAN-V3] Found ${substitutions.size} user food substitutions for before phase`);
    }
  }

  // 6. Get phase targets for the SubPhaseResult shape
  const phaseTargetsMap = splitTargets(targets, input.hours_before);

  // 7. Transform V4 → V2 (exploding composites into individual FoodResults, with user substitutions)
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
      substitutions,
    );

    console.log(`[PLAN-V3] ${phaseResult.phase}: ${subPhaseResult.foods.length} foods (exploded), carbs=${phaseResult.total_carbs_g}g`);

    if (phaseResult.phase === 'meal') beforeResult.meal = subPhaseResult;
    else if (phaseResult.phase === 'snack') beforeResult.snack = subPhaseResult;
    else if (phaseResult.phase === 'top_up') beforeResult.top_up = subPhaseResult;
  }

  return beforeResult;
}
