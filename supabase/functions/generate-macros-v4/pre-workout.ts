/**
 * Algorithm C: Comfort-Capped Hybrid — Pre-workout food selection
 *
 * Ported from _archived/supabase/functions/_test/pre-workout-comparison/algorithms/algo-c-comfort-cap.ts
 * for production use in generate-macros-v4.
 *
 * Flow:
 * 1. Calculate target ranges (carbs, protein, sodium, hydration)
 * 2. For each sub-phase: score templates → pick best → optional stack
 * 3. After food selection: pick drink + electrolyte independently
 * 4. Return targets + ranges + food selections
 */

import {
  type PreWorkoutTemplate,
  type PreWorkoutTargets,
  type SubPhaseTargets,
  type SubPhaseType,
  type PlanState,
  type TemplateSelection,
  type PreWorkoutPhaseResult,
  type PreWorkoutShortfall,
  type AddOn,
  BUDGET_SPLITS,
  BANANA_CARBS,
  BANANA_SODIUM,
  BANANA_FLUID,
  SPORTS_DRINK_CARBS,
  SPORTS_DRINK_SODIUM,
  SPORTS_DRINK_FLUID,
  MIN_TOP_UP_FLUID_ML,
  DATES_CARBS,
  DATES_SODIUM,
  DATES_FLUID,
  APPLESAUCE_CARBS,
  APPLESAUCE_SODIUM,
  APPLESAUCE_FLUID,
  RAISINS_CARBS,
  RAISINS_SODIUM,
  RAISINS_FLUID,
} from './types.ts';

import {
  defaultFormulaDecision,
  logFormulaCascade,
} from '../_shared/nutrition/formula-decision.ts';

import {
  ADDON_GAP_THRESHOLD,
  STACK_THRESHOLD,
  CROSS_PHASE_EXEMPT_FOODS,
  ALLERGEN_ALIASES,
  COMPONENT_ALLERGEN_HINTS,
  normalizeToken,
} from './pre-workout-constants.ts';

import {
  scoreFormula,
  pickBestFormula,
} from './pre-workout-scoring.ts';

// ============================================================================
// Utility Helpers
// ============================================================================

function snapToHalf(value: number): number {
  return Math.round(value * 2) / 2;
}

function normalizeAllergen(value: string): string {
  const normalized = normalizeToken(value);
  return ALLERGEN_ALIASES[normalized] ?? normalized;
}

function inferAllergensFromComponents(componentFoodNames: string[] = []): Set<string> {
  const inferred = new Set<string>();
  for (const name of componentFoodNames) {
    const normalized = normalizeToken(name);
    const hinted = COMPONENT_ALLERGEN_HINTS[normalized] ?? [];
    for (const a of hinted) inferred.add(a);
  }
  return inferred;
}

function wouldExceedHighs(
  state: PlanState,
  addCarbs: number,
  addProtein: number,
  addSodium: number,
  addFluid: number,
): boolean {
  // Protein is intentionally NOT considered (decided 2026-07-29: protein is
  // not a solver constraint anywhere; the addProtein param is kept so call
  // sites stay unchanged).
  void addProtein;
  return (
    (state.carbs_delivered + addCarbs) > (state.carbs_high + 1e-6) ||
    (state.sodium_delivered + addSodium) > (state.sodium_high + 1e-6) ||
    (state.fluid_delivered + addFluid) > (state.fluid_high + 1e-6)
  );
}

function templateCarbs(t: PreWorkoutTemplate, servings: number): number {
  return t.carbs_per_serving * servings;
}

function makeSelection(t: PreWorkoutTemplate, servings: number): TemplateSelection {
  return {
    id: t.id,
    name: t.name,
    base_category: t.base_category,
    serving_unit: t.serving_unit,
    servings,
    carbs_g: Math.round(t.carbs_per_serving * servings * 10) / 10,
    protein_g: Math.round(t.protein_per_serving * servings * 10) / 10,
    fat_g: Math.round(t.fat_per_serving * servings * 10) / 10,
    sodium_mg: Math.round(t.sodium_mg * servings * 10) / 10,
    fluid_ml: Math.round(t.fluid_ml * servings * 10) / 10,
    component_food_names: t.component_food_names ?? [],
    component_quantities: t.component_quantities ?? {},
  };
}

function makeBananaAddOn() {
  return { type: 'banana' as const, carbs_g: BANANA_CARBS, sodium_mg: BANANA_SODIUM, fluid_ml: BANANA_FLUID, servings: 1 };
}

// Pass 1.5 universal fallback add-ons (#15). All three are vegan, gluten-free,
// and free of the common allergens we filter on, so the only gating needed in
// Pass 1.5 is dislikes + macro headroom.
function makeDatesAddOn() {
  return { type: 'dates' as const, carbs_g: DATES_CARBS, sodium_mg: DATES_SODIUM, fluid_ml: DATES_FLUID, servings: 1 };
}

function makeApplesauceAddOn() {
  return { type: 'applesauce' as const, carbs_g: APPLESAUCE_CARBS, sodium_mg: APPLESAUCE_SODIUM, fluid_ml: APPLESAUCE_FLUID, servings: 1 };
}

function makeRaisinsAddOn() {
  return { type: 'raisins' as const, carbs_g: RAISINS_CARBS, sodium_mg: RAISINS_SODIUM, fluid_ml: RAISINS_FLUID, servings: 1 };
}

interface FallbackFoodSpec {
  name: 'dates' | 'applesauce' | 'raisins';
  carbs: number;
  sodium: number;
  fluid: number;
  make: () => AddOn;
}

const PASS_1_5_FALLBACK_FOODS: FallbackFoodSpec[] = [
  { name: 'dates', carbs: DATES_CARBS, sodium: DATES_SODIUM, fluid: DATES_FLUID, make: makeDatesAddOn },
  { name: 'applesauce', carbs: APPLESAUCE_CARBS, sodium: APPLESAUCE_SODIUM, fluid: APPLESAUCE_FLUID, make: makeApplesauceAddOn },
  { name: 'raisins', carbs: RAISINS_CARBS, sodium: RAISINS_SODIUM, fluid: RAISINS_FLUID, make: makeRaisinsAddOn },
];

function makeSportsDrinkAddOn(servings: number = 1) {
  return {
    type: 'sports_drink' as const,
    carbs_g: Math.round(SPORTS_DRINK_CARBS * servings * 10) / 10,
    sodium_mg: Math.round(SPORTS_DRINK_SODIUM * servings * 10) / 10,
    fluid_ml: Math.round(SPORTS_DRINK_FLUID * servings * 10) / 10,
    servings,
  };
}

// ============================================================================
// SSOT constants — pre-workout carbohydrate v2 / hydration v6
// ============================================================================
// Sources: docs/ssot/spec/fueling/pre-workout-carbs.md (v2),
//          docs/ssot/spec/fueling/pre-workout-hydration.md (v6),
//          docs/ssot/spec/fueling/pre-workout-sodium.md (v3).
// Values are literature magnitudes; none is derived, scaled or averaged here.

/** min — meal tier opens here (carbs v2). */
const TIER_MEAL_MIN = 120.0;
/** min — top-off tier closes here (carbs v2). */
const TIER_TOPOFF_MAX = 30.0;
/** min — outer edge of Thomas 2016's carbohydrate window. */
const WINDOW_MAX = 240.0;
const SHARE_MEAL = 0.60;
const SHARE_SNACK = 0.30;
const SHARE_TOPOFF = 0.10;
const SHARE_SNACK_NM = 0.75;
const SHARE_TOPOFF_NM = 0.25;
/** ±12.5 % — the one tolerance used for every carb number. */
const TIER_TOL = 0.125;

/** ml — start-line anchor (J&G 2019 p. 493). */
const A0_ML = 250.0;
/** ml — gastric volume tolerated at t = 0 (NATA 2017). */
const R_CEILING = 400.0;
/** per min — 3.2 h⁻¹ first-order emptying (Mudie 2014). MUST be computed. */
const K = 3.2 / 60;
/** min — lower edge of Thomas 2016's fluid window. */
const T_REF = 120.0;
/** ml/kg — dark-urine correction target (ACSM 2007, midpoint of 3–5). */
const TOPUP_ML_KG = 4.0;
/** ml/kg — top of ACSM 2007's 3–5 band. */
const TOPUP_HIGH_ML_KG = 5.0;
/** ml/kg — ACSM 2007's own maximum for the same protocol. */
const PLAN_CAP_ML_KG = 12.0;

// Cross-spec pin (hydration invariant 10 / carbs invariant 10). The two
// constants are equal for unrelated reasons and are pinned by assertion, never
// derived one from the other. Fail loudly rather than silently diverge.
if (T_REF !== TIER_MEAL_MIN) {
  throw new Error(
    `Cross-spec pin violated: T_REF (${T_REF}) !== TIER_MEAL_MIN (${TIER_MEAL_MIN})`,
  );
}

/** Tier names shared by the carbohydrate and hydration plans. */
export type PreWorkoutTierName = 'meal' | 'snack' | 'top_off';

// ============================================================================
// Pre-Workout Carbohydrates (SSOT v2)
// ============================================================================

export interface PreWorkoutCarbsInput {
  bodyWeightKg: number;
  timeBeforeWorkoutMin: number;
  workoutDurationMin: number;
  isFasted?: boolean;
}

export interface PreWorkoutCarbTier {
  tier: PreWorkoutTierName;
  carbs_g: number;
  range_low_g: number;
  range_high_g: number;
  /** Food-composition class; value set defined by pre-workout-food-composition.md. */
  composition: PreWorkoutTierName;
}

export interface PreWorkoutCarbResult {
  carbs_g: number;
  carbs_low_g: number;
  carbs_high_g: number;
  /** Ordered, furthest-out first. Empty only on the `isFasted` path. */
  tiers: PreWorkoutCarbTier[];
  target_basis: 'evidenced_band' | 'design_choice' | 'none';
}

/**
 * The band the FOOD SOLVER portions against — `carbsG ± TIER_TOL`.
 *
 * This is deliberately NOT the plan band. `pre-workout-carbs.md` v2 gives the
 * two ranges two different jobs and forbids conflating them:
 *
 * - `[carbsLowG, carbsHighG]` is the **plan band** — what the athlete is shown.
 *   In the cited regime it is Thomas's `[1·BW, 4·BW]`, which is headroom, not a
 *   portioning instruction. Feeding it to the solver's rejection ceiling lets a
 *   65 kg athlete's 195 g plan accept 260 g of food.
 * - `TIER_TOL` ±12.5 % is a **solver tolerance** — a constraint on how the food
 *   engine portions, never a goal for the athlete. It is the same tolerance the
 *   per-tier `range_low_g`/`range_high_g` carry, and because the tier portions
 *   sum to the total, the tier windows sum to exactly this band.
 *
 * One helper so the overlay's `solver_targets` and `selectPreWorkoutFoods`
 * cannot drift apart.
 */
