/**
 * Shared utilities for during-phase solvers (template + rule-based).
 *
 * Extracted from during-rule-solver.ts to avoid duplication between the
 * template solver and the rule solver.
 */

import { roundToIncrement } from "../utils.ts";
import {
  deriveTimingCategory,
  type Food,
  type FoodResult,
  type TimingCategory,
} from "./types.ts";
import { PREFERENCE_SCORE_MAP } from "./constants.ts";

// ============================================================================
// Types
// ============================================================================

export type ProductCategory =
  | "primary_carb" // gel, chew, drink_mix
  | "sports_drink" // sports_drink (liquid with carbs)
  | "bike_solid" // bar, waffle, real food solids (cycling)
  | "hydration" // water/beverage
  | "electrolyte"; // supplement, electrolyte tablet

export interface CategorizedFoods {
  primary_carb: Food[];
  sports_drink: Food[];
  bike_solid: Food[];
  hydration: Food[];
  electrolyte: Food[];
}

export interface ElectrolytePickResult {
  food: Food;
  servings: number;
  score: number;
  sodium: number;
  fluid: number;
  carbs: number;
}

export interface ElectrolyteBounds {
  sodiumTarget: number;
  sodiumLower: number;
  sodiumUpper: number;
  fluidTarget: number;
  fluidUpper: number;
  carbTarget: number;
  carbUpper: number;
}

// ============================================================================
// Food Categorization
// ============================================================================

export function categorizeFood(food: Food): ProductCategory {
  const pt = food.product_type;

  // Explicit product_type mapping
  if (pt === "gel" || pt === "chew" || pt === "drink_mix") {
    return "primary_carb";
  }
  if (pt === "sports_drink") return "sports_drink";
  if (pt === "bar") return "bike_solid";
  if (pt === "beverage") return "hydration";
  if (pt === "supplement") return "electrolyte";

  // Derived: if liquid with significant carbs → sports_drink
  if (food.is_liquid && food.per_serving.carbs_g > 5) return "sports_drink";

  // Derived: if liquid with no/low carbs → hydration
  if (food.is_liquid) return "hydration";

  // Derived: if electrolyte → electrolyte
  if (food.is_electrolyte) return "electrolyte";

  // Solid food (waffle, real food) → bike_solid
  return "bike_solid";
}

