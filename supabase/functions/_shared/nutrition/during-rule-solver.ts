/**
 * Rule-Based During-Phase Solver
 *
 * Replaces the LP solver for the during-workout phase with a deterministic
 * algorithm that selects from a curated product catalog.
 *
 * Algorithm:
 * 1. Categorize foods by product_type
 * 2. Select primary carb source (gel/chew/drink_mix) from user preferences
 * 3. Enforce mixing constraints (running: ONE of gel/chew/drink_mix)
 * 4. Calculate quantities to meet carb target
 * 5. Add hydration (water) to meet fluid target
 * 6. Add electrolytes to meet sodium target
 */

import { roundToIncrement } from '../utils.ts';
import {
  type Food,
  type FoodResult,
  type MacroTargets,
  type ActivityType,
  type TimingCategory,
  deriveTimingCategory,
} from './types.ts';
import { calculateTotals } from './food-utils.ts';
import { PREFERENCE_SCORE_MAP } from './constants.ts';

// ============================================================================
// Types
// ============================================================================

type ProductCategory =
  | 'primary_carb'    // gel, chew, drink_mix
  | 'sports_drink'    // sports_drink (liquid with carbs)
  | 'bike_solid'      // bar, waffle (cycling solids)
  | 'hydration'       // water/beverage
  | 'electrolyte';    // supplement, electrolyte tablet

interface CategorizedFoods {
  primary_carb: Food[];
  sports_drink: Food[];
  bike_solid: Food[];
  hydration: Food[];
  electrolyte: Food[];
}

interface RuleSolverResult {
  foods: FoodResult[];
}

// ============================================================================
// Food Categorization
// ============================================================================

function categorizeFood(food: Food): ProductCategory {
  const pt = food.product_type;

  // Explicit product_type mapping
  if (pt === 'gel' || pt === 'chew' || pt === 'drink_mix') return 'primary_carb';
  if (pt === 'sports_drink') return 'sports_drink';
  if (pt === 'bar') return 'bike_solid';
  if (pt === 'supplement') return 'electrolyte';

  // Derived: if liquid with significant carbs → sports_drink
  if (food.is_liquid && food.per_serving.carbs_g > 5) return 'sports_drink';

  // Derived: if liquid with no/low carbs → hydration
  if (food.is_liquid) return 'hydration';

  // Derived: if electrolyte → electrolyte
  if (food.is_electrolyte) return 'electrolyte';

  // Solid food (waffle, real food) → bike_solid
  return 'bike_solid';
}

function categorizeFoods(foods: Food[]): CategorizedFoods {
  const result: CategorizedFoods = {
    primary_carb: [],
    sports_drink: [],
    bike_solid: [],
    hydration: [],
    electrolyte: [],
  };

  for (const food of foods) {
    const category = categorizeFood(food);
    result[category].push(food);
  }

  return result;
}

// ============================================================================
// Selection Helpers
// ============================================================================

/** Sort foods by preference score (liked > willing > neutral), then by carbs descending */
function sortByPreference(foods: Food[]): Food[] {
  return [...foods].sort((a, b) => {
    if (b.preference_score !== a.preference_score) {
      return b.preference_score - a.preference_score;
    }
    return b.per_serving.carbs_g - a.per_serving.carbs_g;
  });
}

/** Pick the best food from a list by preference. Returns null if empty. */
function pickBest(foods: Food[]): Food | null {
  if (foods.length === 0) return null;
  return sortByPreference(foods)[0];
}

/** Clamp servings to [min, max], respecting indivisibility */
function clampServings(servings: number, food: Food): number {
  const min = food.min_servings;
  const max = food.max_servings;

  let clamped = Math.max(min, Math.min(max, servings));

  if (food.is_indivisible) {
    clamped = Math.max(1, Math.round(clamped));
  } else {
    clamped = roundToIncrement(clamped);
  }

  return clamped;
}

