/**
 * During-phase carb gap-fill — the closing pass of the during cascade.
 *
 * Whatever path produced the plan (pinned system template, unpinned template
 * with an accepted shortfall, or the rule solver), this pass tops the plan up
 * toward the carb target from the same food pool the solvers used. It never
 * removes or replaces anything already in the plan (pins stay honored), and it
 * respects the athlete's gut-training per-hour caps — a `low`-gut athlete with
 * a high target may still land short, which is the honest outcome and is
 * reported via the shortfalls field by the caller.
 *
 * Bounds policy matches the solvers: never push carbs past the upper band, and
 * never let a carb top-up blow through the sodium/fluid upper bands as a side
 * effect.
 */

import {
  type FoodResult,
  type MacroTargets,
  shouldPrioritizeMacroTarget,
} from "./types.ts";
import { calculateTotals } from "./food-utils.ts";
import { MACRO_CONSTRAINT_RANGES } from "./constants.ts";
import { categorizeFood } from "./during-utils.ts";
import {
  addOrUpdateFoodResult,
  type FoodWithConstraints,
  type GutTrainingLevel,
  maxAllowedServingsForDuration,
} from "./during-template-solver.ts";

/** Carb slack (grams) below the point target that the fill tolerates.
 *
 * The fill used to anchor on the 90% shortfall line: it only fired below
 * 90% of target and stopped filling once delivery crossed back over that
 * line, so every gap-filled plan settled ~10% short — "in range", but
 * systematically under-fueled (Lee, 2026-08-06: shoot for the TARGET, the
 * range is a reporting band, not the goal). The fill now aims at the point
 * target itself; this slack only absorbs increment-rounding noise, so a
 * plan 2g under target doesn't grow a whole extra gel. */
const GAP_FILL_SLACK_G = 2;

/** Cap on distinct NEW food items the fill may introduce, so a large deficit
 * can't turn a tidy 3-item formula into a grab bag. Top-ups of items already
 * in the plan don't count against this. */
const MAX_NEW_ITEMS = 3;

export interface GapFillOutcome {
  foods: FoodResult[];
  /** Grams of carbs the fill added (0 when the pass didn't apply). */
  addedCarbs: number;
  applied: boolean;
}

/**
 * Top up a during-phase plan toward its carb target.
 *
 * Ordering: items already in the plan are topped up first (fewest distinct
 * items wins), then new items by preference score, then by carb density.
 * Disliked foods never appear here — the constrained pool already excludes
 * them (honor-pin components and essentials aside), so the fill can't sneak
 * in a food the user rejected.
 *
 * @param durationMinutes when unknown (legacy clients), per-hour gut caps
 *   cannot be computed and only `max_servings` bounds apply.
 */
