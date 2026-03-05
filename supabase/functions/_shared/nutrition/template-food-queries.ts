/**
 * Database queries for food retrieval from template_foods table (v2)
 *
 * This file is the v2 equivalent of food-queries.ts. It queries the
 * unified `template_foods` table instead of the legacy `foods` table.
 *
 * BACKWARDS COMPATIBILITY: food-queries.ts is left untouched for v1.
 * This file is only imported by generate-nutrition-plan-v2.
 *
 * Key differences from food-queries.ts:
 * - Queries `template_foods` table (not `foods`)
 * - Column names: carbs_g (not carbs_per_serving), fluid_ml (not fluid_ml_per_serving)
 * - Uses activityType as 3rd param (not userId — v2 uses device_id, no userId needed)
 * - Still queries user_foods for user-created foods
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { safe } from '../utils.ts';
import type { Food, Phase, ActivityType } from './types.ts';
import { PREFERENCE_SCORE_MAP, DEFAULT_MAX_SERVINGS, getCategoryForPhase } from './constants.ts';
import { matchesPreference, buildPreferenceSet } from './food-utils.ts';

/**
 * Build a Supabase category filter for the given categories
 * Uses the categories array column with overlaps operator
 */
function buildCategoryFilter(categories: string[]): string {
  return `{${categories.join(',')}}`;
}

/**
 * Get max servings for a food based on phase
 * Uses max_servings_before/during/after columns with fallback to default
 */
function getMaxServings(food: Record<string, unknown>, phase: Phase): number {
  switch (phase) {
    case 'before':
      return (food.max_servings_before as number) ?? DEFAULT_MAX_SERVINGS;
    case 'during':
      return (food.max_servings_during as number) ?? DEFAULT_MAX_SERVINGS;
    case 'after':
      return (food.max_servings_after as number) ?? DEFAULT_MAX_SERVINGS;
  }
}

/**
 * Get foods suitable for a specific phase and activity type from template_foods
 *
 * Note: Parameter order differs from food-queries.ts:
 *   food-queries.ts:          (supabase, phase, userId, liked, willing, disliked, activityType)
 *   template-food-queries.ts: (supabase, phase, activityType, liked, willing, disliked, deviceId)
 */
