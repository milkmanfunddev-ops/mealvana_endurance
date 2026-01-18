/**
 * Get Foods Edge Function
 *
 * Returns foods filtered by category with essential foods always included.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';

serve(async (req) => {
  // Handle CORS preflight
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    // Use anon key with user's auth for RLS
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: {
            Authorization: req.headers.get('Authorization') ?? '',
          },
        },
      }
    );

    const { category } = await req.json();

    // Map category name to filter value
    const categoryName = category; // 'before_run', 'during_run', 'after_run'

    let categorizedFoods: any[] = [];
    let essentialFoods: any[] = [];

    if (categoryName) {
      // Get foods assigned to this specific category using array contains
      const { data, error } = await supabaseClient
        .from('foods')
        .select('*')
        .filter('categories', 'cs', `{${categoryName}}`);

      if (error) throw error;
      categorizedFoods = data || [];
    } else {
      // Get ALL foods with categories (non-empty array)
      const { data, error } = await supabaseClient
        .from('foods')
        .select('*')
        .not('categories', 'eq', '{}');

      if (error) throw error;
      categorizedFoods = data || [];
    }

    // Always get essential foods (Water, Salt, etc.) - available in all phases
    const { data: essentialData, error: essentialError } = await supabaseClient
      .from('foods')
      .select('*')
      .eq('is_essential', true);

    if (!essentialError && essentialData) {
      essentialFoods = essentialData;
    }

    // Combine and deduplicate foods
    const foodsMap = new Map();
    for (const food of [...categorizedFoods, ...essentialFoods]) {
      if (!foodsMap.has(food.id)) {
        foodsMap.set(food.id, food);
      }
    }
    const foods = Array.from(foodsMap.values());

    // Format the response
    const formattedFoods = foods.map((food) => ({
      id: food.id,
      name: food.name,
      display_name: food.display_name,
      display_name_plural: food.display_name_plural,
      image_address: food.image_address,
      description: food.description,
      instructions: food.instructions,
      categories: food.categories || [],
      carbs_per_serving: food.carbs_per_serving || 0,
      sodium_mg: food.sodium_mg || 0,
      fluid_ml_per_serving: food.fluid_ml_per_serving || 0,
      calories_per_serving: food.calories_per_serving || 0,
      protein_per_serving: food.protein_per_serving || 0,
      fat_per_serving: food.fat_per_serving || 0,
      serving_amount: food.serving_amount || 1.0,
      before_run_suitable: food.before_run_suitable,
      during_run_suitable: food.during_run_suitable,
      run_portable: food.run_portable,
      requires_preparation: food.requires_preparation,
      aid_station_available: food.aid_station_available,
      max_servings_before: food.max_servings_before,
      max_servings_during: food.max_servings_during,
      caffeine_mg: food.caffeine_mg,
      potassium_mg: food.potassium_mg,
      show_in_preferences: food.show_in_preferences,
      is_electrolyte: food.is_electrolyte,
      to_exclude_from_solver: food.to_exclude_from_solver,
      created_at: food.created_at,
    }));

    return jsonResponse({ foods: formattedFoods });
  } catch (error) {
    console.error('Error fetching foods:', error);
    return errorResponse(error instanceof Error ? error.message : 'Unknown error', 400);
  }
});
