/**
 * Before Phase — Post-Pin-Overlay Reconciliation
 *
 * Algorithm C generates meal + snack + top_up as a coherent set: the top_up's
 * drink and electrolyte are sized to fill the exact fluid/sodium gap left by
 * Algorithm C's own meal + snack. When the pin overlay then replaces meal
 * and/or snack with the user's personal formulas (a different macro profile),
 * the top_up keeps its now-stale gap-fill items and the phase totals can land
 * outside every range at once (bug 3abe3fdb754c818c93e8fbbd801dae8e:
 * carbs 55 g under a 66–84 g floor while fluids 16 oz and sodium 581 mg blew
 * their ceilings).
 *
 * This pass runs only when at least one slot was pin-overlaid. It re-sums the
 * phase and, touching ONLY non-pinned slots:
 *   1. trims drink fluid down toward the phase fluid target when the total is
 *      above the ceiling;
 *   2. trims electrolyte sodium down toward the phase sodium target when the
 *      total is above the ceiling;
 *   3. adds universal carb add-ons (banana / dates / applesauce / raisins —
 *      the same Pass 1.5 pool) when the total is below the carb floor,
 *      aiming at the carb target without breaching any ceiling.
 *
 * Pass/fail is the calculated range and scaling aims at the point target —
 * never at the nearest boundary, and with no percentage grace
 * (⚙️ Engineering Decisions 2026-07-28, S7). Pinned slots are honored
 * unconditionally, so a pin that by itself exceeds a phase ceiling is
 * reported in the log rather than trimmed.
 */

import type { FoodResult } from "../_shared/nutrition/types.ts";
import type {
  BeforePhaseResult,
  SubPhaseResult,
} from "../_shared/nutrition/templates/types.ts";
import {
  type AddOn,
  APPLESAUCE_CARBS,
  APPLESAUCE_FLUID,
  APPLESAUCE_SODIUM,
  BANANA_CARBS,
  BANANA_FLUID,
  BANANA_SODIUM,
  DATES_CARBS,
  DATES_FLUID,
  DATES_SODIUM,
  type PreWorkoutTargets,
  RAISINS_CARBS,
  RAISINS_FLUID,
  RAISINS_SODIUM,
} from "../generate-macros-v4/types.ts";
import { addOnToFoodResult } from "./before-phase-explosion.ts";
import { getSubPhaseTimingLabel } from "./sub-phase-timing.ts";

type SlotName = "meal" | "snack" | "top_up";

const SLOT_ORDER: SlotName[] = ["top_up", "snack", "meal"];

interface PhaseTotals {
  carbs: number;
  sodium: number;
  fluid: number;
}

function sumTotals(result: BeforePhaseResult): PhaseTotals {
  const totals: PhaseTotals = { carbs: 0, sodium: 0, fluid: 0 };
  for (const slot of SLOT_ORDER) {
    const sub = result[slot];
    if (!sub) continue;
    for (const f of sub.foods) {
      totals.carbs += f.carbs_grams;
      totals.sodium += f.sodium_mg;
      totals.fluid += f.fluids_ml;
    }
  }
  return totals;
}

function roundHalf(value: number): number {
  return Math.round(value * 2) / 2;
}

/** Rescale a food to a new quantity, keeping per-serving macros. */
function rescaleFood(food: FoodResult, newQuantity: number): void {
  if (food.quantity <= 0) return;
  const factor = newQuantity / food.quantity;
  food.quantity = newQuantity;
  food.carbs_grams = Math.round(food.carbs_grams * factor * 10) / 10;
  food.protein_grams = Math.round(food.protein_grams * factor * 10) / 10;
  food.fat_grams = Math.round(food.fat_grams * factor * 10) / 10;
  food.sodium_mg = Math.round(food.sodium_mg * factor * 10) / 10;
  food.fluids_ml = Math.round(food.fluids_ml * factor * 10) / 10;
  food.calories = Math.round(
    (food.carbs_grams * 4) + (food.protein_grams * 4) + (food.fat_grams * 9),
  );
}

/**
 * Trim one macro toward its point target by reducing matching foods in
 * non-pinned slots. Quantities move in 0.5-serving steps; a food trimmed to
 * zero is removed. Never trims the total below the range floor.
 */
