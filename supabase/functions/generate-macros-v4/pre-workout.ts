/**
 * Algorithm C: Comfort-Capped Hybrid — Pre-workout food selection
 *
 * Ported from _test/pre-workout-comparison/algorithms/algo-c-comfort-cap.ts
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
  return (
    (state.carbs_delivered + addCarbs) > (state.carbs_high + 1e-6) ||
    (state.protein_delivered + addProtein) > (state.protein_high + 1e-6) ||
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
// Target Calculation
// ============================================================================

/**
 * Calculate pre-workout macro targets with ranges.
 * V4: adds carb/protein ranges on top of V3's sodium/hydration ranges.
 */
export function calculatePreWorkoutTargets(
  weightKg: number,
  hoursBefore: number,
  isFasted: boolean,
  sweatSodiumCat: string,
  envLabel: string,
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

  // Carbs: 1 g/kg per hour, capped at 4h, min 0.5
  const carbPerKg = Math.max(0.5, Math.min(hoursBefore, 4.0));
  const carbs = Math.round(weightKg * carbPerKg);
  const carbsLow = Math.round(carbs * 0.875);   // ±12.5%
  const carbsHigh = Math.round(carbs * 1.125);

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

  if (hoursBefore >= 2.5) {
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
  } else if (hoursBefore >= 1.0) {
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

export interface PreWorkoutHydrationInput {
  bodyWeightKg: number;
  workoutDurationMin: number;
  timeBeforeWorkoutMin: number;
  tempC: number | null;
}

export interface PreWorkoutHydrationResult {
  tier: 1 | 2 | 3;
  gate_triggered: boolean;
  fluid_ml: number;
  fluid_low_ml: number;
  fluid_high_ml: number;
  sodium_mg: number;
  sodium_low_mg: number;
  sodium_high_mg: number;
  message: string | null;
}

/**
 * Pre-workout hydration targets per spec tiers.
 *
 * Gate: workoutDurationMin < 60 AND tempC < 30 → no structured plan.
 * Gate is bypassed when tempC >= 30 regardless of duration.
 *
 * Tier 1 (timeBeforeWorkoutMin >= 120):
 *   fluid = BW * 6 ml [BW*5 .. BW*7]; sodium = 450 mg [300 .. 600]
 * Tier 2 (10 <= timeBeforeWorkoutMin < 120):
 *   fluid = 250 ml [200 .. 300]; sodium = 150 mg [100 .. 200]
 * Tier 3 (timeBeforeWorkoutMin < 10):
 *   fluid = 0; sodium = 0; informational message
 */
export function calculatePreWorkoutHydration(
  input: PreWorkoutHydrationInput,
): PreWorkoutHydrationResult {
  const { bodyWeightKg, workoutDurationMin, timeBeforeWorkoutMin, tempC } = input;
  const temp = tempC ?? 22;

  // Gate: duration < 60 AND temp < 30
  const gateTriggered = workoutDurationMin < 60 && temp < 30;
  if (gateTriggered) {
    // Target is 0 — the spec recommends no structured pre-hydration. We still
    // emit an advisory upper band (matched to Tier-2 ceilings) so the UI can
    // render a meaningful range bar. Athletes who happen to drink a bit pre-
    // workout are graded against this ceiling rather than against zero.
    return {
      tier: 1, // tier is irrelevant when gated, but set to what it would have been
      gate_triggered: true,
      fluid_ml: 0,
      fluid_low_ml: 0,
      fluid_high_ml: 300,
      sodium_mg: 0,
      sodium_low_mg: 0,
      sodium_high_mg: 200,
      message: 'No structured pre-hydration needed for short workouts in mild conditions.',
    };
  }

  // Tier selection
  if (timeBeforeWorkoutMin >= 120) {
    const fluid = Math.round(bodyWeightKg * 6);
    return {
      tier: 1,
      gate_triggered: false,
      fluid_ml: fluid,
      fluid_low_ml: Math.round(bodyWeightKg * 5),
      fluid_high_ml: Math.round(bodyWeightKg * 7),
      sodium_mg: 450,
      sodium_low_mg: 300,
      sodium_high_mg: 600,
      message: null,
    };
  }

  if (timeBeforeWorkoutMin >= 10) {
    return {
      tier: 2,
      gate_triggered: false,
      fluid_ml: 250,
      fluid_low_ml: 200,
      fluid_high_ml: 300,
      sodium_mg: 150,
      sodium_low_mg: 100,
      sodium_high_mg: 200,
      // Spec verbatim (`transparency_pre_hydration.md:49`) + evening-before
      // append for early-morning case (`transparency_pre_hydration.md:57`).
      message:
        'Small top-up only — not enough time for full pre-hydration. Rely on during-workout hydration to cover the gap. For early morning workouts with limited time, consider hydrating well the evening before (extra 300–500 ml with dinner).',
    };
  }

  // Tier 3: too late
  return {
    tier: 3,
    gate_triggered: false,
    fluid_ml: 0,
    fluid_low_ml: 0,
    fluid_high_ml: 0,
    sodium_mg: 0,
    sodium_low_mg: 0,
    sodium_high_mg: 0,
    message: 'Too late for structured pre-hydration. Focus on your during-workout plan.',
  };
}

/**
 * Overlay spec-compliant pre-workout hydration values onto the legacy
 * carb/protein/fat targets produced by calculatePreWorkoutTargets.
 *
 * Carbs/protein/fat/meal_type come from the legacy time-window path (still
 * drives food selection). Fluid and sodium are replaced with the time-tier
 * algorithm values from calculatePreWorkoutHydration.
 */
export function applyPreWorkoutHydrationOverlay(
  targets: PreWorkoutTargets,
  hydration: PreWorkoutHydrationResult,
): PreWorkoutTargets {
  return {
    ...targets,
    sodium_mg: hydration.sodium_mg,
    sodium_low_mg: hydration.sodium_low_mg,
    sodium_high_mg: hydration.sodium_high_mg,
    water_ml: hydration.fluid_ml,
    water_low_ml: hydration.fluid_low_ml,
    water_high_ml: hydration.fluid_high_ml,
  };
}

// ============================================================================
// Phase Schedule & Target Splitting
// ============================================================================

export function getActiveSubPhases(hoursBefore: number): SubPhaseType[] {
  if (hoursBefore >= 2.5) return ['meal', 'snack', 'top_up'];
  if (hoursBefore >= 1.0) return ['snack', 'top_up'];
  return ['top_up'];
}

function getTimeWindowForPhase(phase: SubPhaseType): string {
  switch (phase) {
    case 'meal': return '1.5-3 hours';
    case 'snack': return '30-90 min';
    case 'top_up': return '< 30 min';
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
  const timeWindow = getTimeWindowForPhase(phase);
  let filtered = templates.filter((t) => t.time_window === timeWindow);
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
      const resultCarbs = carbsDelivered + template.carbs_per_serving * servings;
      const resultProtein = proteinDelivered + template.protein_per_serving * servings;
      const resultSodium = totalSodiumDelivered + template.sodium_mg * servings;
      const resultFluid = totalFluidDelivered + template.fluid_ml * servings;

      // Hard cap: skip any combo that would push fluids past 1.5x target
      if (fluidTarget > 0 && resultFluid > fluidTarget * 1.5) continue;
      if (resultCarbs > carbsHigh + 1e-6) continue;
      if (resultProtein > proteinHigh + 1e-6) continue;
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
  // Only add electrolyte if sodium is below the low bound.
  if (totalSodiumDelivered >= sodiumLow) return null;

  let bestScore = scoreDrinkOption(totalSodiumDelivered, totalFluidDelivered, sodiumTarget, fluidTarget);
  let bestPick: { template: PreWorkoutTemplate; servings: number } | null = null;

  for (const template of electrolyteTemplates) {
    for (let srv = template.min_servings; srv <= template.max_servings; srv += 1) {
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

      if (
        score < bestScore ||
        (bestPick === null && resultSodium >= sodiumLow && resultSodium <= sodiumHigh)
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
  if (!bestPick) {
    let leastOvershootSodium = Infinity;
    for (const template of electrolyteTemplates) {
      for (let srv = template.min_servings; srv <= template.max_servings; srv += 1) {
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

// ============================================================================
// Main Entry Point
// ============================================================================

/**
 * Run Algorithm C food selection against pre-workout templates from the database.
 * Returns per-phase food recommendations.
 */
export function selectPreWorkoutFoods(
  targets: PreWorkoutTargets,
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
): PreWorkoutPhaseResult[] {
  if (targets.meal_type === 'fasted') return [];
  const dislikedSet = new Set(dislikedFoods.map(normalizeToken));

  const phases = getActiveSubPhases(hoursBefore);
  const phaseTargets = splitTargets(targets, hoursBefore);

  // ── Pre-check: redistribute budget from empty phases ─────────────
  // If a phase has zero eligible food templates (e.g. all top-off foods
  // disliked), redistribute its carb/protein/fat budget proportionally
  // to the surviving phases so the targets aren't silently dropped.
  const emptyPhases = phases.filter(
    (p) => getEligibleTemplates(foodTemplates, p, diet, dislikedFoods, allergies).length === 0,
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
    carbs_low: targets.carbs_low_g,
    carbs_high: targets.carbs_high_g,
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
    const phaseTimeWindow = getTimeWindowForPhase(phase);
    const pinnedForPhase = pinsActive
      ? foodTemplates.filter(
          (t) => pinnedTemplateIds!.has(t.id) && t.time_window === phaseTimeWindow,
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
            pinned_template_id: null,
            pinned_template_name: null,
            fallthrough_reason: 'no_pin_for_scope' as const,
            pin_set_size: pinnedForPhase.length,
          },
        }),
      });
      continue;
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
      ...(pinsActive && {
        pin_decision: pinOverrideActive
          ? {
              used_pin: true,
              pinned_template_id: pick.template.id,
              pinned_template_name: pick.template.name,
              fallthrough_reason: null,
              pin_set_size: pinnedForPhase.length,
            }
          : {
              used_pin: false,
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
  if (totalCarbsAfterPass1 < targets.carbs_low_g) {
    const carbDeficit = targets.carbs_g - totalCarbsAfterPass1;
    console.log(`[ALGO-C] Cross-phase carb gap: delivered=${totalCarbsAfterPass1.toFixed(1)}g, ` +
      `target=${targets.carbs_g}g, low=${targets.carbs_low_g}g, deficit=${carbDeficit.toFixed(1)}g`);

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
      if (currentTotal >= targets.carbs_low_g) break;
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
      postAdjustTotal < targets.carbs_low_g &&
      !state.sports_drink_used &&
      !dislikedSet.has('sports_drink') &&
      !dislikedSet.has('sports_drink_mix')
    ) {
      const remaining = targets.carbs_low_g - postAdjustTotal;
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
        const carbHeadroom = Math.max(0, targets.carbs_high_g - state.carbs_delivered);
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

  return results;
}
