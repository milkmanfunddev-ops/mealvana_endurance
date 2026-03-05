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
  matchesPreference,
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
  PREFERENCE_SCORE_MAP,
  DEFAULT_MAX_SERVINGS,
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
    serving_size: food.serving_size,
    serving_unit: food.serving_unit,
    serving_qualifier: food.serving_qualifier,
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
// Brick Workout Handler
// ============================================================================

async function handleBrickNutritionPlan(
  supabase: ReturnType<typeof createServiceClient>,
  body: any
): Promise<Response> {
  console.log('[BRICK-PLAN] Starting brick nutrition plan generation (v2-running-fix)');

  const userId = body.device_id;
  const { phases } = body.macro_targets;

  if (!phases) {
    return errorResponse(
      'Brick workouts require macro_targets.phases with before, during_segments, transitions, and after',
      400
    );
  }

  // Parse preferences
  const likedFoods = buildPreferenceSet(body.liked_foods);
  const willTryFoods = buildPreferenceSet(body.willing_to_try_foods);
  const dislikedFoods = buildPreferenceSet(body.disliked_foods);

  console.log('[BRICK-PREFERENCES] Received:', {
    liked: Array.from(likedFoods).slice(0, 5),
    willing: Array.from(willTryFoods).slice(0, 5),
    disliked: Array.from(dislikedFoods).slice(0, 5),
  });

  // Get electrolyte foods for all phases
  // Note: Use 'running' as activity type since foods table doesn't have 'brick' in activity_types
  // Before/after foods are universal across sports, and electrolytes aren't sport-specific
  const electrolyteFoods = await getElectrolyteFoods(supabase, userId, likedFoods, willTryFoods, 'running', 'during');
  console.log(`[BRICK-PLAN] Found ${electrolyteFoods.length} electrolyte options for brick`);

  // 1. Optimize BEFORE phase (standard)
  console.log('[BRICK-PLAN] Optimizing before phase');
  const beforeTargets: MacroTargets = {
    carbs_g: safe(phases.before.carbs_g),
    protein_g: safe(phases.before.protein_g),
    sodium_mg: safe(phases.before.sodium_mg),
    water_ml: safe(phases.before.water_ml),
  };

  // Note: Use 'running' as activity type for before phase since foods table
  // doesn't have 'brick' in activity_types. Before foods are universal across sports.
  const beforeResult = await optimizePhase(
    supabase,
    'before',
    userId,
    beforeTargets,
    likedFoods,
    willTryFoods,
    dislikedFoods,
    electrolyteFoods,
    'running'
  );

  // 2. Optimize DURING SEGMENTS (sport-specific)
  console.log('[BRICK-PLAN] Optimizing during segments');
  const duringSegments: Record<number, PhaseResult> = {};

  if (phases.during_segments && Array.isArray(phases.during_segments)) {
    for (const segment of phases.during_segments) {
      const segmentOrder = segment.segment_order;
      const sport = segment.sport; // 'swimming', 'cycling', 'running'

      console.log(`[BRICK-PLAN] Optimizing segment ${segmentOrder} (${sport})`);

      const segmentTargets: MacroTargets = {
        carbs_g: safe(segment.carbs_g),
        protein_g: 0, // No protein during exercise
        sodium_mg: safe(segment.sodium_mg),
        water_ml: safe(segment.water_ml),
      };

      // Use sport-specific activity type for food filtering
      const segmentActivityType = sport === 'swimming' ? 'swimming' : sport === 'cycling' ? 'cycling' : 'running';

      const segmentResult = await optimizePhase(
        supabase,
        'during',
        userId,
        segmentTargets,
        likedFoods,
        willTryFoods,
        dislikedFoods,
        electrolyteFoods,
        segmentActivityType as ActivityType
      );

      duringSegments[segmentOrder] = segmentResult;
    }
  }

  // 3. Optimize TRANSITIONS (T1, T2)
  console.log('[BRICK-PLAN] Optimizing transitions');
  const transitions: Record<string, PhaseResult> = {};

  if (phases.transitions && Array.isArray(phases.transitions)) {
    for (const transition of phases.transitions) {
      const transitionName = transition.transition_name; // 'T1' or 'T2'

      console.log(`[BRICK-PLAN] Optimizing transition ${transitionName}`);

      const transitionTargets: MacroTargets = {
        carbs_g: safe(transition.carbs_g),
        protein_g: 0,
        sodium_mg: safe(transition.sodium_mg),
        water_ml: safe(transition.water_ml),
      };

      // Optimize transition using brick activity type with transition food filtering
      const transitionResult = await optimizeBrickTransition(
        supabase,
        transitionName,
        userId,
        transitionTargets,
        likedFoods,
        willTryFoods,
        dislikedFoods,
        electrolyteFoods
      );

      transitions[transitionName] = transitionResult;
    }
  }

  // 4. Optimize AFTER phase (standard)
  console.log('[BRICK-PLAN] Optimizing after phase');
  const afterTargets: MacroTargets = {
    carbs_g: safe(phases.after.carbs_g),
    protein_g: safe(phases.after.protein_g),
    sodium_mg: safe(phases.after.sodium_mg),
    water_ml: safe(phases.after.water_ml),
  };

  // Note: Use 'running' as activity type for after phase since foods table
  // doesn't have 'brick' in activity_types. After/recovery foods are universal across sports.
  const afterResult = await optimizePhase(
    supabase,
    'after',
    userId,
    afterTargets,
    likedFoods,
    willTryFoods,
    dislikedFoods,
    electrolyteFoods,
    'running'
  );

  // Generate response
  const planId = crypto.randomUUID();

  return jsonResponse({
    success: true,
    plan_id: planId,
    activity_type: 'brick',
    detailed_message: 'Optimized brick workout nutrition plan with multi-phase food selection.',
    plan: {
      before: beforeResult.items,
      during_segments: Object.fromEntries(
        Object.entries(duringSegments).map(([order, result]) => [order, result.items])
      ),
      transitions: Object.fromEntries(
        Object.entries(transitions).map(([name, result]) => [name, result.items])
      ),
      after: afterResult.items,
    },
    macro_targets: body.macro_targets,
  });
}

