/**
 * Generate Nutrition Plan V2 Edge Function
 *
 * Template-based pre-workout food selection with LP solver for during/after phases.
 *
 * Pre-workout (before) phase:
 * - Template selection via meal chain algorithm
 * - Proportional scaling via grid search
 * - Per-phase drink selection from drink pool
 * - Nested sub-phases: meal, snack, top_up
 *
 * During/transition/after phases:
 * - Reuses existing LP solver from _shared/nutrition/lp-solver.ts
 * - Falls back to greedy algorithm if LP fails
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

// Shared utilities
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError } from '../_shared/responses.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';
import { generateUUID, roundToIncrement } from '../_shared/utils.ts';
import { initSentry, withSentry } from '../_shared/sentry.ts';

// Nutrition types and LP solver (unchanged)
import {
  type Phase,
  type ActivityType,
  type MacroTargets,
  type FoodResult,
  type TimingCategory,
  deriveTimingCategory,
  buildLPModel,
  solveLPModel,
  greedyFallback,
  getSportConfig,
  getOptimizationWeights,
  MACRO_CONSTRAINT_RANGES,
  PREFERENCE_SCORE_MAP,
  POST_PROCESS_THRESHOLDS,
  calculateTotals,
} from '../_shared/nutrition/index.ts';

// v2 food queries — queries template_foods table (not legacy foods table)
import { getTemplateFoodsForPhase, getTemplateElectrolyteFoods, getTransitionFoods } from '../_shared/nutrition/template-food-queries.ts';

// Rule-based during solver (replaces LP for during phase)
import { generateDuringPhaseRuleBased } from '../_shared/nutrition/during-rule-solver.ts';

// Template system modules
import {
  type Template,
  type DrinkPoolItem,
  type SubPhaseType,
  type BeforePhaseResult,
  type SubPhaseResult,
} from '../_shared/nutrition/templates/types.ts';

import { getActiveSubPhases, splitPreWorkoutTargets, getSubPhaseTimingLabel } from '../_shared/nutrition/templates/pre-workout-targets.ts';
import { filterTemplatesByDiet, filterDrinksByDiet, scoreTemplatesByPreference } from '../_shared/nutrition/templates/diet-filter.ts';
import { scaleTemplate } from '../_shared/nutrition/templates/scaling.ts';
import { selectTemplateChain } from '../_shared/nutrition/templates/meal-chain.ts';
import { selectDrinksForPhases } from '../_shared/nutrition/templates/drink-selection.ts';

// ============================================================================
// Types
// ============================================================================

interface PlanInputV2 {
  device_id: string;
  activity_type: string;
  hours_before: number;
  weight_kg: number;
  macro_targets: {
    pre_run: MacroTargets & { protein_g?: number; fat_g?: number };
    during_run: MacroTargets;
    post_run: MacroTargets & { protein_g?: number };
  };
  dietary_preference?: string;
  allergies?: string[];
  liked_foods?: string[];
  disliked_foods?: string[];
  willing_to_try_foods?: string[];
  duration_minutes?: number;
  gut_training_level?: 'low' | 'moderate' | 'high';
  brick_segments?: Array<{
    sport: string;
    duration_minutes: number;
    macro_targets: MacroTargets;
  }>;
}

// ============================================================================
// Database Queries
// ============================================================================

async function fetchTemplates(
  supabase: ReturnType<typeof createServiceClient>,
): Promise<Template[]> {
  const { data, error } = await supabase
    .from('templates')
    .select('*')
    .eq('is_active', true)
    .eq('phase', 'before')
    .order('sort_order', { ascending: true });

  if (error) throw new Error(`Failed to fetch templates: ${error.message}`);

  // Parse JSONB fields
  return (data ?? []).map((row: Record<string, unknown>) => ({
    ...row,
    foods: typeof row.foods === 'string' ? JSON.parse(row.foods as string) : (row.foods ?? []),
    allergens: row.allergens ?? [],
    excluded_diets: row.excluded_diets ?? [],
    food_names: row.food_names ?? [],
  })) as Template[];
}

async function fetchDrinkPool(
  supabase: ReturnType<typeof createServiceClient>,
): Promise<DrinkPoolItem[]> {
  const { data, error } = await supabase
    .from('template_foods')
    .select('*')
    .eq('is_drink_pool', true)
    .eq('is_active', true);

  if (error) throw new Error(`Failed to fetch drink pool: ${error.message}`);

  return (data ?? []).map((row: Record<string, unknown>) => ({
    id: row.id,
    name: row.name,
    display_name: row.display_name,
    serving_size: row.serving_size,
    carbs_g: Number(row.carbs_g) || 0,
    protein_g: Number(row.protein_g) || 0,
    fat_g: Number(row.fat_g) || 0,
    sodium_mg: Number(row.sodium_mg) || 0,
    fluid_ml: Number(row.fluid_ml) || 0,
    calories: Number(row.calories) || 0,
    caffeine_mg: row.caffeine_mg != null ? Number(row.caffeine_mg) : null,
    is_electrolyte: row.is_electrolyte === true,
    drink_pool_phases: row.drink_pool_phases ?? [],
  })) as DrinkPoolItem[];
}

// ============================================================================
// Before Phase (Template-Based)
// ============================================================================

async function generateBeforePhase(
  supabase: ReturnType<typeof createServiceClient>,
  input: PlanInputV2,
): Promise<BeforePhaseResult> {
  console.log(`[PLAN-V2] Generating before phase (hours_before=${input.hours_before})`);

  // 0. Handle fasted state: if all pre-run targets are 0, skip the before phase
  const preTargetsCheck = input.macro_targets.pre_run;
  const totalPreCarbs = preTargetsCheck.carbs_g ?? 0;
  const totalPreFluids = preTargetsCheck.water_ml ?? 0;
  if (totalPreCarbs <= 0 && totalPreFluids <= 0) {
    console.log(`[PLAN-V2] Fasted state detected (carbs=0, fluids=0), skipping before phase`);
    return {};
  }

  // 1. Determine active sub-phases
  const activeSubPhases = getActiveSubPhases(input.hours_before);
  console.log(`[PLAN-V2] Active sub-phases: ${activeSubPhases.join(', ')}`);

  // 2. Split targets across sub-phases
  const preTargets = input.macro_targets.pre_run;
  const totalPreTargets = {
    carbs_g: preTargets.carbs_g,
    protein_g: preTargets.protein_g ?? 0,
    fat_g: (preTargets as Record<string, number>).fat_g ?? 0,
    sodium_mg: preTargets.sodium_mg,
    water_ml: preTargets.water_ml,
  };

  const subPhaseTargets = splitPreWorkoutTargets(totalPreTargets, input.hours_before);

  for (const [phase, targets] of subPhaseTargets) {
    console.log(`[PLAN-V2] ${phase} targets: carbs=${targets.carbs_g}g, protein=${targets.protein_g}g, fluid=${targets.water_ml}ml, sodium=${targets.sodium_mg}mg`);
  }

  // 3. Fetch templates and drink pool
  const [allTemplates, drinkPool] = await Promise.all([
    fetchTemplates(supabase),
    fetchDrinkPool(supabase),
  ]);

  console.log(`[PLAN-V2] Fetched ${allTemplates.length} templates, ${drinkPool.length} drinks`);

  // 4. Filter by diet/allergens
  let filteredTemplates = filterTemplatesByDiet(
    allTemplates,
    input.dietary_preference,
    input.allergies,
  );

  // 5. Score by food preferences
  filteredTemplates = scoreTemplatesByPreference(
    filteredTemplates,
    input.liked_foods,
    input.disliked_foods,
  );

  const filteredDrinks = filterDrinksByDiet(
    drinkPool,
    input.dietary_preference,
    input.allergies,
  );

  console.log(`[PLAN-V2] After filtering: ${filteredTemplates.length} templates, ${filteredDrinks.length} drinks`);

  // 6. Select template chain (fit-aware: prefers templates whose base carbs naturally match the target)
  const templateChain = selectTemplateChain(filteredTemplates, activeSubPhases, subPhaseTargets);

  // 7. Build has_liquid_base phase set (skip drink assignment for these)
  const hasLiquidBasePhases = new Set<SubPhaseType>();
  for (const [subPhase, template] of templateChain) {
    if (template.has_liquid_base) {
      hasLiquidBasePhases.add(subPhase);
      console.log(`[PLAN-V2] ${subPhase}: template "${template.name}" has liquid base — skipping drink`);
    }
  }

  // 8. Select drinks for each phase (skipping has_liquid_base phases)
  const drinkTargetsMap = new Map<SubPhaseType, { carbs_g: number; water_ml: number }>();
  for (const [phase, targets] of subPhaseTargets) {
    drinkTargetsMap.set(phase, { carbs_g: targets.carbs_g, water_ml: targets.water_ml });
  }

  const selectedDrinks = selectDrinksForPhases(
    filteredDrinks,
    activeSubPhases,
    drinkTargetsMap,
    input.liked_foods,
    input.disliked_foods,
    hasLiquidBasePhases,
  );

  // 8b. Fetch display_name_plural for all template_foods (templates only
  // store display_name; the plural form lives in the template_foods table).
  // This covers both template foods and drink-pool items in a single query.
  const displayPluralMap = new Map<string, string>();
  {
    const { data: pluralRows } = await supabase
      .from('template_foods')
      .select('id, display_name_plural')
      .eq('is_active', true);
    for (const row of pluralRows ?? []) {
      if (row.display_name_plural) displayPluralMap.set(row.id as string, row.display_name_plural as string);
    }
  }

  // 9. Scale templates and build sub-phase results
  const beforeResult: BeforePhaseResult = {};

  for (const subPhase of activeSubPhases) {
    const template = templateChain.get(subPhase);
    const drink = selectedDrinks.get(subPhase);
    const targets = subPhaseTargets.get(subPhase)!;

    if (!template) {
      console.log(`[PLAN-V2] No template for ${subPhase}, skipping`);
      continue;
    }

    // Calculate drink contributions to subtract from food targets
    const drinkCarbs = drink ? drink.carbs_grams : 0;
    const drinkFluids = drink ? drink.fluids_ml : 0;
    const drinkSodium = drink ? drink.sodium_mg : 0;

    // Scale template foods (adjusted targets account for drink contribution)
    const scaled = scaleTemplate(template.foods, targets, drinkCarbs, drinkFluids, drinkSodium);

    console.log(
      `[PLAN-V2] ${subPhase}: ${template.name} scaled @${scaled.multiplier}x ` +
      `(score: ${scaled.score.toFixed(2)}, carbs: ${scaled.total_carbs}g)`
    );

    // Convert scaled foods to FoodResult format
    // Only include fluids_ml for liquid foods (milk, OJ) — non-liquid food moisture
    // (banana 88ml, grapes 122ml) doesn't count toward hydration targets
    const foodResults: FoodResult[] = scaled.foods.map((sf) => {
      const originalFood = template.foods.find(f => f.food_id === sf.food_id);
      const isLiquid = originalFood?.is_liquid === true;
      return {
        food_id: sf.food_id,
        quantity: sf.quantity,
        carbs_grams: sf.carbs_grams,
        protein_grams: sf.protein_grams,
        fat_grams: sf.fat_grams,
        sodium_mg: sf.sodium_mg,
        fluids_ml: isLiquid ? sf.fluids_ml : 0,
        calories: sf.calories,
        display_name: sf.display_name,
        display_name_plural: displayPluralMap.get(sf.food_id) ?? undefined,
        serving_size: sf.serving_size,
        timing: getSubPhaseTimingLabel(subPhase, input.hours_before),
        is_drink: isLiquid,
        is_liquid: isLiquid,
        template_id: template.id,
        scale_multiplier: sf.scale_multiplier,
      } as FoodResult & { is_drink: boolean; is_liquid: boolean; template_id: string; scale_multiplier: number };
    });

    // Add drink to the food list — but skip if template already includes a liquid food
    // (e.g., Sports Drink Mix in template + Sports Drink from drink pool = duplicate)
    const templateHasLiquid = foodResults.some(
      (f: any) => f.is_liquid === true
    );
    if (drink && !templateHasLiquid) {
      foodResults.push({
        ...drink,
        display_name_plural: displayPluralMap.get(drink.id) ?? undefined,
        timing: getSubPhaseTimingLabel(subPhase, input.hours_before),
      });
    } else if (drink && templateHasLiquid) {
      console.log(
        `[PLAN-V2] ${subPhase}: skipping drink "${drink.display_name}" — template already has a liquid food`
      );
    }

    const subPhaseResult: SubPhaseResult = {
      sub_phase_type: subPhase,
      targets,
      foods: foodResults,
      template_id: template.id,
      template_name: template.name,
      drink: drink ?? undefined,
    };

    if (subPhase === 'meal') beforeResult.meal = subPhaseResult;
    else if (subPhase === 'snack') beforeResult.snack = subPhaseResult;
    else if (subPhase === 'top_up') beforeResult.top_up = subPhaseResult;
  }

  return beforeResult;
}

// ============================================================================
// By-Hour Apportionment (Server-Side)
// ============================================================================

interface ByHourTimeSlot {
  hourIndex: number;
  slotIndex: number;
}

interface ByHourAssignment {
  foodItemId: string;
  timeSlot: ByHourTimeSlot;
  isSipThroughout: boolean;
  adjustedQuantity: number;
  timingCategory: string;
}

interface ByHourData {
  durationMinutes: number;
  assignments: ByHourAssignment[];
}

const QUIET_ZONE_MINUTES = 30;
const END_CUTOFF_MINUTES = 15;
const SIP_INCREMENT = 0.5;
const QUICK_INCREMENT = 0.5;

function gelIntervalMinutes(gutTrainingLevel: string): number {
  switch (gutTrainingLevel) {
    case 'low': return 45;
    case 'high': return 25;
    default: return 30; // moderate
  }
}

function minuteToTimeSlot(absoluteMinutes: number): ByHourTimeSlot {
  const hourIndex = Math.floor(absoluteMinutes / 60);
  const minuteInHour = absoluteMinutes % 60;
  const slotIndex = Math.min(Math.floor(minuteInHour / 15), 3);
  return { hourIndex, slotIndex };
}

function sipPlacementCount(originalQty: number, totalHours: number): number {
  let placementCount = totalHours;
  const perHourQty = placementCount > 0 ? originalQty / placementCount : 0;
  if (perHourQty < SIP_INCREMENT && originalQty > 0) {
    placementCount = Math.min(
      totalHours,
      Math.max(1, Math.floor(originalQty / SIP_INCREMENT)),
    );
  }
  return placementCount;
}

function splitSipQuantity(originalQty: number, placementCount: number): number[] {
  if (placementCount <= 0) return [];

  // Snap to 0.5 increments while preserving total quantity.
  const baseQty = Math.floor((originalQty / placementCount) / SIP_INCREMENT) * SIP_INCREMENT;
  const quantities = Array.from(
    { length: placementCount },
    () => Math.round(baseQty * 10) / 10,
  );

  const assignedTotal = quantities.reduce((sum, q) => sum + q, 0);
  let extraUnits = Math.floor((originalQty - assignedTotal + 1e-9) / SIP_INCREMENT);
  extraUnits = Math.max(0, Math.min(extraUnits, placementCount));

  // Add remainder to later hours (e.g., 8 over 3h => 2.5, 2.5, 3.0).
  for (let i = 0; i < extraUnits; i++) {
    const idx = placementCount - 1 - i;
    quantities[idx] = Math.round((quantities[idx] + SIP_INCREMENT) * 10) / 10;
  }

  return quantities;
}

function eventPlacementCount(
  originalQty: number,
  availableSlots: number,
  minIncrement: number,
  isIndivisible: boolean,
): number {
  if (availableSlots <= 0) return 0;
  const qty = originalQty < 1 ? 1 : originalQty;

  if (isIndivisible) {
    return Math.min(availableSlots, Math.max(1, Math.round(qty)));
  }

  let placementCount = availableSlots;
  const perSlotQty = qty / placementCount;
  if (perSlotQty < minIncrement) {
    placementCount = Math.min(
      availableSlots,
      Math.max(1, Math.floor(qty / minIncrement)),
    );
  }
  return placementCount;
}

function selectEvenlySpacedMinutes(minutes: number[], count: number): number[] {
  if (count <= 0 || minutes.length === 0) return [];
  if (count >= minutes.length) return [...minutes];
  if (count === 1) return [minutes[0]];

  const selectedIdx: number[] = [];
  const used = new Set<number>();
  const maxIndex = minutes.length - 1;

  for (let i = 0; i < count; i++) {
    let idx = Math.round((i * maxIndex) / (count - 1));
    if (!used.has(idx)) {
      used.add(idx);
      selectedIdx.push(idx);
      continue;
    }

    let offset = 1;
    let placed = false;
    while (!placed) {
      const left = idx - offset;
      const right = idx + offset;
      if (left >= 0 && !used.has(left)) {
        used.add(left);
        selectedIdx.push(left);
        placed = true;
      } else if (right <= maxIndex && !used.has(right)) {
        used.add(right);
        selectedIdx.push(right);
        placed = true;
      } else {
        offset += 1;
      }
    }
  }

  selectedIdx.sort((a, b) => a - b);
  return selectedIdx.map((idx) => minutes[idx]);
}

function omitLastAllowedPlacement(minutes: number[]): number[] {
  if (minutes.length <= 1) return minutes;
  return minutes.slice(0, minutes.length - 1);
}

/**
 * @deprecated No longer used for during phase (rule solver returns no by-hour data).
 * Kept for potential future use. Client creates empty buckets for user-driven placement.
 *
 * Generate by-hour time slot assignments for during-phase foods.
 *
 * Same 4-phase algorithm as client-side ByHourApportionmentService:
 * Phase 1: SIP_THROUGHOUT — drinks at :00 every hour
 * Phase 2: ELECTROLYTES — every 60 min starting at minute 60 (skip if <90 min)
 * Phase 3: QUICK_CONSUME — gels/chews after quiet zone, spaced by gut training
 * Phase 4: SLOW_CONSUME — bars/real food after quiet zone
 */
