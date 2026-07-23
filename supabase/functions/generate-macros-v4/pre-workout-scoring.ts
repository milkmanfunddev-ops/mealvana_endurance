/**
 * Pre-workout Algorithm C Scoring Functions
 *
 * Extracted from pre-workout.ts for maintainability.
 * Contains the core scoring/selection algorithm for food templates.
 */

import {
  type PreWorkoutTemplate,
  type PlanState,
  type ScoredFormula,
  type AddOn,
  BANANA_CARBS,
  BANANA_SODIUM,
  BANANA_FLUID,
  SPORTS_DRINK_CARBS,
  SPORTS_DRINK_SODIUM,
  SPORTS_DRINK_FLUID,
} from './types.ts';

import {
  ADDON_GAP_THRESHOLD,
  DIVERSITY_BAND,
  DIVERSITY_FLOOR,
  normalizeToken,
} from './pre-workout-constants.ts';

// ============================================================================
// Utility Helpers
// ============================================================================

function snapToHalf(value: number): number {
  return Math.round(value * 2) / 2;
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
// Core Scoring Logic
// ============================================================================

/**
 * Score a single food template: calculate ideal servings, add-ons.
 * Add-on ordering is sodium-aware.
 */
export function scoreFormula(
  template: PreWorkoutTemplate,
  carbTarget: number,
  state: PlanState,
  dislikedSet: Set<string>,
  likedFoods: string[] = [],
  /**
   * When true, bypass the [min_servings, max_servings] clamp so the scaling
   * factor can exceed the template's normal range. Used for pinned-template
   * honoring per the locked Formula Kit policy ("if the pinned formula needs
   * 3× to hit carb target, ship 3×"). When false (default), behavior is
   * identical to pre-pin v3.
   */
  bypassScaleClamp = false,
): ScoredFormula {
  // Calculate ideal servings directly
  const ideal = carbTarget / template.carbs_per_serving;
  const clamped = bypassScaleClamp
    ? Math.max(0, ideal)
    : Math.max(template.min_servings, Math.min(template.max_servings, ideal));
  const servings = snapToHalf(clamped);

  let carbs = templateCarbs(template, servings);
  let protein = template.protein_per_serving * servings;
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
      if (wouldExceedHighs(state, carbs + BANANA_CARBS, protein, sodium + BANANA_SODIUM, fluid + BANANA_FLUID)) {
        continue;
      }
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

        const sodiumWouldOvershoot = (state.sodium_delivered + sodium + drinkSodium) > state.sodium_high;
        const fluidWouldOvershoot = state.fluid_target > 0 &&
          (state.fluid_delivered + fluid + drinkFluid) > state.fluid_high;
        const carbsWouldOvershoot = (state.carbs_delivered + carbs + drinkCarbs) > state.carbs_high;
        const wouldOvershoot = sodiumWouldOvershoot || fluidWouldOvershoot;

        const newGap = Math.abs(carbTarget - (carbs + drinkCarbs));
        const carbImprovement = Math.abs(gap) - newGap;
        const carbsNeedHelp = carbImprovement > 5 && carbTarget > 0 && Math.abs(gap) / carbTarget > 0.15;

        if ((wouldOvershoot || carbsWouldOvershoot) && !preferDrinkFirst && !carbsNeedHelp) continue;
        if (wouldExceedHighs(state, carbs + drinkCarbs, protein, sodium + drinkSodium, fluid + drinkFluid)) continue;

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
    const likedSet = new Set(likedFoods.map(normalizeToken));
    const hasLiked = components.some((name) => likedSet.has(normalizeToken(name)));
    if (hasLiked) {
      effectiveGap *= 0.85; // 15% preference boost
    }
  }

  return { template, servings, carbs, protein, addOns, gap: effectiveGap, sodium, fluid };
}

/**
 * Pick from the carb-close pool using sodium/fluid alignment as tiebreaker,
 * with controlled randomization so repeated plans get variety.
 */
