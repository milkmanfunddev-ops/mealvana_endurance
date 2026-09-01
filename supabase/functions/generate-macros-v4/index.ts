/**
 * generate-macros-v4 Edge Function
 *
 * Algorithm C "Comfort-Capped Hybrid" — extends V3 with:
 * - Range-based targets for ALL pre-workout macros (carbs, protein, sodium, hydration)
 * - Food selection from pre_workout_templates database table
 * - Independent drink + electrolyte selection
 * - Per-phase food recommendations
 *
 * V3 calculations reused: during-workout, post-workout, energy, brick workouts
 *
 * References:
 * - ISSN Position Stand: Nutrient Timing (Kerksick et al. 2017)
 * - Jeukendrup A. (2014). "A Step Towards Personalized Sports Nutrition"
 * - Baker 2017 sweat rate calculations
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { initSentry, withSentry } from "../_shared/sentry.ts";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import {
  errorResponse,
  jsonResponse,
  serverError,
  validationError,
} from "../_shared/responses.ts";
import {
  calculateMacrosV4,
  loadPreWorkoutTemplates,
  toKg,
  type MacroInputV4,
} from "./single-sport.ts";
import { calculateBrickMacrosV4 } from "./brick-workout.ts";
import {
  applyPreWorkoutHydrationOverlay,
  calculatePreWorkoutCarbs,
  calculatePreWorkoutHydration,
  legacyHydrationTier,
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
} from "./pre-workout.ts";
import { classifyEnvironment } from "../_shared/nutrition/sweat-hydration.ts";
import { fetchUserPinnedTemplateIds } from "../_shared/nutrition/pins.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";

// ============================================================================
// EDGE FUNCTION HANDLER
// ============================================================================

// Initialise Sentry once per cold-start. No-op when SENTRY_DSN is not set.
initSentry();

serve(withSentry(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const input: MacroInputV4 = await req.json();

    // Food preferences (liked / disliked) are consumed again as of
    // 2026-07-21 — parity with the 2026-07-08 re-enable that covered the
    // plan function's solvers but never reached this function's Algorithm C.
    // Safe against the failure mode behind the 2026-07-03 rip-out (a stale
    // disliked list collapsing the pool to an empty plan) because Algorithm C
    // now degrades softly: an all-disliked phase redistributes its budget and
    // emits shortfalls (#15), Pass 1.5 universal fallback foods only gate on
    // dislikes + headroom, and liked foods are a scoring boost, never a
    // filter. Diet + allergy remain separate, hard inputs.
    input.liked_foods = input.liked_foods ?? [];
    input.disliked_foods = input.disliked_foods ?? [];

    // Client opt-in for the ephemeral default-formula safety net on the
    // before phase (formula-first flip, plan Phase 2 #5). Threaded to
    // `selectPreWorkoutFoods` so an unpinned before phase can tag its selected
    // system formula as ephemeral. Old clients omit it → byte-identical.
    const emitEphemeralDefault = input.emit_ephemeral_default_formula === true;

    // Validate required fields
    if (!input.weight) return validationError("Missing required field: weight");
    if (!input.hours_before && input.hours_before !== 0) {
      return validationError("Missing required field: hours_before");
    }
    if (input.is_fasted === undefined) {
      return validationError("Missing required field: is_fasted");
    }

    const activityType = input.activity_type || "running";

    // Activity-specific validation (same as V3)
    if (activityType === "running") {
      if (!input.run_distance || !input.run_pace) {
        return validationError(
          "Missing required fields for running: run_distance and run_pace",
        );
      }
    } else if (activityType === "cycling") {
      if (!input.distance_miles || !input.speed_mph) {
        return validationError(
          "Missing required fields for cycling: distance_miles and speed_mph",
        );
      }
    } else if (activityType === "swimming") {
      if (!input.distance_meters || !input.pace_per_100m_seconds) {
        return validationError(
          "Missing required fields for swimming: distance_meters and pace_per_100m_seconds",
        );
      }
    } else if (activityType === "brick") {
      if (!input.brick_segments || !Array.isArray(input.brick_segments)) {
        return validationError(
          "Missing required field for brick: brick_segments array",
        );
      }
      if (input.brick_segments.length < 2 || input.brick_segments.length > 3) {
        return validationError("Brick workouts must have 2-3 segments");
      }
      for (let i = 0; i < input.brick_segments.length; i++) {
        const seg = input.brick_segments[i];
        if (
          !seg.sport || seg.duration_minutes === undefined ||
          seg.duration_minutes === null || seg.duration_minutes <= 0
        ) {
          return validationError(
            `Brick segment ${i} missing required fields: sport and duration_minutes (must be > 0)`,
          );
        }
        const validSports = ["swimming", "cycling", "running"];
        if (!validSports.includes(seg.sport)) {
          return validationError(
            `Brick segment ${i} has invalid sport: ${seg.sport}. Must be swimming, cycling, or running.`,
          );
        }
      }
    } else {
      return errorResponse(
        `Invalid activity_type: ${activityType}. Must be running, cycling, swimming, or brick.`,
      );
    }

    // Load pre-workout templates from database
    const templates = await loadPreWorkoutTemplates();
    console.log(
      `📦 Loaded templates: ${templates.food.length} food, ${templates.drink.length} drink, ${templates.electrolyte.length} electrolyte`,
    );

    // Load the user's active formula pins (before-phase scope). Used to
    // override candidate selection in `selectPreWorkoutFoods`. Empty when
    // device_id is absent or the user has no active pins — yields byte-
    // identical pre-pin behavior. Formula Kit PR 2 substep 5b-followup.
    const supabaseForPins = createServiceClient();
    const userPins = await fetchUserPinnedTemplateIds(
      supabaseForPins,
      input.device_id,
    );

    // Calculate macros
    if (activityType === "brick") {
      const weightKg = toKg(input.weight, input.weight_unit);
      const [_envMultiplier, envLabel] = classifyEnvironment(
        input.temp_c ?? null,
        input.humidity_pct ?? null,
      );

      // Total workout duration is the sum of brick segment durations. It
      // drives both the hydration <60 min gate and the carbohydrate plan band.
      const totalDurationMin = (input.brick_segments ?? []).reduce(
        (sum, s) => sum + (s.duration_minutes ?? 0),
        0,
      );

      const preTargetsLegacy = calculatePreWorkoutTargets(
        weightKg,
        input.hours_before,
        input.is_fasted,
        input.sweat_sodium ?? "average",
        envLabel,
        totalDurationMin,
      );

      // Spec-compliant pre-workout hydration overlay (hydration SSOT v6).
      const preHydrationInput = {
        bodyWeightKg: weightKg,
        workoutDurationMin: totalDurationMin,
        timeBeforeWorkoutMin: input.hours_before * 60,
        tempC: input.temp_c ?? null,
        hydrationCheck: input.hydration_check ?? "unknown",
      };
      const preHydration = calculatePreWorkoutHydration(preHydrationInput);
      // Per-feeding carbohydrate split (carbs SSOT v2) — `tiers` is
      // load-bearing; see single-sport.ts.
      const preCarbPlan = calculatePreWorkoutCarbs({
        bodyWeightKg: weightKg,
        timeBeforeWorkoutMin: input.hours_before * 60,
        workoutDurationMin: totalDurationMin,
        isFasted: input.is_fasted,
      });

      // Apply hydration overlay regardless of is_fasted — fasted only affects
      // carbs/protein/fat, not fluid/sodium. Spec's pre-workout gate is
      // duration-/temp-based, not fasted status.
      const preTargets = applyPreWorkoutHydrationOverlay(
        preTargetsLegacy,
        preHydration,
      );

      const diet = input.diet || "none";
      const preSelections = selectPreWorkoutFoods(
        preTargets,
        input.hours_before,
        diet,
        templates.food,
        templates.drink,
        templates.electrolyte,
        input.liked_foods ?? [],
        input.disliked_foods ?? [],
        input.allergies ?? [],
        userPins.beforePinIds,
        emitEphemeralDefault,
      );

      const brickMacros = calculateBrickMacrosV4(input, preTargets);
      const brickMacrosWithSelections = {
        ...brickMacros,
        pre_run_selections: preSelections,
        // `regime` replaces the integer `pre_run_hydration_tier`, which is
        // still emitted for clients up to 1.22.x (PW-013).
        pre_run_hydration_regime: preHydration.regime,
        pre_run_hydration_tier: legacyHydrationTier(preHydrationInput),
        pre_run_fluid_target_basis: preHydration.target_basis,
        pre_run_hydration_check_used: preHydration.hydration_check_used,
        pre_run_fluid_tiers: preHydration.tiers,
        pre_run_hydration_gate_triggered: preHydration.gate_triggered,
        pre_run_hydration_message: preHydration.message,
        pre_run_carb_target_basis: preCarbPlan.target_basis,
        pre_run_carb_tiers: preCarbPlan.tiers,
      };

      console.log("✅ V4 brick macros calculated successfully:", {
        activity_type: brickMacrosWithSelections.activity_type,
        duration_h: brickMacrosWithSelections.duration_h,
        pre_run_selections: brickMacrosWithSelections.pre_run_selections.length,
        segments: brickMacrosWithSelections.phases.during_segments.length,
        transitions: brickMacrosWithSelections.phases.transitions.length,
      });

      return jsonResponse({ success: true, macros: brickMacrosWithSelections });
    }

    const macros = await calculateMacrosV4(
      input,
      templates,
      userPins.beforePinIds,
      emitEphemeralDefault,
    );

    console.log("✅ V4 macros calculated successfully:", {
      activity_type: macros.activity_type,
      duration_h: macros.duration_h,
      pre_run_carbs_g: macros.pre_run_carbs_g,
      pre_run_selections: macros.pre_run_selections.length,
      during_rate_g_per_h: macros.during_rate_g_per_h,
      during_total_g: macros.during_total_g,
      post_run_carbs_g: macros.post_run_carbs_g,
    });

    return jsonResponse({ success: true, macros });
  } catch (error) {
    console.error("❌ Error in generate-macros-v4:", error);
    return serverError(error);
  }
}));
