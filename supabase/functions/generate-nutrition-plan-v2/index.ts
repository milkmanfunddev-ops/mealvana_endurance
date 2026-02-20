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
import { generateUUID } from '../_shared/utils.ts';

// Existing nutrition module (for during/after LP solving)
import {
  type Phase,
  type ActivityType,
  type MacroTargets,
  type FoodResult,
  getFoodsForPhase,
  getElectrolyteFoods,
  buildLPModel,
  solveLPModel,
  greedyFallback,
  getSportConfig,
  getOptimizationWeights,
  MACRO_CONSTRAINT_RANGES,
  PREFERENCE_SCORE_MAP,
  calculateTotals,
} from '../_shared/nutrition/index.ts';

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

  // 6. Select template chain
  const templateChain = selectTemplateChain(filteredTemplates, activeSubPhases);

  // 7. Select drinks for each phase
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
  );

  // 8. Scale templates and build sub-phase results
  const beforeResult: BeforePhaseResult = {};

  for (const subPhase of activeSubPhases) {
    const template = templateChain.get(subPhase);
    const drink = selectedDrinks.get(subPhase);
    const targets = subPhaseTargets.get(subPhase)!;

    if (!template) {
      console.log(`[PLAN-V2] No template for ${subPhase}, skipping`);
      continue;
    }

    // Calculate drink carb contribution to subtract from food target
    const drinkCarbs = drink ? drink.carbs_grams : 0;

    // Scale template foods
    const scaled = scaleTemplate(template.foods, targets, drinkCarbs);

    console.log(
      `[PLAN-V2] ${subPhase}: ${template.name} scaled @${scaled.multiplier}x ` +
      `(score: ${scaled.score.toFixed(2)}, carbs: ${scaled.total_carbs}g)`
    );

    // Convert scaled foods to FoodResult format
    const foodResults: FoodResult[] = scaled.foods.map((sf) => ({
      food_id: sf.food_id,
      quantity: sf.quantity,
      carbs_grams: sf.carbs_grams,
      protein_grams: sf.protein_grams,
      fat_grams: sf.fat_grams,
      sodium_mg: sf.sodium_mg,
      fluids_ml: sf.fluids_ml,
      calories: sf.calories,
      display_name: sf.display_name,
      serving_size: sf.serving_size,
      timing: getSubPhaseTimingLabel(subPhase, input.hours_before),
      is_drink: false,
      template_id: template.id,
      scale_multiplier: sf.scale_multiplier,
    } as FoodResult & { is_drink: boolean; template_id: string; scale_multiplier: number }));

    // Add drink to the food list
    if (drink) {
      foodResults.push({
        ...drink,
        timing: getSubPhaseTimingLabel(subPhase, input.hours_before),
      });
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
// During/After Phases (LP-Based, reusing existing solver)
// ============================================================================

async function generateLPPhase(
  supabase: ReturnType<typeof createServiceClient>,
  phase: Phase,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
): Promise<FoodResult[]> {
  console.log(`[PLAN-V2] Generating ${phase} phase via LP solver`);

  // Get foods for this phase
  const foods = await getFoodsForPhase(
    supabase,
    phase,
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
  );

  if (foods.length === 0) {
    console.log(`[PLAN-V2] No foods found for ${phase} phase`);
    return [];
  }

  console.log(`[PLAN-V2] ${phase}: ${foods.length} foods available`);

  // Get optimization weights for this phase
  const weights = getOptimizationWeights(activityType, phase);
  const constraints = MACRO_CONSTRAINT_RANGES;

  // Build and solve LP model
  const model = buildLPModel(foods, targets, phase, weights, constraints);
  const solution = solveLPModel(model, foods, targets, phase);

  if (solution && solution.foods.length > 0) {
    console.log(`[PLAN-V2] ${phase} LP solved: ${solution.foods.length} foods`);
    return solution.foods;
  }

  // Fallback to greedy
  console.log(`[PLAN-V2] ${phase} LP failed, using greedy fallback`);
  const greedyResult = greedyFallback(foods, targets, phase);
  return greedyResult.foods;
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

    // Generate all phases
    const [beforeResult, duringResult, afterResult] = await Promise.all([
      // Before: template-based
      generateBeforePhase(supabase, input),

      // During: LP-based
      input.macro_targets.during_run
        ? generateLPPhase(
            supabase,
            'during',
            input.macro_targets.during_run,
            activityType,
            input.liked_foods,
            input.willing_to_try_foods,
            input.disliked_foods,
            input.device_id,
          )
        : Promise.resolve([]),

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
        : Promise.resolve([]),
    ]);

    // Build response
    const response = {
      success: true,
      plan_id: planId,
      plan: {
        before: beforeResult,
        during: duringResult,
        after: afterResult,
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
});