function solverCarbBand(carbsG: number): { low: number; high: number } {
  return { low: carbsG * (1 - TIER_TOL), high: carbsG * (1 + TIER_TOL) };
}

function makeCarbTier(tier: PreWorkoutTierName, carbsG: number): PreWorkoutCarbTier {
  return {
    tier,
    carbs_g: carbsG,
    range_low_g: carbsG * (1 - TIER_TOL),
    range_high_g: carbsG * (1 + TIER_TOL),
    composition: tier,
  };
}

/**
 * Pre-workout carbohydrate plan — SSOT `pre-workout-carbs.md` v2.
 *
 * The engine NEVER rounds; rounding is a display concern. The spec never
 * gates — only `isFasted` returns nothing.
 */
export function calculatePreWorkoutCarbs(
  input: PreWorkoutCarbsInput,
): PreWorkoutCarbResult {
  const { bodyWeightKg, timeBeforeWorkoutMin, workoutDurationMin } = input;
  const isFasted = input.isFasted ?? false;

  // D-001 — fasted returns zeros and an EMPTY tiers array (never null).
  if (isFasted) {
    return {
      carbs_g: 0,
      carbs_low_g: 0,
      carbs_high_g: 0,
      tiers: [],
      target_basis: 'none',
    };
  }

  const t = Math.max(timeBeforeWorkoutMin, 0);
  const BW = bodyWeightKg;

  // v1's max(0.5, …) floor removed (D-002 superseded).
  const carbPerKg = Math.min(t / 60, 4.0);
  const total = BW * carbPerKg;

  let meal = 0;
  let snack = 0;
  let topOff = 0;
  if (t >= TIER_MEAL_MIN) {
    meal = SHARE_MEAL * total;
    snack = SHARE_SNACK * total;
    topOff = SHARE_TOPOFF * total;
  } else if (t >= TIER_TOPOFF_MAX) {
    snack = SHARE_SNACK_NM * total;
    topOff = SHARE_TOPOFF_NM * total;
  } else {
    topOff = total;
  }

  // Tier membership: `meal` iff t >= 120; `snack` iff t >= 30; `top_off`
  // always (carrying 0 at t = 0 — a real statement, not an absence).
  const tiers: PreWorkoutCarbTier[] = [];
  if (t >= TIER_MEAL_MIN) tiers.push(makeCarbTier('meal', meal));
  if (t >= TIER_TOPOFF_MAX) tiers.push(makeCarbTier('snack', snack));
  tiers.push(makeCarbTier('top_off', topOff));

  const inWindow = t >= 60 && t <= WINDOW_MAX && workoutDurationMin >= 60;
  const carbsLow = inWindow ? 1.0 * BW : total * (1 - TIER_TOL);
  const carbsHigh = inWindow ? 4.0 * BW : total * (1 + TIER_TOL);

  return {
    carbs_g: total,
    carbs_low_g: carbsLow,
    carbs_high_g: carbsHigh,
    tiers,
    target_basis: inWindow ? 'evidenced_band' : 'design_choice',
  };
}

// ============================================================================
// Target Calculation
// ============================================================================

/**
 * Calculate pre-workout macro targets with ranges.
 * V4: adds carb/protein ranges on top of V3's sodium/hydration ranges.
 *
 * Carbohydrate is delegated to `calculatePreWorkoutCarbs` (SSOT v2) and
 * rounded to int only at this map boundary, so existing consumers of the
 * `PreWorkoutTargets` map keep working. Protein/fat/sodium/water and
 * `meal_type` still feed food selection and are out of the v6/v2/v3 bundle —
 * except that their tier boundaries now agree with the SSOT's 120/30.
 */
export function calculatePreWorkoutTargets(
  weightKg: number,
  hoursBefore: number,
  isFasted: boolean,
  sweatSodiumCat: string,
  envLabel: string,
  /** Optional — only the carbohydrate plan BAND depends on it (Thomas 2016's
   * >= 60 min scope). Defaults to 60 so omitting it keeps the cited band. */
  workoutDurationMin: number = 60,
): PreWorkoutTargets {
  if (isFasted) {
    return {
      carbs_g: 0, carbs_low_g: 0, carbs_high_g: 0,
      protein_g: 0, protein_low_g: 0, protein_high_g: 0,
      fat_g: 0,
      sodium_mg: 0, sodium_low_mg: 0, sodium_high_mg: 0,
      water_ml: 0, water_low_ml: 0, water_high_ml: 0,
      meal_type: 'fasted',
    };
  }

  const timeBeforeMin = hoursBefore * 60;

  // Carbs: SSOT pre-workout-carbs.md v2. `carbs_g` is duration-free; only the
  // plan band switches between Thomas's cited [1·BW, 4·BW] and ±12.5 % of the
  // total. This map carries no `target_basis`, so consumers see only the band.
  const carbPlan = calculatePreWorkoutCarbs({
    bodyWeightKg: weightKg,
    timeBeforeWorkoutMin: timeBeforeMin,
    workoutDurationMin,
    isFasted: false,
  });
  const carbs = Math.round(carbPlan.carbs_g);
  const carbsLow = Math.round(carbPlan.carbs_low_g);
  const carbsHigh = Math.round(carbPlan.carbs_high_g);

  // Base sodium by sweat category
  const baseSodium = sweatSodiumCat === 'low' ? 300 : sweatSodiumCat === 'medium' ? 450 : 600;
  const envBump = (envLabel === 'hot' || envLabel === 'very_hot') ? 100 : 0;

  const mealSodium = baseSodium + envBump;
  const snackSodium = Math.round((baseSodium + envBump) * 0.5);
  const topUpSodium = envBump + 100;

  let protein: number;
  let proteinLow: number;
  let proteinHigh: number;
  let fat: number;
  let sodium: number;
  let sodiumLow: number;
  let sodiumHigh: number;
  let hydration: number;
  let hydrationLow: number;
  let hydrationHigh: number;
  let mealType: string;

  // Tier boundaries are the SSOT's: `meal` iff t >= TIER_MEAL_MIN (120),
  // `snack` iff t >= TIER_TOPOFF_MAX (30), `top_off` always
  // (pre-workout-carbs.md v2, invariant 6). `meal_type` is kept only so food
  // selection keeps working, and it is derived from those same boundaries.
  // (Previously 90 min / 30 min, and 2.5 h / 1.0 h before that.)
  if (timeBeforeMin >= TIER_MEAL_MIN) {
    // Full meal
    protein = Math.round(weightKg * 0.25);
    proteinLow = Math.round(weightKg * 0.15);
    proteinHigh = Math.round(weightKg * 0.35);
    fat = Math.round(weightKg * 0.4);
    sodium = mealSodium + snackSodium + topUpSodium;
    hydration = Math.round(weightKg * 6.5);
    mealType = 'full_meal';
    sodiumLow = 200;
    sodiumHigh = 2000;
    hydrationLow = Math.max(200, Math.round(hydration * 0.50));
    hydrationHigh = Math.max(600, Math.round(hydration * 1.50));
  } else if (timeBeforeMin >= TIER_TOPOFF_MAX) {
    // Snack
    protein = Math.round(weightKg * 0.15);
    proteinLow = 0;
    proteinHigh = Math.round(weightKg * 0.25);
    fat = 5;
    sodium = snackSodium + topUpSodium;
    hydration = Math.round(weightKg * 5.5);
    mealType = 'snack';
    sodiumLow = 100;
    sodiumHigh = 1000;
    hydrationLow = Math.max(150, Math.round(hydration * 0.50));
    hydrationHigh = Math.max(500, Math.round(hydration * 1.50));
  } else {
    // Top-up
    protein = 0;
    proteinLow = 0;
    proteinHigh = 10;
    fat = 0;
    sodium = topUpSodium;
    hydration = 250;
    mealType = 'top_up';
    sodiumLow = 0;
    sodiumHigh = 400;
    hydrationLow = 0;
    hydrationHigh = 500;
  }

  return {
    carbs_g: carbs,
    carbs_low_g: carbsLow,
    carbs_high_g: carbsHigh,
    protein_g: protein,
    protein_low_g: proteinLow,
    protein_high_g: proteinHigh,
    fat_g: fat,
    sodium_mg: sodium,
    sodium_low_mg: sodiumLow,
    sodium_high_mg: sodiumHigh,
    water_ml: hydration,
    water_low_ml: hydrationLow,
    water_high_ml: hydrationHigh,
    meal_type: mealType,
  };
}

// ============================================================================
// Pre-Workout Hydration (new spec — time-based tiers)
// ============================================================================

/** Wire values: 'pale' | 'dark' | 'unknown'. */
export type HydrationCheck = 'pale' | 'dark' | 'unknown';
export type HydrationRegime =
  | 'cited'
  | 'extrapolated'
  | 'clearance_bound'
  | 'gated';
export type PreWorkoutTargetBasis = 'evidenced_band' | 'design_choice' | 'none';

export interface PreWorkoutHydrationInput {
  bodyWeightKg: number;
  workoutDurationMin: number;
  /** Lead time captured at PLAN GENERATION and frozen for the plan's life. */
  timeBeforeWorkoutMin: number;
  tempC: number | null;
  /** Defaults to 'unknown'. Only affects output when t >= T_REF. */
  hydrationCheck?: HydrationCheck;
}

export interface PreWorkoutFluidTier {
  tier: PreWorkoutTierName;
  fluid_ml: number;
}

export interface PreWorkoutHydrationResult {
  gate_triggered: boolean;
  /** Exact ml — plan total across all tiers. `null` on the gate path. */
  fluid_ml: number | null;
  fluid_low_ml: number | null;
  fluid_high_ml: number | null;
  /** Ordered, furthest-out first. `[]` on the gate path. */
  tiers: PreWorkoutFluidTier[];
  regime: HydrationRegime;
  target_basis: PreWorkoutTargetBasis;
  /** Echo of the value actually applied. `null` on the gate path. */
  hydration_check_used: HydrationCheck | null;
  /** ALWAYS null — pre-workout-sodium.md v3. `0` is a failure, not a pass. */
  sodium_mg: null;
  sodium_low_mg: null;
  sodium_high_mg: null;
  /** Advisory copy. Not part of the math contract; gate path only. */
  message: string | null;
}

/**
 * Pre-workout hydration — SSOT `pre-workout-hydration.md` v6, with sodium per
 * `pre-workout-sodium.md` v3 (always null).
 *
 * Gate: workoutDurationMin < 60 AND tempC < 30 → nulls, empty tiers. The gate
 * is bypassed when tempC >= 30 regardless of duration.
 *
 * Above T_REF the dose is Thomas 2016's 7.5 ml/kg midpoint, consumed in
 * [now, t-120], plus ACSM 2007's +4 ml/kg correction in the snack window when
 * the urine check reads dark. Below T_REF everything is a Mealvana design
 * choice (`target_basis: 'design_choice'`): a linear taper from 7.5 ml/kg down
 * to the 250 ml start-line anchor, with the high bound clamped by gastric
 * clearance.
 *
 * The engine NEVER rounds and is PURE with respect to `hydrationCheck`.
 */
