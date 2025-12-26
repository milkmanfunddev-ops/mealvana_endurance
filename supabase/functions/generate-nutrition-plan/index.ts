/**
 * IMPROVED LINEAR PROGRAMMING NUTRITION PLANNER
 * Uses javascript-lp-solver for optimization with post-processing for electrolytes and water
 */ import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import solver from "https://esm.sh/javascript-lp-solver@0.4.24?target=deno";
// ---------------- CORS ----------------
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
// ---------------- Config ----------------
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// Note: Food exclusions now handled via to_exclude_from_solver database field
// Optimization weights - carbs prioritized in all phases, reduced sodium weights to prevent overshoot
const OPTIMIZATION_WEIGHTS = {
  before: {
    carbs: 1.0,
    protein: 0.6,
    sodium: 0.2 // Reduced from 0.5 (was 4.5x over-target!)
  },
  during: {
    carbs: 1.0,
    sodium: 0.8 // High constraint importance to avoid cramping (during was fine)
  },
  after: {
    carbs: 0.9,
    protein: 0.7,
    sodium: 0.3 // Reduced from 0.6 (was 3x over-target!)
  }
};
const MACRO_CONSTRAINT_RANGES = {
  carbs: {
    before: {
      min: 0.9,
      max: 1.1
    },
    during: {
      min: 0.9,
      max: 1.1
    },
    after: {
      min: 0.9,
      max: 1.1
    }
  },
  protein: {
    before: {
      min: 0.9,
      max: 1.1
    },
    after: {
      min: 0.9,
      max: 1.1
    }
  },
  sodium: {
    before: {
      min: 0.85,
      max: 1.1
    },
    during: {
      min: 0.9,
      max: 1.1
    },
    after: {
      min: 0.85,
      max: 1.1
    }
  },
  water: {
    before: {
      min: 0.85,
      max: 1.1
    },
    during: {
      min: 0.9,
      max: 1.1
    },
    after: {
      min: 0.85,
      max: 1.1
    }
  }
};
// Tolerance thresholds for post-processing - tighter to prevent massive overshoots
const POST_PROCESS_THRESHOLDS = {
  sodium_deficit_percent: 0.03,
  water_deficit_percent: 0.15,
  sodium_surplus_percent: 0.10,
  water_surplus_percent: 0.15 // Don't add if > 115% of target (was 120%, too loose)
};
const PREFERENCE_SCORE_MAP = {
  liked: 200,
  willing: 80,
  essential: 50,
  neutral: 20
};
// ---------------- Utils ----------------
const safe = (n, d = 0)=>Number.isFinite(Number(n)) ? Number(n) : d;
function roundToIncrement(value, increment = 0.5) {
  return Math.round(value / increment) * increment;
}
function roundUpToIncrement(value, increment = 0.5) {
  if (value <= 0) return 0;
  return Math.ceil(value / increment) * increment;
}
function buildPreferenceSet(values) {
  const result = new Set();
  if (!values) return result;
  for (const value of values){
    if (!value) continue;
    result.add(value);
    result.add(value.toLowerCase());
  }
  return result;
}
// Display functions removed - frontend handles all display logic via database lookups
function deduplicateFoods(foods) {
  const foodMap = new Map();
  for (const food of foods){
    // Group by food_id since that's our unique identifier
    const foodId = food.food_id;
    if (foodMap.has(foodId)) {
      const existing = foodMap.get(foodId);
      // Combine quantities and recalculate all nutritional values
      const totalQuantity = existing.quantity + food.quantity;
      existing.quantity = roundToIncrement(totalQuantity);
      existing.carbs_grams += food.carbs_grams || 0;
      existing.protein_grams += food.protein_grams || 0;
      existing.fat_grams += food.fat_grams || 0;
      existing.sodium_mg += food.sodium_mg || 0;
      existing.fluids_ml += food.fluids_ml || 0;
      existing.calories += food.calories || 0;
    } else {
      foodMap.set(foodId, {
        ...food
      });
    }
  }
  // Return deduplicated foods with rounded values
  return Array.from(foodMap.values()).map((food)=>({
      ...food,
      quantity: roundToIncrement(food.quantity),
      carbs_grams: Math.round((food.carbs_grams || 0) * 10) / 10,
      protein_grams: Math.round((food.protein_grams || 0) * 10) / 10,
      fat_grams: Math.round((food.fat_grams || 0) * 10) / 10,
      sodium_mg: Math.round(food.sodium_mg || 0),
      fluids_ml: Math.round(food.fluids_ml || 0),
      calories: Math.round(food.calories || 0)
    }));
}
// ---------------- Database Helpers ----------------
async function getFoodsForPhase(supabase, phase, userId, likedFoods, willTryFoods, dislikedFoods, activityType = 'running') {
  const categoryName = phase === "before" ? "before_run" : phase === "after" ? "after_run" : "during_run";
  console.log(`[FOODS-${phase.toUpperCase()}] Filtering for category: ${categoryName}, activity_type: ${activityType}`);
  // STEP 1: Get generic foods for this phase using array contains operator
  let genericFoods = [];
  const { data: foods, error: foodsError } = await supabase.from("foods").select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount,
      max_servings_before, max_servings_during, max_servings_after,
      is_electrolyte, to_exclude_from_solver, is_essential,
      categories, activity_types
    `).filter('categories', 'cs', `{${categoryName}}`).or(`activity_types.is.null,activity_types.cs.{${activityType}}`);
  if (foodsError) {
    console.log(`[FOODS-${phase.toUpperCase()}] Error fetching generic foods:`, foodsError);
  } else if (foods) {
    genericFoods = foods;
    console.log(`[FOODS-${phase.toUpperCase()}] Found ${genericFoods.length} generic foods suitable for ${activityType}`);
  }
  // STEP 2: Get user foods for this phase using array contains operator
  // Query by user UUID directly
  let userFoods = [];
  console.log(`[FOODS-${phase.toUpperCase()}] Querying user foods for user_id: ${userId}`);
  const { data: categoryUserFoods, error: userFoodsError } = await supabase.from("user_foods").select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type,
      is_electrolyte, to_exclude_from_solver, is_deleted,
      categories, activity_types
    `).eq("user_id", userId).eq("is_deleted", false).filter('categories', 'cs', `{${categoryName}}`).or(`activity_types.is.null,activity_types.cs.{${activityType}}`);
  if (userFoodsError) {
    console.log(`[FOODS-${phase.toUpperCase()}] Error fetching categorized user foods:`, userFoodsError);
  } else if (categoryUserFoods) {
    userFoods = userFoods.concat(categoryUserFoods);
  }
  // Get user foods WITHOUT category assignments (empty array = available for all phases)
  const { data: uncategorizedUserFoods, error: uncatError } = await supabase.from("user_foods").select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type,
      is_electrolyte, to_exclude_from_solver, is_deleted,
      categories, activity_types
    `).eq("user_id", userId).eq("is_deleted", false).or(`categories.eq.{},categories.is.null`).or(`activity_types.is.null,activity_types.cs.{${activityType}}`);
  if (uncatError) {
    console.log(`[FOODS-${phase.toUpperCase()}] Error fetching uncategorized user foods:`, uncatError);
  } else if (uncategorizedUserFoods) {
    // Filter out user foods that are already categorized to avoid duplicates
    const categorizedUserFoodIds = new Set(userFoods.map((f)=>f.id));
    const filteredUncategorized = uncategorizedUserFoods.filter((f)=>!categorizedUserFoodIds.has(f.id));
    userFoods = userFoods.concat(filteredUncategorized);
    console.log(`[FOODS-${phase.toUpperCase()}] Found ${filteredUncategorized.length} uncategorized user foods (${userFoods.length} total user foods)`);
  }
  // STEP 3: Combine generic and user foods (NO essential foods in initial pool)
  // Essential foods (water, salt) are now ONLY added in post-processing when there's
  // an actual deficit that other foods cannot fill. This prevents unnecessary 3.5 salt packets.
  const allFoodsMap = new Map();
  const addFoods = (list, isUserFood = false)=>{
    if (!list) return;
    for (const food of list){
      if (!allFoodsMap.has(food.id)) {
        // Mark user foods so they can be given "liked" preference automatically
        allFoodsMap.set(food.id, { ...food, _isUserFood: isUserFood });
      }
    }
  };
  addFoods(genericFoods, false);
  addFoods(userFoods, true);
  // NOTE: Essential foods intentionally NOT added here - they're added in postProcessPhase
  // only when there's a true sodium/water deficit that regular foods cannot fill
  const allFoods = Array.from(allFoodsMap.values());
  const userFoodCount = allFoods.filter(f => f._isUserFood).length;
  console.log(`[FOODS-${phase.toUpperCase()}] Combined ${genericFoods.length} generic + ${userFoods.length} user foods = ${allFoods.length} total (${userFoodCount} marked as user foods for preference boost)`);
  if (allFoods.length === 0) return [];
  // Helper function to check if a food matches user preferences
  const matchesPreference = (food, preferenceSet)=>{
    const foodName = food.name?.toLowerCase();
    const displayName = food.display_name?.toLowerCase();
    // Check multiple name variations for better matching
    return preferenceSet.has(food.id) || // Check by ID
    preferenceSet.has(food.name) || // Check exact name
    foodName && preferenceSet.has(foodName) || // Check lowercase name
    displayName && preferenceSet.has(displayName) || // Check display name
    // Check if any preference contains the food name (partial match)
    Array.from(preferenceSet).some((pref)=>foodName && pref.toLowerCase().includes(foodName) || foodName && foodName.includes(pref.toLowerCase()));
  };
  // Filter out disliked foods and foods excluded from solver
  // NOTE: Essential foods are no longer in the pool - they're added in post-processing only when needed
  // NOTE: User foods are NEVER filtered as disliked - they should always be available
  return allFoods.filter((f)=>{
    const isUserFood = f._isUserFood === true;
    const isDisliked = matchesPreference(f, dislikedFoods);
    const isExcludedFromSolver = f.to_exclude_from_solver === true;
    // CRITICAL: Never filter out user foods as disliked - user explicitly added them
    if (isDisliked && !isUserFood) {
      console.log(`[FILTER-DISLIKED] Excluding disliked food: ${f.name} (id: ${f.id})`);
      return false;
    }
    if (isDisliked && isUserFood) {
      console.log(`[FILTER-DISLIKED] Keeping user food despite dislike match: ${f.name} (id: ${f.id})`);
    }
    return !isExcludedFromSolver;
  }).map((f)=>{
    // Calculate preference score using improved matching
    // CRITICAL: User foods are automatically considered "liked" since the user added them
    const isUserFood = f._isUserFood === true;
    const isLiked = isUserFood || matchesPreference(f, likedFoods);
    const isWilling = matchesPreference(f, willTryFoods);
    let preferenceCategory = 'neutral';
    if (isLiked) {
      preferenceCategory = 'liked';
    } else if (isWilling) {
      preferenceCategory = 'willing';
    }
    const preference_score = PREFERENCE_SCORE_MAP[preferenceCategory];
    if (isUserFood) {
      console.log(`[PREFERENCE] User food (auto-liked): ${f.name} (score: ${preference_score})`);
    } else if (preferenceCategory === 'liked') {
      console.log(`[PREFERENCE] Loved food found: ${f.name} (score: ${preference_score})`);
    } else if (preferenceCategory === 'willing') {
      console.log(`[PREFERENCE] Willing-to-try food found: ${f.name} (score: ${preference_score})`);
    } else {
      console.log(`[PREFERENCE] Neutral food: ${f.name} (score: ${preference_score})`);
    }
    // Get phase-specific max servings for generic foods, default to 4 for user foods
    let maxServings = 4; // Default for user foods as requested
    if (f.max_servings_before !== undefined) {
      // This is a generic food with max_servings fields
      maxServings = phase === "before" ? f.max_servings_before : phase === "during" ? f.max_servings_during : f.max_servings_after;
    }
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
        calories: safe(f.calories_per_serving)
      },
      serving_amount: f.serving_amount,
      max_servings: maxServings || 4,
      preference_score,
      is_electrolyte: f.is_electrolyte || false,
      is_essential: f.is_essential || false,
      is_user_food: f._isUserFood || false
    };
  });
}
async function getElectrolyteFoods(supabase, userId, likedFoods, willTryFoods) {
  // STEP 1: Get generic electrolyte foods
  const { data: genericElectrolytes, error: genericError } = await supabase.from("foods").select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml_per_serving,
      serving_amount,
      is_electrolyte, to_exclude_from_solver, is_essential
    `).eq("is_electrolyte", true);
  if (genericError) {
    console.log("[ELECTROLYTES] Error fetching generic electrolytes:", genericError);
  }
  // STEP 2: Get user electrolyte foods
  console.log(`[ELECTROLYTES] Querying user electrolytes for user_id: ${userId}`);
  const { data: userElectrolytes, error: userElectrolyteError } = await supabase.from("user_foods").select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml_per_serving,
      serving_amount,
      is_electrolyte, to_exclude_from_solver, is_deleted
    `).eq("user_id", userId).eq("is_electrolyte", true).eq("is_deleted", false);
  if (userElectrolyteError) {
    console.log("[ELECTROLYTES] Error fetching user electrolytes:", userElectrolyteError);
  }
  // STEP 3: Combine all electrolytes
  const allElectrolytes = [
    ...genericElectrolytes || [],
    ...userElectrolytes || []
  ];
  console.log(`[ELECTROLYTES] Found ${genericElectrolytes?.length || 0} generic + ${userElectrolytes?.length || 0} user electrolytes = ${allElectrolytes.length} total`);
  if (allElectrolytes.length === 0) return [];
  // Helper function to check if electrolyte matches user preferences (reusing logic)
  const matchesElectrolytePreference = (food, preferenceSet)=>{
    const foodName = food.name?.toLowerCase();
    const displayName = food.display_name?.toLowerCase();
    return preferenceSet.has(food.id) || // Check by ID
    preferenceSet.has(food.name) || // Check exact name
    foodName && preferenceSet.has(foodName) || // Check lowercase name
    displayName && preferenceSet.has(displayName) || // Check display name
    Array.from(preferenceSet).some((pref)=>foodName && pref.toLowerCase().includes(foodName) || foodName && foodName.includes(pref.toLowerCase()));
  };
  return allElectrolytes.filter((e)=>{
    // Check if this is a generic food (has is_essential field)
    const isGenericFood = 'is_essential' in e;
    const isEssential = isGenericFood && e.is_essential === true;
    if (isEssential) {
      console.log(`[ELECTROLYTE] Including essential electrolyte: ${e.name}`);
      return true;
    }
    // Only use liked or willing-to-try electrolytes (improved matching)
    const isLiked = matchesElectrolytePreference(e, likedFoods);
    const isWillingToTry = matchesElectrolytePreference(e, willTryFoods);
    if (isLiked || isWillingToTry) {
      console.log(`[ELECTROLYTE] Including electrolyte: ${e.name} (liked: ${isLiked}, willing: ${isWillingToTry})`);
      return true;
    }
    return false;
  }).map((e)=>({
      id: e.id,
      name: e.name,
      display_name: e.display_name,
      display_name_plural: e.display_name_plural,
      description: e.description,
      image_address: e.image_address,
      per_serving: {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: safe(e.sodium_mg),
        water_ml: safe(e.fluid_ml_per_serving),
        calories: 0
      },
      serving_amount: e.serving_amount,
      is_electrolyte: true,
      is_essential: 'is_essential' in e ? e.is_essential : false // Only generic foods have this field
    }));
}
// ---------------- LP Solver Integration ----------------
function buildLPModel(foods, targets, phase) {
  const weights = OPTIMIZATION_WEIGHTS[phase];
  // Build the LP model
  const model = {
    optimize: "score",
    opType: "max",
    constraints: {},
    variables: {},
    ints: {},
    binaries: {}
  };
  // Phase-specific carb constraints (relaxed slightly for feasibility)
  const carbBounds = MACRO_CONSTRAINT_RANGES.carbs[phase];
  if (carbBounds) {
    // CRITICAL FIX: Handle zero carb targets (e.g., swimming during phase)
    if (targets.carbs_g === 0) {
      // When target is 0, enforce a strict maximum of 0-5g to prevent solver from adding carbs
      model.constraints.carbs = {
        min: 0,
        max: 5 // Allow tiny amount for numerical stability, but effectively zero
      };
    } else {
      // Normal carb targeting with bounds
      model.constraints.carbs = {
        min: targets.carbs_g * carbBounds.min,
        max: targets.carbs_g * carbBounds.max
      };
    }
  }
  // Add protein constraints for before and after phases
  if ((phase === "before" || phase === "after") && targets.protein_g) {
    const proteinBounds = MACRO_CONSTRAINT_RANGES.protein[phase];
    model.constraints.protein = {
      min: targets.protein_g * proteinBounds.min,
      max: targets.protein_g * proteinBounds.max
    };
  }
  // Balanced sodium constraints - prevent massive overshoot but allow feasibility
  if (targets.sodium_mg > 0) {
    const sodiumBounds = MACRO_CONSTRAINT_RANGES.sodium[phase];
    model.constraints.sodium = {
      min: targets.sodium_mg * Math.min(sodiumBounds.min, 0.75),
      max: targets.sodium_mg * sodiumBounds.max
    };
  }
  // Phase-specific water constraints (relaxed slightly for feasibility)
  if (targets.water_ml > 0) {
    const waterBounds = MACRO_CONSTRAINT_RANGES.water[phase];
    model.constraints.water = {
      max: targets.water_ml * waterBounds.max
    };
  }
  // Constraint to limit number of distinct foods (binary indicators link servings to selection)
  model.constraints.total_food_items = {
    max: 4
  };
  // Add variables for each food
  foods.forEach((food, index)=>{
    const varName = `food_${index}`;
    const selectionConstraint = `select_${index}`;
    const selectionVarName = `choose_${index}`;
    const maxServings = Math.max(0.5, Math.min(food.max_servings ?? 4, 4));
    // Calculate score based on preference and macro contribution
    let score = food.preference_score; // Base score from preference (already scaled)
    // Add weighted macro contributions to score
    score += weights.carbs * food.per_serving.carbs_g;
    // Add protein scoring for before and after phases
    if ((phase === "before" || phase === "after") && 'protein' in weights) {
      score += weights.protein * food.per_serving.protein_g;
    }
    // Add sodium consideration for all phases
    if (weights.sodium) {
      // Moderate sodium amounts get positive score, extremes get penalized
      const sodiumScore = Math.max(0, weights.sodium * (200 - Math.abs(food.per_serving.sodium_mg - 200)));
      score += sodiumScore;
    }
    // Penalize high water content foods in pre-run (avoid bloating)
    if (phase === "before" && food.per_serving.water_ml > 300) {
      score -= 3;
    }
    const variable = {
      score: score,
      carbs: food.per_serving.carbs_g,
      protein: food.per_serving.protein_g,
      sodium: food.per_serving.sodium_mg,
      water: food.per_serving.water_ml
    };
    variable[selectionConstraint] = 1;
    model.variables[varName] = variable;
    // Link servings to binary selection variable so distinct foods stay within limit
    model.constraints[selectionConstraint] = {
      max: 0
    };
    model.variables[selectionVarName] = {
      score: -0.1,
      [selectionConstraint]: -maxServings,
      total_food_items: 1
    };
    model.binaries[selectionVarName] = 1;
  });
  return model;
}
function solveLPModel(model, foods, phase) {
  try {
    const solution = solver.Solve(model);
    if (!solution || !solution.feasible) {
      console.log("[LP-SOLVER] No feasible solution found");
      return null;
    }
    // Extract selected foods and quantities
    const selectedFoods = [];
    let totals = {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0
    };
    foods.forEach((food, index)=>{
      const varName = `food_${index}`;
      const servings = solution[varName] || 0;
      if (servings > 0) {
        const roundedServings = roundToIncrement(servings);
        if (roundedServings <= 0) {
          return;
        }
        selectedFoods.push({
          food_id: food.id,
          quantity: roundedServings,
          carbs_grams: food.per_serving.carbs_g * roundedServings,
          protein_grams: food.per_serving.protein_g * roundedServings,
          fat_grams: food.per_serving.fat_g * roundedServings,
          sodium_mg: food.per_serving.sodium_mg * roundedServings,
          fluids_ml: food.per_serving.water_ml * roundedServings,
          calories: food.per_serving.calories * roundedServings,
          timing: phase === "before" ? "2-3 hours before" : phase === "during" ? "Throughout run" : "Within 30 minutes",
          // Include display fields for Flutter app
          display_name: food.display_name,
          display_name_plural: food.display_name_plural,
          description: food.description,
          image_address: food.image_address
        });
        totals.carbs_g += food.per_serving.carbs_g * roundedServings;
        totals.protein_g += food.per_serving.protein_g * roundedServings;
        totals.fat_g += food.per_serving.fat_g * roundedServings;
        totals.sodium_mg += food.per_serving.sodium_mg * roundedServings;
        totals.water_ml += food.per_serving.water_ml * roundedServings;
      }
    });
    return {
      foods: selectedFoods,
      totals,
      needsElectrolyte: false,
      needsWater: false
    };
  } catch (error) {
    console.error("[LP-SOLVER] Error solving model:", error);
    return null;
  }
}
// ---------------- Greedy Fallback Algorithm ----------------
function greedyFallback(foods, targets, phase) {
  console.log(`[GREEDY-FALLBACK] Using greedy approach for ${phase} phase`);
  const selectedFoods = [];
  let totals = {
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    water_ml: 0
  };
  // Sort foods by preference score and macro efficiency
  const sortedFoods = [
    ...foods
  ].sort((a, b)=>{
    // Primary: preference score
    if (a.preference_score !== b.preference_score) {
      return b.preference_score - a.preference_score;
    }
    // Secondary: carb efficiency (carbs per serving)
    const carbsA = a.per_serving.carbs_g;
    const carbsB = b.per_serving.carbs_g;
    if (phase === "after") {
      // For after-run, also consider protein efficiency
      const proteinA = a.per_serving.protein_g;
      const proteinB = b.per_serving.protein_g;
      return carbsB + proteinB - (carbsA + proteinA);
    }
    return carbsB - carbsA;
  });
  // Greedily select foods to meet targets with overshoot prevention (can expand to 4-5 with post-processing)
  let maxFoods = 3;
  const carbsTarget = targets.carbs_g;
  const proteinTarget = targets.protein_g || 0;
  const sodiumTarget = targets.sodium_mg || 0;
  const waterTarget = targets.water_ml || 0;
  for (const food of sortedFoods){
    if (selectedFoods.length >= maxFoods) break;
    // Check if adding this food would cause excessive overshoots
    const wouldOvershootSodium = sodiumTarget > 0 && totals.sodium_mg + food.per_serving.sodium_mg > sodiumTarget * 1.3;
    const wouldOvershootWater = waterTarget > 0 && totals.water_ml + food.per_serving.water_ml > waterTarget * 1.3;
    // Skip foods that would cause major overshoots (unless we're very under-target)
    if (wouldOvershootSodium && totals.sodium_mg > sodiumTarget * 0.7) continue;
    if (wouldOvershootWater && totals.water_ml > waterTarget * 0.7) continue;
    // Calculate how many servings we need based on primary targets
    let neededServings = 0;
    if (phase === "after" && proteinTarget > 0) {
      // For after-run, prioritize protein then carbs
      const proteinDeficit = Math.max(0, proteinTarget - totals.protein_g);
      const carbsDeficit = Math.max(0, carbsTarget - totals.carbs_g);
      if (proteinDeficit > 0 && food.per_serving.protein_g > 0) {
        neededServings = Math.ceil(proteinDeficit / food.per_serving.protein_g);
      } else if (carbsDeficit > 0 && food.per_serving.carbs_g > 0) {
        neededServings = Math.ceil(carbsDeficit / food.per_serving.carbs_g);
      }
    } else {
      // For before/during, focus on carbs
      const carbsDeficit = Math.max(0, carbsTarget - totals.carbs_g);
      if (carbsDeficit > 0 && food.per_serving.carbs_g > 0) {
        neededServings = Math.ceil(carbsDeficit / food.per_serving.carbs_g);
      }
    }
    // Reduce servings if it would cause major overshoots
    if (neededServings > 0) {
      // Check sodium overshoot potential
      if (sodiumTarget > 0 && food.per_serving.sodium_mg > 0) {
        const maxSodiumServings = Math.floor((sodiumTarget * 1.25 - totals.sodium_mg) / food.per_serving.sodium_mg);
        neededServings = Math.min(neededServings, Math.max(1, maxSodiumServings));
      }
      // Check water overshoot potential
      if (waterTarget > 0 && food.per_serving.water_ml > 0) {
        const maxWaterServings = Math.floor((waterTarget * 1.2 - totals.water_ml) / food.per_serving.water_ml);
        neededServings = Math.min(neededServings, Math.max(1, maxWaterServings));
      }
    }
    // Cap servings at reasonable amounts
    neededServings = Math.min(neededServings, 3);
    neededServings = roundToIncrement(neededServings);
    if (neededServings > 0) {
      selectedFoods.push({
        food_id: food.id,
        food_name: food.name,
        quantity: neededServings,
        carbs_grams: food.per_serving.carbs_g * neededServings,
        protein_grams: food.per_serving.protein_g * neededServings,
        fat_grams: food.per_serving.fat_g * neededServings,
        sodium_mg: food.per_serving.sodium_mg * neededServings,
        fluids_ml: food.per_serving.water_ml * neededServings,
        calories: food.per_serving.calories * neededServings,
        // Include display fields for Flutter app
        display_name: food.display_name,
        display_name_plural: food.display_name_plural,
        description: food.description,
        image_address: food.image_address
      });
      totals.carbs_g += food.per_serving.carbs_g * neededServings;
      totals.protein_g += food.per_serving.protein_g * neededServings;
      totals.fat_g += food.per_serving.fat_g * neededServings;
      totals.sodium_mg += food.per_serving.sodium_mg * neededServings;
      totals.water_ml += food.per_serving.water_ml * neededServings;
      // Stop if we've met our carb target
      if (totals.carbs_g >= carbsTarget * 0.9) break;
    }
  }
  return {
    foods: selectedFoods,
    totals,
    needsElectrolyte: false,
    needsWater: false
  };
}
// ---------------- Post-Processing ----------------
async function postProcessPhase(supabase, result, targets, electrolyteFoods, allFoods, phase) {
  // Fetch essential foods (water, salt) directly for post-processing
  // They are NOT in allFoods anymore - they're only added when there's a true deficit
  const { data: essentialFoods, error: essentialError } = await supabase.from("foods").select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, is_electrolyte, is_essential
    `).eq("is_essential", true);
  if (essentialError) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Error fetching essential foods:`, essentialError);
  }
  // Transform essential foods to the same format as allFoods
  const essentialFoodsTransformed = (essentialFoods || []).map(f => ({
    id: f.id,
    name: f.name,
    display_name: f.display_name,
    display_name_plural: f.display_name_plural,
    image_address: f.image_address,
    description: f.description,
    is_essential: f.is_essential,
    is_electrolyte: f.is_electrolyte,
    per_serving: {
      calories: f.calories_per_serving || 0,
      carbs_g: f.carbs_per_serving || 0,
      protein_g: f.protein_per_serving || 0,
      fat_g: f.fat_per_serving || 0,
      sodium_mg: f.sodium_mg || 0,
      water_ml: f.fluid_ml_per_serving || 0
    }
  }));
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Fetched ${essentialFoodsTransformed.length} essential foods for deficit-filling`);

  // First, fix any water/electrolyte items from solver with incorrect formatting
  const foods = result.foods.map((food)=>{
    // Check if this is a water/electrolyte item (identified by name pattern)
    if (food.food_name?.toLowerCase().includes('water') && food.food_name?.toLowerCase().includes('electrolyte')) {
      // Fix "34.5 servings water with electrolytes" → proper format
      const flOz = roundToIncrement(food.servings * 8, 0.5); // 8 fl oz per serving
      const sodium = Math.round(food.sodium_mg || food.servings * 200); // 200mg per serving default
      const packets = Math.round(sodium / 200 * 2) / 2; // Round to nearest 0.5
      console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Fixed Water with Electrolytes format: ${food.servings} servings → ${flOz} fl oz`);
      return {
        ...food,
        description: `${flOz} fl oz with ${sodium}mg electrolytes (~${packets} salt packet${packets !== 1 ? 's' : ''})`,
        fluids_ml: flOz * 30,
        sodium_mg: sodium
      };
    }
    // Check for plain water with bad formatting (using name pattern)
    if (food.food_name?.toLowerCase().includes('water') && !food.food_name?.toLowerCase().includes('electrolyte') && food.description?.includes('servings')) {
      const flOz = roundToIncrement(food.servings, 0.5);
      console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Fixed Water format: ${food.servings} servings → ${flOz} fl oz`);
      return {
        ...food,
        description: `${flOz} fl oz`,
        fluids_ml: flOz * 30
      };
    }
    // Check for salt with bad formatting (using name pattern)
    if (food.food_name?.toLowerCase().includes('salt') && !food.description?.includes('packet')) {
      const packets = roundToIncrement(food.servings);
      return {
        ...food,
        description: `${packets} salt packet${packets !== 1 ? 's' : ''}`,
        sodium_mg: packets * 200
      };
    }
    return food;
  });
  // Check what hydration/electrolyte items solver already provided (using name patterns)
  const hasWaterWithElectrolytes = foods.some((f)=>f.food_name?.toLowerCase().includes('water') && f.food_name?.toLowerCase().includes('electrolyte'));
  const hasPlainWater = foods.some((f)=>f.food_name?.toLowerCase().includes('water') && !f.food_name?.toLowerCase().includes('electrolyte'));
  const hasSalt = foods.some((f)=>f.food_name?.toLowerCase().includes('salt'));
  // Recalculate totals after fixing formats
  const totals = foods.reduce((acc, food)=>({
      carbs_g: acc.carbs_g + (food.carbs_grams || 0),
      protein_g: acc.protein_g + (food.protein_grams || 0),
      fat_g: acc.fat_g + (food.fat_grams || 0),
      sodium_mg: acc.sodium_mg + (food.sodium_mg || 0),
      water_ml: acc.water_ml + (food.fluids_ml || 0)
    }), {
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    water_ml: 0
  });
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Starting SMART post-processing with ${foods.length} foods`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Solver already included: WaterElectrolytes=${hasWaterWithElectrolytes}, Water=${hasPlainWater}, Salt=${hasSalt}`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Current totals:`, totals);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Targets:`, targets);
  // Check deficits
  const sodiumDeficit = targets.sodium_mg - totals.sodium_mg;
  const waterDeficit = targets.water_ml - totals.water_ml;
  const sodiumDeficitPercent = targets.sodium_mg > 0 ? sodiumDeficit / targets.sodium_mg : 0;
  const waterDeficitPercent = targets.water_ml > 0 ? waterDeficit / targets.water_ml : 0;
  const currentSodiumPercent = targets.sodium_mg > 0 ? totals.sodium_mg / targets.sodium_mg : 0;
  const currentWaterPercent = targets.water_ml > 0 ? totals.water_ml / targets.water_ml : 0;
  const waterBounds = MACRO_CONSTRAINT_RANGES.water[phase];
  const waterMaxAllowed = targets.water_ml > 0 && waterBounds ? targets.water_ml * waterBounds.max : Number.POSITIVE_INFINITY;
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Sodium: current ${totals.sodium_mg}mg vs target ${targets.sodium_mg}mg (${(currentSodiumPercent * 100).toFixed(0)}%)`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Water: current ${totals.water_ml}ml vs target ${targets.water_ml}ml (${(currentWaterPercent * 100).toFixed(0)}%)`);
  // Guard clause: Don't add anything if we have no room for more foods
  if (foods.length >= 5) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] At food limit (${foods.length}/5), skipping post-processing`);
    return foods;
  }
  // Check if we need individual sodium and water additions
  const needsSodium = sodiumDeficit > 0 && sodiumDeficitPercent > POST_PROCESS_THRESHOLDS.sodium_deficit_percent && currentSodiumPercent <= 1.1;
  const needsWater = waterDeficit > 0 && waterDeficitPercent > POST_PROCESS_THRESHOLDS.water_deficit_percent && totals.water_ml < waterMaxAllowed;
  if (!needsWater && targets.water_ml > 0 && totals.water_ml < waterMaxAllowed) {
    const remainingCapacity = waterMaxAllowed - totals.water_ml;
    // Look in essential foods first, then fall back to allFoods
    const waterFood = essentialFoodsTransformed.find((f)=>{
      const name = f.name?.toLowerCase();
      const displayName = f.display_name?.toLowerCase();
      return name === 'water' || displayName?.includes('water');
    }) || allFoods.find((f)=>{
      const name = f.name?.toLowerCase();
      const displayName = f.display_name?.toLowerCase();
      return name === 'water' || displayName?.includes('water');
    });
    if (waterFood && waterFood.per_serving.water_ml > 0) {
      const minimalServings = Math.min((targets.water_ml * 0.9 - totals.water_ml) / waterFood.per_serving.water_ml, remainingCapacity / waterFood.per_serving.water_ml);
      // Use roundToIncrement for consistency
      const roundedWaterServings = roundToIncrement(Math.max(0, minimalServings), 0.5);
      const potentialWater = waterFood.per_serving.water_ml * roundedWaterServings;
      if (roundedWaterServings >= 0.5 && totals.water_ml + potentialWater <= waterMaxAllowed + 1e-3) {
        foods.push({
          food_id: waterFood.id,
          food_name: waterFood.name,
          quantity: roundedWaterServings,
          carbs_grams: waterFood.per_serving.carbs_g * roundedWaterServings,
          protein_grams: waterFood.per_serving.protein_g * roundedWaterServings,
          fat_grams: waterFood.per_serving.fat_g * roundedWaterServings,
          sodium_mg: waterFood.per_serving.sodium_mg * roundedWaterServings,
          fluids_ml: waterFood.per_serving.water_ml * roundedWaterServings,
          calories: waterFood.per_serving.calories * roundedWaterServings,
          display_name: waterFood.display_name ?? waterFood.name,
          display_name_plural: waterFood.display_name_plural ?? waterFood.display_name ?? waterFood.name,
          description: waterFood.description,
          image_address: waterFood.image_address
        });
        totals.water_ml += potentialWater;
      }
    }
  }
  // INDIVIDUAL SOLUTIONS: Add water and electrolytes separately
  // Add sodium if needed - use essential foods that were fetched at start of post-processing
  // Max sodium allowed is 110% of target (current tolerance)
  const sodiumMaxAllowed = targets.sodium_mg * 1.1;
  if (needsSodium) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Adding sodium for deficit: ${sodiumDeficit}mg (max allowed: ${sodiumMaxAllowed}mg)`);
    // Use essential foods fetched at start of post-processing + electrolyte foods
    const essentialSodiumOptions = essentialFoodsTransformed.filter((f)=>safe(f.per_serving.sodium_mg) > 0);
    const sodiumCandidates = [
      ...electrolyteFoods,
      ...essentialSodiumOptions
    ].filter((food, index, self)=>self.findIndex((other)=>other.id === food.id) === index);
    const sortedCandidates = sodiumCandidates.sort((a, b)=>{
      const ratioA = a.per_serving.sodium_mg / Math.max(1, a.per_serving.water_ml);
      const ratioB = b.per_serving.sodium_mg / Math.max(1, b.per_serving.water_ml);
      if (ratioB !== ratioA) return ratioB - ratioA;
      return b.per_serving.sodium_mg - a.per_serving.sodium_mg;
    });
    for (const option of sortedCandidates){
      const sodiumPerServing = option.per_serving.sodium_mg;
      if (sodiumPerServing <= 0) continue;
      const exactServings = sodiumDeficit / sodiumPerServing;
      // Use roundToIncrement (nearest 0.5) instead of roundUpToIncrement to prevent overshooting
      const roundedServings = Math.max(0.5, roundToIncrement(exactServings, 0.5));
      const potentialSodium = sodiumPerServing * roundedServings;
      const potentialWater = option.per_serving.water_ml * roundedServings;
      // OVERSHOOT PREVENTION: Check if adding this would exceed 110% of target
      if (totals.sodium_mg + potentialSodium > sodiumMaxAllowed + 1e-3) {
        console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Skipping ${option.name}: would overshoot sodium (${totals.sodium_mg + potentialSodium}mg > ${sodiumMaxAllowed}mg max)`);
        // Try with fewer servings if possible
        const maxServingsForSodium = (sodiumMaxAllowed - totals.sodium_mg) / sodiumPerServing;
        const reducedServings = roundToIncrement(maxServingsForSodium, 0.5);
        if (reducedServings >= 0.5) {
          const reducedSodium = sodiumPerServing * reducedServings;
          const reducedWater = option.per_serving.water_ml * reducedServings;
          if (totals.water_ml + reducedWater <= waterMaxAllowed + 1e-3) {
            console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Using reduced servings: ${reducedServings} of ${option.name}`);
            foods.push({
              food_id: option.id,
              food_name: option.name,
              quantity: reducedServings,
              carbs_grams: option.per_serving.carbs_g * reducedServings,
              protein_grams: option.per_serving.protein_g * reducedServings,
              fat_grams: option.per_serving.fat_g * reducedServings,
              sodium_mg: reducedSodium,
              fluids_ml: reducedWater,
              calories: option.per_serving.calories * reducedServings,
              display_name: option.display_name ?? option.name,
              display_name_plural: option.display_name_plural ?? option.display_name ?? option.name,
              description: option.description,
              image_address: option.image_address
            });
            totals.sodium_mg += reducedSodium;
            totals.water_ml += reducedWater;
            break;
          }
        }
        continue;
      }
      if (totals.water_ml + potentialWater > waterMaxAllowed + 1e-3) {
        continue;
      }
      foods.push({
        food_id: option.id,
        food_name: option.name,
        quantity: roundedServings,
        carbs_grams: option.per_serving.carbs_g * roundedServings,
        protein_grams: option.per_serving.protein_g * roundedServings,
        fat_grams: option.per_serving.fat_g * roundedServings,
        sodium_mg: potentialSodium,
        fluids_ml: potentialWater,
        calories: option.per_serving.calories * roundedServings,
        display_name: option.display_name ?? option.name,
        display_name_plural: option.display_name_plural ?? option.display_name ?? option.name,
        description: option.description,
        image_address: option.image_address
      });
      totals.sodium_mg += potentialSodium;
      totals.water_ml += potentialWater;
      break;
    }
    // Only add electrolyte powder as last resort if still significantly under target
    if (targets.sodium_mg > 0 && totals.sodium_mg < targets.sodium_mg * (1 - POST_PROCESS_THRESHOLDS.sodium_deficit_percent)) {
      const electrolytePowder = essentialFoodsTransformed.find((f)=>f.name === 'Electrolyte Powder (1mg sodium)') ||
                               allFoods.find((f)=>f.name === 'Electrolyte Powder (1mg sodium)');
      if (electrolytePowder) {
        const remainingSodium = Math.min(targets.sodium_mg - totals.sodium_mg, sodiumMaxAllowed - totals.sodium_mg);
        if (remainingSodium > 0) {
          const preciseServings = Math.max(0, remainingSodium / Math.max(1, electrolytePowder.per_serving.sodium_mg));
          // Use roundToIncrement instead of roundUpToIncrement
          const roundedServings = Math.max(0.5, roundToIncrement(preciseServings, 0.5));
          const potentialSodiumPowder = electrolytePowder.per_serving.sodium_mg * roundedServings;
          const potentialWater = electrolytePowder.per_serving.water_ml * roundedServings;
          // Also check overshoot for electrolyte powder
          if (totals.sodium_mg + potentialSodiumPowder <= sodiumMaxAllowed + 1e-3 &&
              totals.water_ml + potentialWater <= waterMaxAllowed + 1e-3) {
            foods.push({
              food_id: electrolytePowder.id,
              food_name: electrolytePowder.name,
              quantity: roundedServings,
              carbs_grams: electrolytePowder.per_serving.carbs_g * roundedServings,
              protein_grams: electrolytePowder.per_serving.protein_g * roundedServings,
              fat_grams: electrolytePowder.per_serving.fat_g * roundedServings,
              sodium_mg: potentialSodiumPowder,
              fluids_ml: potentialWater,
              calories: electrolytePowder.per_serving.calories * roundedServings,
              display_name: electrolytePowder.display_name ?? electrolytePowder.name,
              display_name_plural: electrolytePowder.display_name_plural ?? electrolytePowder.display_name ?? electrolytePowder.name,
              description: electrolytePowder.description,
              image_address: electrolytePowder.image_address
            });
            totals.sodium_mg += potentialSodiumPowder;
            totals.water_ml += potentialWater;
          }
        }
      }
    }
  }
  // Add water if needed - look in essential foods first (since water is essential)
  if (needsWater && !hasPlainWater && !hasWaterWithElectrolytes) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Adding water for deficit: ${waterDeficit}ml`);
    // Look in essential foods first, then fall back to allFoods
    const water = essentialFoodsTransformed.find((f)=>{
      const name = f.name?.toLowerCase();
      const displayName = f.display_name?.toLowerCase();
      return name === 'water' || displayName?.includes('water');
    }) || allFoods.find((f)=>{
      const name = f.name?.toLowerCase();
      const displayName = f.display_name?.toLowerCase();
      return name === 'water' || displayName?.includes('water');
    });
    if (water) {
      const waterPerServing = water.per_serving.water_ml || 0;
      if (waterPerServing > 0) {
        const remainingCapacity = waterMaxAllowed - totals.water_ml;
        const feasibleServings = Math.min(waterDeficit / waterPerServing, remainingCapacity / waterPerServing);
        // Use roundToIncrement for consistency
        const roundedWaterServings = roundToIncrement(Math.max(0, feasibleServings), 0.5);
        const potentialWater = water.per_serving.water_ml * roundedWaterServings;
        if (roundedWaterServings >= 0.5 && totals.water_ml + potentialWater <= waterMaxAllowed + 1e-3) {
          foods.push({
            food_id: water.id,
            food_name: water.name,
            quantity: roundedWaterServings,
            carbs_grams: water.per_serving.carbs_g * roundedWaterServings,
            protein_grams: water.per_serving.protein_g * roundedWaterServings,
            fat_grams: water.per_serving.fat_g * roundedWaterServings,
            sodium_mg: water.per_serving.sodium_mg * roundedWaterServings,
            fluids_ml: water.per_serving.water_ml * roundedWaterServings,
            calories: water.per_serving.calories * roundedWaterServings,
            display_name: water.display_name ?? water.name,
            display_name_plural: water.display_name_plural ?? water.display_name ?? water.name,
            description: water.description,
            image_address: water.image_address
          });
          totals.water_ml += potentialWater;
        }
      }
    }
  }
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Post-processing complete. Total foods: ${foods.length}`);
  return foods;
}
// ---------------- Main Optimization Function ----------------
async function optimizePhase(supabase, phase, userId, targets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType = 'running') {
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Starting optimization for ${activityType}`);
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Targets:`, targets);
  // Get foods for this phase with activity type filtering
  const foods = await getFoodsForPhase(supabase, phase, userId, likedFoods, willTryFoods, dislikedFoods, activityType);
  if (foods.length === 0) {
    console.log(`[OPTIMIZE-${phase.toUpperCase()}] No foods available`);
    return {
      items: [],
      totals: {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 0,
        water_ml: 0
      }
    };
  }
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Found ${foods.length} candidate foods`);
  // Build and solve LP model
  const model = buildLPModel(foods, targets, phase);
  let solution = solveLPModel(model, foods, phase);
  // Use greedy fallback if LP solver fails
  if (!solution) {
    console.log(`[OPTIMIZE-${phase.toUpperCase()}] LP solver failed, using greedy fallback`);
    solution = greedyFallback(foods, targets, phase);
  }
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] LP solution found with ${solution.foods.length} foods`);
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Pre-post-process totals:`, solution.totals);
  // Post-process to add electrolytes and water as needed
  const postProcessedFoods = await postProcessPhase(supabase, solution, targets, electrolyteFoods, foods, phase);
  // Deduplicate foods to consolidate duplicate items
  const finalFoods = deduplicateFoods(postProcessedFoods);
  // Calculate final totals
  const finalTotals = finalFoods.reduce((acc, food)=>({
      carbs_g: acc.carbs_g + (food.carbs_grams || 0),
      protein_g: acc.protein_g + (food.protein_grams || 0),
      fat_g: acc.fat_g + (food.fat_grams || 0),
      sodium_mg: acc.sodium_mg + (food.sodium_mg || 0),
      water_ml: acc.water_ml + (food.fluids_ml || 0)
    }), {
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    water_ml: 0
  });
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Final totals after deduplication:`, finalTotals);
  return {
    items: finalFoods,
    totals: finalTotals
  };
}
// ---------------- Request Handler ----------------
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    console.log("[IMPROVED-LP] Starting improved LP solver with post-processing");
    const body = await req.json();
    // Validate required fields (device_id contains the user UUID)
    if (!body.device_id || !body.macro_targets) {
      return new Response(JSON.stringify({
        success: false,
        message: "Missing required fields: device_id (user UUID) and macro_targets are required"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const { pre_run, during_run, post_run } = body.macro_targets;
    // Normalize targets
    const preTargets = {
      carbs_g: safe(pre_run.carbs_g),
      protein_g: safe(pre_run.protein_g),
      sodium_mg: safe(pre_run.sodium_mg),
      water_ml: safe(pre_run.water_ml)
    };
    const duringTargets = {
      carbs_g: safe(during_run.carbs_g || during_run.carbs_total_g),
      sodium_mg: safe(during_run.sodium_mg || during_run.sodium_total_mg),
      water_ml: safe(during_run.water_ml || during_run.water_total_ml)
    };
    const postTargets = {
      carbs_g: safe(post_run.carbs_g),
      protein_g: safe(post_run.protein_g),
      sodium_mg: safe(post_run.sodium_mg),
      water_ml: safe(post_run.water_ml)
    };
    // Parse preferences with debugging
    const likedFoods = buildPreferenceSet(body.liked_foods);
    const willTryFoods = buildPreferenceSet(body.willing_to_try_foods);
    const dislikedFoods = buildPreferenceSet(body.disliked_foods);
    // CRITICAL DEBUG: Log received food preferences
    console.log("[FOOD-PREFERENCES] Received preferences:", {
      liked_foods: Array.from(likedFoods),
      willing_to_try_foods: Array.from(willTryFoods),
      disliked_foods: Array.from(dislikedFoods),
      raw_body_preferences: {
        liked_foods: body.liked_foods,
        willing_to_try_foods: body.willing_to_try_foods,
        disliked_foods: body.disliked_foods
      }
    });
    // Get activity type (default to running for backward compatibility)
    const activityType = body.activity_type || 'running';
    console.log(`[IMPROVED-LP] Processing nutrition plan for activity_type: ${activityType}`);
    // Get user ID (which is the UUID sent as device_id)
    const userId = body.device_id; // This is actually the user's UUID
    // Get electrolyte foods once for all phases
    const electrolyteFoods = await getElectrolyteFoods(supabase, userId, likedFoods, willTryFoods);
    console.log(`[IMPROVED-LP] Found ${electrolyteFoods.length} preferred electrolyte options`);
    // Optimize each phase with activity_type filtering
    const [before, during, after] = await Promise.all([
      optimizePhase(supabase, "before", userId, preTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType),
      optimizePhase(supabase, "during", userId, duringTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType),
      optimizePhase(supabase, "after", userId, postTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods, activityType)
    ]);
    // Generate response
    const planId = crypto.randomUUID(); // Generate proper UUID instead of custom string format
    const detailedMessage = `Optimized nutrition plan using linear programming with targeted macro optimization and intelligent electrolyte/water supplementation.`;
    return new Response(JSON.stringify({
      success: true,
      plan_id: planId,
      detailed_message: detailedMessage,
      plan: {
        before: before.items,
        during: during.items,
        after: after.items
      },
      macro_targets: {
        ...body.macro_targets,
        activity_type: activityType // Include activity type for section title generation
      }
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    console.error("[IMPROVED-LP] Error:", error);
    return new Response(JSON.stringify({
      success: false,
      error: String(error),
      fallback_to_algorithm: true
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
