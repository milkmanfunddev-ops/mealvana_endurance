/**
 * Generate Nutrition Plan V3 Edge Function
 *
 * Algorithm C pre-workout food selection with V2's during/after phases unchanged.
 *
 * Pre-workout (before) phase:
 * - Algorithm C from generate-macros-v4 (scoring/stacking/drink/electrolyte)
 * - Uses pre_workout_templates table
 * - Transformed to V2's BeforePhaseResult shape
 *
 * During/transition/after phases:
 * - Unchanged from V2
 * - During: rule-based solver
 * - After: LP solver with greedy fallback
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Shared utilities
import { handleCors } from "../_shared/cors.ts";
import {
  errorResponse,
  jsonResponse,
  serverError,
} from "../_shared/responses.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";
import { generateUUID, roundToIncrement } from "../_shared/utils.ts";

// Nutrition types and LP solver (unchanged from V2)
import {
  type ActivityType,
  buildLPModel,
  calculateTotals,
  deriveTimingCategory,
  type FoodResult,
  getOptimizationWeights,
  getSportConfig,
  greedyFallback,
  MACRO_CONSTRAINT_RANGES,
  type MacroTargets,
  type Phase,
  POST_PROCESS_THRESHOLDS,
  PREFERENCE_SCORE_MAP,
  solveLPModel,
  type TimingCategory,
} from "../_shared/nutrition/index.ts";

// v2 food queries — queries template_foods table (not legacy foods table)
import {
  getTemplateElectrolyteFoods,
  getTemplateFoodsForPhase,
  getTransitionFoods,
} from "../_shared/nutrition/template-food-queries.ts";

// Rule-based during solver (replaces LP for during phase)
import { generateDuringPhaseRuleBased } from "../_shared/nutrition/during-rule-solver.ts";

// V3 before phase — Algorithm C
import { generateBeforePhaseV3 } from "./before-phase.ts";

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
    phases?: {
      during_segments?: Array<{
        segment_order?: number;
        sport?: string;
        duration_minutes?: number;
        carbs_g: number;
        carbs_low_g?: number;
        carbs_high_g?: number;
        sodium_mg: number;
        sodium_low_mg?: number;
        sodium_high_mg?: number;
        water_ml: number;
        water_low_ml?: number;
        water_high_ml?: number;
      }>;
      transitions?: Array<{
        transition_name?: string;
        transition_id?: string;
        carbs_g: number;
        carbs_low_g?: number;
        carbs_high_g?: number;
        sodium_mg: number;
        sodium_low_mg?: number;
        sodium_high_mg?: number;
        water_ml: number;
        water_low_ml?: number;
        water_high_ml?: number;
      }>;
    };
  };
  dietary_preference?: string;
  allergies?: string[];
  liked_foods?: string[];
  disliked_foods?: string[];
  willing_to_try_foods?: string[];
  duration_minutes?: number;
  gut_training_level?: "low" | "moderate" | "high";
  brick_segments?: Array<{
    sport: string;
    duration_minutes: number;
    macro_targets: MacroTargets;
  }>;
  brick_phases?: {
    transitions?: Array<{
      transition_name?: string;
      transition_id?: string;
      carbs_g: number;
      carbs_low_g?: number;
      carbs_high_g?: number;
      sodium_mg: number;
      sodium_low_mg?: number;
      sodium_high_mg?: number;
      water_ml: number;
      water_low_ml?: number;
      water_high_ml?: number;
    }>;
  };
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
    case "low":
      return 45;
    case "high":
      return 25;
    default:
      return 30; // moderate
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

function splitSipQuantity(
  originalQty: number,
  placementCount: number,
): number[] {
  if (placementCount <= 0) return [];

  // Snap to 0.5 increments while preserving total quantity.
  const baseQty = Math.floor((originalQty / placementCount) / SIP_INCREMENT) *
    SIP_INCREMENT;
  const quantities = Array.from(
    { length: placementCount },
    () => Math.round(baseQty * 10) / 10,
  );

  const assignedTotal = quantities.reduce((sum, q) => sum + q, 0);
  let extraUnits = Math.floor(
    (originalQty - assignedTotal + 1e-9) / SIP_INCREMENT,
  );
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
  gutTrainingLevel: string = "moderate",
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
    const tc = food.timing_category ?? "slow_consume";
    switch (tc) {
      case "sip_throughout":
      case "fuel_drink":
        // fuel_drink is placed like sip_throughout (at :00) but tagged differently for UI
        sipItems.push(food);
        break;
      case "electrolyte":
        electrolyteItems.push(food);
        break;
      case "quick_consume":
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
    const tc = drink.timing_category ?? "sip_throughout";
    const assignmentCategory = tc === "fuel_drink"
      ? "fuelDrink"
      : "sipThroughout";
    const isSip = tc !== "fuel_drink";

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
          timingCategory: "electrolyte",
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
            timingCategory: "quickConsume",
          });
        }
      }
    }
  }

  // Phase 4: SLOW_CONSUME — bars/real food after quiet zone
  if (slowItems.length > 0) {
    let endCutoff = durationMinutes - END_CUTOFF_MINUTES;

    // Cycling: solids only in first 2/3
    if (activityType === "cycling") {
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
            timingCategory: "slowConsume",
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
): Promise<FoodResult[]> {
  const totals = calculateTotals(resultFoods);
  const sodiumDeficit = targets.sodium_mg - totals.sodium_mg;
  const deficitPercent = targets.sodium_mg > 0
    ? sodiumDeficit / targets.sodium_mg
    : 0;
  const existingElectrolyteIndex = resultFoods.findIndex(
    (f) => f.is_electrolyte === true || f.timing_category === "electrolyte",
  );

  console.log(
    `[POST-PROCESS-DURING] Totals: sodium=${totals.sodium_mg.toFixed(0)}mg, ` +
      `target=${targets.sodium_mg}mg, deficit=${sodiumDeficit.toFixed(0)}mg (${
        (deficitPercent * 100).toFixed(1)
      }%)`,
  );

  // Skip if sodium deficit is within threshold
  if (deficitPercent <= POST_PROCESS_THRESHOLDS.sodium_deficit_percent) {
    console.log(
      `[POST-PROCESS-DURING] Sodium within threshold (${
        (deficitPercent * 100).toFixed(1)
      }% <= ${(POST_PROCESS_THRESHOLDS.sodium_deficit_percent *
        100)}%), skipping`,
    );
    return resultFoods;
  }

  // Skip if already at max food items and we can't edit an existing electrolyte item.
  if (resultFoods.length >= maxFoodsAllowed && existingElectrolyteIndex < 0) {
    console.log(
      `[POST-PROCESS-DURING] Already ${resultFoods.length} foods, skipping electrolyte addition`,
    );
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
      const maxAdditionalForCap = (maxSodiumAllowed - totals.sodium_mg) /
        sodiumPerServing;
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
          carbs_grams: existing.carbs_grams +
            perServingCarbs * additionalServings,
          protein_grams: existing.protein_grams +
            perServingProtein * additionalServings,
          fat_grams: existing.fat_grams + perServingFat * additionalServings,
          sodium_mg: existing.sodium_mg + sodiumPerServing * additionalServings,
          fluids_ml: existing.fluids_ml + perServingFluids * additionalServings,
          calories: Math.round(
            existing.calories + perServingCalories * additionalServings,
          ),
        } as FoodResult;

        const updatedFoods = [...resultFoods];
        updatedFoods[existingElectrolyteIndex] = updated;
        return updatedFoods;
      }
    }
  }

  // Fetch electrolyte foods
  const electrolytes = await getTemplateElectrolyteFoods(
    supabase,
    likedFoods,
    willingToTryFoods,
  );
  if (electrolytes.length === 0) {
    console.log(`[POST-PROCESS-DURING] No electrolyte foods available`);
    return resultFoods;
  }

  // Sort by sodium-to-water ratio (prefer high sodium, low water — tablets over drinks)
  const sortedElectrolytes = [...electrolytes].sort((a, b) => {
    const ratioA = a.per_serving.sodium_mg /
      Math.max(1, a.per_serving.water_ml);
    const ratioB = b.per_serving.sodium_mg /
      Math.max(1, b.per_serving.water_ml);
    return ratioB - ratioA;
  });

  const best = sortedElectrolytes[0];

  // Calculate needed servings to fill deficit
  if (best.per_serving.sodium_mg <= 0) {
    console.log(
      `[POST-PROCESS-DURING] Best electrolyte has 0mg sodium, skipping`,
    );
    return resultFoods;
  }

  let neededServings = sodiumDeficit / best.per_serving.sodium_mg;

  // Enforce is_indivisible rounding (electrolytes are typically tablets)
  neededServings = best.is_indivisible
    ? Math.max(1, Math.round(neededServings))
    : roundToIncrement(neededServings);

  // Cap: don't overshoot sodium by more than 10%
  const maxSodiumAllowed = targets.sodium_mg * 1.1;
  const maxServingsForCap = (maxSodiumAllowed - totals.sodium_mg) /
    best.per_serving.sodium_mg;
  const cappedServings = best.is_indivisible
    ? Math.max(1, Math.floor(maxServingsForCap))
    : roundToIncrement(Math.max(0.5, maxServingsForCap));

  neededServings = Math.min(neededServings, cappedServings);

  if (neededServings <= 0) {
    console.log(
      `[POST-PROCESS-DURING] Needed servings <= 0 after capping, skipping`,
    );
    return resultFoods;
  }

  console.log(
    `[POST-PROCESS-DURING] Adding ${neededServings}x "${
      best.display_name ?? best.name
    }" ` +
      `(${(best.per_serving.sodium_mg * neededServings).toFixed(0)}mg sodium)`,
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
    timing: "Throughout activity",
    display_name: best.display_name ?? undefined,
    display_name_plural: best.display_name_plural ?? undefined,
    description: best.description ?? undefined,
    image_address: best.image_address ?? undefined,
    is_liquid: false,
    is_electrolyte: true,
    is_drink: false,
    is_indivisible: best.is_indivisible ?? true,
    timing_category: "electrolyte",
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
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  console.log(`[PLAN-V3] Generating ${phase} phase via LP solver`);
  const isDuringPhase = phase === "during";
  const useDefaultDuringFilter = isDuringPhase && activityType === "running";

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
    allergies,
    dietaryPreference,
  );

  if (foods.length === 0) {
    console.log(`[PLAN-V3] No foods found for ${phase} phase`);
    return { foods: [] };
  }

  console.log(`[PLAN-V3] ${phase}: ${foods.length} foods available`);

  // After phase: filter out foods that are clearly not recovery foods.
  // Foods with high carbs and near-zero protein (e.g. drink mixes, gels)
  // are during-phase products that shouldn't dominate recovery plans.
  if (phase === "after" && targets.carbs_g > 0) {
    const beforeCount = foods.length;
    foods = foods.filter((f) => {
      // A food is inappropriate for recovery if it has massive carbs relative
      // to the target AND virtually no protein. This catches drink mixes (80g carbs)
      // and gels but keeps bananas (27g carbs) and other real foods.
      const isHighCarbNoProtein = f.per_serving.protein_g < 1 &&
        f.per_serving.carbs_g > targets.carbs_g * 0.5;
      if (isHighCarbNoProtein) {
        console.log(
          `[PLAN-V3] after: excluding ${f.name} (${f.per_serving.carbs_g}g carbs, ${f.per_serving.protein_g}g protein — not suitable for recovery)`,
        );
      }
      return !isHighCarbNoProtein;
    });
    if (foods.length < beforeCount) {
      console.log(
        `[PLAN-V3] after: filtered ${
          beforeCount - foods.length
        } non-recovery foods, ${foods.length} remaining`,
      );
    }
  }

  // Hydration strategy: filter food pool based on carb demand per hour
  if (isDuringPhase && durationMinutes && durationMinutes > 0) {
    const durationHours = durationMinutes / 60;
    const carbsPerHour = targets.carbs_g / durationHours;

    if (carbsPerHour <= 30) {
      // Low carb demand: remove sports drink, let electrolyte+water handle hydration
      const before = foods.length;
      foods = foods.filter((f) => {
        const tc = deriveTimingCategory(f);
        return tc !== "fuel_drink";
      });
      if (foods.length < before) {
        console.log(
          `[PLAN-V3] Hydration strategy: electrolyte_water (removed ${
            before - foods.length
          } fuel drinks, carbsPerHour=${carbsPerHour.toFixed(1)})`,
        );
      }
    } else if (carbsPerHour > 60) {
      console.log(
        `[PLAN-V3] Hydration strategy: sports_drink (high carb demand, carbsPerHour=${
          carbsPerHour.toFixed(1)
        })`,
      );
    }
    // carbsPerHour 30-60: 'auto' — no filtering, let LP decide
  }

  const sportConfig = getSportConfig(activityType);
  const phaseConfig = sportConfig.phases[phase];
  const dynamicMaxServingsCap = phase === "after" && targets.water_ml > 2000
    ? Math.max(phaseConfig.maxServingsCap, 8)
    : phaseConfig.maxServingsCap;

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
    maxServingsCap: dynamicMaxServingsCap,
    selectionPenalty: isDuringPhase ? 1.0 : 0.1,
    maxElectrolyteSupplements: isDuringPhase && activityType === "running"
      ? 1
      : undefined,
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
      allergies,
      dietaryPreference,
    );
    if (expandedFoods.length > foods.length) {
      console.log(
        `[PLAN-V3] during running default pool infeasible; retrying with expanded food pool (${foods.length} -> ${expandedFoods.length})`,
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
    console.log(`[PLAN-V3] ${phase} LP solved: ${solution.foods.length} foods`);
    resultFoods = solution.foods;
  } else {
    // Fallback to greedy
    console.log(`[PLAN-V3] ${phase} LP failed, using greedy fallback`);
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
    );
  }

  // If phase output is out-of-range and imported user foods are present in the pool,
  // retry without imported user foods. This keeps user foods helpful without letting
  // imported labels with extreme sodium/fluid destroy macro contract adherence.
  const initialValidation = validatePhaseResultAgainstTargets(
    resultFoods,
    targets,
    phase,
  );
  if (!initialValidation.ok) {
    const hasImportedUserFoods = foods.some((f) =>
      f.is_user_food === true &&
      (!f.product_type || f.product_type === "import")
    );

    if (hasImportedUserFoods) {
      const sanitizedFoods = foods.filter((f) =>
        !(f.is_user_food === true &&
          (!f.product_type || f.product_type === "import"))
      );

      if (sanitizedFoods.length > 0) {
        console.warn(
          `[PLAN-V3] ${phase}: out-of-range with imported user foods. ` +
            `Retrying with imported user foods removed (${foods.length} -> ${sanitizedFoods.length}). Issues: ${
              initialValidation.issues.join("; ")
            }`,
        );

        const retryModel = buildLPModel(
          sanitizedFoods,
          targets,
          phase,
          weights,
          weightOverrides,
          constraintOverrides,
          modelOptions,
        );
        const retrySolution = solveLPModel(retryModel, sanitizedFoods, phase);
        let retryFoods: FoodResult[];
        if (retrySolution && retrySolution.foods.length > 0) {
          retryFoods = retrySolution.foods;
        } else {
          retryFoods = greedyFallback(sanitizedFoods, targets, phase).foods;
        }

        if (isDuringPhase) {
          retryFoods = await postProcessDuringPhase(
            supabase,
            retryFoods,
            targets,
            phaseConfig.maxFoods,
            likedFoods,
            willingToTryFoods,
          );
        }

        const retryValidation = validatePhaseResultAgainstTargets(
          retryFoods,
          targets,
          phase,
        );

        if (
          retryValidation.ok ||
          retryValidation.issues.length < initialValidation.issues.length
        ) {
          resultFoods = retryFoods;
          console.log(
            `[PLAN-V3] ${phase}: adopted sanitized retry result (issues ${initialValidation.issues.length} -> ${retryValidation.issues.length})`,
          );
        } else {
          console.warn(
            `[PLAN-V3] ${phase}: keeping original result (sanitized retry not better).`,
          );
        }
      }
    }
  }

  // Generate by-hour data for during phase
  let byHourData: ByHourData | null = null;
  if (isDuringPhase && durationMinutes && durationMinutes >= 60) {
    byHourData = generateByHourData(
      resultFoods,
      durationMinutes,
      activityType,
      gutTrainingLevel ?? "moderate",
    );
    if (byHourData) {
      console.log(
        `[PLAN-V3] Generated by-hour data: ${byHourData.assignments.length} assignments for ${durationMinutes}min`,
      );
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
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  // Swimming: no during-phase nutrition
  if (activityType === "swimming") {
    console.log("[PLAN-V3] Swimming activity — skipping during phase");
    return { foods: [], by_hour_data: null };
  }

  console.log(
    `[PLAN-V3] Generating during phase via rule solver (${activityType})`,
  );

  // Get foods from template_foods table
  let foods = await getTemplateFoodsForPhase(
    supabase,
    "during",
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    false,
    allergies,
    dietaryPreference,
  );

  if (foods.length === 0) {
    console.log("[PLAN-V3] No during foods found, trying expanded pool");
    foods = await getTemplateFoodsForPhase(
      supabase,
      "during",
      activityType,
      likedFoods,
      willingToTryFoods,
      dislikedFoods,
      deviceId,
      true,
      allergies,
      dietaryPreference,
    );
  }

  if (foods.length === 0) {
    console.log("[PLAN-V3] No during foods available at all");
    return { foods: [] };
  }

  const ruleResult = generateDuringPhaseRuleBased(foods, targets, activityType);
  const ruleValidation = validatePhaseResultAgainstTargets(
    ruleResult.foods,
    targets,
    "during",
  );

  if (ruleValidation.ok) {
    return { foods: ruleResult.foods, by_hour_data: null };
  }

  console.warn(
    `[PLAN-V3] During rule-solver out of range (${
      ruleValidation.issues.join("; ")
    }). ` +
      `Retrying with LP solver.`,
  );

  const lpResult = await generateLPPhase(
    supabase,
    "during",
    targets,
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    undefined,
    undefined,
    allergies,
    dietaryPreference,
  );

  const lpValidation = validatePhaseResultAgainstTargets(
    lpResult.foods,
    targets,
    "during",
  );
  if (!lpValidation.ok) {
    // Return best-effort LP result with warning instead of throwing
    console.warn(
      `[PLAN-V3] During phase LP out of range (non-fatal): ${
        lpValidation.issues.join("; ")
      }`,
    );
  }

  return lpResult;
}

interface PhaseValidationResult {
  ok: boolean;
  issues: string[];
}

function resolveMacroBounds(
  target: number,
  low: number | undefined,
  high: number | undefined,
  phaseRange: { min: number; max: number } | undefined,
): { min: number; max: number } {
  if (target <= 0) {
    return { min: 0, max: 0 };
  }
  if (low != null && high != null) {
    return { min: low, max: high };
  }
  if (phaseRange) {
    return {
      min: target * phaseRange.min,
      max: target * phaseRange.max,
    };
  }
  return { min: target * 0.9, max: target * 1.1 };
}

function validatePhaseResultAgainstTargets(
  foods: FoodResult[],
  targets: MacroTargets,
  phase: Phase,
): PhaseValidationResult {
  const totals = calculateTotals(foods);
  const issues: string[] = [];
  const ranges = {
    carbs: MACRO_CONSTRAINT_RANGES.carbs[phase],
    protein: MACRO_CONSTRAINT_RANGES.protein[phase],
    sodium: MACRO_CONSTRAINT_RANGES.sodium[phase],
    water: MACRO_CONSTRAINT_RANGES.water[phase],
  };

  const carbBounds = resolveMacroBounds(
    targets.carbs_g,
    targets.carbs_low_g,
    targets.carbs_high_g,
    ranges.carbs,
  );
  if (totals.carbs_g < carbBounds.min || totals.carbs_g > carbBounds.max) {
    issues.push(
      `carbs=${totals.carbs_g.toFixed(1)} not in [${
        carbBounds.min.toFixed(1)
      }, ${carbBounds.max.toFixed(1)}]`,
    );
  }

  if (
    targets.sodium_mg > 0 || targets.sodium_low_mg != null ||
    targets.sodium_high_mg != null
  ) {
    const sodiumBounds = resolveMacroBounds(
      targets.sodium_mg,
      targets.sodium_low_mg,
      targets.sodium_high_mg,
      ranges.sodium,
    );
    if (
      totals.sodium_mg < sodiumBounds.min || totals.sodium_mg > sodiumBounds.max
    ) {
      issues.push(
        `sodium=${totals.sodium_mg.toFixed(0)} not in [${
          sodiumBounds.min.toFixed(0)
        }, ${sodiumBounds.max.toFixed(0)}]`,
      );
    }
  }

  if (
    targets.water_ml > 0 || targets.water_low_ml != null ||
    targets.water_high_ml != null
  ) {
    const waterBounds = resolveMacroBounds(
      targets.water_ml,
      targets.water_low_ml,
      targets.water_high_ml,
      ranges.water,
    );
    if (
      totals.water_ml < waterBounds.min || totals.water_ml > waterBounds.max
    ) {
      issues.push(
        `water=${totals.water_ml.toFixed(0)} not in [${
          waterBounds.min.toFixed(0)
        }, ${waterBounds.max.toFixed(0)}]`,
      );
    }
  }

  if (
    (phase === "before" || phase === "after") && (targets.protein_g ?? 0) > 0
  ) {
    const proteinBounds = resolveMacroBounds(
      targets.protein_g ?? 0,
      targets.protein_low_g,
      targets.protein_high_g,
      ranges.protein,
    );
    if (
      totals.protein_g < proteinBounds.min ||
      totals.protein_g > proteinBounds.max
    ) {
      issues.push(
        `protein=${totals.protein_g.toFixed(1)} not in [${
          proteinBounds.min.toFixed(1)
        }, ${proteinBounds.max.toFixed(1)}]`,
      );
    }
  }

  return { ok: issues.length === 0, issues };
}

function flattenBeforeFoods(
  beforeResult: Record<string, { foods?: FoodResult[] }>,
): FoodResult[] {
  const foods: FoodResult[] = [];
  for (const key of ["meal", "snack", "top_up"]) {
    const sub = beforeResult[key];
    if (sub?.foods?.length) {
      foods.push(...sub.foods);
    }
  }
  return foods;
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
  segments: Array<
    { sport: string; duration_minutes: number; macro_targets: MacroTargets }
  >,
  transitionIndex: number,
): MacroTargets {
  const totalDurationMinutes = segments.reduce(
    (sum, s) => sum + s.duration_minutes,
    0,
  );

  if (totalDurationMinutes < 90) {
    return {
      carbs_g: 0,
      carbs_low_g: 0,
      carbs_high_g: 0,
      sodium_mg: 0,
      sodium_low_mg: 0,
      sodium_high_mg: 0,
      water_ml: 0,
      water_low_ml: 0,
      water_high_ml: 0,
    };
  }
  if (totalDurationMinutes < 180) {
    return {
      carbs_g: 0,
      carbs_low_g: 0,
      carbs_high_g: 0,
      sodium_mg: 0,
      sodium_low_mg: 0,
      sodium_high_mg: 0,
      water_ml: 50,
      water_low_ml: 45,
      water_high_ml: 55,
    };
  }
  if (totalDurationMinutes < 420) {
    return transitionIndex === 0
      ? {
        carbs_g: 25,
        carbs_low_g: 23,
        carbs_high_g: 28,
        sodium_mg: 150,
        sodium_low_mg: 135,
        sodium_high_mg: 165,
        water_ml: 150,
        water_low_ml: 128,
        water_high_ml: 173,
      }
      : {
        carbs_g: 10,
        carbs_low_g: 9,
        carbs_high_g: 11,
        sodium_mg: 100,
        sodium_low_mg: 90,
        sodium_high_mg: 110,
        water_ml: 100,
        water_low_ml: 85,
        water_high_ml: 115,
      };
  }
  // Ironman (420+ min)
  return transitionIndex === 0
    ? {
      carbs_g: 30,
      carbs_low_g: 27,
      carbs_high_g: 33,
      sodium_mg: 200,
      sodium_low_mg: 180,
      sodium_high_mg: 220,
      water_ml: 200,
      water_low_ml: 170,
      water_high_ml: 230,
    }
    : {
      carbs_g: 25,
      carbs_low_g: 23,
      carbs_high_g: 28,
      sodium_mg: 150,
      sodium_low_mg: 135,
      sodium_high_mg: 165,
      water_ml: 150,
      water_low_ml: 128,
      water_high_ml: 173,
    };
}

function normalizeTransitionName(name?: string | null): string | null {
  if (!name) return null;
  const trimmed = name.trim();
  if (!trimmed) return null;
  const match = /^t?(\d+)$/i.exec(trimmed);
  if (!match) return trimmed;
  return `T${match[1]}`;
}

function collectTransitionTargets(
  input: PlanInputV2,
): Map<string, MacroTargets> {
  const collected: Array<Record<string, unknown>> = [];
  const fromBrickPhases = input.brick_phases?.transitions ?? [];
  const fromMacroPhases = input.macro_targets?.phases?.transitions ?? [];
  for (const t of fromBrickPhases) collected.push(t as Record<string, unknown>);
  for (const t of fromMacroPhases) collected.push(t as Record<string, unknown>);

  const map = new Map<string, MacroTargets>();
  for (const raw of collected) {
    const key = normalizeTransitionName(
      (raw.transition_name as string | undefined) ??
        (raw.transition_id as string | undefined),
    );
    if (!key) continue;

    const carbs = Number(raw.carbs_g ?? 0);
    const sodium = Number(raw.sodium_mg ?? 0);
    const water = Number(raw.water_ml ?? 0);
    const carbsLow = raw.carbs_low_g != null
      ? Number(raw.carbs_low_g)
      : undefined;
    const carbsHigh = raw.carbs_high_g != null
      ? Number(raw.carbs_high_g)
      : undefined;
    const sodiumLow = raw.sodium_low_mg != null
      ? Number(raw.sodium_low_mg)
      : undefined;
    const sodiumHigh = raw.sodium_high_mg != null
      ? Number(raw.sodium_high_mg)
      : undefined;
    const waterLow = raw.water_low_ml != null
      ? Number(raw.water_low_ml)
      : undefined;
    const waterHigh = raw.water_high_ml != null
      ? Number(raw.water_high_ml)
      : undefined;
    map.set(key, {
      carbs_g: Number.isFinite(carbs) ? carbs : 0,
      ...(carbsLow != null && Number.isFinite(carbsLow) &&
        { carbs_low_g: carbsLow }),
      ...(carbsHigh != null && Number.isFinite(carbsHigh) &&
        { carbs_high_g: carbsHigh }),
      sodium_mg: Number.isFinite(sodium) ? sodium : 0,
      ...(sodiumLow != null && Number.isFinite(sodiumLow) &&
        { sodium_low_mg: sodiumLow }),
      ...(sodiumHigh != null && Number.isFinite(sodiumHigh) &&
        { sodium_high_mg: sodiumHigh }),
      water_ml: Number.isFinite(water) ? water : 0,
      ...(waterLow != null && Number.isFinite(waterLow) &&
        { water_low_ml: waterLow }),
      ...(waterHigh != null && Number.isFinite(waterHigh) &&
        { water_high_ml: waterHigh }),
    });
  }
  return map;
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
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  console.log(
    `[PLAN-V3-BRICK] Generating transition phase ${transitionName}: carbs=${targets.carbs_g}g, sodium=${targets.sodium_mg}mg, water=${targets.water_ml}ml`,
  );

  // Skip food generation when all targets are 0 (sprint/olympic distance)
  if (
    targets.carbs_g === 0 && targets.sodium_mg === 0 && targets.water_ml === 0
  ) {
    console.log(
      `[PLAN-V3-BRICK] ${transitionName}: all targets are 0, returning empty foods`,
    );
    return { foods: [] };
  }

  const foods = await getTransitionFoods(
    supabase,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    allergies,
    dietaryPreference,
  );

  if (foods.length === 0) {
    console.log(
      `[PLAN-V3-BRICK] No transition foods available for ${transitionName}`,
    );
    return { foods: [] };
  }

  console.log(
    `[PLAN-V3-BRICK] ${transitionName}: ${foods.length} transition foods available`,
  );

  // Use LP solver with 'during' phase weights (transition is similar to during)
  const weights = getOptimizationWeights("running", "during");
  const modelOptions = {
    maxFoodItems: 3,
    maxServingsCap: 2,
    selectionPenalty: 0.5,
    enforceWaterMin: true,
  };

  const model = buildLPModel(
    foods,
    targets,
    "during",
    weights,
    undefined,
    undefined,
    modelOptions,
  );
  const solution = solveLPModel(model, foods, "during");

  if (solution && solution.foods.length > 0) {
    console.log(
      `[PLAN-V3-BRICK] ${transitionName} LP solved: ${solution.foods.length} foods`,
    );
    return { foods: solution.foods };
  }

  // Fallback to greedy
  console.log(
    `[PLAN-V3-BRICK] ${transitionName} LP failed, using greedy fallback`,
  );
  const greedyResult = greedyFallback(foods, targets, "during");
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
    console.log(
      "[PLAN-V3-BRICK] No brick_segments provided, falling back to standard plan",
    );
    // Fall through to standard generation handled by caller
    throw new Error("No brick_segments provided for brick activity");
  }

  console.log(
    `[PLAN-V3-BRICK] Starting brick plan generation with ${segments.length} segments`,
  );

  // 1. Generate before phase (shared across all segments — Algorithm C)
  console.log(
    `[PLAN-V3-BRICK] Before phase input: pre_run carbs=${input.macro_targets.pre_run?.carbs_g}, water=${input.macro_targets.pre_run?.water_ml}, hours_before=${input.hours_before}`,
  );
  const beforeResult = await generateBeforePhaseV3(supabase, input);
  const beforeSubPhases = Object.keys(beforeResult);
  const beforeFoodCount = beforeSubPhases.reduce((sum, key) => {
    const sp = (beforeResult as Record<string, { foods?: unknown[] }>)[key];
    return sum + (sp?.foods?.length ?? 0);
  }, 0);
  console.log(
    `[PLAN-V3-BRICK] Before phase result: sub-phases=[${
      beforeSubPhases.join(",")
    }], total foods=${beforeFoodCount}`,
  );
  const beforeValidation = validatePhaseResultAgainstTargets(
    flattenBeforeFoods(
      beforeResult as Record<string, { foods?: FoodResult[] }>,
    ),
    input.macro_targets.pre_run,
    "before",
  );
  if (!beforeValidation.ok) {
    // Before phase uses template-based Algorithm C — non-fatal for brick too
    console.warn(
      `[PLAN-V3-BRICK] Before phase out of range (non-fatal): ${
        beforeValidation.issues.join("; ")
      }`,
    );
  }

  // 2. Generate during phase for each segment + transitions between them
  const duringSegments: Record<string, FoodResult[]> = {};
  const transitions: Record<string, FoodResult[]> = {};
  const segmentTargetsList: Array<{
    segment_order: number;
    sport: string;
    carbs_g: number;
    carbs_low_g?: number;
    carbs_high_g?: number;
    sodium_mg: number;
    sodium_low_mg?: number;
    sodium_high_mg?: number;
    water_ml: number;
    water_low_ml?: number;
    water_high_ml?: number;
  }> = [];
  const transitionTargetsList: Array<{
    transition_name: string;
    carbs_g: number;
    carbs_low_g?: number;
    carbs_high_g?: number;
    sodium_mg: number;
    sodium_low_mg?: number;
    sodium_high_mg?: number;
    water_ml: number;
    water_low_ml?: number;
    water_high_ml?: number;
  }> = [];
  const transitionTargetOverrides = collectTransitionTargets(input);

  for (let i = 0; i < segments.length; i++) {
    const segment = segments[i];
    const segmentOrder = i + 1;
    const sport = segment.sport as ActivityType;
    const segmentTargets: MacroTargets = {
      carbs_g: segment.macro_targets.carbs_g,
      sodium_mg: segment.macro_targets.sodium_mg,
      water_ml: segment.macro_targets.water_ml,
      // Preserve V4 range fields if provided
      ...(segment.macro_targets.carbs_low_g != null &&
        { carbs_low_g: segment.macro_targets.carbs_low_g }),
      ...(segment.macro_targets.carbs_high_g != null &&
        { carbs_high_g: segment.macro_targets.carbs_high_g }),
      ...(segment.macro_targets.sodium_low_mg != null &&
        { sodium_low_mg: segment.macro_targets.sodium_low_mg }),
      ...(segment.macro_targets.sodium_high_mg != null &&
        { sodium_high_mg: segment.macro_targets.sodium_high_mg }),
      ...(segment.macro_targets.water_low_ml != null &&
        { water_low_ml: segment.macro_targets.water_low_ml }),
      ...(segment.macro_targets.water_high_ml != null &&
        { water_high_ml: segment.macro_targets.water_high_ml }),
    };

    console.log(
      `[PLAN-V3-BRICK] Segment ${segmentOrder} (${sport}): carbs=${segmentTargets.carbs_g}g, sodium=${segmentTargets.sodium_mg}mg, water=${segmentTargets.water_ml}ml`,
    );

    // Track segment targets for response
    segmentTargetsList.push({
      segment_order: segmentOrder,
      sport: segment.sport,
      carbs_g: segmentTargets.carbs_g,
      ...(segmentTargets.carbs_low_g != null &&
        { carbs_low_g: segmentTargets.carbs_low_g }),
      ...(segmentTargets.carbs_high_g != null &&
        { carbs_high_g: segmentTargets.carbs_high_g }),
      sodium_mg: segmentTargets.sodium_mg,
      ...(segmentTargets.sodium_low_mg != null &&
        { sodium_low_mg: segmentTargets.sodium_low_mg }),
      ...(segmentTargets.sodium_high_mg != null &&
        { sodium_high_mg: segmentTargets.sodium_high_mg }),
      water_ml: segmentTargets.water_ml,
      ...(segmentTargets.water_low_ml != null &&
        { water_low_ml: segmentTargets.water_low_ml }),
      ...(segmentTargets.water_high_ml != null &&
        { water_high_ml: segmentTargets.water_high_ml }),
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
      input.allergies,
      input.dietary_preference,
    );

    duringSegments[String(segmentOrder)] = duringResult.foods;

    // Generate transition after each segment (except the last)
    if (i < segments.length - 1) {
      const transitionName = `T${i + 1}`;
      const transitionTargets = transitionTargetOverrides.get(transitionName) ??
        getTransitionTargets(segments, i);

      transitionTargetsList.push({
        transition_name: transitionName,
        carbs_g: transitionTargets.carbs_g,
        ...(transitionTargets.carbs_low_g != null &&
          { carbs_low_g: transitionTargets.carbs_low_g }),
        ...(transitionTargets.carbs_high_g != null &&
          { carbs_high_g: transitionTargets.carbs_high_g }),
        sodium_mg: transitionTargets.sodium_mg,
        ...(transitionTargets.sodium_low_mg != null &&
          { sodium_low_mg: transitionTargets.sodium_low_mg }),
        ...(transitionTargets.sodium_high_mg != null &&
          { sodium_high_mg: transitionTargets.sodium_high_mg }),
        water_ml: transitionTargets.water_ml,
        ...(transitionTargets.water_low_ml != null &&
          { water_low_ml: transitionTargets.water_low_ml }),
        ...(transitionTargets.water_high_ml != null &&
          { water_high_ml: transitionTargets.water_high_ml }),
      });

      const transitionResult = await generateTransitionPhase(
        supabase,
        transitionName,
        transitionTargets,
        input.liked_foods,
        input.willing_to_try_foods,
        input.disliked_foods,
        input.device_id,
        input.allergies,
        input.dietary_preference,
      );

      const transitionValidation = validatePhaseResultAgainstTargets(
        transitionResult.foods,
        transitionTargets,
        "during",
      );
      if (!transitionValidation.ok) {
        console.warn(
          `[PLAN-V3-BRICK] ${transitionName} out of range (non-fatal): ${
            transitionValidation.issues.join("; ")
          }`,
        );
      }

      transitions[transitionName] = transitionResult.foods;
    }
  }

  // 3. Generate after phase (use 'running' activity type — brick recovery is run-like)
  const afterResult = input.macro_targets.post_run
    ? await generateLPPhase(
      supabase,
      "after",
      input.macro_targets.post_run,
      "running",
      input.liked_foods,
      input.willing_to_try_foods,
      input.disliked_foods,
      input.device_id,
      undefined,
      undefined,
      input.allergies,
      input.dietary_preference,
    )
    : { foods: [] as FoodResult[] };
  if (input.macro_targets.post_run) {
    const afterValidation = validatePhaseResultAgainstTargets(
      afterResult.foods,
      input.macro_targets.post_run,
      "after",
    );
    if (!afterValidation.ok) {
      console.warn(
        `[PLAN-V3-BRICK] After phase out of range (non-fatal): ${
          afterValidation.issues.join("; ")
        }`,
      );
    }
  }

  // 4. Build response matching V1 brick format
  const response = {
    success: true,
    plan_id: planId,
    activity_type: "brick",
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
      activity_type: "brick",
      phases: {
        before: input.macro_targets.pre_run,
        during_segments: segmentTargetsList,
        transitions: transitionTargetsList,
        after: input.macro_targets.post_run,
      },
    },
  };

  console.log(
    `[PLAN-V3-BRICK] Brick plan generated successfully (plan_id=${planId}, segments=${segments.length}, transitions=${
      Object.keys(transitions).length
    })`,
  );

  return jsonResponse(response);
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const input: PlanInputV2 = await req.json();

    // Validate required fields
    if (!input.device_id) {
      return errorResponse("Missing device_id", 400);
    }
    if (!input.macro_targets) {
      return errorResponse("Missing macro_targets", 400);
    }
    if (input.hours_before == null || input.hours_before < 0) {
      return errorResponse("Invalid hours_before", 400);
    }

    const supabase = createServiceClient();
    const activityType = (input.activity_type as ActivityType) || "running";
    const planId = generateUUID();

    console.log(
      `[PLAN-V3] Starting plan generation (activity=${activityType}, hours_before=${input.hours_before})`,
    );
    console.log(
      `[PLAN-V3] Full input: pre_run={carbs_g: ${input.macro_targets?.pre_run?.carbs_g}, protein_g: ${input.macro_targets?.pre_run?.protein_g}, water_ml: ${input.macro_targets?.pre_run?.water_ml}, sodium_mg: ${input.macro_targets?.pre_run?.sodium_mg}}, during_run={carbs_g: ${input.macro_targets?.during_run?.carbs_g}, sodium_mg: ${input.macro_targets?.during_run?.sodium_mg}, water_ml: ${input.macro_targets?.during_run?.water_ml}}, post_run={carbs_g: ${input.macro_targets?.post_run?.carbs_g}, protein_g: ${input.macro_targets?.post_run?.protein_g}, sodium_mg: ${input.macro_targets?.post_run?.sodium_mg}, water_ml: ${input.macro_targets?.post_run?.water_ml}}, duration_minutes=${input.duration_minutes}, gut_training_level=${input.gut_training_level}, dietary_preference=${input.dietary_preference}`,
    );

    // Brick workouts: route to dedicated handler
    if (activityType === "brick") {
      return await handleBrickPlan(supabase, input, planId);
    }

    // Generate all phases
    const [beforeResult, duringPhaseResult, afterPhaseResult] = await Promise
      .all([
        // Before: Algorithm C
        generateBeforePhaseV3(supabase, input),

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
            input.allergies,
            input.dietary_preference,
          )
          : Promise.resolve({ foods: [] } as LPPhaseResult),

        // After: LP-based
        input.macro_targets.post_run
          ? generateLPPhase(
            supabase,
            "after",
            input.macro_targets.post_run,
            activityType,
            input.liked_foods,
            input.willing_to_try_foods,
            input.disliked_foods,
            input.device_id,
            undefined,
            undefined,
            input.allergies,
            input.dietary_preference,
          )
          : Promise.resolve({ foods: [] } as LPPhaseResult),
      ]);

    const beforeValidation = validatePhaseResultAgainstTargets(
      flattenBeforeFoods(
        beforeResult as Record<string, { foods?: FoodResult[] }>,
      ),
      input.macro_targets.pre_run,
      "before",
    );
    const beforeWarnings: string[] = [];
    if (!beforeValidation.ok) {
      // Before phase uses template-based Algorithm C which optimizes for carbs.
      // Protein and sodium are secondary and may slightly exceed ranges.
      // Log warning but don't reject the plan — the food selection is still valid.
      console.warn(
        `[PLAN-V3] Before phase out of range (non-fatal): ${
          beforeValidation.issues.join("; ")
        }`,
      );
      beforeWarnings.push(...beforeValidation.issues);
    }

    if (input.macro_targets.during_run) {
      const duringValidation = validatePhaseResultAgainstTargets(
        duringPhaseResult.foods,
        input.macro_targets.during_run,
        "during",
      );
      if (!duringValidation.ok) {
        console.warn(
          `[PLAN-V3] During phase out of range (non-fatal): ${
            duringValidation.issues.join("; ")
          }`,
        );
        beforeWarnings.push(...duringValidation.issues.map(i => `during: ${i}`));
      }
    }

    if (input.macro_targets.post_run) {
      const afterValidation = validatePhaseResultAgainstTargets(
        afterPhaseResult.foods,
        input.macro_targets.post_run,
        "after",
      );
      if (!afterValidation.ok) {
        console.warn(
          `[PLAN-V3] After phase out of range (non-fatal): ${
            afterValidation.issues.join("; ")
          }`,
        );
        beforeWarnings.push(...afterValidation.issues.map(i => `after: ${i}`));
      }
    }

    // Build during response — always Map format with foods + by_hour_data
    const duringResponse = {
      foods: duringPhaseResult.foods,
      by_hour_data: duringPhaseResult.by_hour_data ?? null,
    };

    // Build response
    const response: Record<string, unknown> = {
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
    if (beforeWarnings.length > 0) {
      response.warnings = beforeWarnings;
    }

    // Log detailed response for debugging same-plan issues
    console.log(
      `[PLAN-V3] Plan result: before_subphases=${
        Object.keys(beforeResult)
      }, during_foods=${duringPhaseResult.foods.length}, after_foods=${afterPhaseResult.foods.length}`,
    );
    if (afterPhaseResult.foods.length > 0) {
      console.log(
        `[PLAN-V3] After-phase foods: ${
          afterPhaseResult.foods.map((f) =>
            `${f.display_name ?? f.food_id}(carbs=${
              f.carbs_grams.toFixed(0)
            },protein=${f.protein_grams.toFixed(0)},qty=${f.quantity})`
          ).join(", ")
        }`,
      );
    }
    console.log(`[PLAN-V3] Plan generated successfully (plan_id=${planId})`);

    return jsonResponse(response);
  } catch (error) {
    console.error("[PLAN-V3] Error:", error);
    return serverError(error, true);
  }
});