export function gapFillDuringCarbs(
  currentFoods: FoodResult[],
  pool: FoodWithConstraints[],
  targets: MacroTargets,
  durationMinutes: number | undefined,
  gutTrainingLevel: GutTrainingLevel,
): GapFillOutcome {
  const carbTarget = targets.carbs_g;
  if (carbTarget <= 0 || currentFoods.length === 0 && pool.length === 0) {
    return { foods: currentFoods, addedCarbs: 0, applied: false };
  }

  let totals = calculateTotals(currentFoods);
  if (totals.carbs_g >= carbTarget - GAP_FILL_SLACK_G) {
    return { foods: currentFoods, addedCarbs: 0, applied: false };
  }

  // Upper bounds — same derivation as the template and rule solvers.
  const prioritizeCarbTarget = shouldPrioritizeMacroTarget(targets, "carbs");
  const defaultCarbUpper = carbTarget *
    (MACRO_CONSTRAINT_RANGES.carbs.during?.max ?? 1.1);
  const carbUpper = prioritizeCarbTarget
    ? defaultCarbUpper
    : (targets.carbs_high_g ?? defaultCarbUpper);
  const sodiumUpper = targets.sodium_high_mg ??
    (targets.sodium_mg > 0
      ? targets.sodium_mg * 1.1
      : Number.POSITIVE_INFINITY);
  const fluidUpper = targets.water_high_ml ??
    (targets.water_ml > 0 ? targets.water_ml * 1.1 : Number.POSITIVE_INFINITY);

  const durationHours = durationMinutes && durationMinutes > 0
    ? durationMinutes / 60
    : null;

  const foods = currentFoods.map((f) => ({ ...f }));
  const inPlanIds = new Set(foods.map((f) => f.food_id));

  // Candidate carb sources: carb-contributing fuel foods. Hydration and
  // electrolyte categories are excluded — their incidental carbs are exactly
  // the "couple of salt tabs = 8g" failure this pass exists to prevent from
  // being the plan's only carbs.
  const carbSources = pool
    .filter((f) => {
      if (f.per_serving.carbs_g <= 0) return false;
      const category = categorizeFood(f);
      return category !== "electrolyte" && category !== "hydration";
    })
    .sort((a, b) => {
      const aIn = inPlanIds.has(a.id) ? 1 : 0;
      const bIn = inPlanIds.has(b.id) ? 1 : 0;
      if (aIn !== bIn) return bIn - aIn;
      if (a.preference_score !== b.preference_score) {
        return b.preference_score - a.preference_score;
      }
      return b.per_serving.carbs_g - a.per_serving.carbs_g;
    });

  let addedCarbs = 0;
  let newItemsAdded = 0;

  for (const food of carbSources) {
    totals = calculateTotals(foods);
    const deficit = carbTarget - GAP_FILL_SLACK_G - totals.carbs_g;
    if (deficit <= 1e-6) break;

    const existing = foods.find((r) => r.food_id === food.id);
    if (!existing && newItemsAdded >= MAX_NEW_ITEMS) continue;
    const existingServings = existing?.quantity ?? 0;

    // Gut-training / duration cap, falling back to max_servings when the
    // workout duration is unknown.
    const capServings = durationHours !== null
      ? maxAllowedServingsForDuration(food, durationHours, gutTrainingLevel)
      : food.max_servings;
    let maxAdditional = Math.max(
      0,
      Math.min(capServings, food.max_servings) - existingServings,
    );
    if (maxAdditional <= 0) continue;

    // Headroom from the macro upper bounds.
    if (Number.isFinite(carbUpper)) {
      maxAdditional = Math.min(
        maxAdditional,
        (carbUpper - totals.carbs_g) / food.per_serving.carbs_g,
      );
    }
    if (food.per_serving.sodium_mg > 0 && Number.isFinite(sodiumUpper)) {
      maxAdditional = Math.min(
        maxAdditional,
        (sodiumUpper - totals.sodium_mg) / food.per_serving.sodium_mg,
      );
    }
    if (food.per_serving.water_ml > 0 && Number.isFinite(fluidUpper)) {
      maxAdditional = Math.min(
        maxAdditional,
        (fluidUpper - totals.water_ml) / food.per_serving.water_ml,
      );
    }
    if (maxAdditional <= 0) continue;

    // Aim for the FULL target (not just the 90% trigger line), rounded to
    // the food's increment, floored back if that exceeds the allowed max.
    const fullDeficit = carbTarget - totals.carbs_g;
    const desired = fullDeficit / food.per_serving.carbs_g;
    const increment = food.min_increment ?? (food.is_indivisible ? 1 : 0.5);
    let servings = Math.ceil(Math.min(desired, maxAdditional) / increment - 1e-9) *
      increment;
    if (servings > maxAdditional + 1e-9) {
      servings = Math.floor(maxAdditional / increment + 1e-9) * increment;
    }

    // A NEW item must still respect its min_servings floor.
    if (!existing && servings > 0 && servings < food.min_servings) {
      const minRounded = Math.ceil(food.min_servings / increment - 1e-9) *
        increment;
      if (minRounded <= maxAdditional + 1e-9) {
        servings = minRounded;
      } else {
        continue;
      }
    }
    if (servings <= 0) continue;

    if (!existing) newItemsAdded++;
    addOrUpdateFoodResult(foods, food, servings);
    addedCarbs += food.per_serving.carbs_g * servings;
    console.log(
      `[DURING-GAP-FILL] ${existing ? "Topped up" : "Added"} ${food.name} ` +
        `+${servings} servings (+${
          (food.per_serving.carbs_g * servings).toFixed(0)
        }g carbs)`,
    );
  }

  if (addedCarbs > 0) {
    const finalTotals = calculateTotals(foods);
    console.log(
      `[DURING-GAP-FILL] Fill complete: +${addedCarbs.toFixed(0)}g carbs, ` +
        `now ${finalTotals.carbs_g.toFixed(0)}g/${carbTarget}g`,
    );
    return { foods, addedCarbs, applied: true };
  }

  console.log(
    `[DURING-GAP-FILL] No fill possible (pool exhausted or caps binding): ` +
      `${totals.carbs_g.toFixed(0)}g/${carbTarget}g`,
  );
  return { foods: currentFoods, addedCarbs: 0, applied: false };
}
