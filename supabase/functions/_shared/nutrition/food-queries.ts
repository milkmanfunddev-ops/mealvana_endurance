/**
 * Database queries for food retrieval
 *
 * Uses expanded category_enum for sport-specific filtering:
 * - before: Universal pre-activity
 * - during_run: Running during activity
 * - during_bike: Cycling during activity (allows more solid foods)
 * - during_swim: Swimming during activity (liquids/gels only)
 * - after: Universal post-activity
 * - transition: Triathlon transition zone
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { safe } from '../utils.ts';
import type { Food, Phase, ActivityType } from './types.ts';
import { PREFERENCE_SCORE_MAP, DEFAULT_MAX_SERVINGS, getCategoryForPhase } from './constants.ts';
import { matchesPreference } from './food-utils.ts';

/**
 * Build a Supabase category filter for the given categories
 * Uses the categories array column with overlaps operator
 */
function buildCategoryFilter(categories: string[]): string {
  // Create an "overlaps" filter: categories && {cat1,cat2,cat3}
  return `{${categories.join(',')}}`;
}

/**
 * Get foods suitable for a specific phase and activity type
 */
export async function getFoodsForPhase(
  supabase: SupabaseClient,
  phase: Phase,
  userId: string,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  dislikedFoods: Set<string>,
  activityType: ActivityType = 'running'
): Promise<Food[]> {
  // Get the appropriate categories for this phase and sport
  const categories = getCategoryForPhase(phase, activityType);
  const categoryFilter = buildCategoryFilter(categories);

  console.log(`[FOODS-${phase.toUpperCase()}] Filtering for categories: ${categories.join(', ')}, activity_type: ${activityType}`);

  // STEP 1: Get generic foods for this phase
  // Filter by categories AND activity_types for backwards compatibility
  let genericFoods: any[] = [];
  const { data: foods, error: foodsError } = await supabase
    .from('foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type,
      max_servings_before, max_servings_during, max_servings_after,
      is_electrolyte, to_exclude_from_solver, is_essential,
      categories, activity_types
    `)
    .filter('categories', 'ov', categoryFilter)
    .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);

  if (foodsError) {
    console.log(`[FOODS-${phase.toUpperCase()}] Error fetching generic foods:`, foodsError);
  } else if (foods) {
    genericFoods = foods;
    console.log(`[FOODS-${phase.toUpperCase()}] Found ${genericFoods.length} generic foods for ${activityType}`);
  }

  // STEP 2: Get user foods for this phase
  let userFoods: any[] = [];
  console.log(`[FOODS-${phase.toUpperCase()}] Querying user foods for user_id: ${userId}`);

  const { data: categoryUserFoods, error: userFoodsError } = await supabase
    .from('user_foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type,
      is_electrolyte, to_exclude_from_solver, is_deleted,
      categories, activity_types
    `)
    .eq('user_id', userId)
    .eq('is_deleted', false)
    .filter('categories', 'ov', categoryFilter)
    .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);

  if (userFoodsError) {
    console.log(`[FOODS-${phase.toUpperCase()}] Error fetching categorized user foods:`, userFoodsError);
  } else if (categoryUserFoods) {
    userFoods = userFoods.concat(categoryUserFoods);
  }

  // Get user foods WITHOUT category assignments (empty array = available for all phases)
  const { data: uncategorizedUserFoods, error: uncatError } = await supabase
    .from('user_foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, product_type,
      is_electrolyte, to_exclude_from_solver, is_deleted,
      categories, activity_types
    `)
    .eq('user_id', userId)
    .eq('is_deleted', false)
    .or(`categories.eq.{},categories.is.null`)
    .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);

  if (uncatError) {
    console.log(`[FOODS-${phase.toUpperCase()}] Error fetching uncategorized user foods:`, uncatError);
  } else if (uncategorizedUserFoods) {
    const categorizedUserFoodIds = new Set(userFoods.map((f) => f.id));
    const filteredUncategorized = uncategorizedUserFoods.filter((f) => !categorizedUserFoodIds.has(f.id));
    userFoods = userFoods.concat(filteredUncategorized);
    console.log(`[FOODS-${phase.toUpperCase()}] Found ${filteredUncategorized.length} uncategorized user foods (${userFoods.length} total user foods)`);
  }

  // STEP 3: Combine generic and user foods
  const allFoodsMap = new Map<string, any>();

  const addFoods = (list: any[], isUserFood = false) => {
    if (!list) return;
    for (const food of list) {
      if (!allFoodsMap.has(food.id)) {
        allFoodsMap.set(food.id, { ...food, _isUserFood: isUserFood });
      }
    }
  };

  addFoods(genericFoods, false);
  addFoods(userFoods, true);

  const allFoods = Array.from(allFoodsMap.values());
  const userFoodCount = allFoods.filter((f) => f._isUserFood).length;
  console.log(`[FOODS-${phase.toUpperCase()}] Combined ${genericFoods.length} generic + ${userFoods.length} user foods = ${allFoods.length} total (${userFoodCount} marked as user foods)`);

  if (allFoods.length === 0) return [];

  // STEP 4: Filter and transform foods
  return allFoods
    .filter((f) => {
      const isUserFood = f._isUserFood === true;
      const isDisliked = matchesPreference(f, dislikedFoods);
      const isExcludedFromSolver = f.to_exclude_from_solver === true;

      // CRITICAL: Never filter out user foods as disliked
      if (isDisliked && !isUserFood) {
        console.log(`[FILTER-DISLIKED] Excluding disliked food: ${f.name} (id: ${f.id})`);
        return false;
      }

      if (isDisliked && isUserFood) {
        console.log(`[FILTER-DISLIKED] Keeping user food despite dislike match: ${f.name} (id: ${f.id})`);
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

      // Get max_servings from legacy columns or use default
      const maxServings = getMaxServings(f, phase);

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
        max_servings: maxServings,
        preference_score,
        is_electrolyte: f.is_electrolyte || false,
        is_essential: f.is_essential || false,
        is_user_food: isUserFood,
      };
    });
}

/**
 * Get max servings for a food based on phase
 * Uses max_servings_before/during/after columns with fallback to default
 */
function getMaxServings(food: any, phase: Phase): number {
  switch (phase) {
    case 'before':
      return food.max_servings_before ?? DEFAULT_MAX_SERVINGS;
    case 'during':
      return food.max_servings_during ?? DEFAULT_MAX_SERVINGS;
    case 'after':
      return food.max_servings_after ?? DEFAULT_MAX_SERVINGS;
  }
}

/**
 * Get electrolyte foods for post-processing
 */
export async function getElectrolyteFoods(
  supabase: SupabaseClient,
  userId: string,
  likedFoods: Set<string>,
  willTryFoods: Set<string>,
  activityType: ActivityType = 'running',
  phase: Phase = 'during'
): Promise<Food[]> {
  // Get generic electrolyte foods
  const { data: genericElectrolytes, error: genericError } = await supabase
    .from('foods')
    .select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml_per_serving,
      serving_amount,
      is_electrolyte, to_exclude_from_solver, is_essential
    `)
    .eq('is_electrolyte', true);

  if (genericError) {
    console.log('[ELECTROLYTES] Error fetching generic electrolytes:', genericError);
  }

  // Get user electrolyte foods
  console.log(`[ELECTROLYTES] Querying user electrolytes for user_id: ${userId}`);
  const { data: userElectrolytes, error: userElectrolyteError } = await supabase
    .from('user_foods')
    .select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml_per_serving,
      serving_amount,
      is_electrolyte, to_exclude_from_solver, is_deleted
    `)
    .eq('user_id', userId)
    .eq('is_electrolyte', true)
    .eq('is_deleted', false);

  if (userElectrolyteError) {
    console.log('[ELECTROLYTES] Error fetching user electrolytes:', userElectrolyteError);
  }

  const allElectrolytes = [...(genericElectrolytes || []), ...(userElectrolytes || [])];
  console.log(`[ELECTROLYTES] Found ${genericElectrolytes?.length || 0} generic + ${userElectrolytes?.length || 0} user electrolytes = ${allElectrolytes.length} total`);

  if (allElectrolytes.length === 0) return [];

  return allElectrolytes
    .filter((e) => {
      const isGenericFood = 'is_essential' in e;
      const isEssential = isGenericFood && e.is_essential === true;

      if (isEssential) {
        console.log(`[ELECTROLYTE] Including essential electrolyte: ${e.name}`);
        return true;
      }

      const isLiked = matchesPreference(e, likedFoods);
      const isWillingToTry = matchesPreference(e, willTryFoods);

      if (isLiked || isWillingToTry) {
        console.log(`[ELECTROLYTE] Including electrolyte: ${e.name} (liked: ${isLiked}, willing: ${isWillingToTry})`);
        return true;
      }

      return false;
    })
    .map((e): Food => {
      return {
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
          calories: 0,
        },
        serving_amount: e.serving_amount,
        max_servings: DEFAULT_MAX_SERVINGS,
        preference_score: 50,
        is_electrolyte: true,
        is_essential: 'is_essential' in e ? e.is_essential : false,
        is_user_food: false,
      };
    });
}

/**
 * Get essential foods (water, salt) for post-processing
 */
export async function getEssentialFoods(
  supabase: SupabaseClient,
  activityType: ActivityType = 'running',
  phase: Phase = 'during'
): Promise<Food[]> {
  const { data: essentialFoods, error } = await supabase
    .from('foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, is_electrolyte, is_essential
    `)
    .eq('is_essential', true);

  if (error) {
    console.log('[ESSENTIAL] Error fetching essential foods:', error);
    return [];
  }

  return (essentialFoods || []).map((f): Food => {
    // Essential foods get higher default max_servings (10 for things like water)
    return {
      id: f.id,
      name: f.name,
      display_name: f.display_name,
      display_name_plural: f.display_name_plural,
      description: f.description,
      image_address: f.image_address,
      per_serving: {
        calories: f.calories_per_serving || 0,
        carbs_g: f.carbs_per_serving || 0,
        protein_g: f.protein_per_serving || 0,
        fat_g: f.fat_per_serving || 0,
        sodium_mg: f.sodium_mg || 0,
        water_ml: f.fluid_ml_per_serving || 0,
      },
      serving_amount: f.serving_amount,
      max_servings: 10, // Higher limit for essential foods like water
      preference_score: 50,
      is_essential: true,
      is_electrolyte: f.is_electrolyte || false,
      is_user_food: false,
    };
  });
}
