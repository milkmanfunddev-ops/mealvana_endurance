/**
 * Get Foods Edge Function
 *
 * Returns foods filtered by category with essential foods always included.
 * Queries template_foods table (single source of truth for food data).
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';

// Columns to select from template_foods (avoids SELECT *)
const TEMPLATE_FOODS_COLUMNS = `
  id,
  name,
  display_name,
  display_name_plural,
  image_address,
  description,
  serving_amount,
  serving_size,
  serving_unit,
  serving_qualifier,
  max_servings_before,
  max_servings_during,
  max_servings_after,
  carbs_g,
  protein_g,
  fat_g,
  calories,
  fluid_ml,
  sodium_mg,
  caffeine_mg,
  potassium_mg,
  product_type,
  categories,
  show_in_preferences,
  is_essential,
  is_electrolyte,
  to_exclude_from_solver,
  requires_preparation,
  is_active,
  created_at
`;

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

    const categoryName = category; // 'before_run', 'during_run', 'after_run'

    let categorizedFoods: any[] = [];
    let essentialFoods: any[] = [];

    if (categoryName) {
      // Get foods assigned to this specific category using array contains
      const { data, error } = await supabaseClient
        .from('template_foods')
        .select(TEMPLATE_FOODS_COLUMNS)
        .eq('is_active', true)
        .filter('categories', 'cs', `{${categoryName}}`);

      if (error) throw error;
      categorizedFoods = data || [];
    } else {
      // Get ALL active foods with categories (non-empty array)
      const { data, error } = await supabaseClient
        .from('template_foods')
        .select(TEMPLATE_FOODS_COLUMNS)
        .eq('is_active', true)
        .not('categories', 'eq', '{}');

      if (error) throw error;
      categorizedFoods = data || [];
    }

    // Always get essential foods (Water, Salt, etc.) - available in all phases
    const { data: essentialData, error: essentialError } = await supabaseClient
      .from('template_foods')
      .select(TEMPLATE_FOODS_COLUMNS)
      .eq('is_essential', true)
      .eq('is_active', true);

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

    // Format the response — map template_foods columns to the expected response shape
    const formattedFoods = foods.map((food) => ({
      id: food.id,
      name: food.name,
      display_name: food.display_name,
      display_name_plural: food.display_name_plural,
      image_address: food.image_address,
      description: food.description ?? null,
      instructions: null, // template_foods doesn't have instructions
      categories: food.categories || [],
      // Map template_foods column names → response shape expected by Flutter client
      carbs_per_serving: food.carbs_g || 0,
      sodium_mg: food.sodium_mg || 0,
      fluid_ml_per_serving: food.fluid_ml || 0,
      calories_per_serving: food.calories || 0,
      protein_per_serving: food.protein_g || 0,
      fat_per_serving: food.fat_g || 0,
      serving_amount: food.serving_amount || 1.0,
      serving_size: food.serving_size || null,
      serving_unit: food.serving_unit || null,
      serving_qualifier: food.serving_qualifier || null,
      // Suitability derived from categories array
      before_run_suitable: (food.categories || []).includes('before_run'),
      during_run_suitable: (food.categories || []).includes('during_run'),
      run_portable: true, // template_foods doesn't track this; default true
      requires_preparation: food.requires_preparation ?? false,
      aid_station_available: false, // template_foods doesn't track this
      max_servings_before: food.max_servings_before,
      max_servings_during: food.max_servings_during,
      caffeine_mg: food.caffeine_mg,
      potassium_mg: food.potassium_mg,
      show_in_preferences: food.show_in_preferences,
      is_electrolyte: food.is_electrolyte,
      to_exclude_from_solver: food.to_exclude_from_solver,
      product_type: food.product_type || null,
      created_at: food.created_at,
    }));

    return jsonResponse({ foods: formattedFoods });
  } catch (error) {
    console.error('Error fetching foods:', error);
    return errorResponse(error instanceof Error ? error.message : 'Unknown error', 400);
  }
});
