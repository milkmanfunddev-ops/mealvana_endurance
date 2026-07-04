/**
 * Types for generate-nutrition-plan-v3
 */

import type { ActivityType, FoodResult, MacroTargets } from "../_shared/nutrition/index.ts";
import type { PreWorkoutPhaseResult } from "../generate-macros-v4/types.ts";

// ============================================================================
// Plan Input
// ============================================================================

export interface PlanInputV2 {
  device_id: string;
  activity_type: string;
  hours_before: number;
  weight_kg: number;
  pre_run_selections?: PreWorkoutPhaseResult[];
  macro_targets: {
    pre_run: MacroTargets & { protein_g?: number; fat_g?: number };
    during_run: MacroTargets;
    post_run: MacroTargets & { protein_g?: number };
    phases?: {
      during_segments?: Array<{
        segment_order?: number;
        sport?: string;
        duration_minutes?: number;
        carbs_g: number;
        carbs_low_g?: number;
        carbs_high_g?: number;
        sodium_mg: number;
        sodium_low_mg?: number;
        sodium_high_mg?: number;
        water_ml: number;
        water_low_ml?: number;
        water_high_ml?: number;
      }>;
      transitions?: Array<{
        transition_name?: string;
        transition_id?: string;
        carbs_g: number;
        carbs_low_g?: number;
        carbs_high_g?: number;
        sodium_mg: number;
        sodium_low_mg?: number;
        sodium_high_mg?: number;
        water_ml: number;
        water_low_ml?: number;
        water_high_ml?: number;
      }>;
    };
  };
  dietary_preference?: string;
  allergies?: string[];
  liked_foods?: string[];
  disliked_foods?: string[];
  willing_to_try_foods?: string[];
  duration_minutes?: number;
  gut_training_level?: "low" | "moderate" | "high";
  brick_segments?: Array<{
    sport: string;
    duration_minutes: number;
    macro_targets: MacroTargets;
  }>;
  brick_phases?: {
    transitions?: Array<{
      transition_name?: string;
      transition_id?: string;
      carbs_g: number;
      carbs_low_g?: number;
      carbs_high_g?: number;
      sodium_mg: number;
      sodium_low_mg?: number;
      sodium_high_mg?: number;
      water_ml: number;
      water_low_ml?: number;
      water_high_ml?: number;
    }>;
  };
  /** Client opt-in for the ephemeral default-formula safety net. When true,
   * the plan tags the selected system formula as an ephemeral pin on
   * `pin_decision` (formula-first flip). Only set by clients that keep
   * ephemeral decisions invisible in the pin banner/analytics; old clients
   * omit it and receive byte-identical pre-safety-net telemetry. 2026-07-03. */
  emit_ephemeral_default_formula?: boolean;
}

// ============================================================================
// Phase Result
// ============================================================================

export interface ByHourTimeSlot {
  hourIndex: number;
  slotIndex: number;
}

export interface ByHourAssignment {
  foodItemId: string;
  timeSlot: ByHourTimeSlot;
  isSipThroughout: boolean;
  adjustedQuantity: number;
  timingCategory: string;
}

export interface ByHourData {
  durationMinutes: number;
  assignments: ByHourAssignment[];
}

export interface TemplateMetadata {
  template_id: string;
  template_number: number;
  template_name: string;
  template_formula: string;
  /** Human-readable portion description (post-workout templates only) */
  template_portions?: string | null;
  /** Notion taxonomy fields (post-workout templates only) */
  protein_anchor?: string | null;
  flavor_profile?: string | null;
  prep_effort?: string | null;
  travel_friendliness?: string | null;
}

/**
 * A macro target the algorithm could not fully satisfy because viable foods
 * were filtered out by the user's preferences (dislikes, allergens, diet
 * exclusions). Surfaced to the UI as a guidance card with curated suggestions
 * the user can swap in. Different from validation failure — the plan is still
 * produced with a partial fill.
 */
export interface PhaseShortfall {
  macro: "carbs" | "sodium" | "fluid" | "protein" | "caffeine";
  delivered: number;
  target: number;
  unit: "g" | "mg" | "ml";
  reason: "all_disliked" | "no_diet_match" | "all_templates_filtered";
}

export interface LPPhaseResult {
  foods: FoodResult[];
  by_hour_data?: ByHourData | null;
  template_metadata?: TemplateMetadata | null;
  /**
   * One entry per macro that fell short of target due to preference filtering.
   * Empty/absent when the plan fully satisfies all targets. Issue #14 / #15.
   */
  shortfalls?: PhaseShortfall[];
  /**
   * Pin honoring telemetry for the during phase. Present only when pins were
   * supplied to the algorithm. `used_pin = true` means the selected during
   * template was driven by a user pin (all preference / diet / gut-training
   * filters bypassed). `fallthrough_reason = 'no_pin_for_scope'` means pins
   * were supplied but none matched this workout's activity × duration scope.
   * Omitted when no pins were supplied. Formula Kit PR 2 substep 5b.
   */
  pin_decision?: {
    used_pin: boolean;
    /** True when `used_pin` was satisfied by the EPHEMERAL default-formula
     * safety net (a best-fit system formula selected at generation time)
     * rather than a real `formula_pins` row. Lets the client distinguish
     * "we picked a formula for you" from "you pinned this" and, if desired,
     * nudge the user to pin it. Absent/false for real pins. Formula-first
     * flip, 2026-07-03 (plan Phase 1 #2). */
    ephemeral?: boolean;
    pinned_template_id: string | null;
    /** Template display name when `used_pin = true`, otherwise null. Lets the
     * client render the pinned formula's label in the activity-detail pin
     * banner without an extra round-trip. Formula Kit PR 2 substep 9. */
    pinned_template_name: string | null;
    /** `no_pin_for_scope` — pins supplied but none matched this scope.
     * `pinned_template_unrenderable` — pin was in scope and selected,
     * but the renderer returned null (e.g. a required component food
     * was missing from the food pool). Option A guard so the wire never
     * claims `used_pin: true` while the section served LP foods. Should
     * be unreachable in practice for After once pinnedComponentNames
     * bypass at food-load is in place (PR 3 #35 fix). Formula Kit PR 3
     * substep 9 follow-up.
     * `personal_formula_empty` — a pinned PERSONAL formula matched this
     * scope but rendered zero components (e.g. an empty/corrupt
     * `components` array), so the section fell through to the normal
     * template solver. Previously this case was silently indistinguishable
     * from "no pin at all" — item 12 (personal formulas silently dropped),
     * 2026-07-04. */
    fallthrough_reason:
      | "no_pin_for_scope"
      | "pinned_template_unrenderable"
      | "personal_formula_empty"
      | null;
    /** Count of in-scope pinned candidates the algorithm saw for this phase.
     * Drives `plan_used_pin` / `plan_pin_fallthrough` analytics. 0 when pins
     * were supplied but none matched scope. Formula Kit PR 2 substep 7. */
    pin_set_size: number;
  };
}
