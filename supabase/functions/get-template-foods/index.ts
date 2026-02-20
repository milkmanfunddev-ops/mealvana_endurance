/**
 * Get Template Foods Edge Function
 *
 * Returns template foods for the food catalog / swap UI.
 * Queries template_foods table (unified food table for v2).
 *
 * BACKWARDS COMPATIBILITY: get-foods (legacy) is left untouched.
 * Old app versions continue using get-foods → queries `foods` table.
 * New app versions use this endpoint → queries `template_foods` table.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { handleCors } from '../_shared/cors.ts';
import { jsonResponse, errorResponse } from '../_shared/responses.ts';
import { createServiceClient } from '../_shared/supabase-client.ts';

serve(async (req) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const supabase = createServiceClient();
    const body = await req.json().catch(() => ({}));
    const { category, activity_type } = body as { category?: string; activity_type?: string };

    let categorizedFoods: Record<string, unknown>[] = [];
    let essentialFoods: Record<string, unknown>[] = [];

    if (category) {
      // Get template foods assigned to this category
      const { data, error } = await supabase
        .from('template_foods')
        .select('*')
        .eq('is_active', true)
        .eq('show_in_preferences', true)
        .filter('categories', 'cs', `{${category}}`);

      if (error) throw error;
      categorizedFoods = (data || []) as Record<string, unknown>[];
    } else {
      // Get ALL active, visible template foods
      const { data, error } = await supabase
        .from('template_foods')
        .select('*')
        .eq('is_active', true)
        .eq('show_in_preferences', true);

      if (error) throw error;
      categorizedFoods = (data || []) as Record<string, unknown>[];
    }

    // Always get essential foods (Water, Salt) — available in all phases
    const { data: essentialData, error: essentialError } = await supabase
      .from('template_foods')
      .select('*')
      .eq('is_active', true)
      .eq('is_essential', true);

    if (!essentialError && essentialData) {
      essentialFoods = essentialData as Record<string, unknown>[];
    }

    // Combine and deduplicate
    const foodsMap = new Map<string, Record<string, unknown>>();
    for (const food of [...categorizedFoods, ...essentialFoods]) {
      if (!foodsMap.has(food.id as string)) {
        foodsMap.set(food.id as string, food);
      }
    }
    const foods = Array.from(foodsMap.values());

    // Format response using template_foods column names directly
    const formattedFoods = foods.map((food) => ({
      id: food.id,
      name: food.name,
      display_name: food.display_name,
      display_name_plural: food.display_name_plural,
      image_address: food.image_address,
      description: food.description,
      serving_size: food.serving_size,
      serving_unit: food.serving_unit,
      serving_qualifier: food.serving_qualifier,
      serving_amount: food.serving_amount ?? 1.0,
      serving_weight_g: food.serving_weight_g,
      // Nutrition per serving (template_foods column names)
      calories: food.calories ?? 0,
      carbs_g: Number(food.carbs_g) || 0,
      protein_g: Number(food.protein_g) || 0,
      fat_g: Number(food.fat_g) || 0,
      fiber_g: Number(food.fiber_g) || 0,
      sodium_mg: Number(food.sodium_mg) || 0,
      fluid_ml: Number(food.fluid_ml) || 0,
      // Metadata
      categories: food.categories || [],
      activity_types: food.activity_types || [],
      allergens: food.allergens || [],
      excluded_diets: food.excluded_diets || [],
      product_type: food.product_type,
      digestion_speed: food.digestion_speed,
      // Flags
      is_electrolyte: food.is_electrolyte ?? false,
      is_essential: food.is_essential ?? false,
      is_liquid: food.is_liquid ?? false,
      show_in_preferences: food.show_in_preferences ?? true,
      to_exclude_from_solver: food.to_exclude_from_solver ?? false,
      requires_preparation: food.requires_preparation ?? false,
      // Servings limits
      max_servings_before: food.max_servings_before,
      max_servings_during: food.max_servings_during,
      max_servings_after: food.max_servings_after,
      // Timestamps
      created_at: food.created_at,
    }));

    return jsonResponse({ foods: formattedFoods });
  } catch (error) {
    console.error('Error fetching template foods:', error);
    return errorResponse(error instanceof Error ? error.message : 'Unknown error', 400);
  }
});
