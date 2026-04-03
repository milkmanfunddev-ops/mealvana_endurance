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
  shouldPrioritizeMacroTarget,
} from './types.ts';
import { calculateTotals } from './food-utils.ts';
import { PREFERENCE_SCORE_MAP, MACRO_CONSTRAINT_RANGES } from './constants.ts';

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
  if (pt === 'beverage') return 'hydration';
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

/** Cryptographically secure random integer in [0, max).
 *  Uses crypto.getRandomValues() instead of Math.random() because
 *  Deno/Supabase edge functions may seed Math.random() deterministically. */
function secureRandomInt(max: number): number {
  if (max <= 1) return 0;
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return array[0] % max;
}

/** Sort foods by preference score (liked > willing > neutral).
 *  No secondary tiebreaker — foods with equal preference are shuffled
 *  randomly so that gels, chews, and drink_mix get equal selection chance. */
function sortByPreference(foods: Food[]): Food[] {
  return [...foods].sort((a, b) => {
    return b.preference_score - a.preference_score;
  });
}

/** Pick a food using random selection among equally-preferred items.
 *  Preserves preference ordering (liked > willing > neutral) but randomizes
 *  among foods with the same preference score for variety.
 *  Uses crypto.getRandomValues() for true randomness in edge functions. */
function pickWeighted(foods: Food[], label?: string): Food | null {
  if (foods.length === 0) return null;
  if (foods.length === 1) return foods[0];
  const sorted = sortByPreference(foods);
  const bestScore = sorted[0].preference_score;
  const topTier = sorted.filter(f => f.preference_score === bestScore);
  if (topTier.length > 1) {
    const idx = secureRandomInt(topTier.length);
    const picked = topTier[idx];
    if (label) {
      console.log(
        `[DURING-RULES] ${label}: picked ${picked.name} (${idx + 1}/${topTier.length} candidates: ${topTier.map(f => f.name).join(', ')})`
      );
    }
    return picked;
  }
  return sorted[0];
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

/** Apply macro high-bound caps to a food's servings, then clamp to valid increment/min/max. */
function capServingsByUpperBounds(
  food: Food,
  servings: number,
  carbsAssigned: number,
  sodiumAssigned: number,
  fluidAssigned: number,
  carbUpper: number,
  sodiumUpper: number,
  fluidUpper: number,
): number {
  let capped = servings;

  if (food.per_serving.carbs_g > 0 && Number.isFinite(carbUpper)) {
    const maxByCarbs = (carbUpper - carbsAssigned) / food.per_serving.carbs_g;
    if (Number.isFinite(maxByCarbs)) capped = Math.min(capped, maxByCarbs);
  }
  if (food.per_serving.sodium_mg > 0 && Number.isFinite(sodiumUpper)) {
    const maxBySodium = (sodiumUpper - sodiumAssigned) / food.per_serving.sodium_mg;
    if (Number.isFinite(maxBySodium)) capped = Math.min(capped, maxBySodium);
  }
  if (food.per_serving.water_ml > 0 && Number.isFinite(fluidUpper)) {
    const maxByFluid = (fluidUpper - fluidAssigned) / food.per_serving.water_ml;
    if (Number.isFinite(maxByFluid)) capped = Math.min(capped, maxByFluid);
  }

  if (capped <= 0) return 0;
  return clampServings(capped, food);
}

/** Enumerate feasible serving candidates for a food.
 *  Indivisible foods use whole servings; divisible foods use 0.5 increments. */
function getServingCandidates(food: Food): number[] {
  const candidates: number[] = [];
  const max = Math.max(food.min_servings, food.max_servings);
  const start = food.is_indivisible ? Math.max(1, Math.ceil(food.min_servings)) : Math.max(0.5, roundToIncrement(food.min_servings));
  const step = food.is_indivisible ? 1 : 0.5;

  for (let s = start; s <= max + 1e-6; s += step) {
    candidates.push(food.is_indivisible ? Math.round(s) : roundToIncrement(s));
  }

  return candidates;
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
  const prioritizeCarbTarget = shouldPrioritizeMacroTarget(targets, 'carbs');
  const defaultCarbUpper = carbTarget > 0
    ? carbTarget * (MACRO_CONSTRAINT_RANGES.carbs.during?.max ?? 1.1)
    : Number.POSITIVE_INFINITY;
  const carbUpper = prioritizeCarbTarget
    ? defaultCarbUpper
    : (targets.carbs_high_g ?? defaultCarbUpper);
  const sodiumLower = targets.sodium_low_mg ?? (sodiumTarget > 0 ? sodiumTarget * 0.9 : 0);
  const sodiumUpper = targets.sodium_high_mg ?? (sodiumTarget > 0 ? sodiumTarget * 1.1 : Number.POSITIVE_INFINITY);
  const fluidUpper = targets.water_high_ml ?? (fluidTarget > 0 ? fluidTarget * 1.1 : Number.POSITIVE_INFINITY);
  const isRunning = activityType === 'running';
  const isCycling = activityType === 'cycling';

  console.log(
    `[DURING-RULES] Targets: carbs=${carbTarget}g, sodium=${sodiumTarget}mg, fluid=${fluidTarget}ml, sport=${activityType}`
  );
  if (prioritizeCarbTarget) {
    console.log(
      `[DURING-RULES] Prioritizing carb target (${carbTarget}g) with cap=${carbUpper.toFixed(1)}g`,
    );
  }

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
  // Short events (< 15g carb target): skip primary carb entirely — even the
  // smallest gel (~25g) would overshoot. Just provide water + electrolyte.

  if (carbTarget > 0 && carbTarget < 15) {
    console.log(
      `[DURING-RULES] Skipping primary carb — target ${carbTarget}g too low for any food item`
    );
  }

  const primaryCarb = carbTarget >= 15
    ? pickWeighted(categorized.primary_carb, 'Primary carb selection')
    : null;

  if (primaryCarb && carbTarget > 0) {
    // Determine carb share for primary source
    // If sports drink is also selected, split: 70% primary, 30% sports drink
    const sportsDrinkPeek = pickWeighted(categorized.sports_drink);
    const hasSportsDrink = sportsDrinkPeek !== null && sportsDrinkPeek.per_serving.carbs_g > 0;
    const primaryShare = hasSportsDrink ? 0.7 : 1.0;

    const primaryCarbTarget = carbTarget * primaryShare;
    let primaryServings = primaryCarbTarget / primaryCarb.per_serving.carbs_g;
    primaryServings = capServingsByUpperBounds(
      primaryCarb,
      primaryServings,
      carbsAssigned,
      sodiumAssigned,
      fluidAssigned,
      carbUpper,
      sodiumUpper,
      fluidUpper,
    );

    const primaryResult = buildFoodResult(primaryCarb, primaryServings);
    if (primaryServings > 0) {
      resultFoods.push(primaryResult);
      carbsAssigned += primaryResult.carbs_grams;
      sodiumAssigned += primaryResult.sodium_mg;
      fluidAssigned += primaryResult.fluids_ml;
    }

    if (primaryServings > 0) {
      console.log(
        `[DURING-RULES] Primary carb: ${primaryCarb.name} x${primaryServings} = ${primaryResult.carbs_grams}g carbs`
      );
    }
  }

  // ---- STEP 2: Sports drink (remaining carb share + fluid) ----
  const sportsDrink = pickWeighted(categorized.sports_drink, 'Sports drink selection');
  if (sportsDrink && carbTarget > 0) {
    const remainingCarbs = Math.max(0, carbTarget - carbsAssigned);

    if (remainingCarbs > 0 && sportsDrink.per_serving.carbs_g > 0) {
      let sdServings = remainingCarbs / sportsDrink.per_serving.carbs_g;
      sdServings = capServingsByUpperBounds(
        sportsDrink,
        sdServings,
        carbsAssigned,
        sodiumAssigned,
        fluidAssigned,
        carbUpper,
        sodiumUpper,
        fluidUpper,
      );

      if (sdServings > 0) {
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
  }

  // ---- STEP 2.5: Carb deficit recovery ----
  // If still significantly under carb target after primary + sports drink,
  // try a SECOND primary carb source (different from what was picked)
  {
    const carbDeficit = carbTarget - carbsAssigned;
    if (carbDeficit > carbTarget * 0.2 && categorized.primary_carb.length > 1) {
      const alternates = categorized.primary_carb.filter(f =>
        !primaryCarb || f.id !== primaryCarb.id
      );
      const secondaryCarb = pickWeighted(alternates, 'Secondary carb (deficit recovery)');
      if (secondaryCarb) {
        let secServings = carbDeficit / secondaryCarb.per_serving.carbs_g;
        secServings = capServingsByUpperBounds(
          secondaryCarb,
          secServings,
          carbsAssigned,
          sodiumAssigned,
          fluidAssigned,
          carbUpper,
          sodiumUpper,
          fluidUpper,
        );
        if (secServings > 0) {
          const secResult = buildFoodResult(secondaryCarb, secServings);
          resultFoods.push(secResult);
          carbsAssigned += secResult.carbs_grams;
          sodiumAssigned += secResult.sodium_mg;
          fluidAssigned += secResult.fluids_ml;

          console.log(
            `[DURING-RULES] Secondary carb: ${secondaryCarb.name} x${secServings} = ${secResult.carbs_grams}g carbs (deficit recovery)`
          );
        }
      }
    }
    // If STILL in deficit (>30%) and sports drink was skipped, try adding one now
    if (carbTarget > 0 && carbTarget - carbsAssigned > carbTarget * 0.3) {
      const anySportsDrink = categorized.sports_drink.length > 0
        ? categorized.sports_drink[0]
        : null;
      if (anySportsDrink && !sportsDrink && anySportsDrink.per_serving.carbs_g > 0) {
        const deficit = carbTarget - carbsAssigned;
        let recoveryServings = deficit / anySportsDrink.per_serving.carbs_g;
        recoveryServings = capServingsByUpperBounds(
          anySportsDrink,
          recoveryServings,
          carbsAssigned,
          sodiumAssigned,
          fluidAssigned,
          carbUpper,
          sodiumUpper,
          fluidUpper,
        );
        if (recoveryServings > 0) {
          const recoveryResult = buildFoodResult(anySportsDrink, recoveryServings);
          resultFoods.push(recoveryResult);
          carbsAssigned += recoveryResult.carbs_grams;
          sodiumAssigned += recoveryResult.sodium_mg;
          fluidAssigned += recoveryResult.fluids_ml;

          console.log(
            `[DURING-RULES] Sports drink (deficit recovery): ${anySportsDrink.name} x${recoveryServings} = ${recoveryResult.carbs_grams}g carbs`
          );
        }
      }
    }
  }

  // ---- STEP 3: Bike solids (cycling only) ----
  if (isCycling && categorized.bike_solid.length > 0) {
    // Add bike solids for sustained energy; use remaining carb gap
    const remainingCarbs = Math.max(0, carbTarget - carbsAssigned);
    if (remainingCarbs > 10) {
      const bikeSolid = pickWeighted(categorized.bike_solid, 'Bike solid selection');
      if (bikeSolid && bikeSolid.per_serving.carbs_g > 0) {
        let bsServings = remainingCarbs / bikeSolid.per_serving.carbs_g;
        bsServings = capServingsByUpperBounds(
          bikeSolid,
          bsServings,
          carbsAssigned,
          sodiumAssigned,
          fluidAssigned,
          carbUpper,
          sodiumUpper,
          fluidUpper,
        );

        if (bsServings > 0) {
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
  }

  // ---- STEP 4: Hydration (water to meet fluid target) ----
  const remainingFluid = Math.max(0, fluidTarget - fluidAssigned);
  if (remainingFluid > 0) {
    const waterFood = pickWeighted(categorized.hydration, 'Hydration selection');
    if (waterFood && waterFood.per_serving.water_ml > 0) {
      let waterServings = capServingsByUpperBounds(
        waterFood,
        remainingFluid / waterFood.per_serving.water_ml,
        carbsAssigned,
        sodiumAssigned,
        fluidAssigned,
        carbUpper,
        sodiumUpper,
        fluidUpper,
      );

      if (waterServings > 0) {
        const waterResult = buildFoodResult(waterFood, waterServings);
        resultFoods.push(waterResult);
        fluidAssigned += waterResult.fluids_ml;
        sodiumAssigned += waterResult.sodium_mg;

        console.log(
          `[DURING-RULES] Hydration: ${waterFood.name} x${waterServings} = ${waterResult.fluids_ml}ml`
        );
      }
    }
  }

  // ---- STEP 5: Electrolytes (fill sodium gap) ----
  // Uses a two-pass approach: first pick the best single electrolyte source,
  // then if sodium gap remains > 10%, try adding a second source.
  const remainingSodium = Math.max(0, sodiumTarget - sodiumAssigned);
  if (remainingSodium > 0) {
    const MAX_SUPPLEMENT_SERVINGS = Math.min(10, Math.max(4, Math.ceil(sodiumTarget / 400)));

    const pickBestElectrolyte = (
      pool: Food[],
      currentSodium: number,
      currentFluid: number,
      currentCarbs: number,
    ): { food: Food; servings: number; score: number; sodium: number; fluid: number; carbs: number } | null => {
      const sodiumMin = sodiumLower;
      const baselineSodiumScore = sodiumTarget > 0
        ? (Math.max(0, sodiumMin - currentSodium) + Math.max(0, currentSodium - sodiumUpper)) / sodiumTarget
        : 0;
      const baselineFluidPenalty = fluidTarget > 0 && currentFluid > fluidUpper
        ? ((currentFluid - fluidUpper) / fluidTarget) * 3
        : 0;
      const baselineCarbPenalty = carbTarget > 0 && currentCarbs > carbUpper
        ? ((currentCarbs - carbUpper) / carbTarget) * 2
        : 0;
      const baselineScore = baselineSodiumScore + baselineFluidPenalty + baselineCarbPenalty;

      let best: { food: Food; servings: number; score: number; sodium: number; fluid: number; carbs: number } | null = null;

      for (const electrolyte of pool) {
        if (electrolyte.per_serving.sodium_mg <= 0) continue;

        const candidates = getServingCandidates(electrolyte);
        // Cap supplement (non-liquid) servings to prevent excessive capsule counts
        const cappedCandidates = electrolyte.product_type === 'supplement' && !electrolyte.is_liquid
          ? candidates.filter(s => s <= MAX_SUPPLEMENT_SERVINGS)
          : candidates;

        for (const servings of cappedCandidates) {
          const sodium = currentSodium + (electrolyte.per_serving.sodium_mg * servings);
          const fluid = currentFluid + (electrolyte.per_serving.water_ml * servings);
          const carbs = currentCarbs + (electrolyte.per_serving.carbs_g * servings);
          if (sodium > sodiumUpper + 1e-6) continue;
          if (fluid > fluidUpper + 1e-6) continue;
          if (carbs > carbUpper + 1e-6) continue;

          const sodiumPenalty = sodiumTarget > 0
            ? (Math.max(0, sodiumMin - sodium) + Math.max(0, sodium - sodiumUpper) * 2) / sodiumTarget
            : 0;
          const fluidPenalty = fluidTarget > 0 && fluid > fluidUpper
            ? ((fluid - fluidUpper) / fluidTarget) * 3
            : 0;
          const carbPenalty = carbTarget > 0 && carbs > carbUpper
            ? ((carbs - carbUpper) / carbTarget) * 1.5
            : 0;
          // Progressive penalty for dry capsules/supplements > 2 servings
          const capsulePenalty = electrolyte.product_type === 'supplement' && !electrolyte.is_liquid && servings > 2
            ? 0.05 * (servings - 2)
            : 0;
          const preferenceBonus = electrolyte.preference_score >= PREFERENCE_SCORE_MAP.liked ? -0.02 : 0;
          const score = sodiumPenalty + fluidPenalty + carbPenalty + capsulePenalty + preferenceBonus;

          if (!best || score < best.score || (Math.abs(score - best.score) < 1e-6 && Math.abs(sodiumTarget - sodium) < Math.abs(sodiumTarget - best.sodium))) {
            best = { food: electrolyte, servings, score, sodium, fluid, carbs };
          }
        }
      }

      if (!best) return null;
      if (best.sodium >= sodiumMin) return best;
      return best.score < baselineScore ? best : null;
    };

    // First pass: pick the best electrolyte from the full pool
    const firstPick = pickBestElectrolyte(
      categorized.electrolyte,
      sodiumAssigned,
      fluidAssigned,
      carbsAssigned,
    );

    if (firstPick) {
      const elecResult = buildFoodResult(firstPick.food, firstPick.servings);
      resultFoods.push(elecResult);
      sodiumAssigned += elecResult.sodium_mg;
      fluidAssigned += elecResult.fluids_ml;
      carbsAssigned += elecResult.carbs_grams;

      console.log(
        `[DURING-RULES] Electrolyte: ${firstPick.food.name} x${firstPick.servings} = ` +
        `${elecResult.sodium_mg}mg sodium, ${elecResult.fluids_ml}ml fluid`
      );

      // Second pass: if sodium gap still > 10%, try adding a different electrolyte source
      if (sodiumAssigned < sodiumLower) {
        const secondPool = categorized.electrolyte.filter(e => e.id !== firstPick.food.id);
        const secondPick = pickBestElectrolyte(
          secondPool,
          sodiumAssigned,
          fluidAssigned,
          carbsAssigned,
        );
        if (secondPick) {
          const elecResult2 = buildFoodResult(secondPick.food, secondPick.servings);
          resultFoods.push(elecResult2);
          sodiumAssigned += elecResult2.sodium_mg;
          fluidAssigned += elecResult2.fluids_ml;
          carbsAssigned += elecResult2.carbs_grams;

          console.log(
            `[DURING-RULES] Electrolyte (2nd source): ${secondPick.food.name} x${secondPick.servings} = ` +
            `${elecResult2.sodium_mg}mg sodium, ${elecResult2.fluids_ml}ml fluid`
          );
        }
      }
    } else {
      console.log('[DURING-RULES] Skipping electrolyte — best option does not improve score');
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

  // Warn if significant carb deficit remains after all steps
  const carbDeficitPct = carbTarget > 0 ? ((carbTarget - totals.carbs_g) / carbTarget * 100) : 0;
  if (carbDeficitPct > 20) {
    console.log(
      `[DURING-RULES] WARNING: Carb deficit ${carbDeficitPct.toFixed(0)}% — ` +
      `consider adding more food sources to pool`
    );
  }

  // ---- Post-validation: check totals against MACRO_CONSTRAINT_RANGES ----
  const duringRanges = {
    carbs: MACRO_CONSTRAINT_RANGES.carbs.during,
    sodium: MACRO_CONSTRAINT_RANGES.sodium.during,
    water: MACRO_CONSTRAINT_RANGES.water.during,
  };
  const validationIssues: string[] = [];

  if (duringRanges.carbs && carbTarget > 0) {
    const ratio = totals.carbs_g / carbTarget;
    if (ratio < duringRanges.carbs.min || ratio > duringRanges.carbs.max) {
      validationIssues.push(
        `carbs ${(ratio * 100).toFixed(0)}% (${totals.carbs_g.toFixed(0)}g/${carbTarget}g) outside [${(duringRanges.carbs.min * 100)}%, ${(duringRanges.carbs.max * 100)}%]`
      );
    }
  }
  if (duringRanges.sodium && sodiumTarget > 0) {
    const ratio = totals.sodium_mg / sodiumTarget;
    if (ratio < duringRanges.sodium.min || ratio > duringRanges.sodium.max) {
      validationIssues.push(
        `sodium ${(ratio * 100).toFixed(0)}% (${totals.sodium_mg.toFixed(0)}mg/${sodiumTarget}mg) outside [${(duringRanges.sodium.min * 100)}%, ${(duringRanges.sodium.max * 100)}%]`
      );
    }
  }
  if (duringRanges.water && fluidTarget > 0) {
    const ratio = totals.water_ml / fluidTarget;
    if (ratio < duringRanges.water.min || ratio > duringRanges.water.max) {
      validationIssues.push(
        `water ${(ratio * 100).toFixed(0)}% (${totals.water_ml.toFixed(0)}ml/${fluidTarget}ml) outside [${(duringRanges.water.min * 100)}%, ${(duringRanges.water.max * 100)}%]`
      );
    }
  }

  if (validationIssues.length > 0) {
    console.warn(
      `[DURING-RULES] POST-VALIDATION: ${validationIssues.length} issue(s): ${validationIssues.join('; ')}`
    );
  } else {
    console.log('[DURING-RULES] POST-VALIDATION: All macros within constraint ranges');
  }

  return { foods: resultFoods };
}
