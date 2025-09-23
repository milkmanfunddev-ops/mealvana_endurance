/**
 * IMPROVED LINEAR PROGRAMMING NUTRITION PLANNER
 * Uses javascript-lp-solver for optimization with post-processing for electrolytes and water
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import solver from "https://esm.sh/javascript-lp-solver@0.4.24";

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
    carbs: 1.0,      // Primary focus
    protein: 0.6,    // Important secondary for sustained energy
    fluids: 0.2,     // Reduced from 0.3 (was over-target)
    sodium: 0.2      // Reduced from 0.5 (was 4.5x over-target!)
  },
  during: {
    carbs: 1.0,      // Primary focus for performance
    fluids: 0.7,     // High priority for hydration (during was fine)
    sodium: 0.8      // High constraint importance to avoid cramping (during was fine)
  },
  after: {
    carbs: 0.9,      // Reduced from 1.0 (was 2x over-target)
    protein: 0.7,    // Reduced from 0.8 (was slightly over)
    fluids: 0.2,     // Reduced from 0.4 (was 2.5x over-target!)
    sodium: 0.3      // Reduced from 0.6 (was 3x over-target!)
  }
};

// Tolerance thresholds for post-processing - tighter to prevent massive overshoots
const POST_PROCESS_THRESHOLDS = {
  sodium_deficit_percent: 0.03,  // Add electrolytes if < 97% of target (lowered to catch small deficits like 25mg)
  water_deficit_percent: 0.15,   // Add water if < 85% of target
  sodium_surplus_percent: 0.10,  // Don't add if > 110% of target (was 120%, too loose)
  water_surplus_percent: 0.15    // Don't add if > 115% of target (was 120%, too loose)
};

// ---------------- Types ----------------
interface Food {
  id: string;
  name: string;
  display_name?: string;
  display_name_plural?: string;
  description?: string;
  image_address?: string;
  per_serving: {
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    water_ml: number;
    calories: number;
  };
  serving_amount?: number;
  max_servings_before?: number;
  max_servings_during?: number;
  max_servings_after?: number;
  preference_score: number;
  is_electrolyte?: boolean;
}

interface MacroTargets {
  carbs_g: number;
  protein_g?: number;
  fat_g?: number;
  sodium_mg: number;
  water_ml: number;
}

interface OptimizationResult {
  foods: any[];
  totals: {
    carbs_g: number;
    protein_g: number;
    fat_g: number;
    sodium_mg: number;
    water_ml: number;
  };
  needsElectrolyte: boolean;
  needsWater: boolean;
}

// ---------------- Utils ----------------
const safe = (n: any, d = 0) => Number.isFinite(Number(n)) ? Number(n) : d;

function roundToIncrement(value: number, increment: number = 0.5): number {
  return Math.round(value / increment) * increment;
}

// Display functions removed - frontend handles all display logic via database lookups

function deduplicateFoods(foods: any[]): any[] {
  const foodMap = new Map();

  for (const food of foods) {
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
      foodMap.set(foodId, { ...food });
    }
  }

  // Return deduplicated foods with rounded values
  return Array.from(foodMap.values()).map(food => ({
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
async function getCategoryId(supabase: any, categoryName: string): Promise<string | null> {
  const { data, error } = await supabase
    .from("categories")
    .select("id")
    .eq("name", categoryName)
    .maybeSingle();

  if (error || !data) return null;
  return data.id;
}

async function getFoodsForPhase(
  supabase: any,
  phase: string,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  dislikedFoods: Set<string>
): Promise<Food[]> {
  const categoryName = phase === "before" ? "before_run"
    : phase === "after" ? "after_run"
    : "during_run";

  const categoryId = await getCategoryId(supabase, categoryName);
  if (!categoryId) return [];

  // Get food IDs for this category
  const { data: foodCategories, error: fcError } = await supabase
    .from("food_categories")
    .select("food_id")
    .eq("category_id", categoryId);

  if (fcError || !foodCategories || foodCategories.length === 0) return [];

  const foodIds = foodCategories.map((fc: any) => fc.food_id);

  // Get foods with all needed fields including is_electrolyte
  const { data: foods, error: foodsError } = await supabase
    .from("foods")
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount,
      max_servings_before, max_servings_during, max_servings_after,
      brand_id, is_electrolyte, to_exclude_from_solver
    `)
    .is("brand_id", null) // Only generic foods
    .in("id", foodIds);

  if (foodsError || !foods) return [];

  // Helper function to check if a food matches user preferences
  const matchesPreference = (food: any, preferenceSet: Set<string>): boolean => {
    const foodName = food.name?.toLowerCase();
    const displayName = food.display_name?.toLowerCase();

    // Check multiple name variations for better matching
    return preferenceSet.has(food.id) ||                    // Check by ID
           preferenceSet.has(food.name) ||                   // Check exact name
           (foodName && preferenceSet.has(foodName)) ||      // Check lowercase name
           (displayName && preferenceSet.has(displayName)) || // Check display name
           // Check if any preference contains the food name (partial match)
           Array.from(preferenceSet).some(pref =>
             foodName && pref.toLowerCase().includes(foodName) ||
             foodName && foodName.includes(pref.toLowerCase())
           );
  };

  // Filter out disliked foods and foods excluded from solver
  return foods
    .filter((f: any) => {
      const isDisliked = matchesPreference(f, dislikedFoods);
      const isExcludedFromSolver = f.to_exclude_from_solver === true;

      // CRITICAL: Log when disliked foods are being filtered out
      if (isDisliked) {
        console.log(`[FILTER-DISLIKED] Excluding disliked food: ${f.name} (id: ${f.id})`);
      }

      return !isDisliked && !isExcludedFromSolver;
    })
    .map((f: any) => {
      // Calculate preference score using improved matching
      let preference_score = 0.5; // Neutral

      if (matchesPreference(f, likedFoods)) {
        preference_score = 2.0; // Liked
        console.log(`[PREFERENCE] Liked food found: ${f.name} (score: 2.0)`);
      } else if (matchesPreference(f, willTryFoods)) {
        preference_score = 1.0; // Willing to try
        console.log(`[PREFERENCE] Willing to try food found: ${f.name} (score: 1.0)`);
      } else {
        console.log(`[PREFERENCE] Neutral food: ${f.name} (score: 0.5)`);
      }

      // Get phase-specific max servings
      const maxServings = phase === "before" ? f.max_servings_before :
                         phase === "during" ? f.max_servings_during :
                         f.max_servings_after;

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
        max_servings: maxServings || 10,
        preference_score,
        is_electrolyte: f.is_electrolyte || false
      };
    });
}

async function getElectrolyteFoods(
  supabase: any,
  likedFoods: Set<string>,
  willTryFoods: Set<string>
): Promise<Food[]> {
  const { data: electrolytes, error } = await supabase
    .from("foods")
    .select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml_per_serving,
      serving_amount,
      is_electrolyte, to_exclude_from_solver
    `)
    .eq("is_electrolyte", true);

  if (error || !electrolytes) return [];

  // Helper function to check if electrolyte matches user preferences (reusing logic)
  const matchesElectrolytePreference = (food: any, preferenceSet: Set<string>): boolean => {
    const foodName = food.name?.toLowerCase();
    const displayName = food.display_name?.toLowerCase();

    return preferenceSet.has(food.id) ||                    // Check by ID
           preferenceSet.has(food.name) ||                   // Check exact name
           (foodName && preferenceSet.has(foodName)) ||      // Check lowercase name
           (displayName && preferenceSet.has(displayName)) || // Check display name
           Array.from(preferenceSet).some(pref =>
             foodName && pref.toLowerCase().includes(foodName) ||
             foodName && foodName.includes(pref.toLowerCase())
           );
  };

  return electrolytes
    .filter((e: any) => {
      // Only use liked or willing-to-try electrolytes (improved matching)
      const isLiked = matchesElectrolytePreference(e, likedFoods);
      const isWillingToTry = matchesElectrolytePreference(e, willTryFoods);

      if (isLiked || isWillingToTry) {
        console.log(`[ELECTROLYTE] Including electrolyte: ${e.name} (liked: ${isLiked}, willing: ${isWillingToTry})`);
        return true;
      }

      return false;
    })
    .map((e: any) => ({
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
      is_electrolyte: true
    }));
}

// ---------------- LP Solver Integration ----------------
function buildLPModel(
  foods: Food[],
  targets: MacroTargets,
  phase: string
): any {
  const weights = OPTIMIZATION_WEIGHTS[phase as keyof typeof OPTIMIZATION_WEIGHTS];

  // Build the LP model
  const model: any = {
    optimize: "score",
    opType: "max",
    constraints: {},
    variables: {},
    ints: {}
  };

  // Phase-specific carb constraints (relaxed slightly for feasibility)
  if (phase === "after") {
    model.constraints.carbs = { min: targets.carbs_g * 0.8, max: targets.carbs_g * 1.15 }; // Relaxed for feasibility
  } else {
    model.constraints.carbs = { min: targets.carbs_g * 0.8, max: targets.carbs_g * 1.2 }; // Relaxed for feasibility
  }

  // Add protein constraints for before and after phases
  if ((phase === "before" || phase === "after") && targets.protein_g) {
    model.constraints.protein = { min: targets.protein_g * 0.8, max: targets.protein_g * 1.2 };
  }

  // Balanced sodium constraints - prevent massive overshoot but allow feasibility
  model.constraints.sodium = {
    min: targets.sodium_mg * 0.6, // Relaxed minimum for feasibility
    max: targets.sodium_mg * 1.25 // Moderate upper bound (125% - compromise between 110% and 130%)
  };

  // Phase-specific water constraints (relaxed slightly for feasibility)
  if (phase === "after") {
    model.constraints.water = { max: targets.water_ml * 1.2 }; // Relaxed for feasibility
  } else {
    model.constraints.water = { max: targets.water_ml * 1.4 }; // More flexible for before/during
  }

  // Constraint to limit total number of foods for solver (can expand to 4-5 with post-processing)
  model.constraints.total_foods = { max: 3 };

  // Add variables for each food
  foods.forEach((food, index) => {
    const varName = `food_${index}`;

    // Calculate score based on preference and macro contribution
    let score = food.preference_score * 10; // Base score from preference

    // Add weighted macro contributions to score
    score += weights.carbs * food.per_serving.carbs_g;

    // Add protein scoring for before and after phases
    if ((phase === "before" || phase === "after") && 'protein' in weights) {
      score += (weights as any).protein * food.per_serving.protein_g;
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

    model.variables[varName] = {
      score: score,
      carbs: food.per_serving.carbs_g,
      protein: food.per_serving.protein_g,
      sodium: food.per_serving.sodium_mg,
      water: food.per_serving.water_ml,
      total_foods: 1
    };

    // Set as integer variable with bounds
    model.ints[varName] = 1;
    // Use phase-specific max servings or default to 4
    const maxServings = phase === 'before' ? (food.max_servings_before || 4) :
                       phase === 'during' ? (food.max_servings_during || 4) :
                       (food.max_servings_after || 4);
    model.constraints[varName] = { max: Math.min(maxServings, 4) };
  });

  return model;
}

function solveLPModel(model: any, foods: Food[], phase: string): OptimizationResult | null {
  try {
    const solution = solver.Solve(model);

    if (!solution || !solution.feasible) {
      console.log("[LP-SOLVER] No feasible solution found");
      return null;
    }

    // Extract selected foods and quantities
    const selectedFoods: any[] = [];
    let totals = {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0
    };

    foods.forEach((food, index) => {
      const varName = `food_${index}`;
      const servings = solution[varName] || 0;

      if (servings > 0) {
        const roundedServings = roundToIncrement(servings);

        selectedFoods.push({
          food_id: food.id,
          quantity: roundedServings,
          carbs_grams: food.per_serving.carbs_g * roundedServings,
          protein_grams: food.per_serving.protein_g * roundedServings,
          fat_grams: food.per_serving.fat_g * roundedServings,
          sodium_mg: food.per_serving.sodium_mg * roundedServings,
          fluids_ml: food.per_serving.water_ml * roundedServings,
          calories: food.per_serving.calories * roundedServings,
          timing: phase === "before" ? "2-3 hours before" :
                  phase === "during" ? "Throughout run" :
                  "Within 30 minutes",
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
function greedyFallback(
  foods: Food[],
  targets: MacroTargets,
  phase: string
): OptimizationResult {
  console.log(`[GREEDY-FALLBACK] Using greedy approach for ${phase} phase`);

  const selectedFoods: any[] = [];
  let totals = {
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    water_ml: 0
  };

  // Sort foods by preference score and macro efficiency
  const sortedFoods = [...foods].sort((a, b) => {
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
      return (carbsB + proteinB) - (carbsA + proteinA);
    }

    return carbsB - carbsA;
  });

  // Greedily select foods to meet targets with overshoot prevention (can expand to 4-5 with post-processing)
  let maxFoods = 3;
  const carbsTarget = targets.carbs_g;
  const proteinTarget = targets.protein_g || 0;
  const sodiumTarget = targets.sodium_mg || 0;
  const waterTarget = targets.water_ml || 0;

  for (const food of sortedFoods) {
    if (selectedFoods.length >= maxFoods) break;

    // Check if adding this food would cause excessive overshoots
    const wouldOvershootSodium = sodiumTarget > 0 &&
      (totals.sodium_mg + food.per_serving.sodium_mg) > (sodiumTarget * 1.3);
    const wouldOvershootWater = waterTarget > 0 &&
      (totals.water_ml + food.per_serving.water_ml) > (waterTarget * 1.3);

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
async function postProcessPhase(
  _supabase: any,
  result: OptimizationResult,
  targets: MacroTargets,
  electrolyteFoods: Food[],
  allFoods: Food[],
  phase: string
): Promise<any[]> {
  // First, fix any water/electrolyte items from solver with incorrect formatting
  const foods = result.foods.map(food => {
    // Check if this is a water/electrolyte item (identified by name pattern)
    if (food.food_name?.toLowerCase().includes('water') && food.food_name?.toLowerCase().includes('electrolyte')) {
      // Fix "34.5 servings water with electrolytes" → proper format
      const flOz = roundToIncrement(food.servings * 8, 0.5); // 8 fl oz per serving
      const sodium = Math.round(food.sodium_mg || (food.servings * 200)); // 200mg per serving default
      const packets = Math.round((sodium / 200) * 2) / 2; // Round to nearest 0.5

      console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Fixed Water with Electrolytes format: ${food.servings} servings → ${flOz} fl oz`);

      return {
        ...food,
        description: `${flOz} fl oz with ${sodium}mg electrolytes (~${packets} salt packet${packets !== 1 ? 's' : ''})`,
        fluids_ml: flOz * 30, // Ensure fluid calculation is correct (30ml per fl oz)
        sodium_mg: sodium
      };
    }

    // Check for plain water with bad formatting (using name pattern)
    if (food.food_name?.toLowerCase().includes('water') &&
        !food.food_name?.toLowerCase().includes('electrolyte') &&
        food.description?.includes('servings')) {
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
  const hasWaterWithElectrolytes = foods.some(f =>
    f.food_name?.toLowerCase().includes('water') && f.food_name?.toLowerCase().includes('electrolyte'));
  const hasPlainWater = foods.some(f =>
    f.food_name?.toLowerCase().includes('water') && !f.food_name?.toLowerCase().includes('electrolyte'));
  const hasSalt = foods.some(f =>
    f.food_name?.toLowerCase().includes('salt'));

  // Recalculate totals after fixing formats
  const totals = foods.reduce((acc, food) => ({
    carbs_g: acc.carbs_g + (food.carbs_grams || 0),
    protein_g: acc.protein_g + (food.protein_grams || 0),
    fat_g: acc.fat_g + (food.fat_grams || 0),
    sodium_mg: acc.sodium_mg + (food.sodium_mg || 0),
    water_ml: acc.water_ml + (food.fluids_ml || 0)
  }), { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 });

  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Starting SMART post-processing with ${foods.length} foods`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Solver already included: WaterElectrolytes=${hasWaterWithElectrolytes}, Water=${hasPlainWater}, Salt=${hasSalt}`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Current totals:`, totals);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Targets:`, targets);

  // Check deficits
  const sodiumDeficit = targets.sodium_mg - totals.sodium_mg;
  const waterDeficit = targets.water_ml - totals.water_ml;
  const sodiumDeficitPercent = sodiumDeficit / targets.sodium_mg;
  const waterDeficitPercent = waterDeficit / targets.water_ml;
  const currentSodiumPercent = totals.sodium_mg / targets.sodium_mg;
  const currentWaterPercent = totals.water_ml / targets.water_ml;

  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Sodium: current ${totals.sodium_mg}mg vs target ${targets.sodium_mg}mg (${(currentSodiumPercent * 100).toFixed(0)}%)`);
  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Water: current ${totals.water_ml}ml vs target ${targets.water_ml}ml (${(currentWaterPercent * 100).toFixed(0)}%)`);

  // Guard clause: Don't add anything if we have no room for more foods
  if (foods.length >= 5) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] At food limit (${foods.length}/5), skipping post-processing`);
    return foods;
  }

  // Check if we need individual sodium and water additions
  const needsSodium = sodiumDeficit > 0 &&
                     sodiumDeficitPercent > POST_PROCESS_THRESHOLDS.sodium_deficit_percent &&
                     currentSodiumPercent <= 1.1;

  const needsWater = waterDeficit > 0 &&
                    waterDeficitPercent > POST_PROCESS_THRESHOLDS.water_deficit_percent &&
                    currentWaterPercent <= 1.0;

  // INDIVIDUAL SOLUTIONS: Add water and electrolytes separately

  // Add sodium if needed
  if (needsSodium && !hasSalt && !hasWaterWithElectrolytes) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Adding sodium for deficit: ${sodiumDeficit}mg`);

    // Try preferred electrolyte first
    let electrolyte: Food | null = null;
    if (electrolyteFoods.length > 0) {
      electrolyte = electrolyteFoods
        .sort((a, b) => b.per_serving.sodium_mg - a.per_serving.sodium_mg)[0];
    }

    if (electrolyte) {
      // Use preferred electrolyte
      const servingsNeeded = Math.ceil(sodiumDeficit / electrolyte.per_serving.sodium_mg);
      const roundedServings = roundToIncrement(servingsNeeded);

      foods.push({
        food_id: electrolyte.id,
        quantity: roundedServings,
        carbs_grams: electrolyte.per_serving.carbs_g * roundedServings,
        protein_grams: electrolyte.per_serving.protein_g * roundedServings,
        fat_grams: electrolyte.per_serving.fat_g * roundedServings,
        sodium_mg: electrolyte.per_serving.sodium_mg * roundedServings,
        fluids_ml: electrolyte.per_serving.water_ml * roundedServings,
        calories: electrolyte.per_serving.calories * roundedServings
      });
    } else {
      // Fall back to electrolyte powder - use precise 1mg sodium dosing
      const electrolytePowder = allFoods.find((f: Food) => f.name === 'Electrolyte Powder (1mg sodium)');
      if (electrolytePowder) {
        const roundedSodium = Math.ceil(sodiumDeficit);

        foods.push({
          food_id: electrolytePowder.id,
          quantity: roundedSodium, // Each unit = 1mg sodium
          carbs_grams: electrolytePowder.per_serving.carbs_g * roundedSodium,
          protein_grams: electrolytePowder.per_serving.protein_g * roundedSodium,
          fat_grams: electrolytePowder.per_serving.fat_g * roundedSodium,
          sodium_mg: electrolytePowder.per_serving.sodium_mg * roundedSodium,
          fluids_ml: electrolytePowder.per_serving.water_ml * roundedSodium,
          calories: electrolytePowder.per_serving.calories * roundedSodium
        });
      }
    }
  }

  // Add water if needed
  if (needsWater && !hasPlainWater && !hasWaterWithElectrolytes) {
    console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Adding water for deficit: ${waterDeficit}ml`);

    const water = allFoods.find((f: Food) => f.name === 'Water' && f.display_name?.includes('fl oz'));
    if (water) {
      const waterServingsNeeded = Math.ceil(waterDeficit / 29.5735); // Convert ml to fl oz
      const roundedWaterServings = roundToIncrement(waterServingsNeeded, 0.5);

      foods.push({
        food_id: water.id,
        quantity: roundedWaterServings,
        carbs_grams: water.per_serving.carbs_g * roundedWaterServings,
        protein_grams: water.per_serving.protein_g * roundedWaterServings,
        fat_grams: water.per_serving.fat_g * roundedWaterServings,
        sodium_mg: water.per_serving.sodium_mg * roundedWaterServings,
        fluids_ml: water.per_serving.water_ml * roundedWaterServings,
        calories: water.per_serving.calories * roundedWaterServings
      });
    }
  }

  console.log(`[POST-PROCESS-${phase?.toUpperCase()}] Post-processing complete. Total foods: ${foods.length}`);
  return foods;
}

// ---------------- Main Optimization Function ----------------
async function optimizePhase(
  supabase: any,
  phase: string,
  targets: MacroTargets,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  dislikedFoods: Set<string>,
  electrolyteFoods: Food[]
): Promise<any> {
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Starting optimization`);
  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Targets:`, targets);

  // Get foods for this phase
  const foods = await getFoodsForPhase(supabase, phase, likedFoods, willTryFoods, dislikedFoods);

  if (foods.length === 0) {
    console.log(`[OPTIMIZE-${phase.toUpperCase()}] No foods available`);
    return { items: [], totals: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 } };
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
  const postProcessedFoods = await postProcessPhase(
    supabase,
    solution,
    targets,
    electrolyteFoods,
    foods,
    phase
  );

  // Deduplicate foods to consolidate duplicate items
  const finalFoods = deduplicateFoods(postProcessedFoods);

  // Calculate final totals
  const finalTotals = finalFoods.reduce((acc: any, food: any) => ({
    carbs_g: acc.carbs_g + (food.carbs_grams || 0),
    protein_g: acc.protein_g + (food.protein_grams || 0),
    fat_g: acc.fat_g + (food.fat_grams || 0),
    sodium_mg: acc.sodium_mg + (food.sodium_mg || 0),
    water_ml: acc.water_ml + (food.fluids_ml || 0)
  }), { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0 });

  console.log(`[OPTIMIZE-${phase.toUpperCase()}] Final totals after deduplication:`, finalTotals);

  return {
    items: finalFoods,
    totals: finalTotals
  };
}

// ---------------- Request Handler ----------------
serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    console.log("[IMPROVED-LP] Starting improved LP solver with post-processing");

    const body = await req.json();

    // Validate required fields
    if (!body.device_id || !body.macro_targets) {
      return new Response(JSON.stringify({
        success: false,
        message: "Missing required fields: device_id and macro_targets are required"
      }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      });
    }

    const { pre_run, during_run, post_run } = body.macro_targets;

    // Normalize targets
    const preTargets: MacroTargets = {
      carbs_g: safe(pre_run.carbs_g),
      protein_g: safe(pre_run.protein_g),
      sodium_mg: safe(pre_run.sodium_mg),
      water_ml: safe(pre_run.water_ml)
    };

    const duringTargets: MacroTargets = {
      carbs_g: safe(during_run.carbs_g || during_run.carbs_total_g),
      sodium_mg: safe(during_run.sodium_mg || during_run.sodium_total_mg),
      water_ml: safe(during_run.water_ml || during_run.water_total_ml)
    };

    const postTargets: MacroTargets = {
      carbs_g: safe(post_run.carbs_g),
      protein_g: safe(post_run.protein_g),
      sodium_mg: safe(post_run.sodium_mg),
      water_ml: safe(post_run.water_ml)
    };

    // Parse preferences with debugging
    const likedFoods = new Set<string>(body.liked_foods || []);
    const willTryFoods = new Set<string>(body.willing_to_try_foods || []);
    const dislikedFoods = new Set<string>(body.disliked_foods || []);

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

    // Get electrolyte foods once for all phases
    const electrolyteFoods = await getElectrolyteFoods(supabase, likedFoods, willTryFoods);
    console.log(`[IMPROVED-LP] Found ${electrolyteFoods.length} preferred electrolyte options`);

    // Optimize each phase
    const [before, during, after] = await Promise.all([
      optimizePhase(supabase, "before", preTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods),
      optimizePhase(supabase, "during", duringTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods),
      optimizePhase(supabase, "after", postTargets, likedFoods, willTryFoods, dislikedFoods, electrolyteFoods)
    ]);

    // Generate response
    const planId = `improved-lp-${Date.now()}-${body.device_id.slice(-6)}`;
    const detailedMessage = `Optimized nutrition plan using linear programming with targeted macro optimization and intelligent electrolyte/water supplementation.`;

    // Save plan to database
    const nutritionPlan = {
      detailed_message: detailedMessage,
      plan: {
        before: before.items,
        during: during.items,
        after: after.items
      }
    };

    await supabase.from("nutrition_plans").insert({
      device_id: body.device_id,
      plan_id: planId,
      plan_name: "LP-Optimized Nutrition Plan",
      plan_data: JSON.stringify(nutritionPlan),
      distance_miles: body.distance_miles,
      pace_minutes_per_mile: body.pace_minutes_per_mile,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });

    return new Response(JSON.stringify({
      success: true,
      plan_id: planId,
      detailed_message: detailedMessage,
      plan: {
        before: before.items,
        during: during.items,
        after: after.items
      },
      macro_targets: body.macro_targets
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });

  } catch (error) {
    console.error("[IMPROVED-LP] Error:", error);
    return new Response(JSON.stringify({
      success: false,
      error: String(error),
      fallback_to_algorithm: true
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    });
  }
});