function trimMacroTowardTarget(
  result: BeforePhaseResult,
  pinnedSlots: Set<SlotName>,
  read: (f: FoodResult) => number,
  matches: (f: FoodResult) => boolean,
  total: number,
  target: number,
  low: number,
  high: number,
  logLabel: string,
): number {
  let current = total;
  for (const slot of SLOT_ORDER) {
    if (current <= target) break;
    if (pinnedSlots.has(slot)) continue;
    const sub = result[slot];
    if (!sub) continue;

    for (const food of [...sub.foods]) {
      if (current <= target) break;
      const contribution = read(food);
      if (contribution <= 0 || food.quantity <= 0 || !matches(food)) continue;

      const perServing = contribution / food.quantity;

      // Enumerate 0.5-serving reductions and pick the one that (1) gets the
      // total inside the ceiling — being in range beats staying near target —
      // then (2) lands closest to the point target. Never drop below the
      // range floor.
      let bestSteps = 0;
      let bestBreach = Math.max(0, current - high);
      let bestDistance = Math.abs(current - target);
      for (
        let steps = 0.5;
        steps <= food.quantity + 1e-9;
        steps += 0.5
      ) {
        const candidateTotal = current - steps * perServing;
        if (candidateTotal < low - 1e-9) break;
        const breach = Math.max(0, candidateTotal - high);
        const distance = Math.abs(candidateTotal - target);
        if (
          breach < bestBreach - 1e-9 ||
          (Math.abs(breach - bestBreach) < 1e-9 &&
            distance < bestDistance - 1e-9)
        ) {
          bestBreach = breach;
          bestDistance = distance;
          bestSteps = steps;
        }
      }
      if (bestSteps <= 0) continue;

      const newQuantity = roundHalf(Math.max(0, food.quantity - bestSteps));
      const removed = (food.quantity - newQuantity) * perServing;
      if (removed <= 0) continue;

      if (newQuantity <= 0) {
        sub.foods.splice(sub.foods.indexOf(food), 1);
        console.log(
          `[PLAN-V3] Reconcile: removed ${food.display_name ?? food.food_id} ` +
            `from ${slot} (−${removed.toFixed(0)} ${logLabel})`,
        );
      } else {
        rescaleFood(food, newQuantity);
        console.log(
          `[PLAN-V3] Reconcile: reduced ${food.display_name ?? food.food_id} ` +
            `in ${slot} to ${newQuantity} servings (−${removed.toFixed(0)} ${logLabel})`,
        );
      }
      current -= removed;
    }
  }
  return current;
}

function makeAddOnPool(disliked: Set<string>): Array<{
  name: string;
  addOn: AddOn;
}> {
  // Same universal pool as Algorithm C's Pass 1.5: vegan, gluten-free, and
  // free of the common allergens the phase filters on, so only dislikes and
  // macro headroom gate them here.
  const pool: Array<{ name: string; addOn: AddOn }> = [
    {
      name: "banana",
      addOn: {
        type: "banana",
        carbs_g: BANANA_CARBS,
        sodium_mg: BANANA_SODIUM,
        fluid_ml: BANANA_FLUID,
        servings: 1,
      },
    },
    {
      name: "dates",
      addOn: {
        type: "dates",
        carbs_g: DATES_CARBS,
        sodium_mg: DATES_SODIUM,
        fluid_ml: DATES_FLUID,
        servings: 1,
      },
    },
    {
      name: "applesauce",
      addOn: {
        type: "applesauce",
        carbs_g: APPLESAUCE_CARBS,
        sodium_mg: APPLESAUCE_SODIUM,
        fluid_ml: APPLESAUCE_FLUID,
        servings: 1,
      },
    },
    {
      name: "raisins",
      addOn: {
        type: "raisins",
        carbs_g: RAISINS_CARBS,
        sodium_mg: RAISINS_SODIUM,
        fluid_ml: RAISINS_FLUID,
        servings: 1,
      },
    },
  ];
  return pool.filter((p) => !disliked.has(p.name));
}

/**
 * Reconcile the BEFORE phase after pinned personal formulas replaced one or
 * more slots. Mutates `result` in place. No-op when nothing was pinned.
 */
