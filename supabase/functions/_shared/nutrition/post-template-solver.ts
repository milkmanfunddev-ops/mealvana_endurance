/**
 * Post-Phase Template Selector
 *
 * The post-workout window (30–60 min after the session) is a recovery trigger,
 * not a macro-dosing window. ISSN/ACSM treat total daily intake and the
 * 1–2hr follow-up meal as the load-bearing nutrition events. So this selector
 * does NOT solve for carbs / protein / sodium / fluid targets the way the
 * during-phase solver does — it just picks one template the athlete is most
 * likely to actually eat.
 *
 * Algorithm:
 *   1. Filter templates by allergens and dietary exclusions. Skip templates
 *      whose component foods aren't in the available pool (post-filter).
 *   2. Rank by Travel: in_bag > cooler_friendly > home_only.
 *   3. Tie-break by Prep Effort: grab_and_go > assemble > cook.
 *   4. Random pick from whatever's still tied.
 *
 * Quantities come from the template's `default_servings` map — one shared
 * portion across all athletes, no body-size scaling.
 *
 * Source spec: see Notion "Post-Workout Recovery: What Matters in the First Hour".
 */

import { type ActivityType, type Food, type FoodResult } from "./types.ts";
import { buildFoodResult } from "./during-utils.ts";

// ============================================================================
// Types
// ============================================================================

export interface PostWorkoutTemplate {
  id: string;
  template_number: number;
  name: string;
  formula: string;
  portions: string | null;
  activity_types: string[];
  component_food_names: string[];
  component_ratios: Record<string, number> | null;
  default_servings: Record<string, number> | null;
  target_carb_protein_ratio: string | null;
  allergens: string[];
  excluded_diets: string[];
  travel_friendliness: string | null;
  flavor_profile: string | null;
  prep_effort: string | null;
  protein_anchor: string | null;
  carb_sources: string[];
  notes: string | null;
  is_active: boolean;
  selection_priority?: number | null;
}

export interface PostTemplateSolverResult {
  foods: FoodResult[];
  template_id: string;
  template_number: number;
  template_name: string;
  template_formula: string;
  template_portions: string | null;
  protein_anchor: string | null;
  flavor_profile: string | null;
  prep_effort: string | null;
  travel_friendliness: string | null;
}

// ============================================================================
// Ranking Order
// ============================================================================

// Lower index = higher preference. Unknown values sort to the end.
const TRAVEL_ORDER: string[] = ["in_bag", "cooler_friendly", "home_only"];
const PREP_ORDER: string[] = ["grab_and_go", "assemble", "cook"];

function travelRank(value: string | null | undefined): number {
  if (!value) return TRAVEL_ORDER.length;
  const idx = TRAVEL_ORDER.indexOf(value);
  return idx === -1 ? TRAVEL_ORDER.length : idx;
}

function prepRank(value: string | null | undefined): number {
  if (!value) return PREP_ORDER.length;
  const idx = PREP_ORDER.indexOf(value);
  return idx === -1 ? PREP_ORDER.length : idx;
}

// ============================================================================
// Activity Type Mapping
// ============================================================================

function mapActivityTypeForTemplate(activityType: ActivityType): string[] {
  switch (activityType) {
    case "running":
      return ["running"];
    case "cycling":
      return ["cycling"];
    case "swimming":
      return ["swimming"];
    case "triathlon":
    case "duathlon":
    case "multisport":
      return ["running", "cycling", "swimming", "triathlon"];
    case "brick":
      return ["running", "cycling", "swimming", "brick"];
    default:
      return ["running"];
  }
}

// ============================================================================
// Template Selection
// ============================================================================

/**
 * Filter and rank templates for the athlete. Returns the templates in priority
 * order — caller can pick `[0]` or sample from a top-N if it needs variety.
 *
 * The ranking is strictly deterministic per (travel, prep). A `random` source
 * is used only to break a final tie between otherwise identical-rank templates,
 * so the same athlete asking on the same day might see a different pick than
 * yesterday but the algorithm itself is reproducible given a seed.
 */