export function calculatePreWorkoutHydration(
  input: PreWorkoutHydrationInput,
): PreWorkoutHydrationResult {
  const { bodyWeightKg, workoutDurationMin, timeBeforeWorkoutMin, tempC } = input;
  const hydrationCheck: HydrationCheck = input.hydrationCheck ?? 'unknown';
  const temp = tempC ?? 22;

  // Gate — returns null, never 0. Null means "no statement is made"; zero
  // would mean "drink nothing", which is a different claim.
  if (workoutDurationMin < 60 && temp < 30) {
    return {
      gate_triggered: true,
      fluid_ml: null,
      fluid_low_ml: null,
      fluid_high_ml: null,
      tiers: [],
      regime: 'gated',
      target_basis: 'none',
      hydration_check_used: null,
      sodium_mg: null,
      sodium_low_mg: null,
      sodium_high_mg: null,
      message:
        'No structured pre-hydration needed for short workouts in mild conditions.',
    };
  }

  const t = Math.max(timeBeforeWorkoutMin, 0);
  const BW = bodyWeightKg;
  // Guard; binds only below 33.3 kg.
  const A0 = Math.min(A0_ML, 7.5 * BW);
  const f = (x: number): number =>
    A0 + (7.5 * BW - A0) * Math.min(x, T_REF) / T_REF;

  let mealMl: number;
  let snackMl: number;
  let topOffMl: number;
  let fluidMl: number;
  let fluidLowMl: number;
  let fluidHighMl: number;
  let regime: HydrationRegime;
  let targetBasis: PreWorkoutTargetBasis;
  let checkUsed: HydrationCheck;

  if (t >= T_REF) {
    // `unknown` is treated as `pale` — PROVISIONAL Mealvana design choice, and
    // this is the ONLY place the normalisation happens.
    checkUsed = hydrationCheck === 'unknown' ? 'pale' : hydrationCheck;
    mealMl = 7.5 * BW;                                  // Thomas 2016 midpoint
    const topUpMl = checkUsed === 'dark' ? TOPUP_ML_KG * BW : 0.0;
    snackMl = topUpMl;                        // ACSM places it at ~2 h
    topOffMl = 0.0;
    fluidMl = mealMl + snackMl;
    fluidLowMl = 5.0 * BW;                              // Thomas's cited floor
    // NOT conditioned on hydrationCheck — the band must be computable at entry
    // (t-240) while the check happens at t-120. min(12.5, 12) -> 12.
    fluidHighMl = Math.min(
      7.5 * BW + TOPUP_HIGH_ML_KG * BW,
      PLAN_CAP_ML_KG * BW,
    );
    regime = 'cited';
    targetBasis = 'evidenced_band';
  } else {
    // Below T_REF the check changes nothing — the athlete has drunk nothing
    // yet, so there is no result to evaluate. Echo the RAW value.
    checkUsed = hydrationCheck;
    mealMl = 0.0;
    if (t >= TIER_TOPOFF_MAX) {
      snackMl = f(t);
      topOffMl = 0.0;
    } else {
      snackMl = 0.0;
      topOffMl = f(t);
    }
    const ceiling = R_CEILING * Math.exp(K * t);
    fluidMl = snackMl + topOffMl;
    fluidLowMl = 0.0;                    // zero, NOT null — nothing is required
    fluidHighMl = Math.min(10.0 * BW, ceiling);
    regime = ceiling < 10.0 * BW ? 'clearance_bound' : 'extrapolated';
    targetBasis = 'design_choice';
  }

  // Tier membership matches the carbohydrate plan's: `meal` iff t >= 120,
  // `snack` iff t >= 30, `top_off` always. Zero-valued tiers are still emitted
  // so `fluid_ml == sum(tiers[].fluid_ml)` holds (invariant 2).
  const tiers: PreWorkoutFluidTier[] = [];
  if (t >= TIER_MEAL_MIN) tiers.push({ tier: 'meal', fluid_ml: mealMl });
  if (t >= TIER_TOPOFF_MAX) tiers.push({ tier: 'snack', fluid_ml: snackMl });
  tiers.push({ tier: 'top_off', fluid_ml: topOffMl });

  return {
    gate_triggered: false,
    fluid_ml: fluidMl,
    fluid_low_ml: fluidLowMl,
    fluid_high_ml: fluidHighMl,
    tiers,
    regime,
    target_basis: targetBasis,
    hydration_check_used: checkUsed,
    sodium_mg: null,
    sodium_low_mg: null,
    sodium_high_mg: null,
    message: null,
  };
}

/**
 * Targets after the hydration overlay.
 *
 * Sodium is `null` (pre-workout-sodium.md v3 — Mealvana sets no pre-workout
 * sodium target) and fluid is `null` on the gate path, so this widens the
 * legacy `PreWorkoutTargets` shape. The food solver still needs numeric bounds
 * to score against, so the numeric view it consumes rides along on
 * `solver_targets` — that field is internal and is never serialized.
 */
export interface PreWorkoutOverlaidTargets extends
  Omit<
    PreWorkoutTargets,
    | 'sodium_mg'
    | 'sodium_low_mg'
    | 'sodium_high_mg'
    | 'water_ml'
    | 'water_low_ml'
    | 'water_high_ml'
  > {
  sodium_mg: null;
  sodium_low_mg: null;
  sodium_high_mg: null;
  water_ml: number | null;
  water_low_ml: number | null;
  water_high_ml: number | null;
  /** Ordered fluid tiers, furthest-out first. `[]` on the gate path. */
  water_tiers: PreWorkoutFluidTier[];
  hydration_regime: HydrationRegime;
  hydration_target_basis: PreWorkoutTargetBasis;
  hydration_check_used: HydrationCheck | null;
  /** Numeric view for food selection only. Not part of the response payload. */
  solver_targets: PreWorkoutTargets;
}

/**
 * Overlay spec-compliant pre-workout hydration values onto the legacy
 * carb/protein/fat targets produced by calculatePreWorkoutTargets.
 *
 * Carbs/protein/fat/meal_type come from the legacy time-window path (still
 * drives food selection). Fluid comes from hydration v6; sodium is nulled per
 * sodium v3.
 */
export function applyPreWorkoutHydrationOverlay(
  targets: PreWorkoutTargets,
  hydration: PreWorkoutHydrationResult,
): PreWorkoutOverlaidTargets {
  return {
    ...targets,
    sodium_mg: null,
    sodium_low_mg: null,
    sodium_high_mg: null,
    water_ml: hydration.fluid_ml,
    water_low_ml: hydration.fluid_low_ml,
    water_high_ml: hydration.fluid_high_ml,
    water_tiers: hydration.tiers,
    hydration_regime: hydration.regime,
    hydration_target_basis: hydration.target_basis,
    hydration_check_used: hydration.hydration_check_used,
    // The solver keeps the legacy sodium band: sodium v3 removes the TARGET,
    // not the food selector's need for bounds ("do not strip salt from
    // meal-tier items" — delivered sodium is reported, not targeted). Fluid
    // uses the v6 numbers; on the gate path, where v6 makes no statement, the
    // solver falls back to the legacy bounds rather than to 0 — scoring a
    // drink against a 0 ceiling would reject every drink and ship a dry plan,
    // which is a stronger claim than "no target".
    solver_targets: {
      ...targets,
      // The carb band the solver portions against is `carbs_g ± 12.5 %`, not
      // the plan band the payload reports — see `solverCarbBand`.
      carbs_low_g: Math.round(solverCarbBand(targets.carbs_g).low),
      carbs_high_g: Math.round(solverCarbBand(targets.carbs_g).high),
      water_ml: hydration.fluid_ml ?? targets.water_ml,
      water_low_ml: hydration.fluid_low_ml ?? targets.water_low_ml,
      water_high_ml: hydration.fluid_high_ml ?? targets.water_high_ml,
    },
  };
}

// ============================================================================
// Phase Schedule & Target Splitting
// ============================================================================

export function getActiveSubPhases(hoursBefore: number): SubPhaseType[] {
  // Tier membership per pre-workout-carbs.md v2 invariant 6: `meal` iff
  // t >= 120 min, `snack` iff t >= 30 min, `top_off` always. Kept identical to
  // the boundaries in `calculatePreWorkoutTargets` so `meal_type` and the
  // active sub-phases can never disagree. With this boundary the BUDGET_SPLITS
  // carb shares (60/30/10, renormalizing to 75/25 and 100) are exactly the
  // SSOT's tier shares. (Previously 90 min.)
  const timeBeforeMin = hoursBefore * 60;
  if (timeBeforeMin >= TIER_MEAL_MIN) return ['meal', 'snack', 'top_up'];
  if (timeBeforeMin >= TIER_TOPOFF_MAX) return ['snack', 'top_up'];
  return ['top_up'];
}

/**
 * Classify a `pre_workout_templates.time_window` string to its sub-phase,
 * accepting BOTH catalog generations.
 *
 * The catalog's window labels moved with the 120-minute ruling (D-017): the
 * dev catalog was bulk-migrated on 2026-08-05 to `2-4 hours` / `30-120 min`,
 * while prod still carries `1.5-3 hours` / `30-90 min`. The same function
 * code deploys to both projects, so matching on ONE generation of strings
 * breaks whichever catalog holds the other — that is exactly the failure that
 * produced flat-50 g before-phases on dev: `meal` and `snack` matched zero
 * templates and only the top-off slot delivered.
 *
 * Every template filter must therefore compare PHASES
 * (`timeWindowToPhase(t.time_window) === phase`), never raw strings.
 * An unknown window returns null and simply matches no phase.
 */
export function timeWindowToPhase(timeWindow: string): SubPhaseType | null {
  switch (timeWindow) {
    case '2-4 hours': // current generation (dev catalog, post 2026-08-05)
    case '1.5-3 hours': // previous generation (prod catalog)
      return 'meal';
    case '30-120 min': // current generation
    case '30-90 min': // previous generation
      return 'snack';
    case '< 30 min': // unchanged across generations
      return 'top_up';
    default:
      return null;
  }
}

export function splitTargets(
  targets: PreWorkoutTargets,
  hoursBefore: number,
): Map<SubPhaseType, SubPhaseTargets> {
  const activePhases = getActiveSubPhases(hoursBefore);
  const result = new Map<SubPhaseType, SubPhaseTargets>();

  const totals = {
    carbs_g: targets.carbs_g,
    protein_g: targets.protein_g,
    fat_g: targets.fat_g,
    sodium_mg: targets.sodium_mg,
    water_ml: targets.water_ml,
  };

  for (const phase of activePhases) {
    result.set(phase, { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 });
  }

  const macroMap: Array<{ budget: keyof typeof BUDGET_SPLITS; key: keyof SubPhaseTargets }> = [
    { budget: 'carbs',   key: 'carbs_g' },
    { budget: 'protein', key: 'protein_g' },
    { budget: 'fat',     key: 'fat_g' },
    { budget: 'sodium',  key: 'sodium_mg' },
    { budget: 'water',   key: 'water_ml' },
  ];

  for (const { budget, key } of macroMap) {
    const splits = BUDGET_SPLITS[budget];
    const totalValue = totals[key];

    let activeSum = 0;
    for (const phase of activePhases) {
      activeSum += splits[phase];
    }

    for (const phase of activePhases) {
      const proportion = splits[phase] / activeSum;
      const target = result.get(phase)!;
      target[key] = Math.round(totalValue * proportion * 10) / 10;
    }
  }

  return result;
}

