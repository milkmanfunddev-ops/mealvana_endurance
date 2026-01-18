/**
 * Generate Nutrition Plan Edge Function
 *
 * Uses Linear Programming for optimal food selection with sport-specific configurations.
 * Supports running, cycling, swimming, triathlon, duathlon, and multisport activities.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

// Shared utilities
import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse, serverError } from '../_shared/responses.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';
import { safe } from '../_shared/utils.ts';

// Nutrition module
import {
  // Types
  type Phase,
  type ActivityType,
  type MacroTargets,
  type PhaseResult,
  type Food,
  // Food utilities
  buildPreferenceSet,
  deduplicateFoods,
  calculateTotals,
  // Database queries
  getFoodsForPhase,
  getElectrolyteFoods,
  getEssentialFoods,
  // LP Solver
  buildLPModel,
  solveLPModel,
  // Greedy fallback
  greedyFallback,
  // Sport configs
  getSportConfig,
  getOptimizationWeights,
  // Constants
  MACRO_CONSTRAINT_RANGES,
  POST_PROCESS_THRESHOLDS,
} from '../_shared/nutrition/index.ts';

import { roundToIncrement } from '../_shared/utils.ts';

// ============================================================================
// Post-Processing
// ============================================================================

async function postProcessPhase(
  supabase: ReturnType<typeof createServiceClient>,
  result: { foods: any[]; totals: any },
  targets: MacroTargets,
  electrolyteFoods: Food[],
  allFoods: Food[],
  phase: Phase,
  activityType: ActivityType
): Promise<any[]> {
  // Fetch essential foods for post-processing with sport-specific settings
  const essentialFoods = await getEssentialFoods(supabase, activityType, phase);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Fetched ${essentialFoods.length} essential foods for ${activityType}`);

  const foods = [...result.foods];

  // Recalculate totals
  const totals = calculateTotals(foods);

  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Starting with ${foods.length} foods`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Current totals:`, totals);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Targets:`, targets);

  // Check deficits
  const sodiumDeficit = targets.sodium_mg - totals.sodium_mg;
  const waterDeficit = targets.water_ml - totals.water_ml;
  const sodiumDeficitPercent = targets.sodium_mg > 0 ? sodiumDeficit / targets.sodium_mg : 0;
  const waterDeficitPercent = targets.water_ml > 0 ? waterDeficit / targets.water_ml : 0;

  const waterBounds = MACRO_CONSTRAINT_RANGES.water[phase];
  const waterMaxAllowed = targets.water_ml > 0 && waterBounds
    ? targets.water_ml * waterBounds.max
    : Number.POSITIVE_INFINITY;
  const sodiumMaxAllowed = targets.sodium_mg * 1.1;

  // Guard clause: Don't add anything if we have no room for more foods
  if (foods.length >= 5) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] At food limit, skipping`);
    return foods;
  }

  // Check if we need additions
  const needsSodium =
    sodiumDeficit > 0 &&
    sodiumDeficitPercent > POST_PROCESS_THRESHOLDS.sodium_deficit_percent &&
    totals.sodium_mg / targets.sodium_mg <= 1.1;

  const needsWater =
    waterDeficit > 0 &&
    waterDeficitPercent > POST_PROCESS_THRESHOLDS.water_deficit_percent &&
    totals.water_ml < waterMaxAllowed;

  // Add sodium if needed
  if (needsSodium) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Adding sodium for deficit: ${sodiumDeficit}mg`);

    const sodiumCandidates = [
      ...electrolyteFoods,
      ...essentialFoods.filter((f) => f.per_serving.sodium_mg > 0),
    ].filter((food, index, self) => self.findIndex((other) => other.id === food.id) === index);

    // Sort by sodium to water ratio (prefer high sodium, low water)
    const sortedCandidates = sodiumCandidates.sort((a, b) => {
      const ratioA = a.per_serving.sodium_mg / Math.max(1, a.per_serving.water_ml);
      const ratioB = b.per_serving.sodium_mg / Math.max(1, b.per_serving.water_ml);
      return ratioB - ratioA;
    });

    for (const option of sortedCandidates) {
      const sodiumPerServing = option.per_serving.sodium_mg;
      if (sodiumPerServing <= 0) continue;

      const exactServings = sodiumDeficit / sodiumPerServing;
      const roundedServings = Math.max(0.5, roundToIncrement(exactServings, 0.5));
      const potentialSodium = sodiumPerServing * roundedServings;
      const potentialWater = option.per_serving.water_ml * roundedServings;

      // Check overshoot
      if (totals.sodium_mg + potentialSodium > sodiumMaxAllowed) {
        const reducedServings = roundToIncrement(
          (sodiumMaxAllowed - totals.sodium_mg) / sodiumPerServing,
          0.5
        );
        if (reducedServings >= 0.5) {
          addFoodToResult(foods, option, reducedServings, totals);
          break;
        }
        continue;
      }

      if (totals.water_ml + potentialWater > waterMaxAllowed) continue;

      addFoodToResult(foods, option, roundedServings, totals);
      break;
    }
  }

  // Add water if needed
  if (needsWater) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Adding water for deficit: ${waterDeficit}ml`);

    const water = essentialFoods.find(
      (f) => f.name?.toLowerCase() === 'water' || f.display_name?.toLowerCase()?.includes('water')
    );

    if (water && water.per_serving.water_ml > 0) {
      const remainingCapacity = waterMaxAllowed - totals.water_ml;
      const feasibleServings = Math.min(
        waterDeficit / water.per_serving.water_ml,
        remainingCapacity / water.per_serving.water_ml
      );
      const roundedServings = roundToIncrement(Math.max(0, feasibleServings), 0.5);

      if (roundedServings >= 0.5) {
        addFoodToResult(foods, water, roundedServings, totals);
      }
    }
  }

  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Complete. Total foods: ${foods.length}`);
  return foods;
}

function addFoodToResult(
  foods: any[],
  food: Food,
  servings: number,
  totals: { sodium_mg: number; water_ml: number }
): void {
  foods.push({
    food_id: food.id,
    food_name: food.name,
    quantity: servings,
    carbs_grams: food.per_serving.carbs_g * servings,
    protein_grams: food.per_serving.protein_g * servings,
    fat_grams: food.per_serving.fat_g * servings,
    sodium_mg: food.per_serving.sodium_mg * servings,
    fluids_ml: food.per_serving.water_ml * servings,
    calories: food.per_serving.calories * servings,
    display_name: food.display_name ?? food.name,
    display_name_plural: food.display_name_plural ?? food.display_name ?? food.name,
    description: food.description,
    image_address: food.image_address,
  });

  totals.sodium_mg += food.per_serving.sodium_mg * servings;
  totals.water_ml += food.per_serving.water_ml * servings;
}

// ============================================================================
// Phase Optimization
// ============================================================================

async function optimizePhase(
  supabase: ReturnType<typeof createServiceClient>,
  phase: Phase,
  userId: string,
  targets: MacroTargets,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  dislikedFoods: Set<string>,
  electrolyteFoods: Food[],
  activityType: ActivityType
): Promise<PhaseResult> {
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Starting for ${activityType}`);
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Targets:`, targets);

  // Get foods for this phase with sport-specific filtering
  const foods = await getFoodsForPhase(
    supabase,
    phase,
    userId,
    likedFoods,
    willTryFoods,
    dislikedFoods,
    activityType
  );

  if (foods.length === 0) {
    console.log(`[OPTIMIZE-${phase.toUpperCase()}] No foods available`);
    return {
      items: [],
      totals: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 0 },
    };
  }

  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Found ${foods.length} candidate foods`);

  // Get sport-specific optimization weights
  const weights = getOptimizationWeights(activityType, phase);

  // Build and solve LP model
  const model = buildLPModel(foods, targets, phase, weights);
  let solution = solveLPModel(model, foods, phase);

  // Use greedy fallback if LP solver fails
  if (!solution) {
    console.log(`[OPTIMIZE-${phase.toUpperCase()}] LP solver failed, using greedy fallback`);
    solution = greedyFallback(foods, targets, phase);
  }

  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Solution found with ${solution.foods.length} foods`);

  // Post-process to add electrolytes and water as needed
  const postProcessedFoods = await postProcessPhase(
    supabase,
    solution,
    targets,
    electrolyteFoods,
    foods,
    phase,
    activityType
  );

  // Deduplicate and calculate final totals
  const finalFoods = deduplicateFoods(postProcessedFoods);
  const finalTotals = calculateTotals(finalFoods);

  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Final totals:`, finalTotals);

  return {
    items: finalFoods,
    totals: finalTotals,
  };
}

// ============================================================================
// Request Handler
// ============================================================================

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = createServiceClient();
    console.log('[NUTRITION-PLAN] Starting nutrition plan generation');

    const body = await req.json();

    // Validate required fields
    if (!body.device_id || !body.macro_targets) {
      return errorResponse(
        'Missing required fields: device_id (user UUID) and macro_targets are required',
        400
      );
    }

    const { pre_run, during_run, post_run } = body.macro_targets;

    // Normalize targets
    const preTargets: MacroTargets = {
      carbs_g: safe(pre_run.carbs_g),
      protein_g: safe(pre_run.protein_g),
      sodium_mg: safe(pre_run.sodium_mg),
      water_ml: safe(pre_run.water_ml),
    };

    const duringTargets: MacroTargets = {
      carbs_g: safe(during_run.carbs_g || during_run.carbs_total_g),
      sodium_mg: safe(during_run.sodium_mg || during_run.sodium_total_mg),
      water_ml: safe(during_run.water_ml || during_run.water_total_ml),
    };

    const postTargets: MacroTargets = {
      carbs_g: safe(post_run.carbs_g),
      protein_g: safe(post_run.protein_g),
      sodium_mg: safe(post_run.sodium_mg),
      water_ml: safe(post_run.water_ml),
    };

    // Parse preferences
    const likedFoods = buildPreferenceSet(body.liked_foods);
    const willTryFoods = buildPreferenceSet(body.willing_to_try_foods);
    const dislikedFoods = buildPreferenceSet(body.disliked_foods);

    console.log('[PREFERENCES] Received:', {
      liked: Array.from(likedFoods).slice(0, 5),
      willing: Array.from(willTryFoods).slice(0, 5),
      disliked: Array.from(dislikedFoods).slice(0, 5),
    });

    // Get activity type with sport config
    const activityType = (body.activity_type || 'running') as ActivityType;
    const sportConfig = getSportConfig(activityType);
    console.log(`[NUTRITION-PLAN] Using ${sportConfig.name} configuration`);

    // Get user ID
    const userId = body.device_id;

    // Get electrolyte foods once for all phases (using 'during' phase as primary use case)
    const electrolyteFoods = await getElectrolyteFoods(supabase, userId, likedFoods, willTryFoods, activityType, 'during');
    console.log(`[NUTRITION-PLAN] Found ${electrolyteFoods.length} electrolyte options for ${activityType}`);

    // Optimize each phase in parallel
    const [before, during, after] = await Promise.all([
      optimizePhase(supabase, 'before', userId, preTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType),
      optimizePhase(supabase, 'during', userId, duringTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType),
      optimizePhase(supabase, 'after', userId, postTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType),
    ]);

    // Generate response
    const planId = crypto.randomUUID();

    return jsonResponse({
      success: true,
      plan_id: planId,
      detailed_message: `Optimized ${sportConfig.name.toLowerCase()} nutrition plan with sport-specific food selection.`,
      plan: {
        before: before.items,
        during: during.items,
        after: after.items,
      },
      macro_targets: {
        ...body.macro_targets,
        activity_type: activityType,
      },
    });
  } catch (error) {
    console.error('[NUTRITION-PLAN] Error:', error);
    return serverError(error, true);
  }
});
