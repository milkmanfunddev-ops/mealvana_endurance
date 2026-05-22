/**
 * After (post-workout) Phase generation for nutrition plan V3.
 *
 * Post-workout recovery in the 30–60 min window is treated as a trigger, not
 * a macro-dosing event. We pick one template the athlete is most likely to
 * actually eat — no carbs/protein/sodium/fluid solver, no body-size scaling.
 *
 * Flow:
 *   1. Load active post_workout_templates and after-phase template foods.
 *   2. Filter by diet + allergies + food availability.
 *   3. Rank by Travel (in_bag > cooler_friendly > home_only) then Prep
 *      (grab_and_go > assemble > cook). Break remaining ties randomly.
 *   4. Render the canonical portion from the template's default_servings map.
 *
 * If no template fits (rare — all 21 should be reachable for most athletes),
 * fall back to the LP solver so the athlete still gets *something*.
 *
 * Athlete-facing explanation: Notion "Post-Workout Recovery: What Matters in
 * the First Hour".
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import {
  type ActivityType,
  type Food,
  type MacroTargets,
} from "../_shared/nutrition/index.ts";
import {
  buildFoodMap,
  getPostWorkoutTemplates,
  getTemplateFoodsForPhase,
} from "../_shared/nutrition/template-food-queries.ts";
import {
  renderPostTemplatePortion,
  selectPostWorkoutTemplateCandidates,
} from "../_shared/nutrition/post-template-solver.ts";
import type { LPPhaseResult } from "./types.ts";
import { generateLPPhase } from "./lp-phase.ts";

/**
 * Pick + render a post-workout recovery template.
 *
 * `targets` is accepted to keep the function signature aligned with the other
 * phase generators, but it is intentionally NOT used for selection or
 * portioning — see file header.
 */
export async function generateAfterPhase(
  supabase: ReturnType<typeof createServiceClient>,
  targets: MacroTargets,
  activityType: ActivityType,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  deviceId?: string,
  allergies?: string[],
  dietaryPreference?: string,
): Promise<LPPhaseResult> {
  const phaseStart = performance.now();
  const elapsed = (start: number) => Math.round(performance.now() - start);

  console.log(
    `[PLAN-V3] Generating after phase (${activityType}, diet=${
      dietaryPreference ?? "none"
    }, allergies=${(allergies ?? []).join(",") || "none"})`,
  );

  try {
    const queryStart = performance.now();
    const [templates, afterFoods] = await Promise.all([
      getPostWorkoutTemplates(supabase),
      getTemplateFoodsForPhase(
        supabase,
        "after",
        activityType,
        likedFoods,
        willingToTryFoods,
        dislikedFoods,
        deviceId,
        false,
        allergies,
        dietaryPreference,
      ),
    ]);
    console.log(
      `[PLAN-V3-TIMING] after_template_queries completed in ${
        elapsed(queryStart)
      }ms (templates=${templates.length}, foods=${afterFoods.length})`,
    );

    if (templates.length > 0 && afterFoods.length > 0) {
      const selectStart = performance.now();
      const foodsByName: Map<string, Food> = buildFoodMap(afterFoods);

      // No liked/willing/disliked scoring — the new algorithm ranks purely by
      // Travel + Prep + random. (Disliked foods are already excluded upstream
      // in getTemplateFoodsForPhase, so any template whose components depend
      // on a disliked food won't survive the food-availability filter here.)
      const candidates = selectPostWorkoutTemplateCandidates(
        templates,
        activityType,
        foodsByName,
        allergies,
        dietaryPreference,
      );
      console.log(
        `[PLAN-V3-TIMING] after_template_select completed in ${
          elapsed(selectStart)
        }ms (candidates=${candidates.length}, top=${
          candidates[0]?.template_number ?? "none"
        })`,
      );

      if (candidates.length > 0) {
        const renderStart = performance.now();
        const rendered = renderPostTemplatePortion(
          candidates[0],
          foodsByName,
        );
        console.log(
          `[PLAN-V3-TIMING] after_template_render completed in ${
            elapsed(renderStart)
          }ms (result=${rendered ? "success" : "null"})`,
        );

        if (rendered) {
          console.log(
            `[PLAN-V3] Post-workout template selected: ${rendered.template_number} (${rendered.template_name})`,
          );
          console.log(
            `[PLAN-V3-TIMING] after_phase_total completed in ${
              elapsed(phaseStart)
            }ms (path=template)`,
          );
          return {
            foods: rendered.foods,
            by_hour_data: null,
            template_metadata: {
              template_id: rendered.template_id,
              template_number: rendered.template_number,
              template_name: rendered.template_name,
              template_formula: rendered.template_formula,
              template_portions: rendered.template_portions,
              protein_anchor: rendered.protein_anchor,
              flavor_profile: rendered.flavor_profile,
              prep_effort: rendered.prep_effort,
              travel_friendliness: rendered.travel_friendliness,
            },
          };
        }

        console.log(
          "[PLAN-V3] Post-workout template render returned null, falling back to LP",
        );
      } else {
        console.log(
          "[PLAN-V3] No matching post-workout template (diet/allergy/availability filtered everything), falling back to LP",
        );
      }
    } else {
      console.log(
        `[PLAN-V3] Post-workout template path skipped: ${templates.length} templates, ${afterFoods.length} after foods`,
      );
    }
  } catch (err) {
    console.warn(
      "[PLAN-V3] Post-workout template path errored (falling back to LP):",
      err,
    );
  }

  // ---- LP solver (rare fallback for empty filter pool) ----
  const lpStart = performance.now();
  const lpResult = await generateLPPhase(
    supabase,
    "after",
    targets,
    activityType,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    deviceId,
    undefined,
    undefined,
    allergies,
    dietaryPreference,
  );
  console.log(
    `[PLAN-V3-TIMING] after_lp_fallback completed in ${elapsed(lpStart)}ms`,
  );

  console.log(
    `[PLAN-V3-TIMING] after_phase_total completed in ${
      elapsed(phaseStart)
    }ms (path=lp)`,
  );
  return lpResult;
}
