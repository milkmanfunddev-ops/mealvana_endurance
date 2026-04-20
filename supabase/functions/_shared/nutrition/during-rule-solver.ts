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

import {
  type Food,
  type FoodResult,
  type MacroTargets,
  type ActivityType,
  shouldPrioritizeMacroTarget,
} from './types.ts';
import { calculateTotals } from './food-utils.ts';
import { MACRO_CONSTRAINT_RANGES } from './constants.ts';
import {
  categorizeFoods,
  pickWeighted,
  capServingsByUpperBounds,
  buildFoodResult,
  fillElectrolytes,
  type ElectrolyteBounds,
} from './during-utils.ts';

interface RuleSolverResult {
  foods: FoodResult[];
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
  {
    const elecBounds: ElectrolyteBounds = {
      sodiumTarget,
      sodiumLower,
      sodiumUpper,
      fluidTarget,
      fluidUpper,
      carbTarget: carbTarget,
      carbUpper,
    };
    const elecResult = fillElectrolytes(
      categorized.electrolyte,
      resultFoods,
      sodiumAssigned,
      fluidAssigned,
      carbsAssigned,
      elecBounds,
      '[DURING-RULES]',
    );
    sodiumAssigned = elecResult.sodiumAssigned;
    fluidAssigned = elecResult.fluidAssigned;
    carbsAssigned = elecResult.carbsAssigned;
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