// ============================================================================
// Template Filtering
// ============================================================================

export function getEligibleTemplates(
  templates: PreWorkoutTemplate[],
  phase: SubPhaseType,
  diet: string,
  dislikedFoods: string[] = [],
  allergies: string[] = [],
): PreWorkoutTemplate[] {
  // Phase comparison, not string comparison — the catalog's window labels
  // differ between projects (see timeWindowToPhase).
  let filtered = templates.filter((t) => timeWindowToPhase(t.time_window) === phase);
  const dislikedSet = new Set(dislikedFoods.map(normalizeToken));

  // Diet filtering (dietary preference like 'vegan', 'keto', etc.)
  if (diet !== 'none' && diet) {
    // 1. Allergen-based diet filtering (for -free diets)
    const excluded: string[] = [];
    if (diet === 'gluten-free' || diet === 'all-free') excluded.push('gluten');
    if (diet === 'dairy-free' || diet === 'all-free') excluded.push('dairy');
    if (diet === 'peanut-free' || diet === 'all-free') excluded.push('peanut');

    if (excluded.length > 0) {
      filtered = filtered.filter((t) =>
        !t.allergens.some((a: string) => excluded.some(e => e === a.toLowerCase()))
      );
    }

    // 2. excluded_diets filtering (for vegan, vegetarian, paleo, keto, etc.)
    const normalizedDiet = diet.toLowerCase().replace(/-/g, '_');
    filtered = filtered.filter((t) => {
      const excludedDiets = (t.excluded_diets ?? []) as string[];
      return !excludedDiets.some(d => d.toLowerCase() === normalizedDiet);
    });
  }

  // Allergen filtering — exclude templates whose allergens overlap with user's allergies
  // Uses case-insensitive matching to handle 'Gluten' vs 'gluten' mismatch
  if (allergies.length > 0) {
    const allergySet = new Set(allergies.map(normalizeAllergen));
    filtered = filtered.filter((t) => {
      const templateAllergens = new Set((t.allergens ?? []).map((a: string) => normalizeAllergen(a)));
      const inferred = inferAllergensFromComponents(t.component_food_names ?? []);
      for (const a of inferred) templateAllergens.add(a);
      for (const allergen of templateAllergens) {
        if (allergySet.has(allergen)) return false;
      }
      return true;
    });
  }

  // Exclude templates where ANY component food is disliked
  if (dislikedSet.size > 0) {
    filtered = filtered.filter((t) => {
      const components = (t.component_food_names ?? []).map(normalizeToken);
      if (components.some((name) => dislikedSet.has(name))) return false;

      // Fallback when components are incomplete: also check template/base labels.
      const templateName = normalizeToken(t.name);
      const baseCategory = normalizeToken(t.base_category ?? '');
      if (dislikedSet.has(templateName) || dislikedSet.has(baseCategory)) return false;

      return true;
    });
  }

  return filtered;
}

// ============================================================================
// Stacking Logic
// ============================================================================

/**
 * Try to stack a second food template to fill a large remaining gap.
 */
function tryStack(
  remainingGap: number,
  eligible: PreWorkoutTemplate[],
  state: PlanState,
  usedCategory: string,
  usedTemplateId: string,
  existingPhaseCarbs: number,
  existingPhaseProtein: number,
  existingPhaseSodium: number,
  existingPhaseFluid: number,
): { template: PreWorkoutTemplate; servings: number } | null {
  let candidates = eligible.filter((t) => t.base_category !== usedCategory && t.id !== usedTemplateId);
  if (candidates.length === 0) {
    candidates = eligible.filter((t) => t.id !== usedTemplateId);
  }
  if (candidates.length === 0) return null;

  const sodiumOver = state.sodium_delivered > state.sodium_target;

  let best: { template: PreWorkoutTemplate; servings: number; gap: number; sodium: number } | null = null;

  for (const template of candidates) {
    const ideal = remainingGap / template.carbs_per_serving;
    const clamped = Math.max(template.min_servings, Math.min(template.max_servings, ideal));
    const servings = snapToHalf(clamped);
    const carbs = templateCarbs(template, servings);
    const protein = template.protein_per_serving * servings;
    const gap = Math.abs(remainingGap - carbs);
    const sodium = template.sodium_mg * servings;
    const fluid = template.fluid_ml * servings;

    if (
      wouldExceedHighs(
        state,
        existingPhaseCarbs + carbs,
        existingPhaseProtein + protein,
        existingPhaseSodium + sodium,
        existingPhaseFluid + fluid,
      )
    ) {
      continue;
    }

    if (!best || gap < best.gap) {
      best = { template, servings, gap, sodium };
    } else if (Math.abs(gap - best.gap) < 3 && sodiumOver && sodium < best.sodium) {
      best = { template, servings, gap, sodium };
    }
  }

  return best ? { template: best.template, servings: best.servings } : null;
}

// ============================================================================
// Drink & Electrolyte Selection (Independent)
// ============================================================================

function scoreDrinkOption(
  resultSodium: number,
  resultFluid: number,
  sodiumTarget: number,
  fluidTarget: number,
): number {
  let sodiumError = 0;
  if (sodiumTarget > 0) {
    const diff = resultSodium - sodiumTarget;
    sodiumError = Math.abs(diff) / sodiumTarget * (diff > 0 ? 3.0 : 1.0);
  }

  let fluidError = 0;
  if (fluidTarget > 0) {
    const diff = resultFluid - fluidTarget;
    fluidError = Math.abs(diff) / fluidTarget * (diff > 0 ? 1.5 : 1.0);
  }

  return sodiumError + fluidError;
}

/**
 * Pick the best standalone drink for hydration.
 * Scores every (drink × servings) combo against sodium and fluid targets.
 * "No drink" is a valid baseline.
 */
export function pickDrink(
  drinkTemplates: PreWorkoutTemplate[],
  proteinDelivered: number,
  totalSodiumDelivered: number,
  totalFluidDelivered: number,
  proteinHigh: number,
  sodiumTarget: number,
  fluidTarget: number,
  sodiumHigh: number,
  fluidHigh: number,
  carbsDelivered: number,
  carbsHigh: number,
): TemplateSelection | null {
  let bestScore = scoreDrinkOption(totalSodiumDelivered, totalFluidDelivered, sodiumTarget, fluidTarget);
  let bestPick: { template: PreWorkoutTemplate; servings: number } | null = null;

  for (const template of drinkTemplates) {
    for (let srv = template.min_servings; srv <= template.max_servings; srv += 0.5) {
      const servings = snapToHalf(srv);
      const resultSodium = totalSodiumDelivered + template.sodium_mg * servings;
      const resultFluid = totalFluidDelivered + template.fluid_ml * servings;

      // Hard cap: skip any combo that would push fluids past 1.5x target
      if (fluidTarget > 0 && resultFluid > fluidTarget * 1.5) continue;
      // Headroom-based caps for ALL non-fluid macros (parity with
      // pickElectrolyte): reject only candidates whose own delta exceeds the
      // remaining headroom. When food selection already left the state over
      // carbs_high or protein_high, a zero-carb/zero-protein drink like
      // water must stay selectable — the old absolute checks
      // (`resultCarbs > carbsHigh`, `resultProtein > proteinHigh`) rejected
      // EVERY drink in that case and produced no-water plans (before-water
      // 0%, found 2026-07-21 — same bug class as the #22 sodium fix below,
      // which had only been applied to sodium).
      const carbsHeadroom = Math.max(0, carbsHigh - carbsDelivered);
      const drinkCarbsAdded = template.carbs_per_serving * servings;
      if (drinkCarbsAdded > carbsHeadroom + 1e-6) continue;
      const proteinHeadroom = Math.max(0, proteinHigh - proteinDelivered);
      const drinkProteinAdded = template.protein_per_serving * servings;
      if (drinkProteinAdded > proteinHeadroom + 1e-6) continue;
      // Sodium cap: reject only if the drink itself would consume more sodium
      // headroom than remains. When state is already over sodium_high
      // (headroom = 0), a zero-sodium drink like water is still selectable
      // because it can't make a sodium overage worse. Previously this check
      // was `resultSodium > sodiumHigh`, which rejected water in that case
      // and produced no-water plans. (#22)
      const sodiumHeadroom = Math.max(0, sodiumHigh - totalSodiumDelivered);
      const drinkSodiumAdded = template.sodium_mg * servings;
      if (drinkSodiumAdded > sodiumHeadroom + 1e-6) continue;
      if (resultFluid > fluidHigh + 1e-6) continue;

      const score = scoreDrinkOption(resultSodium, resultFluid, sodiumTarget, fluidTarget);

      if (score < bestScore) {
        bestScore = score;
        bestPick = { template, servings };
      }
    }
  }

  if (!bestPick) return null;
  return makeSelection(bestPick.template, bestPick.servings);
}

/**
 * Pick the best electrolyte supplement for sodium gap.
 * Independent from drink selection — electrolytes dissolve in water.
 */