export function selectPostWorkoutTemplateCandidates(
  templates: PostWorkoutTemplate[],
  activityType: ActivityType,
  foodsByName: Map<string, Food>,
  allergies?: string[],
  dietaryPreference?: string,
  random: () => number = Math.random,
): PostWorkoutTemplate[] {
  const mappedActivities = mapActivityTypeForTemplate(activityType);
  const allergiesLower = (allergies ?? []).map((a) => a.toLowerCase());
  const dietPrefLower = dietaryPreference?.toLowerCase() ?? "";

  console.log(
    `[POST-TEMPLATE] Selecting: activity=${activityType} (mapped=${
      mappedActivities.join(",")
    }), diet=${dietaryPreference ?? "none"}, allergies=${
      allergiesLower.join(",") || "none"
    }`,
  );

  // STEP 1 — filter
  const survivors: PostWorkoutTemplate[] = [];
  for (const template of templates) {
    if (!template.is_active) continue;

    // Activity overlap (allow templates with empty activity_types as universal)
    const hasActivityOverlap = template.activity_types.length === 0 ||
      template.activity_types.some((at) => mappedActivities.includes(at));
    if (!hasActivityOverlap) continue;

    // Allergen overlap → skip
    if (allergiesLower.length > 0 && template.allergens.length > 0) {
      const hasAllergen = template.allergens.some((a) =>
        allergiesLower.includes(a.toLowerCase())
      );
      if (hasAllergen) {
        console.log(
          `[POST-TEMPLATE] Skip ${template.template_number} (${template.name}): allergen conflict`,
        );
        continue;
      }
    }

    // Dietary exclusion → skip
    if (dietPrefLower && template.excluded_diets.length > 0) {
      const dietExcluded = template.excluded_diets.some((d) =>
        d.toLowerCase() === dietPrefLower
      );
      if (dietExcluded) {
        console.log(
          `[POST-TEMPLATE] Skip ${template.template_number} (${template.name}): diet exclusion (${dietaryPreference})`,
        );
        continue;
      }
    }

    // All component foods must be in the available pool, or we can't render
    // the template.
    const required = getRequiredFoodNames(template);
    const missing = required.filter((name) => !foodsByName.has(name));
    if (missing.length > 0) {
      console.log(
        `[POST-TEMPLATE] Skip ${template.template_number} (${template.name}): missing foods ${
          missing.join(", ")
        }`,
      );
      continue;
    }

    survivors.push(template);
  }

  if (survivors.length === 0) {
    console.log("[POST-TEMPLATE] No surviving templates");
    return [];
  }

  // STEP 2/3 — sort by travel rank, then prep rank, then template_number as a
  // stable secondary key (so repeated runs are deterministic up to the final
  // random tiebreak).
  survivors.sort((a, b) => {
    const travelDiff = travelRank(a.travel_friendliness) -
      travelRank(b.travel_friendliness);
    if (travelDiff !== 0) return travelDiff;
    const prepDiff = prepRank(a.prep_effort) - prepRank(b.prep_effort);
    if (prepDiff !== 0) return prepDiff;
    return a.template_number - b.template_number;
  });

  // STEP 4 — break the remaining (travel, prep) tie at the top randomly.
  // Find the contiguous block at the front sharing the same (travel, prep),
  // then shuffle that block in place via a single random index swap.
  const topTravel = survivors[0].travel_friendliness;
  const topPrep = survivors[0].prep_effort;
  let tieEnd = 1;
  while (
    tieEnd < survivors.length &&
    survivors[tieEnd].travel_friendliness === topTravel &&
    survivors[tieEnd].prep_effort === topPrep
  ) {
    tieEnd++;
  }
  if (tieEnd > 1) {
    const pick = Math.floor(random() * tieEnd);
    if (pick !== 0) {
      [survivors[0], survivors[pick]] = [survivors[pick], survivors[0]];
    }
    console.log(
      `[POST-TEMPLATE] Random tiebreak across ${tieEnd} templates with travel=${topTravel}, prep=${topPrep}; picked ${survivors[0].template_number} (${survivors[0].name})`,
    );
  } else {
    console.log(
      `[POST-TEMPLATE] Top template: ${survivors[0].template_number} (${survivors[0].name}) travel=${topTravel}, prep=${topPrep}`,
    );
  }

  return survivors;
}

export function selectPostWorkoutTemplate(
  templates: PostWorkoutTemplate[],
  activityType: ActivityType,
  foodsByName: Map<string, Food>,
  allergies?: string[],
  dietaryPreference?: string,
  random: () => number = Math.random,
): PostWorkoutTemplate | null {
  const candidates = selectPostWorkoutTemplateCandidates(
    templates,
    activityType,
    foodsByName,
    allergies,
    dietaryPreference,
    random,
  );
  return candidates[0] ?? null;
}

// ============================================================================
// Portion Rendering
// ============================================================================

/**
 * Build the food list with quantities from `default_servings`. No macro math,
 * no scaling. Each entry is the canonical portion the template was designed
 * around.
 */
export function renderPostTemplatePortion(
  template: PostWorkoutTemplate,
  foodsByName: Map<string, Food>,
): PostTemplateSolverResult | null {
  const servings = template.default_servings ?? {};
  const foodNames = Object.keys(servings).length > 0
    ? Object.keys(servings)
    : template.component_food_names;

  const results: FoodResult[] = [];
  for (const name of foodNames) {
    const food = foodsByName.get(name);
    if (!food) continue;
    const qty = servings[name] ?? 1;
    if (qty <= 0) continue;
    results.push(buildFoodResult(food, qty));
  }

  if (results.length === 0) return null;

  console.log(
    `[POST-TEMPLATE] Rendered template ${template.template_number} (${template.name}): ${
      results.map((f) => `${f.display_name ?? f.food_id} ×${f.quantity}`).join(
        ", ",
      )
    }`,
  );

  return {
    foods: results,
    template_id: template.id,
    template_number: template.template_number,
    template_name: template.name,
    template_formula: template.formula,
    template_portions: template.portions,
    protein_anchor: template.protein_anchor,
    flavor_profile: template.flavor_profile,
    prep_effort: template.prep_effort,
    travel_friendliness: template.travel_friendliness,
  };
}

// ============================================================================
// Helpers
// ============================================================================

function getRequiredFoodNames(template: PostWorkoutTemplate): string[] {
  // Required = whatever default_servings names (the canonical portion). Fall
  // back to component_food_names if default_servings hasn't been populated.
  const fromServings = Object.keys(template.default_servings ?? {});
  if (fromServings.length > 0) return fromServings;
  return template.component_food_names;
}
