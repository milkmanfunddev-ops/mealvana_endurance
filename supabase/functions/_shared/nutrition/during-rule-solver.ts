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
import {
  type FoodWithConstraints,
  type GutTrainingLevel,
  maxAllowedServingsForDuration,
} from './during-template-solver.ts';
import { MACRO_CONSTRAINT_RANGES } from './constants.ts';
import {
  categorizeFoods,
  pickWeighted,
  capServingsByUpperBounds,
  buildFoodResult,
  fillElectrolytes,
  type ElectrolyteBounds,
} from './during-utils.ts';

export interface RuleSolverShortfall {
  macro: 'carbs' | 'sodium' | 'fluid';
  delivered: number;
  target: number;
  unit: 'g' | 'mg' | 'ml';
  reason: 'no_foods_available' | 'catalog_exhausted';
}

interface RuleSolverResult {
  foods: FoodResult[];
  /** Emitted when the food pool is empty or a macro target cannot be met.
   * Allows callers and clients to distinguish an empty-pool "no fueling available"
   * from a legitimate zero-fuel phase (e.g. swimming). */
  shortfalls?: RuleSolverShortfall[];
  /** Plain-text warnings for logging / wire propagation. */
  warnings?: string[];
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
  /** When provided (with gutTrainingLevel), food picks and serving sizes are
   * clamped to the athlete's per-hour gut-training caps — the same
   * `maxAllowedServingsForDuration` the template solver and gap-fill apply.
   * Without it the solver could pick a food the athlete's gut level rules out
   * entirely (e.g. high_carb_drink_mix at max_per_hr_moderate = 0), whose
   * forced minimum serving then poisons the sodium/carb headroom for the
   * whole plan (2026-08-06, the 45-min ultra stall). */
  durationMinutes?: number,
  gutTrainingLevel?: GutTrainingLevel,
): RuleSolverResult {
  if (foods.length === 0) {
    // Emit a structured signal so the caller can distinguish "no foods" from a
    // legitimate zero-fuel phase (e.g. swimming returns {foods:[]} intentionally).
    const emptyShortfalls: RuleSolverShortfall[] = [];
    if (targets.carbs_g > 0) {
      emptyShortfalls.push({
        macro: 'carbs',
        delivered: 0,
        target: targets.carbs_g,
        unit: 'g',
        reason: 'no_foods_available',
      });
    }
    if (targets.sodium_mg > 0) {
      emptyShortfalls.push({
        macro: 'sodium',
        delivered: 0,
        target: targets.sodium_mg,
        unit: 'mg',
        reason: 'no_foods_available',
      });
    }
    if (targets.water_ml > 0) {
      emptyShortfalls.push({
        macro: 'fluid',
        delivered: 0,
        target: targets.water_ml,
        unit: 'ml',
        reason: 'no_foods_available',
      });
    }
    const warningMsg = `[DURING-RULES] Empty food pool — cannot meet any targets for ${activityType}`;
    console.warn(warningMsg);
    return {
      foods: [],
      shortfalls: emptyShortfalls,
      warnings: [warningMsg],
    };
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

  const durationHours = durationMinutes && durationMinutes > 0
    ? durationMinutes / 60
    : null;
  const gutCap = (food: Food): number =>
    durationHours !== null && gutTrainingLevel
      ? maxAllowedServingsForDuration(
        food as FoodWithConstraints,
        durationHours,
        gutTrainingLevel,
      )
      : Number.POSITIVE_INFINITY;
  const gutEligible = (pool: Food[]): Food[] =>
    pool.filter((f) => gutCap(f) > 0);

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
    ? pickWeighted(gutEligible(categorized.primary_carb), 'Primary carb selection')
    : null;

  if (primaryCarb && carbTarget > 0) {
    // Determine carb share for primary source
    // If sports drink is also selected, split: 70% primary, 30% sports drink
    const sportsDrinkPeek = pickWeighted(categorized.sports_drink);
    const hasSportsDrink = sportsDrinkPeek !== null && sportsDrinkPeek.per_serving.carbs_g > 0;
    const primaryShare = hasSportsDrink ? 0.7 : 1.0;

    const primaryCarbTarget = carbTarget * primaryShare;
    let primaryServings = primaryCarbTarget / primaryCarb.per_serving.carbs_g;
    primaryServings = Math.min(primaryServings, gutCap(primaryCarb));
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
  const sportsDrink = pickWeighted(gutEligible(categorized.sports_drink), 'Sports drink selection');
  if (sportsDrink && carbTarget > 0) {
    const remainingCarbs = Math.max(0, carbTarget - carbsAssigned);

    if (remainingCarbs > 0 && sportsDrink.per_serving.carbs_g > 0) {
      let sdServings = remainingCarbs / sportsDrink.per_serving.carbs_g;
      sdServings = Math.min(sdServings, gutCap(sportsDrink));

      // When carbTarget < 15g the primary carb step was already skipped. For this
      // degenerate low-target case, relax the carb upper bound so sports drink can
      // still contribute one serving (any overshoot is within the parity 8g absolute
      // floor). Pass Infinity as carbUpper so capServingsByUpperBounds doesn't block.
      const effectiveCarbUpperForSD = carbTarget < 15 ? Number.POSITIVE_INFINITY : carbUpper;
      sdServings = capServingsByUpperBounds(
        sportsDrink,
        sdServings,
        carbsAssigned,
        sodiumAssigned,
        fluidAssigned,
        effectiveCarbUpperForSD,
        sodiumUpper,
        fluidUpper,
      );

      // Guard: after clamping/rounding to min_servings, verify carbs still fit
      // within the upper bound. Discrete foods (min_servings≥1) can round UP to
      // their minimum, overshooting carbUpper on standard targets. Skip rather than
      // overshoot.
      //
      // Exception: carbTarget < 15g — see effectiveCarbUpperForSD above.
      const sdCarbsIfAdded = carbsAssigned + sportsDrink.per_serving.carbs_g * sdServings;
      const sdWouldOvershoot = carbTarget >= 15 && sdCarbsIfAdded > carbUpper + 1e-6;

      if (sdServings > 0 && !sdWouldOvershoot) {
        const sdResult = buildFoodResult(sportsDrink, sdServings);
        resultFoods.push(sdResult);
        carbsAssigned += sdResult.carbs_grams;
        sodiumAssigned += sdResult.sodium_mg;
        fluidAssigned += sdResult.fluids_ml;

        console.log(
          `[DURING-RULES] Sports drink: ${sportsDrink.name} x${sdServings} = ${sdResult.carbs_grams}g carbs, ${sdResult.fluids_ml}ml fluid`
        );
      } else if (sdServings > 0 && sdWouldOvershoot) {
        console.log(
          `[DURING-RULES] Sports drink skipped — min serving (${sdServings}x${sportsDrink.per_serving.carbs_g}g=` +
          `${(sportsDrink.per_serving.carbs_g * sdServings).toFixed(0)}g) would push carbs above upper bound ` +
          `(current=${carbsAssigned.toFixed(0)}g, upper=${carbUpper.toFixed(0)}g)`
        );

        // Fallback: if primary carb alone left us below carbLower and sports drink
        // can hit the FULL target from scratch (without primary carb carbs),
        // replace the approach: un-account primary carb contribution and use
        // sports drink targeting the full carbTarget instead.
        // This handles small-target indivisible-food scenarios (e.g. 30g target +
        // 25g-indivisible gel → 25g/30g = 83% fails; but 2× 15g sports drink = 30g).
        const carbLower = carbTarget * (MACRO_CONSTRAINT_RANGES.carbs.during?.min ?? 0.9);
        const primaryCarbContribution = carbsAssigned - 0; // only primary carb contributed so far
        const inPrimaryOnlyLow = primaryCarbContribution < carbLower;
        if (inPrimaryOnlyLow && sportsDrink.per_serving.carbs_g > 0) {
          // Try sports drink targeting the full carbTarget (ignoring prior primary allocation)
          let sdFullServings = Math.min(
            carbTarget / sportsDrink.per_serving.carbs_g,
            gutCap(sportsDrink),
          );
          sdFullServings = capServingsByUpperBounds(
            sportsDrink,
            sdFullServings,
            0, // treat as if no prior carbs assigned (fresh path)
            sodiumAssigned,
            fluidAssigned,
            carbUpper,
            sodiumUpper,
            fluidUpper,
          );
          const sdFullCarbsIfAdded = sportsDrink.per_serving.carbs_g * sdFullServings;
          if (sdFullServings > 0 && sdFullCarbsIfAdded >= carbLower - 1e-6 && sdFullCarbsIfAdded <= carbUpper + 1e-6) {
            // Remove the primary carb that was previously added to resultFoods and roll back its contribution
            const primaryIndex = resultFoods.findIndex(f => f.food_id === primaryCarb?.id);
            if (primaryIndex >= 0) {
              const prev = resultFoods.splice(primaryIndex, 1)[0];
              carbsAssigned -= prev.carbs_grams;
              sodiumAssigned -= prev.sodium_mg;
              fluidAssigned -= prev.fluids_ml;
            }
            const sdFullResult = buildFoodResult(sportsDrink, sdFullServings);
            resultFoods.push(sdFullResult);
            carbsAssigned += sdFullResult.carbs_grams;
            sodiumAssigned += sdFullResult.sodium_mg;
            fluidAssigned += sdFullResult.fluids_ml;
            console.log(
              `[DURING-RULES] Sports drink (full-target replace): ${sportsDrink.name} x${sdFullServings} = ` +
              `${sdFullResult.carbs_grams}g carbs — replaced primary carb (was below carbLower at ${(primaryCarbContribution).toFixed(0)}g)`
            );
          }
        }
      }
    }
  }

  // ---- STEP 2.5: Carb deficit recovery ----
  // If still under carb target after primary + sports drink, try a SECOND
  // primary carb source (different from what was picked). The trigger fires
  // on any deficit beyond rounding noise — it used to wait for a 20% miss,
  // which let an 18% deficit stand while the electrolyte step then consumed
  // the sodium headroom the closing gap-fill needed (the 45-min ultra stall,
  // 2026-08-06). Shoot for the target; the overshoot guards below keep the
  // recovery serving inside the carb upper band.
  {
    const carbDeficit = carbTarget - carbsAssigned;
    const deficitTrigger = Math.max(2, carbTarget * 0.05);
    if (carbDeficit > deficitTrigger && categorized.primary_carb.length > 1) {
      // Try every eligible alternate (weighted order, without replacement)
      // until one fits: a single weighted pick could land on a food whose
      // minimum serving overshoots the carb upper band and give up, leaving
      // an avoidable deficit for the electrolyte step to entrench.
      const alternates = gutEligible(categorized.primary_carb).filter(f =>
        !primaryCarb || f.id !== primaryCarb.id
      );
      const remaining = [...alternates];
      while (remaining.length > 0) {
        const deficitNow = carbTarget - carbsAssigned;
        if (deficitNow <= deficitTrigger) break;
        const secondaryCarb = pickWeighted(remaining, 'Secondary carb (deficit recovery)');
        if (!secondaryCarb) break;
        remaining.splice(remaining.findIndex(f => f.id === secondaryCarb.id), 1);
        let secServings = Math.min(
          deficitNow / secondaryCarb.per_serving.carbs_g,
          gutCap(secondaryCarb),
        );
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
        // Guard: discrete min-serving rounding must not push carbs above upper bound
        const secCarbsIfAdded = carbsAssigned + secondaryCarb.per_serving.carbs_g * secServings;
        if (secServings > 0 && secCarbsIfAdded <= carbUpper + 1e-6) {
          const secResult = buildFoodResult(secondaryCarb, secServings);
          resultFoods.push(secResult);
          carbsAssigned += secResult.carbs_grams;
          sodiumAssigned += secResult.sodium_mg;
          fluidAssigned += secResult.fluids_ml;

          console.log(
            `[DURING-RULES] Secondary carb: ${secondaryCarb.name} x${secServings} = ${secResult.carbs_grams}g carbs (deficit recovery)`
          );
        } else if (secServings > 0) {
          console.log(
            `[DURING-RULES] Secondary carb ${secondaryCarb.name} skipped — min serving would overshoot carb upper bound ` +
            `(current=${carbsAssigned.toFixed(0)}g, upper=${carbUpper.toFixed(0)}g); trying next alternate`
          );
        }
      }
    }
    // If STILL in deficit (>30%) and sports drink was skipped, try adding one now
    if (carbTarget > 0 && carbTarget - carbsAssigned > carbTarget * 0.3) {
      const sdPool = gutEligible(categorized.sports_drink);
      const anySportsDrink = sdPool.length > 0 ? sdPool[0] : null;
      if (anySportsDrink && !sportsDrink && anySportsDrink.per_serving.carbs_g > 0) {
        const deficit = carbTarget - carbsAssigned;
        let recoveryServings = Math.min(
          deficit / anySportsDrink.per_serving.carbs_g,
          gutCap(anySportsDrink),
        );
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
        // Guard: min-serving rounding must not push carbs above upper bound
        const recoveryCarbsIfAdded = carbsAssigned + anySportsDrink.per_serving.carbs_g * recoveryServings;
        if (recoveryServings > 0 && recoveryCarbsIfAdded <= carbUpper + 1e-6) {
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
      const bikeSolid = pickWeighted(gutEligible(categorized.bike_solid), 'Bike solid selection');
      if (bikeSolid && bikeSolid.per_serving.carbs_g > 0) {
        let bsServings = Math.min(
          remainingCarbs / bikeSolid.per_serving.carbs_g,
          gutCap(bikeSolid),
        );
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
  // Keep filling from the hydration pool until the fluid TARGET is reached —
  // a single pick capped at its max_servings used to strand the total below
  // the range floor even with more hydration foods available (aim at the
  // target, land in range; 2026-07-29).
  {
    // Dedicated hydration foods first, then any other liquid in the pool
    // (e.g. an extra half-serving of sports drink) — capped by the carb and
    // sodium uppers so the top-up never buys fluid at the price of another
    // macro's ceiling.
    // Electrolyte drinks may top up fluid only when even their smallest
    // serving keeps sodium inside the ceiling — a tiny sodium target must
    // not grow an electrolyte item just to buy water.
    const liquidExtras = foods.filter(
      (f) =>
        f.per_serving.water_ml > 0 &&
        !categorized.hydration.includes(f) &&
        (!f.is_electrolyte ||
          sodiumAssigned + f.per_serving.sodium_mg * (f.min_servings ?? 0.5) <=
            sodiumUpper),
    );
    const hydrationPool = [...categorized.hydration, ...liquidExtras];
    while (fluidTarget - fluidAssigned > 0 && hydrationPool.length > 0) {
      const waterFood = hydrationPool.shift();
      if (!waterFood || waterFood.per_serving.water_ml <= 0) continue;

      const existing = resultFoods.find((r) => r.food_id === waterFood.id);
      const alreadyTaken = existing?.quantity ?? 0;
      const maxAdditional = Math.max(
        0,
        (waterFood.max_servings ?? Number.POSITIVE_INFINITY) - alreadyTaken,
      );
      if (maxAdditional <= 0) continue;

      const waterServings = Math.min(
        maxAdditional,
        capServingsByUpperBounds(
          waterFood,
          (fluidTarget - fluidAssigned) / waterFood.per_serving.water_ml,
          carbsAssigned,
          sodiumAssigned,
          fluidAssigned,
          carbUpper,
          sodiumUpper,
          fluidUpper,
        ),
      );

      // clampServings may round UP to the food's minimum increment; never let
      // that push the total past the fluid (or sodium/carb) ceiling.
      if (
        waterServings > 0 &&
        (fluidAssigned + waterFood.per_serving.water_ml * waterServings >
          fluidUpper + 1e-6 ||
          sodiumAssigned + waterFood.per_serving.sodium_mg * waterServings >
            sodiumUpper + 1e-6 ||
          carbsAssigned + waterFood.per_serving.carbs_g * waterServings >
            carbUpper + 1e-6)
      ) {
        continue;
      }

      if (waterServings > 0) {
        const addition = buildFoodResult(waterFood, waterServings);
        if (existing) {
          existing.quantity += addition.quantity;
          existing.carbs_grams += addition.carbs_grams;
          existing.protein_grams += addition.protein_grams;
          existing.fat_grams += addition.fat_grams;
          existing.sodium_mg += addition.sodium_mg;
          existing.fluids_ml += addition.fluids_ml;
          existing.calories += addition.calories;
        } else {
          resultFoods.push(addition);
        }
        fluidAssigned += addition.fluids_ml;
        sodiumAssigned += addition.sodium_mg;
        carbsAssigned += addition.carbs_grams;

        console.log(
          `[DURING-RULES] Hydration: ${waterFood.name} x${waterServings} = ${addition.fluids_ml}ml` +
            (existing ? ' (topped up existing selection)' : ''),
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
      gutLevel: gutTrainingLevel,
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