function generateByHourData(
  foods: FoodResult[],
  durationMinutes: number,
  activityType: string,
  gutTrainingLevel: string = 'moderate',
): ByHourData | null {
  if (durationMinutes < 60) return null;
  if (foods.length === 0) {
    return { durationMinutes, assignments: [] };
  }

  const totalHours = Math.max(1, Math.ceil(durationMinutes / 60));
  const assignments: ByHourAssignment[] = [];

  // Categorize foods
  const sipItems: FoodResult[] = [];
  const electrolyteItems: FoodResult[] = [];
  const quickItems: FoodResult[] = [];
  const slowItems: FoodResult[] = [];

  for (const food of foods) {
    const tc = food.timing_category ?? 'slow_consume';
    switch (tc) {
      case 'sip_throughout':
      case 'fuel_drink':
        // fuel_drink is placed like sip_throughout (at :00) but tagged differently for UI
        sipItems.push(food);
        break;
      case 'electrolyte':
        electrolyteItems.push(food);
        break;
      case 'quick_consume':
        quickItems.push(food);
        break;
      default:
        slowItems.push(food);
        break;
    }
  }

  // Phase 1: SIP_THROUGHOUT + FUEL_DRINK — drinks at :00 every hour
  for (const drink of sipItems) {
    const originalQty = drink.quantity;
    const placementCount = sipPlacementCount(originalQty, totalHours);
    const splitQuantities = splitSipQuantity(originalQty, placementCount);
    const hourStep = placementCount < totalHours
      ? Math.floor(totalHours / placementCount)
      : 1;

    // Preserve the original timing category for UI display
    const tc = drink.timing_category ?? 'sip_throughout';
    const assignmentCategory = tc === 'fuel_drink' ? 'fuelDrink' : 'sipThroughout';
    const isSip = tc !== 'fuel_drink';

    for (let i = 0; i < placementCount; i++) {
      const h = Math.min(i * hourStep, totalHours - 1);
      assignments.push({
        foodItemId: drink.food_id,
        timeSlot: { hourIndex: h, slotIndex: 0 },
        isSipThroughout: isSip,
        adjustedQuantity: splitQuantities[i],
        timingCategory: assignmentCategory,
      });
    }
  }

  // Phase 2: ELECTROLYTES — every 60 min starting at minute 60, skip if <90 min
  // Enforce whole-number quantities (can't split a tablet)
  if (durationMinutes >= 90) {
    for (const elec of electrolyteItems) {
      const allMinutes: number[] = [];
      for (let m = 60; m < durationMinutes; m += 60) {
        allMinutes.push(m);
      }
      if (allMinutes.length === 0) continue;

      // Round to whole number — tablets are indivisible
      const wholeQty = Math.max(1, Math.round(elec.quantity));
      // Limit placements to available quantity (each gets exactly 1)
      const placementCount = Math.min(allMinutes.length, wholeQty);
      const usedMinutes = allMinutes.slice(0, placementCount);

      for (const minute of usedMinutes) {
        assignments.push({
          foodItemId: elec.food_id,
          timeSlot: minuteToTimeSlot(minute),
          isSipThroughout: false,
          adjustedQuantity: 1.0,
          timingCategory: 'electrolyte',
        });
      }
    }
  }

  // Phase 3: QUICK_CONSUME — gels/chews after quiet zone, spaced by gut training
  // Distribute by time to avoid early front-loading.
  if (quickItems.length > 0) {
    const interval = gelIntervalMinutes(gutTrainingLevel);
    const endCutoff = durationMinutes - END_CUTOFF_MINUTES;

    const placementMinutes: number[] = [];
    for (let m = QUIET_ZONE_MINUTES; m <= endCutoff; m += interval) {
      placementMinutes.push(m);
    }
    const trimmedPlacementMinutes = omitLastAllowedPlacement(placementMinutes);

    if (trimmedPlacementMinutes.length > 0) {
      for (const food of quickItems) {
        const originalQty = food.quantity;
        const placementCount = eventPlacementCount(
          originalQty,
          trimmedPlacementMinutes.length,
          QUICK_INCREMENT,
          food.is_indivisible === true,
        );
        const selectedMinutes = selectEvenlySpacedMinutes(
          trimmedPlacementMinutes,
          placementCount,
        );
        const splitQuantities = food.is_indivisible
          ? Array.from({ length: placementCount }, () => 1.0)
          : splitSipQuantity(originalQty, placementCount);

        for (let i = 0; i < selectedMinutes.length; i++) {
          assignments.push({
            foodItemId: food.food_id,
            timeSlot: minuteToTimeSlot(selectedMinutes[i]),
            isSipThroughout: false,
            adjustedQuantity: splitQuantities[i],
            timingCategory: 'quickConsume',
          });
        }
      }
    }
  }

  // Phase 4: SLOW_CONSUME — bars/real food after quiet zone
  if (slowItems.length > 0) {
    let endCutoff = durationMinutes - END_CUTOFF_MINUTES;

    // Cycling: solids only in first 2/3
    if (activityType === 'cycling') {
      const twoThirds = Math.round(durationMinutes * 2 / 3);
      endCutoff = Math.min(endCutoff, twoThirds);
    }

    // Place solids, avoiding :00 (top-of-hour) slots reserved for drinks
    const placementMinutes: number[] = [];
    for (let m = QUIET_ZONE_MINUTES; m <= endCutoff; m += 30) {
      if (m % 60 === 0) continue; // Skip :00 slots
      placementMinutes.push(m);
    }

    if (placementMinutes.length > 0) {
      for (let i = 0; i < slowItems.length; i++) {
        const food = slowItems[i];
        const foodPlacements: number[] = [];
        for (let j = i; j < placementMinutes.length; j += slowItems.length) {
          foodPlacements.push(placementMinutes[j]);
        }

        if (foodPlacements.length === 0) {
          foodPlacements.push(QUIET_ZONE_MINUTES);
        }

        const originalQty = food.is_indivisible
          ? Math.max(1, Math.round(food.quantity))
          : food.quantity;
        let remaining = originalQty < 1 ? 1 : originalQty;

        for (const minute of foodPlacements) {
          if (remaining <= 0) break;
          assignments.push({
            foodItemId: food.food_id,
            timeSlot: minuteToTimeSlot(minute),
            isSipThroughout: false,
            adjustedQuantity: 1.0,
            timingCategory: 'slowConsume',
          });
          remaining -= 1;
        }
      }
    }
  }

  return { durationMinutes, assignments };
}

