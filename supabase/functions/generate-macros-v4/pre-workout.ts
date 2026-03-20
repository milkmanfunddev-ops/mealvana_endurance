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
  type ScoredFormula,
  type AddOn,
  type TemplateSelection,
  type PreWorkoutPhaseResult,
  BUDGET_SPLITS,
  BANANA_CARBS,
  BANANA_SODIUM,
  BANANA_FLUID,
  SPORTS_DRINK_CARBS,
  SPORTS_DRINK_SODIUM,
  SPORTS_DRINK_FLUID,
} from './types.ts';

// ============================================================================
// Algorithm Constants
// ============================================================================

const ADDON_GAP_THRESHOLD = 10;  // Only add banana/drink if gap > 10g
const STACK_THRESHOLD = 0.20;    // Stack second formula if >20% short AND >20g gap
const DIVERSITY_BAND = 0.15;     // Pick among formulas within 15% of best carb gap
const DIVERSITY_FLOOR = 8;       // Minimum absolute carb gap for diversity band

// Foods that may appear across multiple sub-phases without feeling repetitive
const CROSS_PHASE_EXEMPT_FOODS = new Set([
  'water', 'sports_drink', 'sports_drink_mix',
  'electrolyte_tablet', 'electrolyte_drink_mix',
]);

const ALLERGEN_ALIASES: Record<string, string> = {
  peanut: 'peanut',
  peanuts: 'peanut',
  tree_nut: 'tree_nuts',
  tree_nuts: 'tree_nuts',
  tree_nuts_allergy: 'tree_nuts',
  dairy: 'dairy',
  milk: 'dairy',
  eggs: 'eggs',
  egg: 'eggs',
  gluten: 'gluten',
  soy: 'soy',
};

const COMPONENT_ALLERGEN_HINTS: Record<string, string[]> = {
  oatmeal: ['gluten'],
  toast: ['gluten'],
  bagel: ['gluten'],
  cereal: ['gluten'],
  granola: ['gluten'],
  granola_bar: ['gluten'],
  pancake: ['gluten', 'eggs', 'dairy'],
  toaster_waffle: ['gluten', 'eggs', 'dairy'],
  graham_crackers: ['gluten'],
  fig_bar: ['gluten'],
  stroopwafel: ['gluten', 'dairy'],
  pretzels: ['gluten'],
  milk: ['dairy'],
  yogurt: ['dairy'],
  cream_cheese: ['dairy'],
  cheese_slice: ['dairy'],
  butter: ['dairy'],
  protein_shake: ['dairy'],
  protein_powder: ['dairy'],
  peanut_butter: ['peanut'],
  almond_butter: ['tree_nuts'],
  trail_mix: ['tree_nuts', 'peanut'],
  egg: ['eggs'],
  soy_sauce: ['soy', 'gluten'],
  teriyaki_sauce: ['soy', 'gluten'],
};

