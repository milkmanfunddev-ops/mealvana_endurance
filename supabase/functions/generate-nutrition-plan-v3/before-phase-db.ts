/**
 * Before Phase — Database Queries
 *
 * Fetches pre_workout_templates and template_foods rows for before-phase processing.
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import type { PreWorkoutTemplate } from "../generate-macros-v4/types.ts";

// ============================================================================
// Pre-Workout Templates
// ============================================================================

export async function fetchPreWorkoutTemplates(
  supabase: ReturnType<typeof createServiceClient>,
  templateType: string,
): Promise<PreWorkoutTemplate[]> {
  const { data, error } = await supabase
    .from("pre_workout_templates")
    .select("*")
    .eq("is_active", true)
    .eq("template_type", templateType);

  if (error) {
    throw new Error(
      `Failed to fetch pre_workout_templates (${templateType}): ${error.message}`,
    );
  }

  return (data ?? []).map((row: Record<string, unknown>) => ({
    ...row,
    allergens: row.allergens ?? [],
    excluded_diets: row.excluded_diets ?? [],
  })) as PreWorkoutTemplate[];
}

// ============================================================================
// Template Foods Lookup (for component explosion)
// ============================================================================

export interface TemplateFoodRow {
  name: string;
  display_name: string | null;
  display_name_plural: string | null;
  serving_size: string | null;
  serving_unit: string | null;
  serving_amount: number | null;
  serving_qualifier: string | null;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  is_liquid: boolean;
  is_electrolyte: boolean;
  product_type: string | null;
}

/** Fetches template_foods rows for the given food names (keyed by name). */
export async function fetchTemplateFoodsByName(
  supabase: ReturnType<typeof createServiceClient>,
  names: string[],
): Promise<Map<string, TemplateFoodRow>> {
  if (names.length === 0) return new Map();

  const { data, error } = await supabase
    .from("template_foods")
    .select(
      "name, display_name, display_name_plural, serving_size, serving_unit, serving_amount, serving_qualifier, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml, is_liquid, is_electrolyte, product_type",
    )
    .in("name", names)
    .eq("is_active", true);

  if (error) {
    console.warn(`[PLAN-V3] Failed to fetch template_foods: ${error.message}`);
    return new Map();
  }

  const map = new Map<string, TemplateFoodRow>();
  for (const row of (data ?? [])) {
    map.set(row.name as string, row as TemplateFoodRow);
  }
  return map;
}