export async function getTemplateFoodsForPhase(
  supabase: SupabaseClient,
  phase: Phase,
  activityType: ActivityType = 'running',
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  allowNonDefaultDuring: boolean = false,
): Promise<Food[]> {
  const likedSet = buildPreferenceSet(likedFoods);
  const willTrySet = buildPreferenceSet(willingToTryFoods);
  const dislikedSet = buildPreferenceSet(dislikedFoods);

  // Get the appropriate categories for this phase and sport
  const categories = getCategoryForPhase(phase, activityType);
  const categoryFilter = buildCategoryFilter(categories);

  console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Filtering template_foods for categories: ${categories.join(', ')}, activity_type: ${activityType}`);

  // STEP 1: Get foods from template_foods table
  let templateFoods: Record<string, unknown>[] = [];
  const selectWithDefaultDuring = `
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      max_servings_before, max_servings_during, max_servings_after,
      min_servings_during,
      is_electrolyte, to_exclude_from_solver, is_essential, is_indivisible,
      categories, activity_types, is_liquid, product_type, default_during
    `;
  const selectWithoutDefaultDuring = `
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      max_servings_before, max_servings_during, max_servings_after,
      is_electrolyte, to_exclude_from_solver, is_essential, is_indivisible,
      categories, activity_types, is_liquid, product_type
    `;

  let foodsData: Record<string, unknown>[] | null = null;
  let foodsError: { message?: string } | null = null;
  {
    const { data, error } = await supabase
      .from('template_foods')
      .select(selectWithDefaultDuring)
      .eq('is_active', true)
      .filter('categories', 'ov', categoryFilter)
      .or(`activity_types.is.null,activity_types.ov.{${activityType}}`);
    foodsData = data as Record<string, unknown>[] | null;
    foodsError = error;
  }

  // Backward compatibility if DB has not yet added default_during.
  if (foodsError && foodsError.message?.includes('default_during')) {
    const fallback = await supabase
      .from('template_foods')
      .select(selectWithoutDefaultDuring)
      .eq('is_active', true)
      .filter('categories', 'ov', categoryFilter)
      .or(`activity_types.is.null,activity_types.ov.{${activityType}}`);
    foodsData = fallback.data as Record<string, unknown>[] | null;
    foodsError = fallback.error;
  }

  if (foodsError) {
    console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Error fetching template foods:`, foodsError);
  } else if (foodsData) {
    templateFoods = foodsData as Record<string, unknown>[];
    console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Found ${templateFoods.length} template foods for ${activityType}`);
  }

  // STEP 2: Get user foods for this phase (same as food-queries.ts)
  let userFoods: Record<string, unknown>[] = [];
  if (deviceId) {
    // Look up user_id from device_id
    const { data: userData } = await supabase
      .from('users')
      .select('id')
      .eq('device_id', deviceId)
      .single();

    const userId = userData?.id;
    if (userId) {
      console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Querying user foods for device_id: ${deviceId} (user_id: ${userId})`);

      const { data: categoryUserFoods, error: userFoodsError } = await supabase
        .from('user_foods')
        .select(`
          id, name, display_name, display_name_plural, image_address, description,
          calories_per_serving, carbs_per_serving, protein_per_serving,
          fat_per_serving, sodium_mg, fluid_ml_per_serving,
          serving_amount, product_type, serving_unit,
          is_electrolyte, to_exclude_from_solver, is_deleted,
          categories, activity_types
        `)
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .filter('categories', 'ov', categoryFilter)
        .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);

      if (userFoodsError) {
        console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Error fetching user foods:`, userFoodsError);
      } else if (categoryUserFoods) {
        userFoods = userFoods.concat(categoryUserFoods);
      }

      // Get uncategorized user foods (empty categories = all phases)
      const { data: uncategorizedUserFoods, error: uncatError } = await supabase
        .from('user_foods')
        .select(`
          id, name, display_name, display_name_plural, image_address, description,
          calories_per_serving, carbs_per_serving, protein_per_serving,
          fat_per_serving, sodium_mg, fluid_ml_per_serving,
          serving_amount, product_type, serving_unit,
          is_electrolyte, to_exclude_from_solver, is_deleted,
          categories, activity_types
        `)
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .or(`categories.eq.{},categories.is.null`)
        .or(`activity_types.is.null,activity_types.cs.{${activityType}}`);

      if (uncatError) {
        console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Error fetching uncategorized user foods:`, uncatError);
      } else if (uncategorizedUserFoods) {
        const categorizedIds = new Set(userFoods.map((f) => f.id));
        const filtered = (uncategorizedUserFoods as Record<string, unknown>[]).filter((f) => !categorizedIds.has(f.id));
        userFoods = userFoods.concat(filtered);
        console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Found ${filtered.length} uncategorized user foods (${userFoods.length} total user foods)`);
      }
    }
  }

  // STEP 3: Combine template_foods and user_foods
  const allFoodsMap = new Map<string, { data: Record<string, unknown>; isUserFood: boolean }>();

  for (const food of templateFoods) {
    allFoodsMap.set(food.id as string, { data: food, isUserFood: false });
  }
  for (const food of userFoods) {
    if (!allFoodsMap.has(food.id as string)) {
      allFoodsMap.set(food.id as string, { data: food, isUserFood: true });
    }
  }

  const allEntries = Array.from(allFoodsMap.values());
  console.log(`[TMPL-FOODS-${phase.toUpperCase()}] Combined ${templateFoods.length} template + ${userFoods.length} user = ${allEntries.length} total`);

  if (allEntries.length === 0) return [];

  // STEP 4: Filter and transform to Food interface
  return allEntries
    .filter(({ data: f, isUserFood }) => {
      const isDisliked = matchesPreference(f as { id?: string; name?: string; display_name?: string | null }, dislikedSet);
      const isExcludedFromSolver = f.to_exclude_from_solver === true;
      const isLiked = matchesPreference(f as { id?: string; name?: string; display_name?: string | null }, likedSet);
      const isWilling = matchesPreference(f as { id?: string; name?: string; display_name?: string | null }, willTrySet);
      const isPreferredDuring = isLiked || isWilling;
      const isDefaultDuring = f.default_during === true;
      const isEssential = f.is_essential === true;

      // Never filter out user foods as disliked
      if (isDisliked && !isUserFood) {
        console.log(`[TMPL-FILTER-DISLIKED] Excluding disliked food: ${f.name} (id: ${f.id})`);
        return false;
      }
      if (isDisliked && isUserFood) {
        console.log(`[TMPL-FILTER-DISLIKED] Keeping user food despite dislike: ${f.name}`);
      }

      // Running during default policy:
      // - include default_during foods
      // - include user-preferred foods (liked/willing_to_try)
      // - include user foods and essentials
      // - optionally include all during foods in fallback mode
      if (phase === 'during' &&
          activityType === 'running' &&
          !allowNonDefaultDuring &&
          !isUserFood &&
          !isEssential &&
          !isPreferredDuring &&
          !isDefaultDuring) {
        return false;
      }

      return !isExcludedFromSolver;
    })
    .map(({ data: f, isUserFood }): Food => {
      const isLiked = isUserFood || matchesPreference(f as { id?: string; name?: string; display_name?: string | null }, likedSet);
      const isWilling = matchesPreference(f as { id?: string; name?: string; display_name?: string | null }, willTrySet);

      let preferenceCategory: 'liked' | 'willing' | 'essential' | 'neutral' = 'neutral';
      if (isLiked) preferenceCategory = 'liked';
      else if (isWilling) preferenceCategory = 'willing';

      const preference_score = PREFERENCE_SCORE_MAP[preferenceCategory];
      const maxServings = getMaxServings(f, phase);

      // Map column names: template_foods uses carbs_g, user_foods uses carbs_per_serving
      const carbsG = isUserFood ? safe(f.carbs_per_serving as number) : safe(f.carbs_g as number);
      const proteinG = isUserFood ? safe(f.protein_per_serving as number) : safe(f.protein_g as number);
      const fatG = isUserFood ? safe(f.fat_per_serving as number) : safe(f.fat_g as number);
      const sodiumMg = safe(f.sodium_mg as number);
      const waterMl = isUserFood ? safe(f.fluid_ml_per_serving as number) : safe(f.fluid_ml as number);
      const calories = isUserFood ? safe(f.calories_per_serving as number) : safe(f.calories as number);

      // min_servings_during defaults to 1.0 for template foods, 0.5 for user foods
      const minServings = isUserFood ? 0.5 : ((f.min_servings_during as number) ?? 1.0);

      return {
        id: f.id as string,
        name: f.name as string,
        display_name: (f.display_name as string) ?? null,
        display_name_plural: (f.display_name_plural as string) ?? null,
        description: (f.description as string) ?? null,
        image_address: (f.image_address as string) ?? null,
        serving_size: (f.serving_size as string) ?? null,
        serving_unit: (f.serving_unit as string) ?? null,
        serving_qualifier: (f.serving_qualifier as string) ?? null,
        per_serving: {
          carbs_g: carbsG,
          protein_g: proteinG,
          fat_g: fatG,
          sodium_mg: sodiumMg,
          water_ml: waterMl,
          calories: calories,
        },
        serving_amount: (f.serving_amount as number) ?? null,
        min_servings: minServings,
        max_servings: maxServings,
        preference_score,
        is_electrolyte: (f.is_electrolyte as boolean) || false,
        is_liquid: isUserFood ? false : ((f.is_liquid as boolean) || false),
        is_essential: (f.is_essential as boolean) || false,
        is_user_food: isUserFood,
        is_indivisible: isUserFood ? false : ((f.is_indivisible as boolean) || false),
        product_type: isUserFood ? ((f.product_type as string) ?? undefined) : ((f.product_type as string) ?? undefined),
      };
    });
}

/**
 * Get electrolyte foods from template_foods for post-processing
 */
export async function getTemplateElectrolyteFoods(
  supabase: SupabaseClient,
  likedFoods?: string[],
  willingToTryFoods?: string[],
): Promise<Food[]> {
  const likedSet = buildPreferenceSet(likedFoods);
  const willTrySet = buildPreferenceSet(willingToTryFoods);

  const { data: electrolytes, error } = await supabase
    .from('template_foods')
    .select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml,
      serving_amount,
      serving_size, serving_unit, serving_qualifier,
      is_electrolyte, to_exclude_from_solver, is_essential
    `)
    .eq('is_active', true)
    .eq('is_electrolyte', true);

  if (error) {
    console.log('[TMPL-ELECTROLYTES] Error fetching electrolytes:', error);
    return [];
  }

  console.log(`[TMPL-ELECTROLYTES] Found ${electrolytes?.length || 0} electrolyte items`);

  return (electrolytes || [])
    .filter((e: Record<string, unknown>) => {
      if (e.is_essential === true) return true;

      const isLiked = matchesPreference(e as { id?: string; name?: string; display_name?: string | null }, likedSet);
      const isWilling = matchesPreference(e as { id?: string; name?: string; display_name?: string | null }, willTrySet);

      return isLiked || isWilling;
    })
    .map((e: Record<string, unknown>): Food => ({
      id: e.id as string,
      name: e.name as string,
      display_name: (e.display_name as string) ?? null,
      display_name_plural: (e.display_name_plural as string) ?? null,
      description: (e.description as string) ?? null,
      image_address: (e.image_address as string) ?? null,
      serving_size: (e.serving_size as string) ?? null,
      serving_unit: (e.serving_unit as string) ?? null,
      serving_qualifier: (e.serving_qualifier as string) ?? null,
      per_serving: {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: safe(e.sodium_mg as number),
        water_ml: safe(e.fluid_ml as number),
        calories: 0,
      },
      serving_amount: (e.serving_amount as number) ?? null,
      min_servings: 1.0,
      max_servings: DEFAULT_MAX_SERVINGS,
      preference_score: 50,
      is_electrolyte: true,
      is_liquid: false,
      is_essential: (e.is_essential as boolean) || false,
      is_user_food: false,
      is_indivisible: true, // electrolyte items (tablets, etc.) are indivisible
    }));
}