/** Build a FoodResult from a Food and quantity */
function buildFoodResult(food: Food, quantity: number): FoodResult {
  const tc = deriveTimingCategory(food);
  return {
    food_id: food.id,
    quantity,
    carbs_grams: Math.round(food.per_serving.carbs_g * quantity * 10) / 10,
    protein_grams: Math.round(food.per_serving.protein_g * quantity * 10) / 10,
    fat_grams: Math.round(food.per_serving.fat_g * quantity * 10) / 10,
    sodium_mg: Math.round(food.per_serving.sodium_mg * quantity),
    fluids_ml: Math.round(food.per_serving.water_ml * quantity),
    calories: Math.round(food.per_serving.calories * quantity),
    timing: 'Throughout activity',
    display_name: food.display_name ?? undefined,
    display_name_plural: food.display_name_plural ?? undefined,
    description: food.description ?? undefined,
    image_address: food.image_address ?? undefined,
    serving_size: food.serving_size ?? undefined,
    serving_unit: food.serving_unit ?? undefined,
    serving_qualifier: food.serving_qualifier ?? undefined,
    is_liquid: food.is_liquid,
    is_electrolyte: food.is_electrolyte,
    is_drink: food.is_liquid,
    is_indivisible: food.is_indivisible,
    timing_category: tc,
    product_type: food.product_type,
  };
}

// ============================================================================
// Main Solver
// ============================================================================

/**
 * Generate during-phase food selection using deterministic rules.
 *
 * @param foods - Available foods for during phase (already filtered by preferences/activity)
 * @param targets - Macro targets for during phase
 * @param activityType - Running, cycling, etc.
 * @returns RuleSolverResult with selected foods
 */