// ============================================================================
// During Phase Post-Processing (Two-Pass Approach)
// ============================================================================

/**
 * @deprecated No longer used for during phase (rule solver handles electrolytes inline).
 * Kept for potential future use.
 *
 * Post-process during-phase results to fill sodium deficit with electrolyte supplements.
 *
 * Pass 1 (LP solver) focuses on carbs + preference with reduced sodium weight.
 * Pass 2 (this function) adds electrolyte supplements to fill any sodium gap.
 *
 * Adapted from v1's postProcessPhase() pattern.
 */
async function postProcessDuringPhase(
  supabase: ReturnType<typeof createServiceClient>,
  resultFoods: FoodResult[],
  targets: MacroTargets,
  maxFoodsAllowed: number,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
): Promise<FoodResult[]> {
  const totals = calculateTotals(resultFoods);
  const sodiumDeficit = targets.sodium_mg - totals.sodium_mg;
  const deficitPercent = targets.sodium_mg > 0 ? sodiumDeficit / targets.sodium_mg : 0;
  const existingElectrolyteIndex = resultFoods.findIndex(
    (f) => f.is_electrolyte === true || f.timing_category === 'electrolyte',
  );

  console.log(
    `[POST-PROCESS-DURING] Totals: sodium=${totals.sodium_mg.toFixed(0)}mg, ` +
    `target=${targets.sodium_mg}mg, deficit=${sodiumDeficit.toFixed(0)}mg (${(deficitPercent * 100).toFixed(1)}%)`
  );

  // Skip if sodium deficit is within threshold
  if (deficitPercent <= POST_PROCESS_THRESHOLDS.sodium_deficit_percent) {
    console.log(`[POST-PROCESS-DURING] Sodium within threshold (${(deficitPercent * 100).toFixed(1)}% <= ${(POST_PROCESS_THRESHOLDS.sodium_deficit_percent * 100)}%), skipping`);
    return resultFoods;
  }

  // Skip if already at max food items and we can't edit an existing electrolyte item.
  if (resultFoods.length >= maxFoodsAllowed && existingElectrolyteIndex < 0) {
    console.log(`[POST-PROCESS-DURING] Already ${resultFoods.length} foods, skipping electrolyte addition`);
    return resultFoods;
  }

  // If an electrolyte already exists, top it up first instead of skipping.
  if (existingElectrolyteIndex >= 0) {
    const existing = resultFoods[existingElectrolyteIndex];
    const currentServings = Math.max(1, existing.quantity || 1);
    const sodiumPerServing = existing.sodium_mg / currentServings;

    if (sodiumPerServing > 0) {
      let additionalServings = sodiumDeficit / sodiumPerServing;
      const isIndivisible = existing.is_indivisible ?? true;
      additionalServings = isIndivisible
        ? Math.max(1, Math.round(additionalServings))
        : roundToIncrement(additionalServings);

      const maxSodiumAllowed = targets.sodium_mg * 1.1;
      const maxAdditionalForCap = (maxSodiumAllowed - totals.sodium_mg) / sodiumPerServing;
      const cappedAdditional = isIndivisible
        ? Math.max(0, Math.floor(maxAdditionalForCap))
        : roundToIncrement(Math.max(0, maxAdditionalForCap));
      additionalServings = Math.min(additionalServings, cappedAdditional);

      if (additionalServings > 0) {
        const nextServings = currentServings + additionalServings;
        const perServingCarbs = existing.carbs_grams / currentServings;
        const perServingProtein = existing.protein_grams / currentServings;
        const perServingFat = existing.fat_grams / currentServings;
        const perServingFluids = existing.fluids_ml / currentServings;
        const perServingCalories = existing.calories / currentServings;

        const updated = {
          ...existing,
          quantity: nextServings,
          carbs_grams: existing.carbs_grams + perServingCarbs * additionalServings,
          protein_grams: existing.protein_grams + perServingProtein * additionalServings,
          fat_grams: existing.fat_grams + perServingFat * additionalServings,
          sodium_mg: existing.sodium_mg + sodiumPerServing * additionalServings,
          fluids_ml: existing.fluids_ml + perServingFluids * additionalServings,
          calories: Math.round(existing.calories + perServingCalories * additionalServings),
        } as FoodResult;

        const updatedFoods = [...resultFoods];
        updatedFoods[existingElectrolyteIndex] = updated;
        return updatedFoods;
      }
    }
  }

  // Fetch electrolyte foods
  const electrolytes = await getTemplateElectrolyteFoods(supabase, likedFoods, willingToTryFoods, dislikedFoods);
  if (electrolytes.length === 0) {
    console.log(`[POST-PROCESS-DURING] No electrolyte foods available`);
    return resultFoods;
  }

  // Sort by sodium-to-water ratio (prefer high sodium, low water — tablets over drinks)
  const sortedElectrolytes = [...electrolytes].sort((a, b) => {
    const ratioA = a.per_serving.sodium_mg / Math.max(1, a.per_serving.water_ml);
    const ratioB = b.per_serving.sodium_mg / Math.max(1, b.per_serving.water_ml);
    return ratioB - ratioA;
  });

  const best = sortedElectrolytes[0];

  // Calculate needed servings to fill deficit
  if (best.per_serving.sodium_mg <= 0) {
    console.log(`[POST-PROCESS-DURING] Best electrolyte has 0mg sodium, skipping`);
    return resultFoods;
  }

  let neededServings = sodiumDeficit / best.per_serving.sodium_mg;

  // Enforce is_indivisible rounding (electrolytes are typically tablets)
  neededServings = best.is_indivisible
    ? Math.max(1, Math.round(neededServings))
    : roundToIncrement(neededServings);

  // Cap: don't overshoot sodium by more than 10%
  const maxSodiumAllowed = targets.sodium_mg * 1.1;
  const maxServingsForCap = (maxSodiumAllowed - totals.sodium_mg) / best.per_serving.sodium_mg;
  const cappedServings = best.is_indivisible
    ? Math.max(1, Math.floor(maxServingsForCap))
    : roundToIncrement(Math.max(0.5, maxServingsForCap));

  neededServings = Math.min(neededServings, cappedServings);

  if (neededServings <= 0) {
    console.log(`[POST-PROCESS-DURING] Needed servings <= 0 after capping, skipping`);
    return resultFoods;
  }

  console.log(
    `[POST-PROCESS-DURING] Adding ${neededServings}x "${best.display_name ?? best.name}" ` +
    `(${(best.per_serving.sodium_mg * neededServings).toFixed(0)}mg sodium)`
  );

  const electrolyteFoodResult: FoodResult = {
    food_id: best.id,
    quantity: neededServings,
    carbs_grams: best.per_serving.carbs_g * neededServings,
    protein_grams: best.per_serving.protein_g * neededServings,
    fat_grams: best.per_serving.fat_g * neededServings,
    sodium_mg: best.per_serving.sodium_mg * neededServings,
    fluids_ml: best.per_serving.water_ml * neededServings,
    calories: best.per_serving.calories * neededServings,
    timing: 'Throughout activity',
    display_name: best.display_name ?? undefined,
    display_name_plural: best.display_name_plural ?? undefined,
    description: best.description ?? undefined,
    image_address: best.image_address ?? undefined,
    is_liquid: false,
    is_electrolyte: true,
    is_drink: false,
    is_indivisible: best.is_indivisible ?? true,
    timing_category: 'electrolyte',
    product_type: best.product_type,
  };

  return [...resultFoods, electrolyteFoodResult];
}