export function reconcileBeforePhaseAfterPins(
  result: BeforePhaseResult,
  targets: PreWorkoutTargets,
  pinnedSlots: Set<SlotName>,
  dislikedFoods?: Set<string>,
): void {
  if (pinnedSlots.size === 0) return;

  let totals = sumTotals(result);
  console.log(
    `[PLAN-V3] Reconcile (post-pin): totals carbs=${totals.carbs.toFixed(1)}g ` +
      `[${targets.carbs_low_g}-${targets.carbs_high_g}, target ${targets.carbs_g}], ` +
      `sodium=${totals.sodium.toFixed(0)}mg [${targets.sodium_low_mg}-${targets.sodium_high_mg}, target ${targets.sodium_mg}], ` +
      `fluid=${totals.fluid.toFixed(0)}ml [${targets.water_low_ml}-${targets.water_high_ml}, target ${targets.water_ml}]`,
  );

  // 1. Fluid over ceiling → trim drinks toward the fluid target.
  if (targets.water_ml > 0 && totals.fluid > targets.water_high_ml) {
    totals.fluid = trimMacroTowardTarget(
      result,
      pinnedSlots,
      (f) => f.fluids_ml,
      (f) => (f.is_drink ?? false) || (f.is_liquid ?? false),
      totals.fluid,
      targets.water_ml,
      targets.water_low_ml,
      targets.water_high_ml,
      "ml fluid",
    );
  }

  // 2. Sodium over ceiling → trim electrolyte supplements toward the target.
  if (targets.sodium_mg > 0 && totals.sodium > targets.sodium_high_mg) {
    totals.sodium = trimMacroTowardTarget(
      result,
      pinnedSlots,
      (f) => f.sodium_mg,
      (f) => f.is_electrolyte ?? false,
      totals.sodium,
      targets.sodium_mg,
      targets.sodium_low_mg,
      targets.sodium_high_mg,
      "mg sodium",
    );
  }

  // 3. Carbs under floor → add universal carb add-ons, aiming at the target.
  if (targets.carbs_g > 0 && totals.carbs < targets.carbs_low_g) {
    const host = SLOT_ORDER.find((s) => !pinnedSlots.has(s) && result[s]) ??
      SLOT_ORDER.find((s) => result[s] && s === "top_up");
    if (!host || pinnedSlots.has(host)) {
      console.warn(
        `[PLAN-V3] Reconcile: carbs ${totals.carbs.toFixed(1)}g below floor ` +
          `${targets.carbs_low_g}g but every slot is pinned — leaving plan as pinned`,
      );
    } else {
      const hostSub = result[host] as SubPhaseResult;
      const pool = makeAddOnPool(dislikedFoods ?? new Set());
      let guard = 0;
      while (totals.carbs < targets.carbs_g && guard < 10) {
        guard++;
        let bestPick: { name: string; addOn: AddOn } | null = null;
        let bestDistance = Math.abs(targets.carbs_g - totals.carbs);
        for (const candidate of pool) {
          const newCarbs = totals.carbs + candidate.addOn.carbs_g;
          const newSodium = totals.sodium + candidate.addOn.sodium_mg;
          const newFluid = totals.fluid + candidate.addOn.fluid_ml;
          if (newCarbs > targets.carbs_high_g + 1e-9) continue;
          // A pinned slot may already hold a macro above its ceiling (pins
          // are honored unconditionally); that pre-existing overage must not
          // veto zero-contribution add-ons. Block only additions that would
          // push the macro further past the ceiling.
          if (
            targets.sodium_mg > 0 &&
            candidate.addOn.sodium_mg > 0 &&
            newSodium > targets.sodium_high_mg
          ) {
            continue;
          }
          if (
            targets.water_ml > 0 &&
            candidate.addOn.fluid_ml > 0 &&
            newFluid > targets.water_high_ml
          ) {
            continue;
          }
          const distance = Math.abs(targets.carbs_g - newCarbs);
          if (distance < bestDistance - 1e-9) {
            bestDistance = distance;
            bestPick = candidate;
          }
        }
        if (!bestPick) break;

        const foodResult = addOnToFoodResult(
          bestPick.addOn,
          hostSub.foods[0]?.timing ?? getSubPhaseTimingLabel(host),
        );
        // Merge with an identical add-on already added this pass.
        const existing = hostSub.foods.find(
          (f) => f.food_id === foodResult.food_id,
        );
        if (existing) {
          rescaleFood(existing, existing.quantity + foodResult.quantity);
        } else {
          hostSub.foods.push(foodResult);
        }
        totals.carbs += bestPick.addOn.carbs_g;
        totals.sodium += bestPick.addOn.sodium_mg;
        totals.fluid += bestPick.addOn.fluid_ml;
        console.log(
          `[PLAN-V3] Reconcile: added ${bestPick.name} to ${host} ` +
            `(+${bestPick.addOn.carbs_g}g carbs → ${totals.carbs.toFixed(1)}g)`,
        );
      }
    }
  }

  totals = sumTotals(result);
  const issues: string[] = [];
  if (targets.carbs_g > 0 && totals.carbs < targets.carbs_low_g) {
    issues.push(`carbs ${totals.carbs.toFixed(1)}g < floor ${targets.carbs_low_g}g`);
  }
  if (targets.carbs_g > 0 && totals.carbs > targets.carbs_high_g) {
    issues.push(`carbs ${totals.carbs.toFixed(1)}g > ceiling ${targets.carbs_high_g}g`);
  }
  if (targets.sodium_mg > 0 && totals.sodium > targets.sodium_high_mg) {
    issues.push(
      `sodium ${totals.sodium.toFixed(0)}mg > ceiling ${targets.sodium_high_mg}mg`,
    );
  }
  if (targets.water_ml > 0 && totals.fluid > targets.water_high_ml) {
    issues.push(
      `fluid ${totals.fluid.toFixed(0)}ml > ceiling ${targets.water_high_ml}ml`,
    );
  }
  if (issues.length > 0) {
    console.warn(
      `[PLAN-V3] Reconcile: phase still out of range after reconciliation ` +
        `(pinned slots: ${[...pinnedSlots].join(", ")}): ${issues.join("; ")}`,
    );
  } else {
    console.log(
      `[PLAN-V3] Reconcile: phase in range — carbs=${totals.carbs.toFixed(1)}g, ` +
        `sodium=${totals.sodium.toFixed(0)}mg, fluid=${totals.fluid.toFixed(0)}ml`,
    );
  }
}
