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
import { calculatePreWorkoutTargets, selectPreWorkoutFoods } from "./pre-workout.ts";
import { classifyEnvironment } from "../_shared/nutrition/sweat-hydration.ts";

// ============================================================================
// EDGE FUNCTION HANDLER
// ============================================================================

serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const input: MacroInputV4 = await req.json();

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

    // Calculate macros
    if (activityType === "brick") {
      const weightKg = toKg(input.weight, input.weight_unit);
      const [_envMultiplier, envLabel] = classifyEnvironment(
        input.temp_c ?? null,
        input.humidity_pct ?? null,
      );

      const preTargets = calculatePreWorkoutTargets(
        weightKg,
        input.hours_before,
        input.is_fasted,
        input.sweat_sodium,
        envLabel,
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
      );

      const brickMacros = calculateBrickMacrosV4(input, preTargets);
      const brickMacrosWithSelections = {
        ...brickMacros,
        pre_run_selections: preSelections,
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

    const macros = await calculateMacrosV4(input, templates);

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
});