// ============================================================================
// During/After Phases (LP-Based, reusing existing solver)
// ============================================================================

interface LPPhaseResult {
  foods: FoodResult[];
  by_hour_data?: ByHourData | null;
}

async function generateLPPhase(
  supabase: ReturnType<typeof createServiceClient>,
  phase: Phase,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  durationMinutes?: number,
  gutTrainingLevel?: string,
): Promise<LPPhaseResult> {
  console.log(`[PLAN-V2] Generating ${phase} phase via LP solver`);
  const isDuringPhase = phase === 'during';
  const useDefaultDuringFilter = isDuringPhase && activityType === 'running';

  // Get foods for this phase from template_foods table
  let foods = await getTemplateFoodsForPhase(
    supabase,
    phase,
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    false,
  );

  if (foods.length === 0) {
    console.log(`[PLAN-V2] No foods found for ${phase} phase`);
    return { foods: [] };
  }

  console.log(`[PLAN-V2] ${phase}: ${foods.length} foods available`);

  // Hydration strategy: filter food pool based on carb demand per hour
  if (isDuringPhase && durationMinutes && durationMinutes > 0) {
    const durationHours = durationMinutes / 60;
    const carbsPerHour = targets.carbs_g / durationHours;

    if (carbsPerHour <= 30) {
      // Low carb demand: remove sports drink, let electrolyte+water handle hydration
      const before = foods.length;
      foods = foods.filter(f => {
        const tc = deriveTimingCategory(f);
        return tc !== 'fuel_drink';
      });
      if (foods.length < before) {
        console.log(`[PLAN-V2] Hydration strategy: electrolyte_water (removed ${before - foods.length} fuel drinks, carbsPerHour=${carbsPerHour.toFixed(1)})`);
      }
    } else if (carbsPerHour > 60) {
      console.log(`[PLAN-V2] Hydration strategy: sports_drink (high carb demand, carbsPerHour=${carbsPerHour.toFixed(1)})`);
    }
    // carbsPerHour 30-60: 'auto' — no filtering, let LP decide
  }

  const sportConfig = getSportConfig(activityType);
  const phaseConfig = sportConfig.phases[phase];

  // Get optimization weights for this phase
  const weights = getOptimizationWeights(activityType, phase);

  // Two-pass approach for during phase:
  // Pass 1: LP solver with reduced sodium weight so carbs + preference dominate
  // Pass 2: Post-processing adds electrolyte supplements to fill sodium deficit
  const weightOverrides = isDuringPhase ? { sodium: 0.05 } : undefined;
  const constraintOverrides = isDuringPhase
    ? { sodium: { min: 0.0, max: 1.1 } }
    : undefined;
  const modelOptions = {
    maxFoodItems: phaseConfig.maxFoods,
    maxServingsCap: phaseConfig.maxServingsCap,
    selectionPenalty: isDuringPhase ? 1.0 : 0.1,
    maxElectrolyteSupplements: isDuringPhase && activityType === 'running' ? 1 : undefined,
    enforceWaterMin: isDuringPhase,
    randomVariance: isDuringPhase,
  };

  // Build and solve LP model
  let model = buildLPModel(
    foods,
    targets,
    phase,
    weights,
    weightOverrides,
    constraintOverrides,
    modelOptions,
  );
  let solution = solveLPModel(model, foods, phase);

  // Running during default policy:
  // if default pool is infeasible, retry with all during foods.
  if (useDefaultDuringFilter && (!solution || solution.foods.length === 0)) {
    const expandedFoods = await getTemplateFoodsForPhase(
      supabase,
      phase,
      activityType,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
      deviceId,
      true,
    );
    if (expandedFoods.length > foods.length) {
      console.log(
        `[PLAN-V2] during running default pool infeasible; retrying with expanded food pool (${foods.length} -> ${expandedFoods.length})`
      );
      foods = expandedFoods;
      model = buildLPModel(
        foods,
        targets,
        phase,
        weights,
        weightOverrides,
        constraintOverrides,
        modelOptions,
      );
      solution = solveLPModel(model, foods, phase);
    }
  }

  let resultFoods: FoodResult[];
  if (solution && solution.foods.length > 0) {
    console.log(`[PLAN-V2] ${phase} LP solved: ${solution.foods.length} foods`);
    resultFoods = solution.foods;
  } else {
    // Fallback to greedy
    console.log(`[PLAN-V2] ${phase} LP failed, using greedy fallback`);
    const greedyResult = greedyFallback(foods, targets, phase);
    resultFoods = greedyResult.foods;
  }

  // Pass 2: Post-process during phase to add electrolyte supplements for sodium deficit
  if (isDuringPhase) {
    resultFoods = await postProcessDuringPhase(
      supabase,
      resultFoods,
      targets,
      phaseConfig.maxFoods,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
    );
  }

  // Generate by-hour data for during phase
  let byHourData: ByHourData | null = null;
  if (isDuringPhase && durationMinutes && durationMinutes >= 60) {
    byHourData = generateByHourData(resultFoods, durationMinutes, activityType, gutTrainingLevel ?? 'moderate');
    if (byHourData) {
      console.log(`[PLAN-V2] Generated by-hour data: ${byHourData.assignments.length} assignments for ${durationMinutes}min`);
    }
  }

  return { foods: resultFoods, by_hour_data: byHourData };
}