/**
 * Optimize a brick transition phase (T1 or T2)
 * Uses transition-specific food filtering
 */
async function optimizeBrickTransition(
  supabase: ReturnType<typeof createServiceClient>,
  transitionName: string,
  userId: string,
  targets: MacroTargets,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  dislikedFoods: Set<string>,
  electrolyteFoods: Food[]
): Promise<PhaseResult> {
  console.log(`[OPTIMIZE-${transitionName}] Starting transition optimization`);
  console.log(`[OPTIMIZE-${transitionName}] Targets:`, targets);

  // Get foods with 'transition' category
  const foods = await getTransitionFoods(
    supabase,
    userId,
    likedFoods,
    willTryFoods,
    dislikedFoods
  );

  if (foods.length === 0) {
    console.log(`[OPTIMIZE-${transitionName}] No transition foods available`);
    return {
      items: [],
      totals: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 0 },
    };
  }

  console.log(`[OPTIMIZE-${transitionName}] Found ${foods.length} transition foods`);

  // Use brick optimization weights for transitions
  const weights = getOptimizationWeights('brick', 'during');

  // Build and solve LP model
  const model = buildLPModel(foods, targets, 'during', weights);
  let solution = solveLPModel(model, foods, 'during');

  // Use greedy fallback if LP solver fails
  if (!solution) {
    console.log(`[OPTIMIZE-${transitionName}] LP solver failed, using greedy fallback`);
    solution = greedyFallback(foods, targets, 'during');
  }

  console.log(`[OPTIMIZE-${transitionName}] Solution found with ${solution.foods.length} foods`);

  // Post-process to add electrolytes and water as needed
  const postProcessedFoods = await postProcessPhase(
    supabase,
    solution,
    targets,
    electrolyteFoods,
    foods,
    'during',
    'brick'
  );

  // Deduplicate and calculate final totals
  const finalFoods = deduplicateFoods(postProcessedFoods);
  const finalTotals = calculateTotals(finalFoods);

  console.log(`[OPTIMIZE-${transitionName}] Final totals:`, finalTotals);

  return {
    items: finalFoods,
    totals: finalTotals,
  };
}