/**
 * Get essential foods (water, salt) from template_foods for post-processing
 */
export async function getTemplateEssentialFoods(
  supabase: SupabaseClient,
): Promise<Food[]> {
  const { data: essentialFoods, error } = await supabase
    .from('template_foods')
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      is_electrolyte, is_essential
    `)
    .eq('is_active', true)
    .eq('is_essential', true);

  if (error) {
    console.log('[TMPL-ESSENTIAL] Error fetching essential foods:', error);
    return [];
  }

  return (essentialFoods || []).map((f: Record<string, unknown>): Food => ({
    id: f.id as string,
    name: f.name as string,
    display_name: (f.display_name as string) ?? null,
    display_name_plural: (f.display_name_plural as string) ?? null,
    description: (f.description as string) ?? null,
    image_address: (f.image_address as string) ?? null,
    serving_size: (f.serving_size as string) ?? null,
    serving_unit: (f.serving_unit as string) ?? null,
    serving_qualifier: (f.serving_qualifier as string) ?? null,
    per_serving: {
      calories: safe(f.calories as number),
      carbs_g: safe(f.carbs_g as number),
      protein_g: safe(f.protein_g as number),
      fat_g: safe(f.fat_g as number),
      sodium_mg: safe(f.sodium_mg as number),
      water_ml: safe(f.fluid_ml as number),
    },
    serving_amount: (f.serving_amount as number) ?? null,
    min_servings: 1.0,
    max_servings: 10,
    preference_score: 50,
    is_essential: true,
    is_electrolyte: (f.is_electrolyte as boolean) || false,
    is_liquid: false,
    is_user_food: false,
    is_indivisible: false,
  }));
}