// ============================================================================
// During Phase (Rule-Based)
// ============================================================================

/**
 * Generate during-phase food selection using deterministic rules.
 * Swimming returns empty immediately. Run/bike use the rule solver.
 * No server-side by-hour apportionment (client creates empty buckets).
 */
async function generateDuringPhase(
  supabase: ReturnType<typeof createServiceClient>,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
): Promise<LPPhaseResult> {
  // Swimming: no during-phase nutrition
  if (activityType === 'swimming') {
    console.log('[PLAN-V2] Swimming activity — skipping during phase');
    return { foods: [], by_hour_data: null };
  }

  console.log(`[PLAN-V2] Generating during phase via rule solver (${activityType})`);

  // Get foods from template_foods table
  let foods = await getTemplateFoodsForPhase(
    supabase,
    'during',
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    false,
  );

  if (foods.length === 0) {
    console.log('[PLAN-V2] No during foods found, trying expanded pool');
    foods = await getTemplateFoodsForPhase(
      supabase,
      'during',
      activityType,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
      deviceId,
      true,
    );
  }

  if (foods.length === 0) {
    console.log('[PLAN-V2] No during foods available at all');
    return { foods: [] };
  }

  const result = generateDuringPhaseRuleBased(foods, targets, activityType);

  // No server-side by-hour data — client creates empty buckets
  return { foods: result.foods, by_hour_data: null };
}

