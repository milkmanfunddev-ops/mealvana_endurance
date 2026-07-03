/**
 * Database queries for food retrieval (essential foods only).
 *
 * `getFoodsForPhase` and `getElectrolyteFoods` were removed 2026-07-03 — they
 * were dead (no callers in v3); the legacy `foods` table is now only used for
 * water/salt backfill via `getEssentialFoods` on the pin path. See the
 * food/formula/plan architecture audit.
 */

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import type { ActivityType, Food, Phase } from "./types.ts";

/**
 * Get essential foods (water, salt) for post-processing
 */
export async function getEssentialFoods(
  supabase: SupabaseClient,
  activityType: ActivityType = "running",
  phase: Phase = "during",
): Promise<Food[]> {
  const { data: essentialFoods, error } = await supabase
    .from("foods")
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories_per_serving, carbs_per_serving, protein_per_serving,
      fat_per_serving, sodium_mg, fluid_ml_per_serving,
      serving_amount, serving_size, serving_unit, serving_qualifier, is_electrolyte, is_essential
    `)
    .eq("is_essential", true);

  if (error) {
    console.log("[ESSENTIAL] Error fetching essential foods:", error);
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
      serving_size: f.serving_size,
      serving_unit: f.serving_unit,
      serving_qualifier: f.serving_qualifier,
      per_serving: {
        calories: f.calories_per_serving || 0,
        carbs_g: f.carbs_per_serving || 0,
        protein_g: f.protein_per_serving || 0,
        fat_g: f.fat_per_serving || 0,
        sodium_mg: f.sodium_mg || 0,
        water_ml: f.fluid_ml_per_serving || 0,
      },
      serving_amount: f.serving_amount,
      min_servings: 1.0,
      max_servings: 10, // Higher limit for essential foods like water
      preference_score: 50,
      is_essential: true,
      is_electrolyte: f.is_electrolyte || false,
      is_liquid: false,
      is_user_food: false,
      is_indivisible: false,
    };
  });
}
