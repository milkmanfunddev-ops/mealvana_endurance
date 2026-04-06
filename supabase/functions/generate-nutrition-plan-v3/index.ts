/**
 * Generate Nutrition Plan V3 Edge Function
 *
 * Algorithm C pre-workout food selection with rule-based during and LP-based after phases.
 *
 * Pre-workout (before) phase:
 * - Algorithm C from generate-macros-v4 (scoring/stacking/drink/electrolyte)
 * - Uses pre_workout_templates table
 * - Transformed to V2's BeforePhaseResult shape
 *
 * During phase:
 * - Rule-based solver with LP fallback
 *
 * After phase:
 * - LP solver with greedy fallback
 *
 * Brick workouts:
 * - Multi-segment with transitions (T1, T2)
 *
 * Module structure:
 * - types.ts: PlanInputV2, LPPhaseResult interfaces
 * - by-hour-apportionment.ts: deprecated server-side by-hour placement
 * - during-phase.ts: rule-based during + electrolyte post-processing
 * - lp-phase.ts: LP solver orchestration (after phase + LP fallback)
 * - validation.ts: phase result validation
 * - brick-handler.ts: brick workout multi-segment handler
 * - before-phase.ts: Algorithm C transformation layer
 */

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { handleCors } from "../_shared/cors.ts";
import {
  errorResponse,
  jsonResponse,
  serverError,
} from "../_shared/responses.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";
import { generateUUID } from "../_shared/utils.ts";
import {
  type ActivityType,
  adjustTargetsForOverrides,
  type FoodResult,
} from "../_shared/nutrition/index.ts";

import type { LPPhaseResult, PlanInputV2 } from "./types.ts";
import { generateBeforePhaseV3 } from "./before-phase.ts";
import { generateDuringPhase } from "./during-phase.ts";
import { generateLPPhase } from "./lp-phase.ts";
import {
  flattenBeforeFoods,
  validatePhaseResultAgainstTargets,
} from "./validation.ts";
import { handleBrickPlan } from "./brick-handler.ts";

// ============================================================================
// Timing Helpers
// ============================================================================

function elapsedMs(start: number): number {
  return Math.round(performance.now() - start);
}

async function timeAsync<T>(
  label: string,
  fn: () => Promise<T>,
): Promise<T> {
  const start = performance.now();
  try {
    const result = await fn();
    console.log(`[PLAN-V3-TIMING] ${label} completed in ${elapsedMs(start)}ms`);
    return result;
  } catch (error) {
    console.warn(
      `[PLAN-V3-TIMING] ${label} failed after ${elapsedMs(start)}ms`,
    );
    throw error;
  }
}

// ============================================================================
// Main Handler
// ============================================================================