// ============================================================================
// Transition Targets (Distance-Based)
// ============================================================================

/**
 * Get distance-based transition nutrition targets.
 * Research-backed values vary by total brick duration:
 * - Sprint (<90 min): 0/0/0 (quick transition, no nutrition needed)
 * - Olympic (90-180 min): 0/0/50ml (sip of water only)
 * - Half Ironman (180-420 min): T1=25g/150mg/150ml, T2=10g/100mg/100ml
 * - Ironman (420+ min): T1=30g/200mg/200ml, T2=25g/150mg/150ml
 */
function getTransitionTargets(
  segments: Array<{ sport: string; duration_minutes: number; macro_targets: MacroTargets }>,
  transitionIndex: number,
): MacroTargets {
  const totalDurationMinutes = segments.reduce((sum, s) => sum + s.duration_minutes, 0);

  if (totalDurationMinutes < 90) {
    return { carbs_g: 0, sodium_mg: 0, water_ml: 0 };
  }
  if (totalDurationMinutes < 180) {
    return { carbs_g: 0, sodium_mg: 0, water_ml: 50 };
  }
  if (totalDurationMinutes < 420) {
    return transitionIndex === 0
      ? { carbs_g: 25, sodium_mg: 150, water_ml: 150 }
      : { carbs_g: 10, sodium_mg: 100, water_ml: 100 };
  }
  // Ironman (420+ min)
  return transitionIndex === 0
    ? { carbs_g: 30, sodium_mg: 200, water_ml: 200 }
    : { carbs_g: 25, sodium_mg: 150, water_ml: 150 };
}