function normalizeToken(value: string): string {
  return value
    .toLowerCase()
    .trim()
    .replace(/[+]/g, ' ')
    .replace(/[-/]/g, ' ')
    .replace(/\s+/g, '_');
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
// Utility Helpers
// ============================================================================

function snapToHalf(value: number): number {
  return Math.round(value * 2) / 2;
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

function makeBananaAddOn(): AddOn {
  return { type: 'banana', carbs_g: BANANA_CARBS, sodium_mg: BANANA_SODIUM, fluid_ml: BANANA_FLUID, servings: 1 };
}

function makeSportsDrinkAddOn(servings: number = 1): AddOn {
  return {
    type: 'sports_drink',
    carbs_g: Math.round(SPORTS_DRINK_CARBS * servings * 10) / 10,
    sodium_mg: Math.round(SPORTS_DRINK_SODIUM * servings * 10) / 10,
    fluid_ml: Math.round(SPORTS_DRINK_FLUID * servings * 10) / 10,
    servings,
  };
}

// ============================================================================
// Algorithm C Core Logic
// ============================================================================

/**
 * Score a single food template: calculate ideal servings, add-ons.
 * Add-on ordering is sodium-aware.
 */
function scoreFormula(
  template: PreWorkoutTemplate,
  carbTarget: number,
  state: PlanState,
  dislikedSet: Set<string>,
  likedFoods: string[] = [],
): ScoredFormula {
  // Calculate ideal servings directly
  const ideal = carbTarget / template.carbs_per_serving;
  const clamped = Math.max(template.min_servings, Math.min(template.max_servings, ideal));
  const servings = snapToHalf(clamped);

  let carbs = templateCarbs(template, servings);
  let sodium = template.sodium_mg * servings;
  let fluid = template.fluid_ml * servings;
  const addOns: AddOn[] = [];

  // Fill gap with add-ons — sodium-aware ordering
  let gap = carbTarget - carbs;

  // Banana add-on: skip if banana already used in any prior phase or in this template's components
  const bananaAlreadyUsed = state.used_foods.has('banana') ||
    (template.component_food_names ?? []).includes('banana');
  const bananaEligible = template.plus_banana && !bananaAlreadyUsed && !dislikedSet.has('banana');
  const drinkEligible = template.plus_sports_drink &&
    !state.sports_drink_used &&
    !dislikedSet.has('sports_drink') &&
    !dislikedSet.has('sports_drink_mix');

  const sodiumRemaining = state.sodium_target - (state.sodium_delivered + sodium);
  const preferDrinkFirst = sodiumRemaining > 100;

  const addOnOrder = preferDrinkFirst
    ? [{ type: 'sports_drink' as const, eligible: drinkEligible }, { type: 'banana' as const, eligible: bananaEligible }]
    : [{ type: 'banana' as const, eligible: bananaEligible }, { type: 'sports_drink' as const, eligible: drinkEligible }];

  for (const addOn of addOnOrder) {
    if (gap <= ADDON_GAP_THRESHOLD || !addOn.eligible) continue;

    if (addOn.type === 'banana') {
      const withBanana = Math.abs(carbTarget - (carbs + BANANA_CARBS));
      if (withBanana < Math.abs(gap)) {
        carbs += BANANA_CARBS;
        sodium += BANANA_SODIUM;
        fluid += BANANA_FLUID;
        addOns.push(makeBananaAddOn());
        gap = carbTarget - carbs;
      }
    } else {
      // Try variable sports drink servings (0.5, 1, 2 cups) — pick best fit
      const servingOptions = [0.5, 1, 2];
      let bestDrinkServings = 0;
      let bestDrinkGap = Math.abs(gap);

      for (const srv of servingOptions) {
        const drinkCarbs = SPORTS_DRINK_CARBS * srv;
        const drinkSodium = SPORTS_DRINK_SODIUM * srv;
        const drinkFluid = SPORTS_DRINK_FLUID * srv;

        const sodiumWouldOvershoot = (state.sodium_delivered + sodium + drinkSodium) > state.sodium_target * 1.4;
        const fluidWouldOvershoot = state.fluid_target > 0 &&
          (state.fluid_delivered + fluid + drinkFluid) > state.fluid_target * 1.3;
        const wouldOvershoot = sodiumWouldOvershoot || fluidWouldOvershoot;

        const newGap = Math.abs(carbTarget - (carbs + drinkCarbs));
        const carbImprovement = Math.abs(gap) - newGap;
        const carbsNeedHelp = carbImprovement > 5 && carbTarget > 0 && Math.abs(gap) / carbTarget > 0.15;

        if (wouldOvershoot && !preferDrinkFirst && !carbsNeedHelp) continue;

        if (newGap < bestDrinkGap) {
          bestDrinkGap = newGap;
          bestDrinkServings = srv;
        }
      }

      if (bestDrinkServings > 0) {
        const srv = bestDrinkServings;
        carbs += SPORTS_DRINK_CARBS * srv;
        sodium += SPORTS_DRINK_SODIUM * srv;
        fluid += SPORTS_DRINK_FLUID * srv;
        addOns.push(makeSportsDrinkAddOn(srv));
        gap = carbTarget - carbs;
      }
    }
  }

  // Liked-food bonus: reduce effective gap by 15% for templates containing liked ingredients
  let effectiveGap = Math.abs(gap);
  if (likedFoods.length > 0) {
    const components = template.component_food_names ?? [];
    const hasLiked = components.some((name) => likedFoods.includes(name));
    if (hasLiked) {
      effectiveGap *= 0.85; // 15% preference boost
    }
  }

  return { template, servings, carbs, addOns, gap: effectiveGap, sodium, fluid };
}

/**
 * Pick from the carb-close pool using sodium/fluid alignment as tiebreaker,
 * with controlled randomization so repeated plans get variety.
 */
function pickBestFormula(
  scored: ScoredFormula[],
  state: PlanState,
  carbTarget: number,
): ScoredFormula {
  if (scored.length === 0) throw new Error('No candidates');
  if (scored.length === 1) return scored[0];

  scored.sort((a, b) => a.gap - b.gap);
  const bestGap = scored[0].gap;

  const threshold = bestGap + (bestGap * DIVERSITY_BAND) + DIVERSITY_FLOOR;
  const pool = scored.filter((s) => s.gap <= threshold);

  if (pool.length === 1) return pool[0];

  // Score each candidate, then add random jitter so ties resolve differently each run
  const scoredPool: Array<{ candidate: ScoredFormula; score: number }> = [];

  for (const candidate of pool) {
    const resultSodium = state.sodium_delivered + candidate.sodium;
    const resultFluid = state.fluid_delivered + candidate.fluid;

    let sodiumErr = 0;
    if (state.sodium_target > 0) {
      const diff = resultSodium - state.sodium_target;
      sodiumErr = Math.abs(diff) / state.sodium_target * (diff > 0 ? 1.5 : 1.0);
    }

    let fluidErr = 0;
    if (state.fluid_target > 0) {
      const diff = resultFluid - state.fluid_target;
      fluidErr = Math.abs(diff) / state.fluid_target * (diff > 0 ? 1.5 : 1.0);
    }

    const carbErr = carbTarget > 0 ? candidate.gap / carbTarget : 0;
    const baseScore = carbErr + sodiumErr + fluidErr;

    // Add small random jitter (±10% of score, min ±0.05) to break ties
    const jitter = (Math.random() - 0.5) * Math.max(0.1, baseScore * 0.2);
    scoredPool.push({ candidate, score: baseScore + jitter });
  }

  scoredPool.sort((a, b) => a.score - b.score);
  return scoredPool[0].candidate;
}

/**
 * Try to stack a second food template to fill a large remaining gap.
 */
function tryStack(
  remainingGap: number,
  eligible: PreWorkoutTemplate[],
  state: PlanState,
  usedCategory: string,
  usedTemplateId: string,
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
    const gap = Math.abs(remainingGap - carbs);
    const sodium = template.sodium_mg * servings;

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
    sodiumError = Math.abs(diff) / sodiumTarget * (diff > 0 ? 1.5 : 1.0);
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
function pickDrink(
  drinkTemplates: PreWorkoutTemplate[],
  totalSodiumDelivered: number,
  totalFluidDelivered: number,
  sodiumTarget: number,
  fluidTarget: number,
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
function pickElectrolyte(
  electrolyteTemplates: PreWorkoutTemplate[],
  totalSodiumDelivered: number,
  totalFluidDelivered: number,
  sodiumTarget: number,
  fluidTarget: number,
): TemplateSelection | null {
  // Only add electrolyte if sodium is under target
  if (totalSodiumDelivered >= sodiumTarget * 0.9) return null;

  let bestScore = scoreDrinkOption(totalSodiumDelivered, totalFluidDelivered, sodiumTarget, fluidTarget);
  let bestPick: { template: PreWorkoutTemplate; servings: number } | null = null;

  for (const template of electrolyteTemplates) {
    for (let srv = template.min_servings; srv <= template.max_servings; srv += 1) {
      const resultSodium = totalSodiumDelivered + template.sodium_mg * srv;
      // Electrolytes have 0 fluid_ml — they dissolve in the drink
      const resultFluid = totalFluidDelivered + template.fluid_ml * srv;

      const score = scoreDrinkOption(resultSodium, resultFluid, sodiumTarget, fluidTarget);

      if (score < bestScore) {
        bestScore = score;
        bestPick = { template, servings: srv };
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
): PreWorkoutPhaseResult[] {
  if (targets.meal_type === 'fasted') return [];
  const dislikedSet = new Set(dislikedFoods.map(normalizeToken));

  const phases = getActiveSubPhases(hoursBefore);
  const phaseTargets = splitTargets(targets, hoursBefore);

  const state: PlanState = {
    used_foods: new Set(),
    sports_drink_used: false,
    used_categories: new Set(),
    sodium_delivered: 0,
    fluid_delivered: 0,
    sodium_target: targets.sodium_mg,
    fluid_target: targets.water_ml,
  };

  const results: PreWorkoutPhaseResult[] = [];

  // ── Pass 1: Food selection per phase ────────────────────────────────
  for (const phase of phases) {
    const pTargets = phaseTargets.get(phase);
    const carbTarget = pTargets?.carbs_g ?? 0;

    const eligible = getEligibleTemplates(foodTemplates, phase, diet, dislikedFoods, allergies);

    // Filter to unused categories (fallback to all if none left)
    let candidates = eligible.filter((t) => !state.used_categories.has(t.base_category));
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

    if (candidates.length === 0) {
      results.push({
        phase,
        primary: null,
        add_ons: [],
        total_carbs_g: 0,
        total_protein_g: 0,
        total_fat_g: 0,
        total_sodium_mg: 0,
        total_fluid_ml: 0,
      });
      continue;
    }

    // Score every candidate (with liked-food boost)
    const scored = candidates.map((t) => scoreFormula(t, carbTarget, state, dislikedSet, likedFoods));

    // Pick best by combined score
    const pick = pickBestFormula(scored, state, carbTarget);

    // Check stacking
    const deliveredCarbs = templateCarbs(pick.template, pick.servings)
      + pick.addOns.reduce((s, a) => s + a.carbs_g, 0);
    const remainingGap = carbTarget - deliveredCarbs;
    const pctShort = carbTarget > 0 ? remainingGap / carbTarget : 0;

    let stackSelection: TemplateSelection | null = null;

    if (pctShort > STACK_THRESHOLD && remainingGap > 20) {
      const stack = tryStack(remainingGap, eligible, state, pick.template.base_category, pick.template.id);
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
        const phase = results[phaseIdx];
        phase.add_ons.push(makeBananaAddOn());
        phase.total_carbs_g = Math.round((phase.total_carbs_g + BANANA_CARBS) * 10) / 10;
        phase.total_sodium_mg = Math.round((phase.total_sodium_mg + BANANA_SODIUM) * 10) / 10;
        phase.total_fluid_ml = Math.round((phase.total_fluid_ml + BANANA_FLUID) * 10) / 10;
        state.used_foods.add('banana');
        state.sodium_delivered += BANANA_SODIUM;
        state.fluid_delivered += BANANA_FLUID;
        filled = true;
        console.log(`[ALGO-C] Added banana to ${targetPhase} phase (+${BANANA_CARBS}g carbs). ` +
          `New total: ${(totalCarbsAfterPass1 + BANANA_CARBS).toFixed(1)}g`);
      }
    }

    // If banana wasn't enough or wasn't available, try increasing primary servings
    if (!filled) {
      const newTotal = results.reduce((sum, p) => sum + p.total_carbs_g, 0);
      if (newTotal < targets.carbs_low_g) {
        // Find a phase with a primary selection that can take more servings
        for (const targetPhase of phaseOrder) {
          const phaseIdx = results.findIndex((p) => p.phase === targetPhase);
          if (phaseIdx < 0) continue;
          const phase = results[phaseIdx];
          if (!phase.primary) continue;

          // Find the template to check max servings
          const template = foodTemplates.find((t) => t.id === phase.primary!.id);
          if (!template) continue;

          const currentServings = phase.primary.servings;
          if (currentServings < template.max_servings) {
            const extraServings = snapToHalf(Math.min(
              template.max_servings - currentServings,
              (targets.carbs_low_g - newTotal) / template.carbs_per_serving,
            ));
            if (extraServings >= 0.5) {
              const extraCarbs = Math.round(template.carbs_per_serving * extraServings * 10) / 10;
              const extraSodium = Math.round(template.sodium_mg * extraServings * 10) / 10;
              const extraFluid = Math.round(template.fluid_ml * extraServings * 10) / 10;
              const extraProtein = Math.round(template.protein_per_serving * extraServings * 10) / 10;
              const extraFat = Math.round(template.fat_per_serving * extraServings * 10) / 10;

              phase.primary.servings += extraServings;
              phase.primary.carbs_g += extraCarbs;
              phase.primary.protein_g += extraProtein;
              phase.primary.fat_g += extraFat;
              phase.primary.sodium_mg += extraSodium;
              phase.primary.fluid_ml += extraFluid;
              phase.total_carbs_g = Math.round((phase.total_carbs_g + extraCarbs) * 10) / 10;
              phase.total_protein_g = Math.round((phase.total_protein_g + extraProtein) * 10) / 10;
              phase.total_fat_g = Math.round((phase.total_fat_g + extraFat) * 10) / 10;
              phase.total_sodium_mg = Math.round((phase.total_sodium_mg + extraSodium) * 10) / 10;
              phase.total_fluid_ml = Math.round((phase.total_fluid_ml + extraFluid) * 10) / 10;
              state.sodium_delivered += extraSodium;
              state.fluid_delivered += extraFluid;

              console.log(`[ALGO-C] Increased ${targetPhase} primary servings by ${extraServings} (+${extraCarbs}g carbs)`);
              break;
            }
          }
        }
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
          const fluidHeadroom = Math.max(0, targets.water_ml * 1.5 - state.fluid_delivered);
          addServings = Math.min(addServings, snapToHalf(fluidHeadroom / SPORTS_DRINK_FLUID));
        }
        if (addServings < 0.5) continue;

        const addOn = makeSportsDrinkAddOn(addServings);
        phase.add_ons.push(addOn);
        phase.total_carbs_g = Math.round((phase.total_carbs_g + addOn.carbs_g) * 10) / 10;
        phase.total_sodium_mg = Math.round((phase.total_sodium_mg + addOn.sodium_mg) * 10) / 10;
        phase.total_fluid_ml = Math.round((phase.total_fluid_ml + addOn.fluid_ml) * 10) / 10;
        state.sports_drink_used = true;
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
      state.sodium_delivered,
      state.fluid_delivered,
      state.sodium_target,
      state.fluid_target,
    );
    if (drink) {
      const phase = results[topUpIdx];
      phase.drink = drink;
      phase.total_carbs_g = Math.round((phase.total_carbs_g + drink.carbs_g) * 10) / 10;
      phase.total_protein_g = Math.round((phase.total_protein_g + drink.protein_g) * 10) / 10;
      phase.total_sodium_mg = Math.round((phase.total_sodium_mg + drink.sodium_mg) * 10) / 10;
      phase.total_fluid_ml = Math.round((phase.total_fluid_ml + drink.fluid_ml) * 10) / 10;

      state.sodium_delivered += drink.sodium_mg;
      state.fluid_delivered += drink.fluid_ml;
    }
  }

  // ── Pass 3: Add electrolyte supplement independently ──────────────
  const eligibleElectrolytes = getEligibleTemplates(electrolyteTemplates, 'top_up', diet, dislikedFoods, allergies);
  if (topUpIdx >= 0 && eligibleElectrolytes.length > 0) {
    const electrolyte = pickElectrolyte(
      eligibleElectrolytes,
      state.sodium_delivered,
      state.fluid_delivered,
      state.sodium_target,
      state.fluid_target,
    );
    if (electrolyte) {
      const phase = results[topUpIdx];
      phase.electrolyte = electrolyte;
      phase.total_carbs_g = Math.round((phase.total_carbs_g + electrolyte.carbs_g) * 10) / 10;
      phase.total_sodium_mg = Math.round((phase.total_sodium_mg + electrolyte.sodium_mg) * 10) / 10;
      phase.total_fluid_ml = Math.round((phase.total_fluid_ml + electrolyte.fluid_ml) * 10) / 10;
    }
  }

  return results;
}