export function categorizeFoods(foods: Food[]): CategorizedFoods {
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
export function secureRandomInt(max: number): number {
  if (max <= 1) return 0;
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  return array[0] % max;
}

/** Sort foods by preference score (liked > willing > neutral).
 *  No secondary tiebreaker — foods with equal preference are shuffled
 *  randomly so that gels, chews, and drink_mix get equal selection chance. */
export function sortByPreference(foods: Food[]): Food[] {
  return [...foods].sort((a, b) => {
    return b.preference_score - a.preference_score;
  });
}

/** Pick a food using random selection among equally-preferred items.
 *  Preserves preference ordering (liked > willing > neutral) but randomizes
 *  among foods with the same preference score for variety.
 *  Uses crypto.getRandomValues() for true randomness in edge functions. */
export function pickWeighted(foods: Food[], label?: string): Food | null {
  if (foods.length === 0) return null;
  if (foods.length === 1) return foods[0];
  const sorted = sortByPreference(foods);
  const bestScore = sorted[0].preference_score;
  const topTier = sorted.filter((f) => f.preference_score === bestScore);
  if (topTier.length > 1) {
    const idx = secureRandomInt(topTier.length);
    const picked = topTier[idx];
    if (label) {
      console.log(
        `[DURING] ${label}: picked ${picked.name} (${
          idx + 1
        }/${topTier.length} candidates: ${
          topTier.map((f) => f.name).join(", ")
        })`,
      );
    }
    return picked;
  }
  return sorted[0];
}

/** Clamp servings to [min, max], respecting indivisibility */
export function clampServings(servings: number, food: Food): number {
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

/** Apply macro high-bound caps to a food's servings, then clamp to valid increment/min/max.
 *
 * After computing the upper-bound cap, `clampServings` rounds to the nearest
 * 0.5 increment. When that rounding would push one or more macros past their
 * upper bound, we floor to the previous increment instead of rounding up.
 * This prevents, for example, a 1.375-serving water cap from being rounded to
 * 1.5 and overshooting the fluid target by 120%. */
export function capServingsByUpperBounds(
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
    const maxBySodium = (sodiumUpper - sodiumAssigned) /
      food.per_serving.sodium_mg;
    if (Number.isFinite(maxBySodium)) capped = Math.min(capped, maxBySodium);
  }
  if (food.per_serving.water_ml > 0 && Number.isFinite(fluidUpper)) {
    const maxByFluid = (fluidUpper - fluidAssigned) / food.per_serving.water_ml;
    if (Number.isFinite(maxByFluid)) capped = Math.min(capped, maxByFluid);
  }

  if (capped <= 0) return 0;

  // Clamp to valid serving increment/min/max.
  const rounded = clampServings(capped, food);

  // Safety check: if rounding UP would push a macro past its upper bound, floor
  // to the previous valid increment instead. If even min_servings violates bounds,
  // choose between min_servings and skipping (0) based on which is CLOSER to target.
  //
  // IMPORTANT: only trigger this path when `rounded` actually violates an upper
  // bound (i.e. the rounded total exceeds carbUpper / fluidUpper / sodiumUpper).
  // Do NOT trigger purely because `rounded > capped` — the capped value represents
  // the "ideal" fractional servings needed to hit the target exactly; rounding it
  // up by 0.5 to the nearest increment is normal and acceptable as long as it stays
  // within the hard upper bound.
  //
  // This is particularly important for water allocation: after the carb foods have
  // been selected, the remaining fluid need is a non-integer number of servings.
  // Rounding to the next 0.5 increment should be accepted unless it would violate
  // fluidUpper. Without this guard we would floor unnecessarily and deliver too
  // little fluid (e.g. 1.5 servings = 360ml instead of 2.0 = 480ml for a 700ml
  // target with fluidUpper=770ml).
  const roundedCarbsCheck = food.per_serving.carbs_g * rounded + carbsAssigned;
  const roundedFluidCheck = food.per_serving.water_ml * rounded + fluidAssigned;
  const roundedSodiumCheck = food.per_serving.sodium_mg * rounded + sodiumAssigned;
  const roundedViolatesBounds = !food.is_indivisible && (
    (food.per_serving.carbs_g > 0 && Number.isFinite(carbUpper) && roundedCarbsCheck > carbUpper + 1e-6) ||
    (food.per_serving.water_ml > 0 && Number.isFinite(fluidUpper) && roundedFluidCheck > fluidUpper + 1e-6) ||
    (food.per_serving.sodium_mg > 0 && Number.isFinite(sodiumUpper) && roundedSodiumCheck > sodiumUpper + 1e-6)
  );

  if (roundedViolatesBounds) {
    const increment = 0.5;
    // Try the floored increment value (next step below rounded)
    const floored = Math.floor(capped / increment) * increment;
    if (floored >= food.min_servings - 1e-6 && floored > 0) {
      // Floored value meets min_servings — check it doesn't violate bounds.
      const carbsCheck = food.per_serving.carbs_g * floored + carbsAssigned;
      const fluidCheck = food.per_serving.water_ml * floored + fluidAssigned;
      const sodiumCheck = food.per_serving.sodium_mg * floored + sodiumAssigned;
      const withinBounds =
        (food.per_serving.carbs_g === 0 || !Number.isFinite(carbUpper) || carbsCheck <= carbUpper + 1e-6) &&
        (food.per_serving.water_ml === 0 || !Number.isFinite(fluidUpper) || fluidCheck <= fluidUpper + 1e-6) &&
        (food.per_serving.sodium_mg === 0 || !Number.isFinite(sodiumUpper) || sodiumCheck <= sodiumUpper + 1e-6);
      if (withinBounds) return floored;
    }
    // Floored value is below min_servings (or itself violates bounds).
    // We must use exactly min_servings or skip entirely (0).
    // Choose based on which is CLOSER to the primary constrained macro target.
    const minS = food.min_servings;
    const withMinFluid = food.per_serving.water_ml * minS + fluidAssigned;
    const fluidTargetProxy = Number.isFinite(fluidUpper) ? fluidUpper / 1.1 : 0; // recover approx target
    // For fluid-only foods (e.g. water), use fluid distance heuristic.
    if (food.per_serving.water_ml > 0 && food.per_serving.carbs_g === 0 && Number.isFinite(fluidUpper)) {
      const deltaWithMin = Math.abs(withMinFluid - fluidTargetProxy);
      const deltaSkip = Math.abs(fluidAssigned - fluidTargetProxy);
      if (deltaWithMin <= deltaSkip) {
        // min_servings gets us closer — accept even if it slightly exceeds fluidUpper
        return minS;
      }
      // Skipping (0) is closer to target — skip this food.
      return 0;
    }
    // For carb-containing foods: accept min_servings if carbs remain within bounds.
    const withMinCarbs = food.per_serving.carbs_g * minS + carbsAssigned;
    if (withMinCarbs <= (Number.isFinite(carbUpper) ? carbUpper : Infinity) + 1e-6) {
      return minS;
    }
    return 0;
  }

  return rounded;
}

/** Enumerate feasible serving candidates for a food.
 *  Indivisible foods use whole servings; divisible foods use 0.5 increments. */
export function getServingCandidates(food: Food): number[] {
  const candidates: number[] = [];
  const max = Math.max(food.min_servings, food.max_servings);
  const start = food.is_indivisible
    ? Math.max(1, Math.ceil(food.min_servings))
    : Math.max(0.5, roundToIncrement(food.min_servings));
  const step = food.is_indivisible ? 1 : 0.5;

  for (let s = start; s <= max + 1e-6; s += step) {
    candidates.push(food.is_indivisible ? Math.round(s) : roundToIncrement(s));
  }

  return candidates;
}

/** Build a FoodResult from a Food and quantity */
export function buildFoodResult(food: Food, quantity: number): FoodResult {
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
    timing: "Throughout activity",
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
// Electrolyte Scoring
// ============================================================================

/**
 * Pick the best electrolyte from a pool using a penalty-based scorer.
 *
 * Scores each candidate at every feasible serving count by computing penalties for:
 * - Sodium gap (undershoot or overshoot)
 * - Fluid overshoot
 * - Carb overshoot
 * - Capsule count (progressive penalty for dry supplements > 2 servings)
 * - Preference bonus (liked electrolytes get a small bonus)
 *
 * Returns the best pick, or null if no electrolyte improves the score.
 */
export function pickBestElectrolyte(
  pool: Food[],
  currentSodium: number,
  currentFluid: number,
  currentCarbs: number,
  bounds: ElectrolyteBounds,
): ElectrolytePickResult | null {
  const {
    sodiumTarget,
    sodiumLower,
    sodiumUpper,
    fluidTarget,
    fluidUpper,
    carbTarget,
    carbUpper,
  } = bounds;
  const MAX_SUPPLEMENT_SERVINGS = 4;

  // Baseline = "add nothing". Must use the SAME formula as the candidate
  // score below (target-relative undershoot, 2x-weighted overshoot), or the
  // `best.score < baselineScore` comparison compares two different scales.
  const baselineSodiumScore = sodiumTarget > 0
    ? (Math.max(0, sodiumTarget - currentSodium) +
      Math.max(0, currentSodium - sodiumUpper) * 2) / sodiumTarget
    : 0;
  const baselineFluidPenalty = fluidTarget > 0 && currentFluid > fluidUpper
    ? ((currentFluid - fluidUpper) / fluidTarget) * 3
    : 0;
  const baselineCarbPenalty = carbTarget > 0 && currentCarbs > carbUpper
    ? ((currentCarbs - carbUpper) / carbTarget) * 2
    : 0;
  const baselineScore = baselineSodiumScore + baselineFluidPenalty +
    baselineCarbPenalty;

  let best: ElectrolytePickResult | null = null;

  for (const electrolyte of pool) {
    if (electrolyte.per_serving.sodium_mg <= 0) continue;

    const candidates = getServingCandidates(electrolyte);
    // Cap supplement (non-liquid) servings to prevent excessive capsule counts
    const cappedCandidates =
      electrolyte.product_type === "supplement" && !electrolyte.is_liquid
        ? candidates.filter((s) => s <= MAX_SUPPLEMENT_SERVINGS)
        : candidates;

    for (const servings of cappedCandidates) {
      const sodium = currentSodium +
        (electrolyte.per_serving.sodium_mg * servings);
      const fluid = currentFluid +
        (electrolyte.per_serving.water_ml * servings);
      const carbs = currentCarbs + (electrolyte.per_serving.carbs_g * servings);
      if (sodium > sodiumUpper + 1e-6) continue;
      if (fluid > fluidUpper + 1e-6) continue;
      if (carbs > carbUpper + 1e-6) continue;

      // Undershoot is measured against sodium_TARGET, not sodium_lower
      // (2026-07-29). Against the floor, every candidate that merely cleared
      // sodiumLower scored an identical 0 penalty, so the tie-break decided
      // selection and a pick sitting at the bottom of the band was as "good"
      // as one sitting on the target. Measuring from the target makes the
      // penalty strictly decrease as the pick approaches it. This also brings
      // Deno into line with the Dart mirror (`client_during_phase_solver.dart`
      // `_pickBestElectrolyte`), which has always used the target here.
      const sodiumPenalty = sodiumTarget > 0
        ? (Math.max(0, sodiumTarget - sodium) +
          Math.max(0, sodium - sodiumUpper) * 2) / sodiumTarget
        : 0;
      const fluidPenalty = fluidTarget > 0 && fluid > fluidUpper
        ? ((fluid - fluidUpper) / fluidTarget) * 3
        : 0;
      const carbPenalty = carbTarget > 0 && carbs > carbUpper
        ? ((carbs - carbUpper) / carbTarget) * 1.5
        : 0;
      // Progressive penalty for dry capsules/supplements > 2 servings
      const capsulePenalty =
        electrolyte.product_type === "supplement" && !electrolyte.is_liquid &&
          servings > 2
          ? 0.05 * (servings - 2)
          : 0;
      const preferenceBonus =
        electrolyte.preference_score >= PREFERENCE_SCORE_MAP.liked ? -0.02 : 0;
      const score = sodiumPenalty + fluidPenalty + carbPenalty +
        capsulePenalty + preferenceBonus;

      if (
        !best || score < best.score ||
        (Math.abs(score - best.score) < 1e-6 &&
          Math.abs(sodiumTarget - sodium) <
            Math.abs(sodiumTarget - best.sodium))
      ) {
        best = { food: electrolyte, servings, score, sodium, fluid, carbs };
      }
    }
  }

  if (!best) return null;
  // Floor rescue: when we started BELOW the band floor, take any pick that
  // clears it even if the score says otherwise. Gated on `currentSodium <
  // sodiumLower` (2026-07-29) — previously this read `best.sodium >=
  // sodiumLower`, which, once the penalty became target-relative, would also
  // accept a *score-worsening* pick made from an already-in-range state and
  // push sodium away from target. Above the floor, the score is the only
  // arbiter and it minimizes distance to target.
  if (currentSodium < sodiumLower - 1e-6 && best.sodium >= sodiumLower) {
    return best;
  }
  return best.score < baselineScore ? best : null;
}

/**
 * Run the two-pass electrolyte selection: pick best source, then if sodium
 * is still below the lower bound, pick a second different source.
 *
 * Mutates resultFoods array and returns updated sodium/fluid/carbs totals.
 */
export function fillElectrolytes(
  electrolytePool: Food[],
  resultFoods: FoodResult[],
  currentSodium: number,
  currentFluid: number,
  currentCarbs: number,
  bounds: ElectrolyteBounds,
  logPrefix: string | null = "[DURING]",
): { sodiumAssigned: number; fluidAssigned: number; carbsAssigned: number } {
  let sodiumAssigned = currentSodium;
  let fluidAssigned = currentFluid;
  let carbsAssigned = currentCarbs;
  const shouldLog = logPrefix !== null && logPrefix.length > 0;

  const remainingSodium = Math.max(0, bounds.sodiumTarget - sodiumAssigned);
  if (remainingSodium <= 0 || electrolytePool.length === 0) {
    return { sodiumAssigned, fluidAssigned, carbsAssigned };
  }

  // First pass
  const firstPick = pickBestElectrolyte(
    electrolytePool,
    sodiumAssigned,
    fluidAssigned,
    carbsAssigned,
    bounds,
  );

  if (firstPick) {
    const elecResult = buildFoodResult(firstPick.food, firstPick.servings);
    resultFoods.push(elecResult);
    sodiumAssigned += elecResult.sodium_mg;
    fluidAssigned += elecResult.fluids_ml;
    carbsAssigned += elecResult.carbs_grams;

    if (shouldLog) {
      console.log(
        `${logPrefix} Electrolyte: ${firstPick.food.name} x${firstPick.servings} = ` +
          `${elecResult.sodium_mg}mg sodium, ${elecResult.fluids_ml}ml fluid`,
      );
    }

    // Second pass: if sodium is still below TARGET, try a different source.
    // Gated on `sodiumLower` until 2026-07-29 — because electrolyte servings
    // are discretized, the first pick routinely lands between the floor and
    // the target, and the retry that would have closed that gap never ran.
    // `pickBestElectrolyte` still refuses anything breaching sodiumUpper and
    // returns null unless the second source genuinely improves the score, so
    // widening the gate can add an item but cannot overshoot the ceiling.
    if (sodiumAssigned < bounds.sodiumTarget) {
      const secondPool = electrolytePool.filter((e) =>
        e.id !== firstPick.food.id
      );
      const secondPick = pickBestElectrolyte(
        secondPool,
        sodiumAssigned,
        fluidAssigned,
        carbsAssigned,
        bounds,
      );
      if (secondPick) {
        const elecResult2 = buildFoodResult(
          secondPick.food,
          secondPick.servings,
        );
        resultFoods.push(elecResult2);
        sodiumAssigned += elecResult2.sodium_mg;
        fluidAssigned += elecResult2.fluids_ml;
        carbsAssigned += elecResult2.carbs_grams;

        if (shouldLog) {
          console.log(
            `${logPrefix} Electrolyte (2nd source): ${secondPick.food.name} x${secondPick.servings} = ` +
              `${elecResult2.sodium_mg}mg sodium, ${elecResult2.fluids_ml}ml fluid`,
          );
        }
      }
    }
  } else if (shouldLog) {
    console.log(
      `${logPrefix} Skipping electrolyte — best option does not improve score`,
    );
  }

  return { sodiumAssigned, fluidAssigned, carbsAssigned };
}