export function pickBestFormula(
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
  const safePool = pool.filter((candidate) => {
    const resultCarbs = state.carbs_delivered + candidate.carbs;
    const resultProtein = state.protein_delivered + candidate.protein;
    const resultSodium = state.sodium_delivered + candidate.sodium;
    const resultFluid = state.fluid_delivered + candidate.fluid;
    return (
      resultCarbs <= state.carbs_high + 1e-6 &&
      resultProtein <= state.protein_high + 1e-6 &&
      resultSodium <= state.sodium_high + 1e-6 &&
      resultFluid <= state.fluid_high + 1e-6
    );
  });
  const rankedPool = safePool.length > 0 ? safePool : pool;

  if (rankedPool.length === 1) return rankedPool[0];

  // Score each candidate with hard penalties for macro high-bound violations.
  const scoredPool: Array<{ candidate: ScoredFormula; score: number }> = [];

  for (const candidate of rankedPool) {
    const resultCarbs = state.carbs_delivered + candidate.carbs;
    const resultProtein = state.protein_delivered + candidate.protein;
    const resultSodium = state.sodium_delivered + candidate.sodium;
    const resultFluid = state.fluid_delivered + candidate.fluid;

    // Pass 1 optimizes for carb fit + protein fit + athlete preference only.
    // Sodium/fluid delivery is handled by Pass 2 (pickDrink) and Pass 3
    // (pickElectrolyte), which have their own gap-closing scoring. Rewarding
    // sodium/fluid gap-closing here caused meal-phase picks like Potato + Salt
    // to consume the entire session sodium budget, starving downstream passes
    // and triggering the cascade into the no-water bug. (#25)
    const carbErr = carbTarget > 0 ? candidate.gap / carbTarget : 0;
    const proteinErr = state.protein_target > 0
      ? Math.abs(resultProtein - state.protein_target) / state.protein_target
      : 0;

    const carbOverPenalty = state.carbs_target > 0 && resultCarbs > state.carbs_high
      ? ((resultCarbs - state.carbs_high) / state.carbs_target) * 8
      : 0;
    const carbUnderPenalty = state.carbs_target > 0 && resultCarbs < state.carbs_low
      ? ((state.carbs_low - resultCarbs) / state.carbs_target) * 5
      : 0;
    const proteinOverPenalty = state.protein_target > 0 && resultProtein > state.protein_high
      ? ((resultProtein - state.protein_high) / state.protein_target) * 10
      : 0;
    const proteinUnderPenalty = state.protein_target > 0 && resultProtein < state.protein_low
      ? ((state.protein_low - resultProtein) / state.protein_target) * 3
      : 0;
    // Over-cap penalties remain as safety fallback tiebreakers — they only
    // fire when safePool was empty and the algorithm fell back to scoring
    // over-cap candidates. In that degenerate path we still prefer the
    // least-over option. Under-cap penalties were removed: being below
    // sodium_low is what pickElectrolyte exists to rescue.
    const sodiumOverPenalty = state.sodium_target > 0 && resultSodium > state.sodium_high
      ? ((resultSodium - state.sodium_high) / state.sodium_target) * 8
      : 0;
    const fluidOverPenalty = state.fluid_target > 0 && resultFluid > state.fluid_high
      ? ((resultFluid - state.fluid_high) / state.fluid_target) * 6
      : 0;

    const baseScore = carbErr + proteinErr +
      carbOverPenalty + carbUnderPenalty + proteinOverPenalty + proteinUnderPenalty +
      sodiumOverPenalty + fluidOverPenalty;
    scoredPool.push({ candidate, score: baseScore });
  }

  // Sort by score ascending; break ties deterministically by template id.
  // The original implementation kept the top-N within RANDOM_PICK_MARGIN of
  // the best score and picked one at random for "slight variety among
  // near-equal safe candidates." That randomization made byte-identical
  // inputs produce different outputs — caught as the #33 test flake in
  // pre-workout-pinned.test.ts, but the same nondeterminism leaks to users
  // (two replays of the same workout could pick different templates).
  // PreWorkoutTemplate has no selection_priority column, so we use the
  // UUID id as the deterministic secondary key. Variety still comes from
  // upstream — different workouts yield different scores naturally.
  scoredPool.sort((a, b) => {
    const dScore = a.score - b.score;
    if (dScore !== 0) return dScore;
    return a.candidate.template.id.localeCompare(b.candidate.template.id);
  });
  return scoredPool[0].candidate;
}
