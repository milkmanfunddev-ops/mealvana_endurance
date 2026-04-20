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

/** Apply macro high-bound caps to a food's servings, then clamp to valid increment/min/max. */
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
  return clampServings(capped, food);
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

  const baselineSodiumScore = sodiumTarget > 0
    ? (Math.max(0, sodiumLower - currentSodium) +
      Math.max(0, currentSodium - sodiumUpper)) / sodiumTarget
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

      const sodiumPenalty = sodiumTarget > 0
        ? (Math.max(0, sodiumLower - sodium) +
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
  if (best.sodium >= sodiumLower) return best;
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

    // Second pass: if sodium still below lower bound, try a different source
    if (sodiumAssigned < bounds.sodiumLower) {
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