// ============================================================================
// Transition Phase (Brick Workouts)
// ============================================================================

/**
 * Generate transition-phase food selection for brick workout T1/T2 phases.
 * Uses LP solver with small targets (quick-consume foods like gels, drinks).
 * Skips food generation when all targets are 0 (sprint/olympic distance).
 */
async function generateTransitionPhase(
  supabase: ReturnType<typeof createServiceClient>,
  transitionName: string,
  targets: MacroTargets,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
): Promise<LPPhaseResult> {
  console.log(`[PLAN-V2-BRICK] Generating transition phase ${transitionName}: carbs=${targets.carbs_g}g, sodium=${targets.sodium_mg}mg, water=${targets.water_ml}ml`);

  // Skip food generation when all targets are 0 (sprint/olympic distance)
  if (targets.carbs_g === 0 && targets.sodium_mg === 0 && targets.water_ml === 0) {
    console.log(`[PLAN-V2-BRICK] ${transitionName}: all targets are 0, returning empty foods`);
    return { foods: [] };
  }

  const foods = await getTransitionFoods(
    supabase,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
  );

  if (foods.length === 0) {
    console.log(`[PLAN-V2-BRICK] No transition foods available for ${transitionName}`);
    return { foods: [] };
  }

  console.log(`[PLAN-V2-BRICK] ${transitionName}: ${foods.length} transition foods available`);

  // Use LP solver with 'during' phase weights (transition is similar to during)
  const weights = getOptimizationWeights('running', 'during');
  const modelOptions = {
    maxFoodItems: 3,
    maxServingsCap: 2,
    selectionPenalty: 0.5,
    enforceWaterMin: true,
  };

  const model = buildLPModel(
    foods,
    targets,
    'during',
    weights,
    undefined,
    undefined,
    modelOptions,
  );
  const solution = solveLPModel(model, foods, 'during');

  if (solution && solution.foods.length > 0) {
    console.log(`[PLAN-V2-BRICK] ${transitionName} LP solved: ${solution.foods.length} foods`);
    return { foods: solution.foods };
  }

  // Fallback to greedy
  console.log(`[PLAN-V2-BRICK] ${transitionName} LP failed, using greedy fallback`);
  const greedyResult = greedyFallback(foods, targets, 'during');
  return { foods: greedyResult.foods };
}

// ============================================================================
// Brick Workout Handler
// ============================================================================

/**
 * Handle brick workout plan generation.
 * Generates before (shared), per-segment during phases, transition phases, and after.
 */