serve(async (req) => {
  const requestStart = performance.now();
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  try {
    const parseStart = performance.now();
    const input: PlanInputV2 = await req.json();
    console.log(
      `[PLAN-V3-TIMING] parse_input completed in ${elapsedMs(parseStart)}ms`,
    );

    // Validate required fields
    if (!input.device_id) {
      return errorResponse("Missing device_id", 400);
    }
    if (!input.macro_targets) {
      return errorResponse("Missing macro_targets", 400);
    }
    if (input.hours_before == null || input.hours_before < 0) {
      return errorResponse("Invalid hours_before", 400);
    }

    const supabase = createServiceClient();
    const activityType = (input.activity_type as ActivityType) || "running";
    const planId = generateUUID();

    console.log(
      `[PLAN-V3] Starting plan generation (activity=${activityType}, hours_before=${input.hours_before})`,
    );
    console.log(
      `[PLAN-V3] Full input: pre_run={carbs_g: ${input.macro_targets?.pre_run?.carbs_g}, protein_g: ${input.macro_targets?.pre_run?.protein_g}, water_ml: ${input.macro_targets?.pre_run?.water_ml}, sodium_mg: ${input.macro_targets?.pre_run?.sodium_mg}}, during_run={carbs_g: ${input.macro_targets?.during_run?.carbs_g}, sodium_mg: ${input.macro_targets?.during_run?.sodium_mg}, water_ml: ${input.macro_targets?.during_run?.water_ml}}, post_run={carbs_g: ${input.macro_targets?.post_run?.carbs_g}, protein_g: ${input.macro_targets?.post_run?.protein_g}, sodium_mg: ${input.macro_targets?.post_run?.sodium_mg}, water_ml: ${input.macro_targets?.post_run?.water_ml}}, duration_minutes=${input.duration_minutes}, gut_training_level=${input.gut_training_level}, dietary_preference=${input.dietary_preference}`,
    );

    // Adjust band bounds for user-overridden macros so solvers can reach the target
    if (input.macro_targets.pre_run) {
      input.macro_targets.pre_run = adjustTargetsForOverrides(
        input.macro_targets.pre_run,
      );
    }
    if (input.macro_targets.during_run) {
      input.macro_targets.during_run = adjustTargetsForOverrides(
        input.macro_targets.during_run,
      );
    }
    if (input.macro_targets.post_run) {
      input.macro_targets.post_run = adjustTargetsForOverrides(
        input.macro_targets.post_run,
      );
    }

    // Brick workouts: route to dedicated handler
    if (activityType === "brick") {
      const response = await timeAsync(
        "brick_total",
        () => handleBrickPlan(supabase, input, planId),
      );
      console.log(
        `[PLAN-V3-TIMING] request_total completed in ${
          elapsedMs(requestStart)
        }ms`,
      );
      return response;
    }

    // Generate all phases
    const [beforeResult, duringPhaseResult, afterPhaseResult] = await Promise
      .all([
        // Before: Algorithm C
        timeAsync("before_phase", () => generateBeforePhaseV3(supabase, input)),

        // During: template solver → rule solver → LP fallback
        input.macro_targets.during_run
          ? timeAsync(
            "during_phase",
            () =>
              generateDuringPhase(
                supabase,
                input.macro_targets.during_run,
                activityType,
                input.liked_foods,
                input.willing_to_try_foods,
                input.disliked_foods,
                input.device_id,
                input.allergies,
                input.dietary_preference,
                input.gut_training_level,
                input.duration_minutes,
              ),
          )
          : Promise.resolve({ foods: [] } as LPPhaseResult),

        // After: LP-based
        input.macro_targets.post_run
          ? timeAsync(
            "after_phase",
            () =>
              generateLPPhase(
                supabase,
                "after",
                input.macro_targets.post_run,
                activityType,
                input.liked_foods,
                input.willing_to_try_foods,
                input.disliked_foods,
                input.device_id,
                undefined,
                undefined,
                input.allergies,
                input.dietary_preference,
              ),
          )
          : Promise.resolve({ foods: [] } as LPPhaseResult),
      ]);

    // Validate phases (non-fatal warnings)
    const validationStart = performance.now();
    const warnings: string[] = [];

    const beforeValidation = validatePhaseResultAgainstTargets(
      flattenBeforeFoods(
        beforeResult as Record<string, { foods?: FoodResult[] }>,
      ),
      input.macro_targets.pre_run,
      "before",
    );
    if (!beforeValidation.ok) {
      console.warn(
        `[PLAN-V3] Before phase out of range (non-fatal): ${
          beforeValidation.issues.join("; ")
        }`,
      );
      warnings.push(...beforeValidation.issues);
    }

    if (input.macro_targets.during_run) {
      const duringValidation = validatePhaseResultAgainstTargets(
        duringPhaseResult.foods,
        input.macro_targets.during_run,
        "during",
      );
      if (!duringValidation.ok) {
        console.warn(
          `[PLAN-V3] During phase out of range (non-fatal): ${
            duringValidation.issues.join("; ")
          }`,
        );
        warnings.push(...duringValidation.issues.map((i) => `during: ${i}`));
      }
    }

    if (input.macro_targets.post_run) {
      const afterValidation = validatePhaseResultAgainstTargets(
        afterPhaseResult.foods,
        input.macro_targets.post_run,
        "after",
      );
      if (!afterValidation.ok) {
        console.warn(
          `[PLAN-V3] After phase out of range (non-fatal): ${
            afterValidation.issues.join("; ")
          }`,
        );
        warnings.push(...afterValidation.issues.map((i) => `after: ${i}`));
      }
    }
    console.log(
      `[PLAN-V3-TIMING] validation completed in ${
        elapsedMs(validationStart)
      }ms`,
    );

    // Build response
    const duringResponse: Record<string, unknown> = {
      foods: duringPhaseResult.foods,
      by_hour_data: duringPhaseResult.by_hour_data ?? null,
    };
    if (duringPhaseResult.template_metadata) {
      duringResponse.template_metadata = duringPhaseResult.template_metadata;
    }

    const response: Record<string, unknown> = {
      success: true,
      plan_id: planId,
      plan: {
        before: beforeResult,
        during: duringResponse,
        after: afterPhaseResult.foods,
      },
      macro_targets: {
        ...input.macro_targets,
        activity_type: activityType,
      },
    };
    if (warnings.length > 0) {
      response.warnings = warnings;
    }

    // Log detailed response for debugging
    console.log(
      `[PLAN-V3] Plan result: before_subphases=${
        Object.keys(beforeResult)
      }, during_foods=${duringPhaseResult.foods.length}, after_foods=${afterPhaseResult.foods.length}`,
    );
    if (afterPhaseResult.foods.length > 0) {
      console.log(
        `[PLAN-V3] After-phase foods: ${
          afterPhaseResult.foods.map((f) =>
            `${f.display_name ?? f.food_id}(carbs=${
              f.carbs_grams.toFixed(0)
            },protein=${f.protein_grams.toFixed(0)},qty=${f.quantity})`
          ).join(", ")
        }`,
      );
    }
    console.log(`[PLAN-V3] Plan generated successfully (plan_id=${planId})`);
    console.log(
      `[PLAN-V3-TIMING] request_total completed in ${
        elapsedMs(requestStart)
      }ms`,
    );

    return jsonResponse(response);
  } catch (error) {
    console.error("[PLAN-V3] Error:", error);
    console.warn(
      `[PLAN-V3-TIMING] request_total failed after ${
        elapsedMs(requestStart)
      }ms`,
    );
    return serverError(error, true);
  }
});