export function pickElectrolyte(
  electrolyteTemplates: PreWorkoutTemplate[],
  carbsDelivered: number,
  proteinDelivered: number,
  totalSodiumDelivered: number,
  totalFluidDelivered: number,
  carbsTarget: number,
  carbsHigh: number,
  proteinHigh: number,
  sodiumLow: number,
  sodiumHigh: number,
  sodiumTarget: number,
  fluidHigh: number,
  fluidTarget: number,
): TemplateSelection | null {
  // Aim at sodium_TARGET, not the range floor (2026-07-29). This used to be
  // `if (totalSodiumDelivered >= sodiumLow) return null` — the moment food +
  // drink selection cleared the *floor*, no electrolyte was ever considered,
  // stranding sodium in the low end of the band while `sodium_target` (the
  // midpoint) sat far above. `pickDrink` in this same file has never had such
  // a gate; it just minimizes `scoreDrinkOption` (a |actual-target| score) all
  // the way to the target, and that is the pattern sodium now follows too.
  //
  // Safety: the loop below only ever adopts a candidate that *strictly
  // improves* the distance-to-target score, and every candidate is rejected
  // if its own delta exceeds the remaining sodium/carb/protein/fluid headroom.
  // So when sodium is already at (or past) target, nothing is added, and the
  // ceiling can never be crossed. Aim at the target, pass iff inside the range.
  const startsBelowFloor = totalSodiumDelivered < sodiumLow - 1e-6;

  let bestScore = scoreDrinkOption(totalSodiumDelivered, totalFluidDelivered, sodiumTarget, fluidTarget);
  let bestPick: { template: PreWorkoutTemplate; servings: number } | null = null;

  for (const template of electrolyteTemplates) {
    // Divisible sources (e.g. a half-packet electrolyte mix) step in 0.5
    // increments so the sodium gap can be closed precisely; indivisible
    // sources (tablets) keep the original whole-unit steps. Mirrors the
    // `is_indivisible === false` convention used by pin-backfill.ts.
    // Item 5 (before-run sodium over/undershoot), 2026-07-04.
    const step = template.is_indivisible === false ? 0.5 : 1;
    for (let srv = template.min_servings; srv <= template.max_servings; srv += step) {
      const resultCarbs = carbsDelivered + template.carbs_per_serving * srv;
      const resultProtein = proteinDelivered + template.protein_per_serving * srv;
      const resultSodium = totalSodiumDelivered + template.sodium_mg * srv;
      // Electrolytes have 0 fluid_ml — they dissolve in the drink
      const resultFluid = totalFluidDelivered + template.fluid_ml * srv;
      // Headroom-based caps: reject only candidates whose delta exceeds remaining
      // headroom, so zero-delta picks (e.g. a zero-carb electrolyte tablet when
      // state is already over carbs_high) stay selectable on their sodium criteria.
      // Mirrors the fix in pickDrink for #22.
      const carbsAdded = template.carbs_per_serving * srv;
      const proteinAdded = template.protein_per_serving * srv;
      const sodiumAdded = template.sodium_mg * srv;
      const fluidAdded = template.fluid_ml * srv;
      const carbsHeadroom = Math.max(0, carbsHigh - carbsDelivered);
      const proteinHeadroom = Math.max(0, proteinHigh - proteinDelivered);
      const sodiumHeadroom = Math.max(0, sodiumHigh - totalSodiumDelivered);
      const fluidHeadroom = Math.max(0, fluidHigh - totalFluidDelivered);
      if (carbsAdded > carbsHeadroom + 1e-6) continue;
      if (proteinAdded > proteinHeadroom + 1e-6) continue;
      if (sodiumAdded > sodiumHeadroom + 1e-6) continue;
      if (fluidAdded > fluidHeadroom + 1e-6) continue;

      const score = scoreDrinkOption(resultSodium, resultFluid, sodiumTarget, fluidTarget) +
        (carbsTarget > 0 ? Math.max(0, resultCarbs - carbsHigh) / carbsTarget : 0) * 4;

      // `score < bestScore` is the target-seeking rule and does all the work.
      // The second clause is a floor rescue: accept a *non*-improving pick
      // purely because it lands in-range. It must only fire when we started
      // BELOW the floor — otherwise, now that the early return is gone, it
      // would bolt an unnecessary electrolyte onto an already-in-range plan
      // and push sodium further from target.
      if (
        score < bestScore ||
        (startsBelowFloor && bestPick === null && resultSodium >= sodiumLow &&
          resultSodium <= sodiumHigh)
      ) {
        bestScore = score;
        bestPick = { template, servings: srv };
      }
    }
  }

  // Floor enforcement (before-run sodium fix): the loop above rejects any
  // serving whose sodium overshoots sodium_high. When every eligible
  // electrolyte serving overshoots the high bound (e.g. only a 300mg tablet is
  // available against a 100–200mg target), that leaves `bestPick` null and
  // strands sodium below the low floor — the bug where before-run showed 77mg
  // against a 100mg floor. Rather than emit an under-target plan, add the
  // serving that clears the floor with the *smallest* overshoot (least
  // over-delivery), still respecting the carb/protein/fluid caps so we don't
  // blow other macros. This mirrors the pin/formula path, which always tops
  // sodium up toward target via backfillPinnedFluidsAndSodium.
  // Only rescue when we actually started below the floor. If sodium already
  // cleared the floor, "no bestPick" simply means no candidate got us closer
  // to target without breaching the ceiling — the correct answer is to add
  // nothing rather than to deliberately overshoot.
  if (!bestPick && startsBelowFloor) {
    let leastOvershootSodium = Infinity;
    for (const template of electrolyteTemplates) {
      const step = template.is_indivisible === false ? 0.5 : 1;
      for (let srv = template.min_servings; srv <= template.max_servings; srv += step) {
        const carbsAdded = template.carbs_per_serving * srv;
        const proteinAdded = template.protein_per_serving * srv;
        const fluidAdded = template.fluid_ml * srv;
        const carbsHeadroom = Math.max(0, carbsHigh - carbsDelivered);
        const proteinHeadroom = Math.max(0, proteinHigh - proteinDelivered);
        const fluidHeadroom = Math.max(0, fluidHigh - totalFluidDelivered);
        if (carbsAdded > carbsHeadroom + 1e-6) continue;
        if (proteinAdded > proteinHeadroom + 1e-6) continue;
        if (fluidAdded > fluidHeadroom + 1e-6) continue;
        const resultSodium = totalSodiumDelivered + template.sodium_mg * srv;
        // Must at least reach the floor to be worth adding.
        if (resultSodium < sodiumLow - 1e-6) continue;
        if (resultSodium < leastOvershootSodium) {
          leastOvershootSodium = resultSodium;
          bestPick = { template, servings: srv };
        }
      }
    }
  }

  if (!bestPick) return null;
  return makeSelection(bestPick.template, bestPick.servings);
}

/**
 * Pass 1.6: trim a sodium overage left by carb-driven food selection.
 *
 * Big carb targets (e.g. a 440g pre-marathon load) accumulate food sodium far
 * past `sodium_high` — the sodium band is body-independent [300..600]mg while
 * food sodium scales with servings — and nothing downstream can subtract
 * (pickDrink / pickElectrolyte only ever add). Trim ADD-ONS only — never
 * primaries or stacks, which are the meal's identity — removing the
 * cheapest-carb-loss-per-mg-sodium add-on first, while total carbs stay at or
 * above `carbsLowG`. Must run BEFORE Pass 2 (pickDrink) so water can backfill
 * any fluid the removed add-ons carried, sodium-free.
 *
 * Deliberately does NOT reset `state.sports_drink_used` when a sports-drink
 * add-on is trimmed — that would invite a later pass to re-add what was just
 * removed. Found via before-sodium 154% (Very Heavy Marathon), 2026-07-21.
 *
 * Exported for unit testing.
 */
export function trimSodiumOverage(
  results: PreWorkoutPhaseResult[],
  state: PlanState,
  carbsLowG: number,
): void {
  if (state.sodium_delivered <= state.sodium_high + 1e-6) return;
  console.log(
    `[ALGO-C] Sodium trim: delivered=${state.sodium_delivered.toFixed(0)}mg > ` +
      `high=${state.sodium_high}mg — trimming add-ons`,
  );

  while (state.sodium_delivered > state.sodium_high + 1e-6) {
    let best:
      | { phaseIdx: number; addOnIdx: number; costPerMg: number }
      | null = null;
    for (let pi = 0; pi < results.length; pi++) {
      const addOns = results[pi].add_ons ?? [];
      for (let ai = 0; ai < addOns.length; ai++) {
        const a = addOns[ai];
        if (a.sodium_mg <= 0) continue;
        // Removing must keep total carbs at/above the low band.
        if (state.carbs_delivered - a.carbs_g < carbsLowG - 1e-6) continue;
        const costPerMg = a.carbs_g / a.sodium_mg;
        if (!best || costPerMg < best.costPerMg) {
          best = { phaseIdx: pi, addOnIdx: ai, costPerMg };
        }
      }
    }
    if (!best) {
      console.log(
        `[ALGO-C] Sodium trim: still ${
          (state.sodium_delivered - state.sodium_high).toFixed(0)
        }mg over high — no more trimmable add-ons (primaries are never trimmed)`,
      );
      return;
    }

    const phase = results[best.phaseIdx];
    const [removed] = phase.add_ons.splice(best.addOnIdx, 1);
    phase.total_carbs_g = Math.round((phase.total_carbs_g - removed.carbs_g) * 10) / 10;
    phase.total_sodium_mg = Math.round((phase.total_sodium_mg - removed.sodium_mg) * 10) / 10;
    phase.total_fluid_ml = Math.round((phase.total_fluid_ml - removed.fluid_ml) * 10) / 10;
    state.carbs_delivered -= removed.carbs_g;
    state.sodium_delivered -= removed.sodium_mg;
    state.fluid_delivered -= removed.fluid_ml;
    console.log(
      `[ALGO-C] Sodium trim: removed ${removed.type} from ${phase.phase} ` +
        `(-${removed.sodium_mg}mg sodium, -${removed.carbs_g}g carbs, ` +
        `now ${state.sodium_delivered.toFixed(0)}mg)`,
    );
  }
}

// ============================================================================
// Main Entry Point
// ============================================================================

/**
 * Run Algorithm C food selection against pre-workout templates from the database.
 * Returns per-phase food recommendations.
 */