async function handleBrickPlan(
  supabase: ReturnType<typeof createServiceClient>,
  input: PlanInputV2,
  planId: string,
): Promise<Response> {
  const segments = input.brick_segments ?? [];
  if (segments.length === 0) {
    console.log('[PLAN-V2-BRICK] No brick_segments provided, falling back to standard plan');
    // Fall through to standard generation handled by caller
    throw new Error('No brick_segments provided for brick activity');
  }

  console.log(`[PLAN-V2-BRICK] Starting brick plan generation with ${segments.length} segments`);

  // 1. Generate before phase (shared across all segments — reuse standard logic)
  console.log(`[PLAN-V2-BRICK] Before phase input: pre_run carbs=${input.macro_targets.pre_run?.carbs_g}, water=${input.macro_targets.pre_run?.water_ml}, hours_before=${input.hours_before}`);
  const beforeResult = await generateBeforePhase(supabase, input);
  const beforeSubPhases = Object.keys(beforeResult);
  const beforeFoodCount = beforeSubPhases.reduce((sum, key) => {
    const sp = (beforeResult as Record<string, { foods?: unknown[] }>)[key];
    return sum + (sp?.foods?.length ?? 0);
  }, 0);
  console.log(`[PLAN-V2-BRICK] Before phase result: sub-phases=[${beforeSubPhases.join(',')}], total foods=${beforeFoodCount}`);

  // 2. Generate during phase for each segment + transitions between them
  const duringSegments: Record<string, FoodResult[]> = {};
  const transitions: Record<string, FoodResult[]> = {};
  const segmentTargetsList: Array<{ segment_order: number; sport: string; carbs_g: number; sodium_mg: number; water_ml: number }> = [];
  const transitionTargetsList: Array<{ transition_name: string; carbs_g: number; sodium_mg: number; water_ml: number }> = [];

  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];
    const segmentOrder = i + 1;
    const sport = segment.sport as ActivityType;
    const segmentTargets: MacroTargets = {
      carbs_g: segment.macro_targets.carbs_g,
      sodium_mg: segment.macro_targets.sodium_mg,
      water_ml: segment.macro_targets.water_ml,
    };

    console.log(`[PLAN-V2-BRICK] Segment ${segmentOrder} (${sport}): carbs=${segmentTargets.carbs_g}g, sodium=${segmentTargets.sodium_mg}mg, water=${segmentTargets.water_ml}ml`);

    // Track segment targets for response
    segmentTargetsList.push({
      segment_order: segmentOrder,
      sport: segment.sport,
      carbs_g: segmentTargets.carbs_g,
      sodium_mg: segmentTargets.sodium_mg,
      water_ml: segmentTargets.water_ml,
    });

    // Generate during phase for this segment
    const duringResult = await generateDuringPhase(
      supabase,
      segmentTargets,
      sport,
      input.liked_foods,
      input.willing_to_try_foods,
      input.disliked_foods,
      input.device_id,
    );

    duringSegments[String(segmentOrder)] = duringResult.foods;

    // Generate transition after each segment (except the last)
    if (i < segments.length - 1) {
      const transitionName = `T${i + 1}`;
      const transitionTargets = getTransitionTargets(segments, i);

      transitionTargetsList.push({
        transition_name: transitionName,
        carbs_g: transitionTargets.carbs_g,
        sodium_mg: transitionTargets.sodium_mg,
        water_ml: transitionTargets.water_ml,
      });

      const transitionResult = await generateTransitionPhase(
        supabase,
        transitionName,
        transitionTargets,
        input.liked_foods,
        input.willing_to_try_foods,
        input.disliked_foods,
        input.device_id,
      );

      transitions[transitionName] = transitionResult.foods;
    }
  }

  // 3. Generate after phase (use 'running' activity type — brick recovery is run-like)
  const afterResult = input.macro_targets.post_run
    ? await generateLPPhase(
        supabase,
        'after',
        input.macro_targets.post_run,
        'running',
        input.liked_foods,
        input.willing_to_try_foods,
        input.disliked_foods,
        input.device_id,
      )
    : { foods: [] as FoodResult[] };

  // 4. Build response matching V1 brick format
  const response = {
    success: true,
    plan_id: planId,
    activity_type: 'brick',
    plan: {
      before: beforeResult,
      during_segments: duringSegments,
      transitions: transitions,
      after: afterResult.foods,
    },
    macro_targets: {
      pre_run: input.macro_targets.pre_run,
      during_run: input.macro_targets.during_run,
      post_run: input.macro_targets.post_run,
      activity_type: 'brick',
      phases: {
        before: input.macro_targets.pre_run,
        during_segments: segmentTargetsList,
        transitions: transitionTargetsList,
        after: input.macro_targets.post_run,
      },
    },
  };

  console.log(`[PLAN-V2-BRICK] Brick plan generated successfully (plan_id=${planId}, segments=${segments.length}, transitions=${Object.keys(transitions).length})`);

  return jsonResponse(response);
}

// ============================================================================
// Main Handler
// ============================================================================

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const input: PlanInputV2 = await req.json();

    // Validate required fields
    if (!input.device_id) {
      return errorResponse('Missing device_id', 400);
    }
    if (!input.macro_targets) {
      return errorResponse('Missing macro_targets', 400);
    }
    if (input.hours_before == null || input.hours_before < 0) {
      return errorResponse('Invalid hours_before', 400);
    }

    const supabase = createServiceClient();
    const activityType = (input.activity_type as ActivityType) || 'running';
    const planId = generateUUID();

    console.log(`[PLAN-V2] Starting plan generation (activity=${activityType}, hours_before=${input.hours_before})`);

    // Brick workouts: route to dedicated handler
    if (activityType === 'brick') {
      return await handleBrickPlan(supabase, input, planId);
    }

    // Generate all phases
    const [beforeResult, duringPhaseResult, afterPhaseResult] = await Promise.all([
      // Before: template-based
      generateBeforePhase(supabase, input),

      // During: rule-based solver (no server-side by-hour apportionment)
      input.macro_targets.during_run
        ? generateDuringPhase(
            supabase,
            input.macro_targets.during_run,
            activityType,
            input.liked_foods,
            input.willing_to_try_foods,
            input.disliked_foods,
            input.device_id,
          )
        : Promise.resolve({ foods: [] } as LPPhaseResult),

      // After: LP-based
      input.macro_targets.post_run
        ? generateLPPhase(
            supabase,
            'after',
            input.macro_targets.post_run,
            activityType,
            input.liked_foods,
            input.willing_to_try_foods,
            input.disliked_foods,
            input.device_id,
          )
        : Promise.resolve({ foods: [] } as LPPhaseResult),
    ]);

    // Build during response — always Map format with foods + by_hour_data
    const duringResponse = {
      foods: duringPhaseResult.foods,
      by_hour_data: duringPhaseResult.by_hour_data ?? null,
    };

    // Build response
    const response = {
      success: true,
      plan_id: planId,
      plan: {
        before: beforeResult,
        during: duringResponse,
        after: afterPhaseResult.foods,
      },
      macro_targets: {
        ...input.macro_targets,
        activity_type: activityType,
      },
    };

    console.log(`[PLAN-V2] Plan generated successfully (plan_id=${planId})`);

    return jsonResponse(response);
  } catch (error) {
    console.error('[PLAN-V2] Error:', error);
    return serverError(error, true);
  }
}));