export function generateDuringPhaseRuleBased(
  foods: Food[],
  targets: MacroTargets,
  activityType: ActivityType,
): RuleSolverResult {
  if (foods.length === 0) {
    console.log('[DURING-RULES] No foods available');
    return { foods: [] };
  }

  const carbTarget = targets.carbs_g;
  const sodiumTarget = targets.sodium_mg;
  const fluidTarget = targets.water_ml;
  const isRunning = activityType === 'running';
  const isCycling = activityType === 'cycling';

  console.log(
    `[DURING-RULES] Targets: carbs=${carbTarget}g, sodium=${sodiumTarget}mg, fluid=${fluidTarget}ml, sport=${activityType}`
  );

  const categorized = categorizeFoods(foods);
  console.log(
    `[DURING-RULES] Pool: ${categorized.primary_carb.length} primary_carb, ` +
    `${categorized.sports_drink.length} sports_drink, ${categorized.bike_solid.length} bike_solid, ` +
    `${categorized.hydration.length} hydration, ${categorized.electrolyte.length} electrolyte`
  );

  const resultFoods: FoodResult[] = [];
  let carbsAssigned = 0;
  let sodiumAssigned = 0;
  let fluidAssigned = 0;

  // ---- STEP 1: Select primary carb source ----
  // Running: ONE of gel/chew/drink_mix (mixing constraint)
  // Cycling: can combine freely

  const primaryCarb = pickBest(categorized.primary_carb);

  if (primaryCarb && carbTarget > 0) {
    // Determine carb share for primary source
    // If sports drink is also selected, split: 70% primary, 30% sports drink
    const sportsDrink = pickBest(categorized.sports_drink);
    const hasSportsDrink = sportsDrink !== null && sportsDrink.per_serving.carbs_g > 0;
    const primaryShare = hasSportsDrink ? 0.7 : 1.0;

    const primaryCarbTarget = carbTarget * primaryShare;
    let primaryServings = primaryCarbTarget / primaryCarb.per_serving.carbs_g;
    primaryServings = clampServings(primaryServings, primaryCarb);

    const primaryResult = buildFoodResult(primaryCarb, primaryServings);
    resultFoods.push(primaryResult);
    carbsAssigned += primaryResult.carbs_grams;
    sodiumAssigned += primaryResult.sodium_mg;
    fluidAssigned += primaryResult.fluids_ml;

    console.log(
      `[DURING-RULES] Primary carb: ${primaryCarb.name} x${primaryServings} = ${primaryResult.carbs_grams}g carbs`
    );
  }

  // ---- STEP 2: Sports drink (remaining carb share + fluid) ----
  const sportsDrink = pickBest(categorized.sports_drink);
  if (sportsDrink && carbTarget > 0) {
    const remainingCarbs = Math.max(0, carbTarget - carbsAssigned);

    if (remainingCarbs > 0 && sportsDrink.per_serving.carbs_g > 0) {
      let sdServings = remainingCarbs / sportsDrink.per_serving.carbs_g;
      sdServings = clampServings(sdServings, sportsDrink);

      const sdResult = buildFoodResult(sportsDrink, sdServings);
      resultFoods.push(sdResult);
      carbsAssigned += sdResult.carbs_grams;
      sodiumAssigned += sdResult.sodium_mg;
      fluidAssigned += sdResult.fluids_ml;

      console.log(
        `[DURING-RULES] Sports drink: ${sportsDrink.name} x${sdServings} = ${sdResult.carbs_grams}g carbs, ${sdResult.fluids_ml}ml fluid`
      );
    }
  }

  // ---- STEP 3: Bike solids (cycling only) ----
  if (isCycling && categorized.bike_solid.length > 0) {
    // Add bike solids for sustained energy; use remaining carb gap
    const remainingCarbs = Math.max(0, carbTarget - carbsAssigned);
    if (remainingCarbs > 10) {
      const bikeSolid = pickBest(categorized.bike_solid);
      if (bikeSolid && bikeSolid.per_serving.carbs_g > 0) {
        let bsServings = remainingCarbs / bikeSolid.per_serving.carbs_g;
        bsServings = clampServings(bsServings, bikeSolid);

        const bsResult = buildFoodResult(bikeSolid, bsServings);
        resultFoods.push(bsResult);
        carbsAssigned += bsResult.carbs_grams;
        sodiumAssigned += bsResult.sodium_mg;
        fluidAssigned += bsResult.fluids_ml;

        console.log(
          `[DURING-RULES] Bike solid: ${bikeSolid.name} x${bsServings} = ${bsResult.carbs_grams}g carbs`
        );
      }
    }
  }

  // ---- STEP 4: Hydration (water to meet fluid target) ----
  const remainingFluid = Math.max(0, fluidTarget - fluidAssigned);
  if (remainingFluid > 0) {
    const waterFood = pickBest(categorized.hydration);
    if (waterFood && waterFood.per_serving.water_ml > 0) {
      let waterServings = remainingFluid / waterFood.per_serving.water_ml;
      waterServings = clampServings(waterServings, waterFood);

      const waterResult = buildFoodResult(waterFood, waterServings);
      resultFoods.push(waterResult);
      fluidAssigned += waterResult.fluids_ml;
      sodiumAssigned += waterResult.sodium_mg;

      console.log(
        `[DURING-RULES] Hydration: ${waterFood.name} x${waterServings} = ${waterResult.fluids_ml}ml`
      );
    }
  }

  // ---- STEP 5: Electrolytes (fill sodium gap) ----
  const remainingSodium = Math.max(0, sodiumTarget - sodiumAssigned);
  if (remainingSodium > 0) {
    // Sort electrolytes: prefer high sodium-to-carb ratio (tablets over drink mixes)
    const sortedElectrolytes = [...categorized.electrolyte].sort((a, b) => {
      const ratioA = a.per_serving.sodium_mg / Math.max(1, a.per_serving.carbs_g);
      const ratioB = b.per_serving.sodium_mg / Math.max(1, b.per_serving.carbs_g);
      // First by sodium ratio, then by preference
      if (Math.abs(ratioB - ratioA) > 1) return ratioB - ratioA;
      return b.preference_score - a.preference_score;
    });

    const electrolyte = sortedElectrolytes[0] ?? null;
    if (electrolyte && electrolyte.per_serving.sodium_mg > 0) {
      let elecServings = remainingSodium / electrolyte.per_serving.sodium_mg;
      elecServings = clampServings(elecServings, electrolyte);

      // Cap to avoid overshooting sodium by more than 10%
      const maxSodiumAllowed = sodiumTarget * 1.1;
      const maxServingsForCap = (maxSodiumAllowed - sodiumAssigned) / electrolyte.per_serving.sodium_mg;
      const cappedServings = electrolyte.is_indivisible
        ? Math.max(1, Math.floor(maxServingsForCap))
        : roundToIncrement(Math.max(0.5, maxServingsForCap));
      elecServings = Math.min(elecServings, cappedServings);

      if (elecServings > 0) {
        const elecResult = buildFoodResult(electrolyte, elecServings);
        resultFoods.push(elecResult);
        sodiumAssigned += elecResult.sodium_mg;

        console.log(
          `[DURING-RULES] Electrolyte: ${electrolyte.name} x${elecServings} = ${elecResult.sodium_mg}mg sodium`
        );
      }
    }
  }

  // ---- Summary ----
  const totals = calculateTotals(resultFoods);
  console.log(
    `[DURING-RULES] Final: ${resultFoods.length} foods, ` +
    `carbs=${totals.carbs_g.toFixed(0)}g/${carbTarget}g, ` +
    `sodium=${totals.sodium_mg.toFixed(0)}mg/${sodiumTarget}mg, ` +
    `fluid=${totals.water_ml.toFixed(0)}ml/${fluidTarget}ml`
  );

  return { foods: resultFoods };
}