export function selectPreWorkoutFoods(
  targetsIn: PreWorkoutTargets | PreWorkoutOverlaidTargets,
  hoursBefore: number,
  diet: string,
  foodTemplates: PreWorkoutTemplate[],
  drinkTemplates: PreWorkoutTemplate[],
  electrolyteTemplates: PreWorkoutTemplate[],
  likedFoods: string[] = [],
  dislikedFoods: string[] = [],
  allergies: string[] = [],
  /**
   * Set of pre_workout_template ids the user has actively pinned (food
   * templates only; drink/electrolyte not pinnable in V1). When a pinned
   * template matches the current sub_phase's time_window, it overrides
   * candidate selection: allergen / diet / dislike / cross-phase-dedup
   * filters and the [min_servings, max_servings] scale clamp are all
   * bypassed for that phase. When undefined or empty, behavior is byte-
   * identical to pre-pin v3. Formula Kit PR 2 substep 5a.
   */
  pinnedTemplateIds?: Set<string>,
  /**
   * When true, tag an unpinned phase's selected system formula as an
   * EPHEMERAL default-formula pin on `pin_decision` (formula-first flip,
   * plan Phase 2 #5). Pre templates have no `selection_priority` /
   * `activity_types`, so the "best-fit" default IS whatever `pickBestFormula`
   * already selects from the time_window-scoped eligible set — this only tags
   * that outcome, it does not change food output. Opt-in so old clients stay
   * byte-identical (the no-pin-parity tests rely on `pin_decision` being
   * omitted when neither pins nor this flag are supplied). 2026-07-03.
   */
  emitEphemeralDefault = false,
): PreWorkoutPhaseResult[] {
  // The solver scores against numbers. When it is handed overlaid targets
  // (sodium null per sodium v3, fluid null on the gate path) it uses the
  // numeric view that rides along on them.
  const targets: PreWorkoutTargets = 'solver_targets' in targetsIn
    ? targetsIn.solver_targets
    : targetsIn;
  if (targets.meal_type === 'fasted') return [];

  // Portioning bounds are `carbs_g ± 12.5 %`, NOT the plan band on the map.
  // See `solverCarbBand`. Derived here as well as in the overlay so a caller
  // that hands us raw `calculatePreWorkoutTargets` output (no overlay) is
  // bounded identically to one that goes through it.
  const { low: solverCarbsLowG, high: solverCarbsHighG } = solverCarbBand(
    targets.carbs_g,
  );
  const dislikedSet = new Set(dislikedFoods.map(normalizeToken));

  const phases = getActiveSubPhases(hoursBefore);
  const phaseTargets = splitTargets(targets, hoursBefore);

  // ── Pre-check: redistribute budget from empty phases ─────────────
  // If a phase has zero eligible food templates (e.g. all top-off foods
  // disliked), redistribute its carb/protein/fat budget proportionally
  // to the surviving phases so the targets aren't silently dropped.
  // A phase with an in-scope pin is NOT empty: the pin override below
  // bypasses the preference filters, so the pinned template WILL deliver
  // there. Classifying it empty hands its budget to the other phases and
  // then the pin delivers on top — a guaranteed cross-phase overshoot
  // (picky athlete + fully-pinned 30-min window: 52.5g vs a 42g high).
  const hasPinInScope = (p: SubPhaseType): boolean =>
    pinnedTemplateIds !== undefined &&
    pinnedTemplateIds.size > 0 &&
    foodTemplates.some(
      (t) =>
        pinnedTemplateIds.has(t.id) &&
        timeWindowToPhase(t.time_window) === p,
    );
  const emptyPhases = phases.filter(
    (p) =>
      !hasPinInScope(p) &&
      getEligibleTemplates(foodTemplates, p, diet, dislikedFoods, allergies).length === 0,
  );
  if (emptyPhases.length > 0 && emptyPhases.length < phases.length) {
    const activePhases = phases.filter((p) => !emptyPhases.includes(p));
    const macroKeys: Array<keyof SubPhaseTargets> = [
      'carbs_g', 'protein_g', 'fat_g', 'sodium_mg', 'water_ml',
    ];
    for (const key of macroKeys) {
      let orphaned = 0;
      for (const ep of emptyPhases) {
        orphaned += phaseTargets.get(ep)?.[key] ?? 0;
      }
      if (orphaned <= 0) continue;
      let activeTotal = 0;
      for (const ap of activePhases) {
        activeTotal += phaseTargets.get(ap)?.[key] ?? 0;
      }
      for (const ap of activePhases) {
        const t = phaseTargets.get(ap)!;
        const proportion = activeTotal > 0 ? t[key] / activeTotal : 1 / activePhases.length;
        t[key] = Math.round((t[key] + orphaned * proportion) * 10) / 10;
      }
    }
    console.log(`[ALGO-C] Redistributed budget from empty phases [${emptyPhases.join(', ')}] to [${activePhases.join(', ')}]`);
  }

  const state: PlanState = {
    used_foods: new Set(),
    sports_drink_used: false,
    used_categories: new Set(),
    carbs_delivered: 0,
    protein_delivered: 0,
    sodium_delivered: 0,
    fluid_delivered: 0,
    carbs_target: targets.carbs_g,
    carbs_low: solverCarbsLowG,
    carbs_high: solverCarbsHighG,
    protein_target: targets.protein_g,
    protein_low: targets.protein_low_g,
    protein_high: targets.protein_high_g,
    sodium_target: targets.sodium_mg,
    sodium_low: targets.sodium_low_mg,
    sodium_high: targets.sodium_high_mg,
    fluid_target: targets.water_ml,
    fluid_low: targets.water_low_ml,
    fluid_high: targets.water_high_ml,
  };

  const results: PreWorkoutPhaseResult[] = [];
  const pinsActive = pinnedTemplateIds !== undefined && pinnedTemplateIds.size > 0;

  // ── Pass 1: Food selection per phase ────────────────────────────────
  for (const phase of phases) {
    const pTargets = phaseTargets.get(phase);
    const carbTarget = pTargets?.carbs_g ?? 0;

    // Pin override: when the user has pins matching this phase's time_window,
    // they take over candidate selection — bypassing dietary/dislike/allergen
    // filters, cross-phase dedup, and the scale clamp. Per locked Formula Kit
    // policy (2026-05-21): in-scope pins are honored unconditionally.
    const pinnedForPhase = pinsActive
      ? foodTemplates.filter(
          (t) =>
            pinnedTemplateIds!.has(t.id) &&
            timeWindowToPhase(t.time_window) === phase,
        )
      : [];
    const pinOverrideActive = pinnedForPhase.length > 0;

    const eligible = pinOverrideActive
      ? pinnedForPhase
      : getEligibleTemplates(foodTemplates, phase, diet, dislikedFoods, allergies);

    let candidates: PreWorkoutTemplate[];
    if (pinOverrideActive) {
      // Pins skip category-dedup and cross-phase-dedup. Whichever pinned
      // template scores best is what ships.
      candidates = pinnedForPhase;
    } else {
      // Filter to unused categories (fallback to all if none left)
      candidates = eligible.filter((t) => !state.used_categories.has(t.base_category));
      if (candidates.length === 0) candidates = eligible;

      // Cross-phase food dedup: exclude templates that share non-exempt
      // component foods with already-selected phases (e.g. no bagel in both meal and snack)
      if (state.used_foods.size > 0) {
        const deduped = candidates.filter((t) => {
          const components = t.component_food_names ?? [];
          return !components.some((name) =>
            state.used_foods.has(name) && !CROSS_PHASE_EXEMPT_FOODS.has(name)
          );
        });
        if (deduped.length > 0) candidates = deduped;
      }
    }

    if (candidates.length === 0) {
      // No template survived preference / diet / allergen filtering for this
      // phase. Emit shortfalls so the UI surfaces "no foods matched, try X"
      // guidance instead of silently dropping the carb target (issue #15).
      // Specifically the top-up-only window: when hoursBefore < 0.5 and all
      // top-up templates are disliked, this is the only phase — no
      // redistribution can help, so the shortfall is the user's only signal.
      const shortfalls: PreWorkoutShortfall[] = [];
      if ((pTargets?.carbs_g ?? 0) > 0) {
        shortfalls.push({
          macro: 'carbs',
          delivered: 0,
          target: Math.round(pTargets!.carbs_g),
          unit: 'g',
          reason: 'all_disliked',
        });
      }
      if ((pTargets?.sodium_mg ?? 0) > 0) {
        shortfalls.push({
          macro: 'sodium',
          delivered: 0,
          target: Math.round(pTargets!.sodium_mg),
          unit: 'mg',
          reason: 'all_disliked',
        });
      }
      if ((pTargets?.water_ml ?? 0) > 0) {
        shortfalls.push({
          macro: 'fluid',
          delivered: 0,
          target: Math.round(pTargets!.water_ml),
          unit: 'ml',
          reason: 'all_disliked',
        });
      }
      results.push({
        phase,
        primary: null,
        add_ons: [],
        total_carbs_g: 0,
        total_protein_g: 0,
        total_fat_g: 0,
        total_sodium_mg: 0,
        total_fluid_ml: 0,
        ...(shortfalls.length > 0 && { shortfalls }),
        // pinsActive but no pin matched this scope — the user has pins
        // elsewhere but not here, and the regular eligibility filter
        // returned nothing. Surface as no_pin_for_scope for telemetry.
        ...(pinsActive && {
          pin_decision: {
            used_pin: false,
            decision_source: 'solver' as const,
            pinned_template_id: null,
            pinned_template_name: null,
            fallthrough_reason: 'no_pin_for_scope' as const,
            default_fallthrough_reason: 'no_pin_for_scope',
            pin_set_size: pinnedForPhase.length,
          },
        }),
      });
      // Always-on tripwire: no pin AND no default formula for this slot.
      // `source=solver` here means "nothing rendered at all" — the before
      // phase has no downstream solver, so this slot ships empty.
      logFormulaCascade({
        phase: `before:${phase}`,
        source: 'solver',
        reason: 'no_eligible_template',
        pinSetSize: pinnedForPhase.length,
      });
      continue;
    }

    // Cross-phase carb ceiling: a later phase whose SMALLEST eligible pick
    // would blow past carbs_high_g must not select at all — over-delivering
    // this close to the workout is a GI risk, not a bonus. Concrete case: in
    // the 30-min window the snack phase delivers 30g of a 31-39g band, then
    // the top-up's smallest template (25g chews) lands the total at 55g.
    // Skip the phase instead; if we are still under carbs_low_g, document
    // the gap as a template_constraint shortfall (serving granularity, not
    // preferences). The fill passes below are already headroom-guarded, and
    // Pass 2 can still attach a drink to the phase — fluid is the top-up's
    // real job this close to a start. Pins bypass this per the locked
    // Formula Kit policy (in-scope pins are honored unconditionally).
    if (!pinOverrideActive && state.carbs_delivered > 0) {
      const carbHeadroom = solverCarbsHighG - state.carbs_delivered;
      const minCandidateCarbs = Math.min(
        ...candidates.map((t) => templateCarbs(t, t.min_servings ?? 1)),
      );
      if (minCandidateCarbs > carbHeadroom + 1e-6) {
        const shortfalls: PreWorkoutShortfall[] = [];
        if (
          state.carbs_delivered < solverCarbsLowG &&
          (pTargets?.carbs_g ?? 0) > 0
        ) {
          shortfalls.push({
            macro: 'carbs',
            delivered: 0,
            target: Math.round(pTargets!.carbs_g),
            unit: 'g',
            reason: 'template_constraint',
          });
        }
        console.log(
          `[ALGO-C] Skipping ${phase} phase: smallest eligible pick ` +
            `(${minCandidateCarbs.toFixed(1)}g) exceeds remaining carb ` +
            `headroom (${carbHeadroom.toFixed(1)}g of ${solverCarbsHighG}g high)`,
        );
        results.push({
          phase,
          primary: null,
          add_ons: [],
          total_carbs_g: 0,
          total_protein_g: 0,
          total_fat_g: 0,
          total_sodium_mg: 0,
          total_fluid_ml: 0,
          ...(shortfalls.length > 0 && { shortfalls }),
          ...(pinsActive && {
            pin_decision: {
              used_pin: false,
              decision_source: 'solver' as const,
              pinned_template_id: null,
              pinned_template_name: null,
              fallthrough_reason: 'no_pin_for_scope' as const,
              default_fallthrough_reason: 'no_pin_for_scope',
              pin_set_size: pinnedForPhase.length,
            },
          }),
        });
        // Deliberate skip (carb ceiling), not a formula-resolution failure —
        // still logged so the cascade line exists for every active slot.
        logFormulaCascade({
          phase: `before:${phase}`,
          source: 'solver',
          reason: 'carb_headroom_exhausted',
          pinSetSize: pinnedForPhase.length,
        });
        continue;
      }
    }

    // Score every candidate (with liked-food boost). When the pin override is
    // active, pass bypassScaleClamp=true so the scaling factor can exceed
    // [min_servings, max_servings] — honoring the user's explicit pin even at
    // 3× the template's normal range.
    const scored = candidates.map((t) =>
      scoreFormula(t, carbTarget, state, dislikedSet, likedFoods, pinOverrideActive),
    );

    // Pick best by combined score
    const pick = pickBestFormula(scored, state, carbTarget);

    // Check stacking
    const deliveredCarbs = templateCarbs(pick.template, pick.servings)
      + pick.addOns.reduce((s, a) => s + a.carbs_g, 0);
    const remainingGap = carbTarget - deliveredCarbs;
    const pctShort = carbTarget > 0 ? remainingGap / carbTarget : 0;

    let stackSelection: TemplateSelection | null = null;

    // Stacking is bypassed when the pin override is active: scaling is
    // already unclamped (bypassScaleClamp=true), so the pinned template
    // covers the carb target itself. Stacking another template on top
    // would dilute the pin signal — the user pinned X, they want X.
    if (!pinOverrideActive && pctShort > STACK_THRESHOLD && remainingGap > 20) {
      const stack = tryStack(
        remainingGap,
        eligible,
        state,
        pick.template.base_category,
        pick.template.id,
        pick.carbs,
        pick.protein,
        pick.sodium,
        pick.fluid,
      );
      if (stack) {
        stackSelection = makeSelection(stack.template, stack.servings);
        state.used_categories.add(stack.template.base_category);
      }
    }

    // Update cross-phase state
    state.used_categories.add(pick.template.base_category);
    for (const addOn of pick.addOns) {
      if (addOn.type === 'banana') state.used_foods.add('banana');
      if (addOn.type === 'sports_drink') state.sports_drink_used = true;
    }

    const primarySel = makeSelection(pick.template, pick.servings);

    // Record all component foods from primary and stack selections
    for (const name of (primarySel.component_food_names ?? [])) state.used_foods.add(name);
    if (stackSelection) {
      for (const name of (stackSelection.component_food_names ?? [])) state.used_foods.add(name);
    }

    const totalCarbs = primarySel.carbs_g + (stackSelection?.carbs_g ?? 0)
      + pick.addOns.reduce((s, a) => s + a.carbs_g, 0);
    const totalProtein = primarySel.protein_g + (stackSelection?.protein_g ?? 0);
    const totalFat = primarySel.fat_g + (stackSelection?.fat_g ?? 0);
    const totalSodium = primarySel.sodium_mg + (stackSelection?.sodium_mg ?? 0)
      + pick.addOns.reduce((s, a) => s + a.sodium_mg, 0);
    const totalFluid = primarySel.fluid_ml + (stackSelection?.fluid_ml ?? 0)
      + pick.addOns.reduce((s, a) => s + a.fluid_ml, 0);

    state.carbs_delivered += totalCarbs;
    state.protein_delivered += totalProtein;
    state.sodium_delivered += totalSodium;
    state.fluid_delivered += totalFluid;

    // A formula ALWAYS rendered for this slot at this point: either the user's
    // in-scope pin, or the best-fit system template Algorithm C ranked. The
    // second case is the "default formula" tier and — since the client stopped
    // pre-computing auto-pins (2026-07-29) — it is the common outcome.
    logFormulaCascade({
      phase: `before:${phase}`,
      source: pinOverrideActive ? 'user_pin' : 'default_formula',
      templateId: pick.template.id,
      templateName: pick.template.name,
      reason: pinOverrideActive ? null : 'no_pin_for_scope',
      pinSetSize: pinnedForPhase.length,
    });

    results.push({
      phase,
      primary: primarySel,
      stack: stackSelection,
      add_ons: pick.addOns,
      total_carbs_g: Math.round(totalCarbs * 10) / 10,
      total_protein_g: Math.round(totalProtein * 10) / 10,
      total_fat_g: Math.round(totalFat * 10) / 10,
      total_sodium_mg: Math.round(totalSodium * 10) / 10,
      total_fluid_ml: Math.round(totalFluid * 10) / 10,
      // Emit `pin_decision` when a real pin was supplied OR the client opted
      // into the default-formula telemetry net. When neither, it's omitted so
      // the no-pin-parity contract stays byte-identical for legacy clients.
      // (The `[FORMULA-CASCADE]` log above is unconditional — telemetry gating
      // never hides which tier resolved the formula from the server logs.)
      ...((pinsActive || emitEphemeralDefault) && {
        pin_decision: pinOverrideActive
          ? {
              used_pin: true,
              decision_source: 'user_pin' as const,
              pinned_template_id: pick.template.id,
              pinned_template_name: pick.template.name,
              fallthrough_reason: null,
              pin_set_size: pinnedForPhase.length,
            }
          : emitEphemeralDefault
          // Computed default formula: this slot's algorithmically-selected
          // system formula is honored like a pin (formula-first) without a
          // real pin row. Food output is unchanged; only the tag differs.
          // `used_pin`/`ephemeral` keep their legacy values for wire
          // compatibility; `decision_source` carries the honest provenance.
          ? defaultFormulaDecision({
              templateId: pick.template.id,
              templateName: pick.template.name,
              pinSetSize: pinnedForPhase.length,
            })
          : {
              used_pin: false,
              decision_source: 'default_formula' as const,
              pinned_template_id: null,
              pinned_template_name: null,
              fallthrough_reason: 'no_pin_for_scope' as const,
              pin_set_size: pinnedForPhase.length,
            },
      }),
    });
  }

  // ── Pass 1.5: Cross-phase carb gap check ────────────────────────
  // If total carbs across all phases fall below carbs_low_g, add a banana
  // (or increase servings) to fill the gap and bring us into range.
  const totalCarbsAfterPass1 = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
  if (totalCarbsAfterPass1 < solverCarbsLowG) {
    const carbDeficit = targets.carbs_g - totalCarbsAfterPass1;
    console.log(`[ALGO-C] Cross-phase carb gap: delivered=${totalCarbsAfterPass1.toFixed(1)}g, ` +
      `target=${targets.carbs_g}g, low=${solverCarbsLowG}g, deficit=${carbDeficit.toFixed(1)}g`);

    // Find the best phase to add a banana to (prefer top_up, then snack)
    const phaseOrder: SubPhaseType[] = ['top_up', 'snack', 'meal'];
    let filled = false;

    for (const targetPhase of phaseOrder) {
      if (filled) break;
      const phaseIdx = results.findIndex((p) => p.phase === targetPhase);
      if (phaseIdx < 0) continue;

      // Try adding a banana if not already used in any phase
      if (!state.used_foods.has('banana') && !dislikedSet.has('banana') && carbDeficit > 5) {
        if (wouldExceedHighs(state, BANANA_CARBS, 0, BANANA_SODIUM, BANANA_FLUID)) {
          continue;
        }
        const phase = results[phaseIdx];
        phase.add_ons.push(makeBananaAddOn());
        phase.total_carbs_g = Math.round((phase.total_carbs_g + BANANA_CARBS) * 10) / 10;
        phase.total_sodium_mg = Math.round((phase.total_sodium_mg + BANANA_SODIUM) * 10) / 10;
        phase.total_fluid_ml = Math.round((phase.total_fluid_ml + BANANA_FLUID) * 10) / 10;
        state.used_foods.add('banana');
        state.carbs_delivered += BANANA_CARBS;
        state.sodium_delivered += BANANA_SODIUM;
        state.fluid_delivered += BANANA_FLUID;
        filled = true;
        console.log(`[ALGO-C] Added banana to ${targetPhase} phase (+${BANANA_CARBS}g carbs). ` +
          `New total: ${(totalCarbsAfterPass1 + BANANA_CARBS).toFixed(1)}g`);
      }
    }

    // #15: Try universal fallback foods (dates, applesauce, raisins) if the
    // banana branch didn't fire or didn't close the gap. These are all vegan,
    // gluten-free, and allergen-clean, so they only need dislikes + headroom
    // checks. We loop until we've closed the gap or exhausted the catalog —
    // this matters most in the top-up-only window where a single phase exists
    // and the banana may have been disliked.
    for (const food of PASS_1_5_FALLBACK_FOODS) {
      const currentTotal = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
      if (currentTotal >= solverCarbsLowG) break;
      if (state.used_foods.has(food.name)) continue;
      if (dislikedSet.has(food.name)) continue;
      if (wouldExceedHighs(state, food.carbs, 0, food.sodium, food.fluid)) continue;

      // Prefer top_up phase for fast-digesting fallbacks; fall back to snack/meal.
      const phaseOrder: SubPhaseType[] = ['top_up', 'snack', 'meal'];
      for (const targetPhase of phaseOrder) {
        const phaseIdx = results.findIndex((p) => p.phase === targetPhase);
        if (phaseIdx < 0) continue;
        const phase = results[phaseIdx];
        phase.add_ons.push(food.make());
        phase.total_carbs_g = Math.round((phase.total_carbs_g + food.carbs) * 10) / 10;
        phase.total_sodium_mg = Math.round((phase.total_sodium_mg + food.sodium) * 10) / 10;
        phase.total_fluid_ml = Math.round((phase.total_fluid_ml + food.fluid) * 10) / 10;
        state.used_foods.add(food.name);
        state.carbs_delivered += food.carbs;
        state.sodium_delivered += food.sodium;
        state.fluid_delivered += food.fluid;
        console.log(`[ALGO-C] Added ${food.name} to ${targetPhase} phase (+${food.carbs}g carbs). ` +
          `New total: ${(currentTotal + food.carbs).toFixed(1)}g`);
        break;
      }
    }

    // Last-resort carb top-up: standalone sports drink if still under carbs_low.
    const postAdjustTotal = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
    if (
      postAdjustTotal < solverCarbsLowG &&
      !state.sports_drink_used &&
      !dislikedSet.has('sports_drink') &&
      !dislikedSet.has('sports_drink_mix')
    ) {
      const remaining = solverCarbsLowG - postAdjustTotal;
      const phaseOrder: SubPhaseType[] = ['top_up', 'snack', 'meal'];
      for (const targetPhase of phaseOrder) {
        const phaseIdx = results.findIndex((p) => p.phase === targetPhase);
        if (phaseIdx < 0) continue;
        const phase = results[phaseIdx];

        let addServings = Math.max(0.5, snapToHalf(Math.min(2, remaining / SPORTS_DRINK_CARBS)));
        if (targets.water_ml > 0) {
          const fluidHeadroom = Math.max(0, targets.water_high_ml - state.fluid_delivered);
          addServings = Math.min(addServings, snapToHalf(fluidHeadroom / SPORTS_DRINK_FLUID));
        }
        const carbHeadroom = Math.max(0, solverCarbsHighG - state.carbs_delivered);
        addServings = Math.min(addServings, snapToHalf(carbHeadroom / SPORTS_DRINK_CARBS));
        const sodiumHeadroom = Math.max(0, targets.sodium_high_mg - state.sodium_delivered);
        addServings = Math.min(addServings, snapToHalf(sodiumHeadroom / SPORTS_DRINK_SODIUM));
        if (addServings < 0.5) continue;

        const addOn = makeSportsDrinkAddOn(addServings);
        phase.add_ons.push(addOn);
        phase.total_carbs_g = Math.round((phase.total_carbs_g + addOn.carbs_g) * 10) / 10;
        phase.total_sodium_mg = Math.round((phase.total_sodium_mg + addOn.sodium_mg) * 10) / 10;
        phase.total_fluid_ml = Math.round((phase.total_fluid_ml + addOn.fluid_ml) * 10) / 10;
        state.sports_drink_used = true;
        state.carbs_delivered += addOn.carbs_g;
        state.sodium_delivered += addOn.sodium_mg;
        state.fluid_delivered += addOn.fluid_ml;
        console.log(`[ALGO-C] Added sports drink top-up to ${targetPhase} (+${addOn.carbs_g}g carbs)`);
        break;
      }
    }
  }

  // ── Pass 1.6: Sodium overage trim (before drink selection) ─────────
  trimSodiumOverage(results, state, solverCarbsLowG);

  // ── Pass 2: Add standalone drink to top-up phase ──────────────────
  const topUpIdx = results.findIndex((p) => p.phase === 'top_up');
  const eligibleDrinks = getEligibleTemplates(drinkTemplates, 'top_up', diet, dislikedFoods, allergies);
  if (topUpIdx >= 0 && eligibleDrinks.length > 0) {
    const drink = pickDrink(
      eligibleDrinks,
      state.protein_delivered,
      state.sodium_delivered,
      state.fluid_delivered,
      state.protein_high,
      state.sodium_target,
      state.fluid_target,
      state.sodium_high,
      state.fluid_high,
      state.carbs_delivered,
      state.carbs_high,
    );
    if (drink) {
      const phase = results[topUpIdx];
      phase.drink = drink;
      phase.total_carbs_g = Math.round((phase.total_carbs_g + drink.carbs_g) * 10) / 10;
      phase.total_protein_g = Math.round((phase.total_protein_g + drink.protein_g) * 10) / 10;
      phase.total_sodium_mg = Math.round((phase.total_sodium_mg + drink.sodium_mg) * 10) / 10;
      phase.total_fluid_ml = Math.round((phase.total_fluid_ml + drink.fluid_ml) * 10) / 10;

      state.carbs_delivered += drink.carbs_g;
      state.protein_delivered += drink.protein_g;
      state.sodium_delivered += drink.sodium_mg;
      state.fluid_delivered += drink.fluid_ml;
    }
  }

  // ── Pass 3: Add electrolyte supplement independently ──────────────
  const eligibleElectrolytes = getEligibleTemplates(electrolyteTemplates, 'top_up', diet, dislikedFoods, allergies);
  if (topUpIdx >= 0 && eligibleElectrolytes.length > 0) {
    const electrolyte = pickElectrolyte(
      eligibleElectrolytes,
      state.carbs_delivered,
      state.protein_delivered,
      state.sodium_delivered,
      state.fluid_delivered,
      state.carbs_target,
      state.carbs_high,
      state.protein_high,
      state.sodium_low,
      state.sodium_high,
      state.sodium_target,
      state.fluid_high,
      state.fluid_target,
    );
    if (electrolyte) {
      const phase = results[topUpIdx];
      phase.electrolyte = electrolyte;
      phase.total_carbs_g = Math.round((phase.total_carbs_g + electrolyte.carbs_g) * 10) / 10;
      phase.total_sodium_mg = Math.round((phase.total_sodium_mg + electrolyte.sodium_mg) * 10) / 10;
      phase.total_fluid_ml = Math.round((phase.total_fluid_ml + electrolyte.fluid_ml) * 10) / 10;
      state.carbs_delivered += electrolyte.carbs_g;
      state.protein_delivered += electrolyte.protein_g;
      state.sodium_delivered += electrolyte.sodium_mg;
      state.fluid_delivered += electrolyte.fluid_ml;
    }
  }

  // ── Pass 4: Top-off floor — the slot must never ship empty ────────
  // Bug 3ace3fdb: on a long pre-workout window all three phases activate, and
  // meal+snack can consume the whole carb budget at template serving
  // granularity. The cross-phase ceiling guard then skips top_up, Pass 1.5 is
  // a no-op (carbs are already above carbs_low_g, so there is no gap to fill),
  // and Passes 2 and 3 find no drink or electrolyte that fits under
  // fluid_high — so the slot renders as a header with nothing beneath it.
  //
  // Every earlier pass is correctly headroom-guarded; the invariant they do not
  // encode is that a rendered slot has to carry something. This pass is that
  // invariant, and it is deliberately the ONLY place allowed to exceed
  // water_high_ml — see MIN_TOP_UP_FLUID_ML.
  //
  // Note this does not resolve the upstream distribution problem (meal+snack
  // over-consuming top_up's 10% carb share). That is the 60/30/10 budget rework
  // Xuan raised on 2026-07-29, which is blocked on the fueling spec pinning the
  // exact split. This guarantees the floor in the meantime.
  if (topUpIdx >= 0) {
    const phase = results[topUpIdx];

    // Two shapes need the floor, and they are the same defect wearing
    // different clothes:
    //   1. Nothing selected at all — the reported empty header row.
    //   2. An electrolyte tab and nothing else. Non-empty on paper, but a Nuun
    //      tab with no water is not a top-off an athlete can act on; it fails
    //      the same "should at least have a half a cup of water" bar.
    // A slot that landed real food is left alone: it is already actionable,
    // and stapling water onto every such plan is the distribution rework's
    // call to make, not this fix's.
    const hasFood =
      phase.primary !== null || !!phase.stack || phase.add_ons.length > 0;
    const needsFloor = !hasFood && phase.total_fluid_ml < MIN_TOP_UP_FLUID_ML;

    if (needsFloor) {
      // Reuse a real water template when one is eligible so the slot renders
      // with the same name/unit the rest of the plan uses; synthesize the
      // minimum only if the catalog has nothing (or all of it is filtered out).
      const waterTemplate = eligibleDrinks.find(
        (t) => t.fluid_ml > 0 && t.carbs_per_serving === 0 && t.sodium_mg === 0,
      );

      let floor: TemplateSelection;
      if (waterTemplate) {
        // Smallest half-serving that clears the floor, never below the
        // template's own min_servings.
        const servings = Math.max(
          waterTemplate.min_servings,
          snapToHalf(MIN_TOP_UP_FLUID_ML / waterTemplate.fluid_ml),
        );
        floor = makeSelection(waterTemplate, servings);
      } else {
        floor = {
          id: 'water',
          name: 'Water',
          base_category: 'water',
          serving_unit: 'cup',
          servings: 0.5,
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          sodium_mg: 0,
          fluid_ml: MIN_TOP_UP_FLUID_ML,
          component_food_names: ['water'],
          component_quantities: { water: 0.5 },
        };
      }

      // If a sub-floor drink was already attached, the floor replaces it — back
      // its contribution out of both the phase totals and the cross-phase state
      // so nothing is double-counted.
      const displaced = phase.drink;
      if (displaced) {
        phase.total_carbs_g = Math.round((phase.total_carbs_g - displaced.carbs_g) * 10) / 10;
        phase.total_protein_g = Math.round((phase.total_protein_g - displaced.protein_g) * 10) / 10;
        phase.total_sodium_mg = Math.round((phase.total_sodium_mg - displaced.sodium_mg) * 10) / 10;
        phase.total_fluid_ml = Math.round((phase.total_fluid_ml - displaced.fluid_ml) * 10) / 10;
        state.carbs_delivered -= displaced.carbs_g;
        state.protein_delivered -= displaced.protein_g;
        state.sodium_delivered -= displaced.sodium_mg;
        state.fluid_delivered -= displaced.fluid_ml;
      }

      phase.drink = floor;
      phase.total_fluid_ml = Math.round((phase.total_fluid_ml + floor.fluid_ml) * 10) / 10;
      state.fluid_delivered += floor.fluid_ml;

      console.log(
        `[ALGO-C] Top-off floor: slot was empty after all passes, attached ` +
          `${floor.servings} x ${floor.name} (${floor.fluid_ml}ml). ` +
          `Fluid now ${state.fluid_delivered.toFixed(0)}ml of ` +
          `${state.fluid_high.toFixed(0)}ml high.`,
      );
      logFormulaCascade({
        phase: 'before:top_up',
        source: 'solver',
        reason: 'top_off_floor',
        pinSetSize: 0,
      });
    }
  }

  // A template_constraint carb shortfall is recorded at phase-skip time,
  // before the fill passes run. If those passes closed the gap (total is
  // back at/above carbs_low_g), the shortfall is resolved — drop it so the
  // UI doesn't warn about a target the plan actually hits. Preference-driven
  // shortfalls (all_disliked etc.) are left untouched: issue #15 wants those
  // surfaced even when other phases compensate.
  const finalCarbs = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
  if (finalCarbs >= solverCarbsLowG) {
    for (const phase of results) {
      if (!phase.shortfalls) continue;
      const kept = phase.shortfalls.filter(
        (s) => !(s.macro === 'carbs' && s.reason === 'template_constraint'),
      );
      if (kept.length === 0) delete phase.shortfalls;
      else phase.shortfalls = kept;
    }
  }

  return results;
}