/**
 * Get foods with 'transition' category for brick transitions
 */
async function getTransitionFoods(
  supabase: ReturnType<typeof createServiceClient>,
  userId: string,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  dislikedFoods: Set<string>
): Promise<Food[]> {
  console.log('[TRANSITION-FOODS] Fetching transition category foods');

  // Get generic transition foods
  const { data: genericFoods, error: genericError } = await supabase
    .from('foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type, serving_size, serving_unit, serving_qualifier,
      max_servings_during,
      is_electrolyte, to_exclude_from_solver, is_essential,
      categories
    `)
    .filter('categories', 'cs', '{transition}');

  if (genericError) {
    console.log('[TRANSITION-FOODS] Error fetching generic transition foods:', genericError);
  }

  // Get user transition foods
  const { data: userFoods, error: userError } = await supabase
    .from('user_foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type,
      is_electrolyte, to_exclude_from_solver, is_deleted,
      categories
    `)
    .eq('user_id', userId)
    .eq('is_deleted', false)
    .filter('categories', 'cs', '{transition}');

  if (userError) {
    console.log('[TRANSITION-FOODS] Error fetching user transition foods:', userError);
  }

  // Combine and deduplicate foods
  const allFoodsMap = new Map<string, any>();

  const addFoods = (list: any[], isUserFood = false) => {
    if (!list) return;
    for (const food of list) {
      if (!allFoodsMap.has(food.id)) {
        allFoodsMap.set(food.id, { ...food, _isUserFood: isUserFood });
      }
    }
  };

  addFoods(genericFoods || [], false);
  addFoods(userFoods || [], true);

  const allFoods = Array.from(allFoodsMap.values());
  console.log(`[TRANSITION-FOODS] Found ${allFoods.length} total transition foods`);

  if (allFoods.length === 0) return [];

  // Filter and transform foods (same logic as getFoodsForPhase)
  return allFoods
    .filter((f) => {
      const isUserFood = f._isUserFood === true;
      const isDisliked = matchesPreference(f, dislikedFoods);
      const isExcludedFromSolver = f.to_exclude_from_solver === true;

      if (isDisliked && !isUserFood) {
        console.log(`[TRANSITION-FILTER] Excluding disliked food: ${f.name}`);
        return false;
      }

      return !isExcludedFromSolver;
    })
    .map((f): Food => {
      const isUserFood = f._isUserFood === true;
      const isLiked = isUserFood || matchesPreference(f, likedFoods);
      const isWilling = matchesPreference(f, willTryFoods);

      let preferenceCategory: 'liked' | 'willing' | 'essential' | 'neutral' = 'neutral';
      if (isLiked) {
        preferenceCategory = 'liked';
      } else if (isWilling) {
        preferenceCategory = 'willing';
      }

      const preference_score = PREFERENCE_SCORE_MAP[preferenceCategory];

      return {
        id: f.id,
        name: f.name,
        display_name: f.display_name,
        display_name_plural: f.display_name_plural,
        description: f.description,
        image_address: f.image_address,
        per_serving: {
          carbs_g: safe(f.carbs_per_serving),
          protein_g: safe(f.protein_per_serving),
          fat_g: safe(f.fat_per_serving),
          sodium_mg: safe(f.sodium_mg),
          water_ml: safe(f.fluid_ml_per_serving),
          calories: safe(f.calories_per_serving),
        },
        serving_amount: f.serving_amount,
        min_servings: 1.0,
        max_servings: f.max_servings_during ?? DEFAULT_MAX_SERVINGS,
        preference_score,
        is_electrolyte: f.is_electrolyte || false,
        is_essential: f.is_essential || false,
        is_user_food: isUserFood,
      };
    });
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

    // Get activity type
    const activityType = (body.activity_type || 'running') as ActivityType;

    // Check if this is a brick workout
    if (activityType === 'brick') {
      console.log('[NUTRITION-PLAN] Detected brick workout - using multi-phase logic');
      return await handleBrickNutritionPlan(supabase, body);
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

    // Get sport config for this activity type (activityType already defined above)
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