/**
 * The RETIRED integer hydration tier, reproduced for backwards compatibility.
 *
 * PW-013. `pre_run_hydration_tier` was replaced by the v6
 * `pre_run_hydration_regime` string, but a Flutter build and a Supabase deploy
 * ship independently and users sit on old builds for weeks. App Store clients
 * up to and including 1.22.x read the integer with a null-safe cast, so
 * dropping the key does not crash them — it silently empties their
 * pre-workout hydration and drops them onto their offline path. Emitting both
 * keys costs nothing and removes the hazard.
 *
 * This deliberately recomputes the OLD rule from the OLD inputs rather than
 * mapping the new regime backwards. A regime->tier map would be a guess:
 * `clearance_bound` has no legacy counterpart, and the legacy gate returned
 * tier 1 regardless of lead time. Replaying the retired branch instead means
 * an old client receives byte-identical values to what it received before the
 * bundle landed.
 *
 * Retired rule (pre-bundle `calculatePreWorkoutHydration`):
 *   gate (workoutDurationMin < 60 && tempC < 30) -> 1  ("irrelevant when
 *                                                       gated", but that is
 *                                                       what it emitted)
 *   timeBeforeWorkoutMin >= 120                  -> 1
 *   timeBeforeWorkoutMin >= 10                   -> 2
 *   otherwise                                    -> 3
 *
 * Delete this once no supported client reads the integer.
 */
export function legacyHydrationTier(input: PreWorkoutHydrationInput): number {
  const { workoutDurationMin, timeBeforeWorkoutMin, tempC } = input;
  const temp = tempC ?? 22;
  if (workoutDurationMin < 60 && temp < 30) return 1;
  if (timeBeforeWorkoutMin >= 120) return 1;
  if (timeBeforeWorkoutMin >= 10) return 2;
  return 3;
}
