/**
 * During-Phase Template Solver
 *
 * Selects and fills a during-workout template with quantities that satisfy
 * macro targets (carbs, sodium, fluid) while respecting per-hour max unit
 * constraints and product-specific rounding rules.
 *
 * Flow:
 * 1. selectTemplate()      – filter + score templates by activity, duration,
 *                             gut training, allergies, diet, food preferences
 * 2. generateDuringPhaseTemplate() – compute food quantities, enforce
 *                             constraints, fill water + electrolyte gaps
 *
 * Falls back to null when no template matches or quantities fail validation.
 */

import {
  type ActivityType,
  type Food,
  type FoodResult,
  type MacroTargets,
  shouldPrioritizeMacroTarget,
} from "./types.ts";
import { calculateTotals } from "./food-utils.ts";
import { MACRO_CONSTRAINT_RANGES, PREFERENCE_SCORE_MAP } from "./constants.ts";
import {
  buildFoodResult,
  type ElectrolyteBounds,
  fillElectrolytes,
} from "./during-utils.ts";

/**
 * True when the food matches one of the user's disliked food identifiers.
 * Tolerant of either food.id or food.name being the matched key — production
 * uses food.name, tests sometimes use food.id, both are checked.
 */
function isFoodDisliked(
  food: { id?: string | null; name?: string | null },
  dislikedFoods?: Set<string>,
): boolean {
  if (!dislikedFoods || dislikedFoods.size === 0) return false;
  const id = food.id ?? "";
  const name = food.name ?? "";
  return dislikedFoods.has(id) || dislikedFoods.has(name);
}

// ============================================================================
// Types
// ============================================================================

export interface DuringWorkoutTemplate {
  id: string;
  template_number: number;
  name: string;
  formula: string;
  food_form: string;
  activity_types: string[];
  duration_brackets: string[];
  gut_training_levels: string[];
  component_food_names: string[];
  component_carb_ratios: Record<string, number> | null;
  primary_to_secondary_ratio: string | null;
  allergens: string[];
  excluded_diets: string[];
  notes: string | null;
  is_active: boolean;
  selection_priority?: number | null;
}

export interface FoodWithConstraints extends Food {
  max_per_hr_low?: number | null;
  max_per_hr_moderate?: number | null;
  max_per_hr_high?: number | null;
  min_increment?: number | null;
  sodium_top_up_eligible?: boolean | null;
}

/**
 * Macro shortfall reported when the algorithm couldn't fully satisfy a target
 * because viable foods were filtered out by user preferences (dislikes,
 * allergens, diet exclusions). The plan is still produced — the shortfall
 * tells the UI to render a guidance card naming the gap and suggesting
 * alternatives. Different from a true validation failure (returns null).
 */
export interface MacroShortfall {
  macro: "carbs" | "sodium" | "fluid" | "protein" | "caffeine";
  delivered: number;
  target: number;
  unit: "g" | "mg" | "ml";
  reason:
    | "all_disliked"
    | "no_diet_match"
    | "all_templates_filtered"
    | "template_constraint";
}

export interface TemplateSolverResult {
  foods: FoodResult[];
  template_id: string;
  template_number: number;
  template_name: string;
  template_formula: string;
  /** Present when one or more macro targets were not fully met due to
   * preference/diet filtering. Empty/absent on a clean fit. */
  shortfalls?: MacroShortfall[];
}

export type GutTrainingLevel = "low" | "moderate" | "high";

/**
 * Coerce an untrusted gut-training value to a valid {@link GutTrainingLevel}.
 *
 * The client may omit the field (null profile at generation time) or send a
 * legacy invalid literal (`'medium'` shipped in 1.21.1). Both used to disable
 * the whole template/formula tier: a falsy value failed the solver guard, and
 * a truthy-but-invalid one matched no template's `gut_training_levels` and
 * silently fell through to the rule solver (bug 3a3e3fdb, Critical).
 * `moderate` is the physiological middle ground and the long-standing default
 * elsewhere in the engine (brick handler, by-hour apportionment).
 */
export function normalizeGutTrainingLevel(
  level: string | null | undefined,
): GutTrainingLevel {
  return level === "low" || level === "moderate" || level === "high"
    ? level
    : "moderate";
}

// ============================================================================
// Duration Bracket Matching
// ============================================================================

/**
 * Map a duration in minutes to the matching bracket string(s).
 * Brackets: "< 90 min", "90-150 min", "150-240 min", "> 240 min"
 */
function getDurationBracket(durationMinutes: number): string {
  if (durationMinutes < 90) return "< 90 min";
  if (durationMinutes <= 150) return "90-150 min";
  if (durationMinutes <= 240) return "150-240 min";
  return "> 240 min";
}

// ============================================================================
// Activity Type Mapping
// ============================================================================

/**
 * Map the solver's ActivityType to template activity_types values.
 * Templates store: running, cycling, triathlon_bike, triathlon_run, triathlon_transition
 */
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
      // For composite types, match all constituent sports
      return [
        "running",
        "cycling",
        "triathlon_bike",
        "triathlon_run",
        "triathlon_transition",
      ];
    case "brick":
      // Brick segments are called per-segment with mapped types
      return ["running", "cycling", "triathlon_bike", "triathlon_run"];
    default:
      return ["running"];
  }
}

// ============================================================================
// Template Selection
// ============================================================================

/**
 * Select the best template for given parameters.
 *
 * Filtering:
 * 1. activity_types overlap
 * 2. duration_bracket match
 * 3. gut_training_level match
 * 4. is_active
 * 5. allergens not in user allergies
 * 6. excluded_diets not matching user diet
 * 7. All component foods available in foodsByName map
 *
 * Scoring:
 * - +10 for each liked food in component_food_names
 * - -20 for each disliked food in component_food_names
 * - +5 for each willing-to-try food in component_food_names
 * - Ties broken by template_number (lower = simpler = preferred)
 */
/**
 * Returns the subset of `templates` that are active, pinned, AND in scope for
 * the given workout (activity_type × duration_bracket), sorted by
 * template_number. Shared between the pin-override path inside
 * `selectTemplateCandidates` and the `pin_set_size` analytics field surfaced
 * on `pin_decision`. Returns [] when no pins match scope.
 *
 * Formula Kit PR 2 substep 7.
 */
export function filterPinnedTemplatesInScope(
  templates: DuringWorkoutTemplate[],
  activityType: ActivityType,
  durationMinutes: number,
  pinnedTemplateIds: Set<string>,
): DuringWorkoutTemplate[] {
  const mappedActivities = mapActivityTypeForTemplate(activityType);
  const durationBracket = getDurationBracket(durationMinutes);
  return templates
    .filter(
      (t) =>
        t.is_active &&
        pinnedTemplateIds.has(t.id) &&
        t.activity_types.some((at) => mappedActivities.includes(at)) &&
        t.duration_brackets.includes(durationBracket),
    )
    .sort((a, b) => a.template_number - b.template_number);
}

export function selectTemplateCandidates(
  templates: DuringWorkoutTemplate[],
  activityType: ActivityType,
  durationMinutes: number,
  gutTrainingLevel: GutTrainingLevel,
  foodsByName: Map<string, FoodWithConstraints>,
  likedFoods?: Set<string>,
  willingToTryFoods?: Set<string>,
  dislikedFoods?: Set<string>,
  allergies?: string[],
  dietaryPreference?: string,
  /**
   * Set of during_workout_template ids the user has actively pinned. When a
   * pinned template matches the current activity_type × duration_bracket
   * scope, it overrides candidate selection: allergen / diet / gut-training /
   * food-availability / preference filters are all bypassed for this call.
   * Per locked Formula Kit policy (2026-05-21, revised 2026-05-22): in-scope
   * pins are honored unconditionally — pins even bypass gut training.
   * When undefined or empty, behavior is byte-identical to pre-pin v3.
   * Formula Kit PR 2 substep 5a.
   */
  pinnedTemplateIds?: Set<string>,
): DuringWorkoutTemplate[] {
  const mappedActivities = mapActivityTypeForTemplate(activityType);
  const durationBracket = getDurationBracket(durationMinutes);
  const allergiesLower = (allergies ?? []).map((a) => a.toLowerCase());
  const dietPrefLower = dietaryPreference?.toLowerCase() ?? "";

  console.log(
    `[DURING-TEMPLATE] Selecting template: activity=${activityType} (mapped=${
      mappedActivities.join(",")
    }), ` +
      `duration=${durationMinutes}min (bracket=${durationBracket}), gut=${gutTrainingLevel}`,
  );

  // Pin override: when the user has pins matching this workout's scope
  // (activity_type × duration_bracket), they take over candidate selection —
  // bypassing allergen / diet / gut-training / food-availability filters and
  // the preference-score sort. Multiple pinned templates are returned in
  // template_number order so the caller's solver-retry loop tries them
  // deterministically. When zero pins match this scope, we fall through to
  // the normal candidate-selection path (no fallthrough_reason returned here
  // — that's surfaced by the caller).
  if (pinnedTemplateIds !== undefined && pinnedTemplateIds.size > 0) {
    const pinnedInScope = filterPinnedTemplatesInScope(
      templates,
      activityType,
      durationMinutes,
      pinnedTemplateIds,
    );
    if (pinnedInScope.length > 0) {
      console.log(
        `[DURING-TEMPLATE] Pin override active: ${pinnedInScope.length} pinned template(s) in scope ` +
          `(activity=${activityType}, duration=${durationBracket}), bypassing all filters`,
      );
      return pinnedInScope;
    }
  }

  type ScoredTemplate = { template: DuringWorkoutTemplate; score: number };
  const candidates: ScoredTemplate[] = [];

  for (const template of templates) {
    if (!template.is_active) continue;

    // Activity type overlap
    const hasActivityOverlap = template.activity_types.some(
      (at) => mappedActivities.includes(at),
    );
    if (!hasActivityOverlap) continue;

    // Duration bracket
    if (!template.duration_brackets.includes(durationBracket)) continue;

    // Gut training level
    if (!template.gut_training_levels.includes(gutTrainingLevel)) continue;

    // Allergens: if user has allergies, skip templates with overlapping allergens
    if (allergiesLower.length > 0 && template.allergens.length > 0) {
      const hasAllergen = template.allergens.some(
        (a) => allergiesLower.includes(a.toLowerCase()),
      );
      if (hasAllergen) {
        console.log(
          `[DURING-TEMPLATE] Skipping template ${template.template_number} (${template.name}): allergen conflict`,
        );
        continue;
      }
    }

    // Dietary preference: skip templates with excluded_diets matching user diet
    if (dietPrefLower && template.excluded_diets.length > 0) {
      const isDietExcluded = template.excluded_diets.some(
        (d) => d.toLowerCase() === dietPrefLower,
      );
      if (isDietExcluded) {
        console.log(
          `[DURING-TEMPLATE] Skipping template ${template.template_number} (${template.name}): diet exclusion (${dietaryPreference})`,
        );
        continue;
      }
    }

    // Component food availability: all carb-contributing foods must be in the pool.
    // Water and electrolytes are added separately, so skip them in the check.
    const carbRatios = template.component_carb_ratios ?? {};
    const carbFoodNames = Object.keys(carbRatios);
    const missingFoods = carbFoodNames.filter((name) => !foodsByName.has(name));
    if (missingFoods.length > 0) {
      console.log(
        `[DURING-TEMPLATE] Skipping template ${template.template_number} (${template.name}): missing foods: ${
          missingFoods.join(", ")
        }`,
      );
      continue;
    }

    // Score by catalog priority and food preferences.
    let score = template.selection_priority ?? 0;
    for (const foodName of template.component_food_names) {
      const food = foodsByName.get(foodName);
      if (!food) continue;

      // Check if this food is liked, willing, or disliked by the user
      const foodId = food.id;
      const nameLC = food.name.toLowerCase();
      const displayLC = food.display_name?.toLowerCase() ?? "";

      const isLiked = likedFoods && (
        likedFoods.has(foodId) || likedFoods.has(food.name) ||
        likedFoods.has(nameLC) || likedFoods.has(displayLC)
      );
      const isWilling = willingToTryFoods && (
        willingToTryFoods.has(foodId) || willingToTryFoods.has(food.name) ||
        willingToTryFoods.has(nameLC) || willingToTryFoods.has(displayLC)
      );
      const isDisliked = dislikedFoods && (
        dislikedFoods.has(foodId) || dislikedFoods.has(food.name) ||
        dislikedFoods.has(nameLC) || dislikedFoods.has(displayLC)
      );

      if (isLiked) score += 10;
      else if (isWilling) score += 5;
      else if (isDisliked) score -= 20;
    }

    candidates.push({ template, score });
  }

  if (candidates.length === 0) {
    console.log("[DURING-TEMPLATE] No matching templates found");
    return [];
  }

  // Sort: highest score first, then by template_number (lower = simpler)
  candidates.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.template.template_number - b.template.template_number;
  });

  const selected = candidates[0];
  console.log(
    `[DURING-TEMPLATE] Selected template ${selected.template.template_number} (${selected.template.name}) ` +
      `score=${selected.score}, ${candidates.length} candidates`,
  );

  return candidates.map((candidate) => candidate.template);
}

export function selectTemplate(
  templates: DuringWorkoutTemplate[],
  activityType: ActivityType,
  durationMinutes: number,
  gutTrainingLevel: GutTrainingLevel,
  foodsByName: Map<string, FoodWithConstraints>,
  likedFoods?: Set<string>,
  willingToTryFoods?: Set<string>,
  dislikedFoods?: Set<string>,
  allergies?: string[],
  dietaryPreference?: string,
): DuringWorkoutTemplate | null {
  const candidates = selectTemplateCandidates(
    templates,
    activityType,
    durationMinutes,
    gutTrainingLevel,
    foodsByName,
    likedFoods,
    willingToTryFoods,
    dislikedFoods,
    allergies,
    dietaryPreference,
  );
  return candidates[0] ?? null;
}

// ============================================================================
// Constraint Helpers
// ============================================================================

/**
 * Get the max servings per hour for a food at a given gut training level.
 */
function getMaxPerHour(
  food: FoodWithConstraints,
  gutLevel: GutTrainingLevel,
): number | null {
  switch (gutLevel) {
    case "low":
      return food.max_per_hr_low ?? null;
    case "moderate":
      return food.max_per_hr_moderate ?? null;
    case "high":
      return food.max_per_hr_high ?? null;
  }
}

/**
 * Round servings to the food's min_increment (from DB constraints).
 * Falls back to the food's is_indivisible flag if no min_increment set.
 */
function roundToFoodIncrement(
  servings: number,
  food: FoodWithConstraints,
): number {
  if (servings <= 0) return 0;
  const increment = food.min_increment ?? (food.is_indivisible ? 1 : 0.5);
  return Math.round(servings / increment) * increment;
}

function roundUpToFoodIncrement(
  servings: number,
  food: FoodWithConstraints,
): number {
  if (servings <= 0) return 0;
  const increment = food.min_increment ?? (food.is_indivisible ? 1 : 0.5);
  return Math.ceil((servings - 1e-9) / increment) * increment;
}

/**
 * Clamp servings to [min, max] and round to food's min_increment.
 */
function clampAndRound(
  servings: number,
  food: FoodWithConstraints,
  maxServings = food.max_servings,
  enforceMin = true,
): number {
  const lowerBound = enforceMin ? food.min_servings : 0;
  const upperBound = Math.min(food.max_servings, maxServings);
  if (servings <= 0 || upperBound <= 0 || upperBound < lowerBound) return 0;

  let clamped = Math.max(lowerBound, Math.min(upperBound, servings));
  clamped = roundToFoodIncrement(clamped, food);

  const increment = food.min_increment ?? (food.is_indivisible ? 1 : 0.5);
  if (clamped > upperBound) {
    clamped = Math.floor(upperBound / increment) * increment;
  }
  if (clamped < lowerBound) {
    clamped = upperBound >= lowerBound ? lowerBound : 0;
  }

  return Math.max(0, Math.min(upperBound, clamped));
}

export function maxAllowedServingsForDuration(
  food: FoodWithConstraints,
  durationHours: number,
  gutTrainingLevel: GutTrainingLevel,
): number {
  let maxAllowedServings = food.max_servings;
  const maxPerHr = getMaxPerHour(food, gutTrainingLevel);
  if (maxPerHr !== null && maxPerHr >= 0) {
    maxAllowedServings = Math.min(
      maxAllowedServings,
      maxPerHr * durationHours,
    );
  }
  return Math.max(0, maxAllowedServings);
}

function servingCandidatesForFood(
  food: FoodWithConstraints,
  maxAllowedServings: number,
): number[] {
  const upperBound = Math.min(food.max_servings, maxAllowedServings);
  if (upperBound <= 0) return [0];

  const increment = food.min_increment ?? (food.is_indivisible ? 1 : 0.5);
  const values = new Set<number>([0]);
  for (
    let servings = food.min_servings;
    servings <= upperBound + 1e-9;
    servings += increment
  ) {
    const rounded = Math.round(servings / increment) * increment;
    if (rounded <= upperBound + 1e-9) {
      values.add(Number(rounded.toFixed(4)));
    }
  }

  return [...values].sort((a, b) => a - b);
}

export function addOrUpdateFoodResult(
  foods: FoodResult[],
  food: FoodWithConstraints,
  servings: number,
) {
  if (servings <= 0) return;

  const existing = foods.find((r) => r.food_id === food.id);
  if (!existing) {
    foods.push(buildFoodResult(food, servings));
    return;
  }

  const newQuantity = existing.quantity + servings;
  const updated = buildFoodResult(food, newQuantity);
  Object.assign(existing, updated);
}

function validateDuringTotals(
  totals: ReturnType<typeof calculateTotals>,
  targets: MacroTargets,
): string[] {
  const duringRanges = {
    carbs: MACRO_CONSTRAINT_RANGES.carbs.during,
    sodium: MACRO_CONSTRAINT_RANGES.sodium.during,
    water: MACRO_CONSTRAINT_RANGES.water.during,
  };
  const validationIssues: string[] = [];

  if (duringRanges.carbs && targets.carbs_g > 0) {
    const ratio = totals.carbs_g / targets.carbs_g;
    if (ratio < duringRanges.carbs.min || ratio > duringRanges.carbs.max) {
      validationIssues.push(
        `carbs ${(ratio * 100).toFixed(0)}% (${
          totals.carbs_g.toFixed(0)
        }g/${targets.carbs_g}g)`,
      );
    }
  }
  if (duringRanges.sodium && targets.sodium_mg > 0) {
    const ratio = totals.sodium_mg / targets.sodium_mg;
    if (ratio < duringRanges.sodium.min || ratio > duringRanges.sodium.max) {
      validationIssues.push(
        `sodium ${(ratio * 100).toFixed(0)}% (${
          totals.sodium_mg.toFixed(0)
        }mg/${targets.sodium_mg}mg)`,
      );
    }
  }
  if (duringRanges.water && targets.water_ml > 0) {
    const ratio = totals.water_ml / targets.water_ml;
    if (ratio < duringRanges.water.min || ratio > duringRanges.water.max) {
      validationIssues.push(
        `water ${(ratio * 100).toFixed(0)}% (${
          totals.water_ml.toFixed(0)
        }ml/${targets.water_ml}ml)`,
      );
    }
  }

  return validationIssues;
}

function scoreTotals(
  totals: ReturnType<typeof calculateTotals>,
  targets: MacroTargets,
): number {
  const metricScore = (
    actual: number,
    target: number,
    weight: number,
    low?: number | null,
    high?: number | null,
  ): number => {
    if (target <= 0) return actual > 0 ? actual * weight : 0;
    const ratio = actual / target;
    const deviation = Math.abs(1 - ratio);
    // "Outside" is the REAL calculated range when the targets carry one; the
    // 0.9/1.1 band is only the fallback for callers that pass no range. The
    // squared-deviation term still drives toward the point target inside it.
    const lowRatio = low != null && low > 0 ? low / target : 0.9;
    const highRatio = high != null && high > 0 ? high / target : 1.1;
    const outsidePenalty = ratio < lowRatio || ratio > highRatio ? 10 : 0;
    const overPenalty = ratio > highRatio ? 4 : 0;
    return (deviation * deviation * 100 + outsidePenalty + overPenalty) *
      weight;
  };

  return metricScore(
      totals.carbs_g,
      targets.carbs_g,
      4,
      targets.carbs_low_g,
      targets.carbs_high_g,
    ) +
    metricScore(
      totals.sodium_mg,
      targets.sodium_mg,
      2,
      targets.sodium_low_mg,
      targets.sodium_high_mg,
    ) +
    metricScore(
      totals.water_ml,
      targets.water_ml,
      1,
      targets.water_low_ml,
      targets.water_high_ml,
    );
}

interface SearchComponent {
  name: string;
  food: FoodWithConstraints;
  values: number[];
}

function isSodiumTopUpFood(food: FoodWithConstraints): boolean {
  if (!food.is_electrolyte || food.per_serving.sodium_mg <= 0) return false;

  if (typeof food.sodium_top_up_eligible === "boolean") {
    return food.sodium_top_up_eligible;
  }

  return food.per_serving.carbs_g <= 5 && food.product_type !== "sports_drink";
}

function generateDuringPhaseTemplateBySearch(
  template: DuringWorkoutTemplate,
  foodsByName: Map<string, FoodWithConstraints>,
  targets: MacroTargets,
  durationMinutes: number,
  gutTrainingLevel: GutTrainingLevel,
  dislikedFoods?: Set<string>,
  // When true, this template was selected by an explicit pin override. A pin
  // must win even when the ingredient's max-per-hour cap prevents fully meeting
  // the macro target — so accept a best-effort result and report the shortfall
  // instead of returning null. Decoupled from dislikedFoods (bug: pinned
  // drink-only formula not scheduled for sub-90-min runs).
  pinOverride?: boolean,
): TemplateSolverResult | null {
  const carbRatios = template.component_carb_ratios ?? {};
  const durationHours = durationMinutes / 60;
  const sodiumTarget = targets.sodium_mg;
  const sodiumLower = targets.sodium_low_mg ??
    (sodiumTarget > 0 ? sodiumTarget * 0.9 : 0);
  const sodiumUpper = targets.sodium_high_mg ??
    (sodiumTarget > 0 ? sodiumTarget * 1.1 : Number.POSITIVE_INFINITY);
  const carbTarget = targets.carbs_g;
  const prioritizeCarbTarget = shouldPrioritizeMacroTarget(targets, "carbs");
  const defaultCarbUpper = carbTarget > 0
    ? carbTarget * (MACRO_CONSTRAINT_RANGES.carbs.during?.max ?? 1.1)
    : Number.POSITIVE_INFINITY;
  const carbUpper = prioritizeCarbTarget
    ? defaultCarbUpper
    : (targets.carbs_high_g ?? defaultCarbUpper);
  const fluidTarget = targets.water_ml;
  const fluidUpper = targets.water_high_ml ??
    (fluidTarget > 0 ? fluidTarget * 1.1 : Number.POSITIVE_INFINITY);
  const isTripleSource = template.primary_to_secondary_ratio === "1:1";

  const components: SearchComponent[] = [];
  let solidFoodName: string | null = null;
  let gelFoodName: string | null = null;

  for (const [foodName] of Object.entries(carbRatios)) {
    const food = foodsByName.get(foodName);
    if (!food || food.per_serving.carbs_g <= 0) continue;

    if (isTripleSource) {
      if (food.product_type === "gel") {
        gelFoodName = foodName;
      } else if (!food.is_liquid) {
        solidFoodName = foodName;
      }
    }

    const maxAllowed = maxAllowedServingsForDuration(
      food,
      durationHours,
      gutTrainingLevel,
    );
    components.push({
      name: foodName,
      food,
      values: servingCandidatesForFood(food, maxAllowed),
    });
  }

  if (components.length === 0 && targets.carbs_g > 0) return null;

  const waterFood = foodsByName.get("water");
  const maxWaterByFluid = waterFood?.per_serving.water_ml
    ? Math.max(0, fluidUpper / waterFood.per_serving.water_ml)
    : 0;
  const waterValues = waterFood && fluidTarget > 0
    ? servingCandidatesForFood(
      waterFood,
      Math.min(waterFood.max_servings, maxWaterByFluid),
    )
    : [0];
  // Sodium top-up pool — exclude disliked items so the fill never silently
  // adds a food the user marked as disliked. If filtering empties the pool we
  // accept the sodium shortfall rather than forcing an unwanted food (issue
  // #14). The macro-shortfall pathway (phase.shortfalls) reports the gap.
  const electrolytePool: FoodWithConstraints[] = [];
  for (const [, food] of foodsByName) {
    if (!isSodiumTopUpFood(food)) continue;
    if (isFoodDisliked(food, dislikedFoods)) continue;
    electrolytePool.push(food);
  }

  let bestFoods: FoodResult[] | null = null;
  let bestScore = Number.POSITIVE_INFINITY;
  let bestIssues: string[] = [];
  const selectedServings: Record<string, number> = {};

  const evaluate = () => {
    if (isTripleSource && solidFoodName && gelFoodName) {
      const solidServings = selectedServings[solidFoodName] ?? 0;
      const gelServings = selectedServings[gelFoodName] ?? 0;
      if (Math.abs(solidServings - gelServings) > 1e-9) return;
    }

    for (const waterServings of waterValues) {
      const resultFoods: FoodResult[] = [];
      for (const component of components) {
        addOrUpdateFoodResult(
          resultFoods,
          component.food,
          selectedServings[component.name] ?? 0,
        );
      }
      if (waterFood) {
        addOrUpdateFoodResult(resultFoods, waterFood, waterServings);
      }

      let totals = calculateTotals(resultFoods);
      if (electrolytePool.length > 0) {
        fillElectrolytes(
          electrolytePool,
          resultFoods,
          totals.sodium_mg,
          totals.water_ml,
          totals.carbs_g,
          {
            sodiumTarget,
            sodiumLower,
            sodiumUpper,
            fluidTarget,
            fluidUpper,
            carbTarget,
            carbUpper,
          },
          null,
        );
        totals = calculateTotals(resultFoods);
      }

      const issues = validateDuringTotals(totals, targets);
      const score = scoreTotals(totals, targets) +
        resultFoods.reduce((sum, food) => sum + food.quantity, 0) * 0.05;

      if (
        issues.length === 0 &&
        (bestIssues.length > 0 || score < bestScore)
      ) {
        bestFoods = resultFoods;
        bestScore = score;
        bestIssues = issues;
      } else if (bestFoods === null || score < bestScore) {
        bestFoods = resultFoods;
        bestScore = score;
        bestIssues = issues;
      }
    }
  };

  const recurse = (index: number) => {
    if (index >= components.length) {
      evaluate();
      return;
    }

    const component = components[index];
    for (const servings of component.values) {
      selectedServings[component.name] = servings;
      recurse(index + 1);
    }
  };
  recurse(0);

  // Accept the best candidate even if macro validation fails when EITHER:
  //  - the user has dislikes (the shortfall is a known consequence of their
  //    preferences, not an algorithmic failure), OR
  //  - this template was pin-selected (an explicit pin must win even if an
  //    ingredient's max-per-hour cap can't fully meet the target).
  // The shortfalls field tells the UI to render guidance instead of silently
  // dropping the phase. Absent both, any validation failure is genuine
  // (template doesn't fit constraints) and should still return null so the
  // next-best template is tried.
  const allowShortfall = (!!dislikedFoods && dislikedFoods.size > 0) ||
    !!pinOverride;

  if (!bestFoods) {
    return null;
  }
  if (bestIssues.length > 0 && !allowShortfall) {
    console.log(
      `[DURING-TEMPLATE-SEARCH] Best candidate failed validation: ${
        bestIssues.join("; ")
      }`,
    );
    return null;
  }

  const totals = calculateTotals(bestFoods);
  console.log(
    `[DURING-TEMPLATE-SEARCH] Selected optimized quantities: ` +
      `carbs=${totals.carbs_g.toFixed(0)}g/${targets.carbs_g}g, ` +
      `sodium=${totals.sodium_mg.toFixed(0)}mg/${targets.sodium_mg}mg, ` +
      `fluid=${totals.water_ml.toFixed(0)}ml/${targets.water_ml}ml`,
  );

  const shortfalls = collectShortfalls(totals, targets, dislikedFoods);

  return {
    foods: bestFoods,
    template_id: template.id,
    template_number: template.template_number,
    template_name: template.name,
    template_formula: template.formula,
    ...(shortfalls.length > 0 && { shortfalls }),
  };
}

/**
 * Compute per-macro shortfalls for a phase result.
 *
 * Emits a shortfall whenever a macro is delivered below the 90% threshold,
 * regardless of whether user dislikes are present. This ensures the client
 * always receives a signal when a phase cannot meet its targets — not just
 * when the cause is preference-driven.
 *
 * The `reason` field indicates the likely cause:
 *   - "all_disliked" : shortfall is traceable to disliked foods in the pool
 *   - "template_constraint" : shortfall is from catalog/template limits
 *     (dislikes not involved or not the primary cause)
 *
 * Threshold: shortfall is emitted when delivered < 90% of target. Above that
 * the gap is small enough to be noise.
 */
export function collectShortfalls(
  totals: { carbs_g: number; sodium_mg: number; water_ml: number },
  targets: MacroTargets,
  dislikedFoods?: Set<string>,
): MacroShortfall[] {
  const out: MacroShortfall[] = [];
  const SHORTFALL_THRESHOLD = 0.9;
  const hasDislikedCause = !!dislikedFoods && dislikedFoods.size > 0;
  // The flag floor is the RANGE LOW when the targets carry one — delivery
  // anywhere inside the acceptable range is not a gap, even when it misses
  // the point target (reported 2026-07-22: sodium inside its range was
  // flagged as a "sodium gap"). The 90%-of-target floor remains only as the
  // fallback for callers that pass no range.
  const sodiumFloor = targets.sodium_low_mg ??
    targets.sodium_mg * SHORTFALL_THRESHOLD;
  if (targets.sodium_mg > 0 && totals.sodium_mg < sodiumFloor) {
    out.push({
      macro: "sodium",
      delivered: Math.round(totals.sodium_mg),
      target: targets.sodium_mg,
      unit: "mg",
      reason: hasDislikedCause ? "all_disliked" : "template_constraint",
    });
  }
  const carbFloor = targets.carbs_low_g ??
    targets.carbs_g * SHORTFALL_THRESHOLD;
  if (targets.carbs_g > 0 && totals.carbs_g < carbFloor) {
    out.push({
      macro: "carbs",
      delivered: Math.round(totals.carbs_g),
      target: targets.carbs_g,
      unit: "g",
      reason: hasDislikedCause ? "all_disliked" : "template_constraint",
    });
  }
  const fluidFloor = targets.water_low_ml ??
    targets.water_ml * SHORTFALL_THRESHOLD;
  if (targets.water_ml > 0 && totals.water_ml < fluidFloor) {
    out.push({
      macro: "fluid",
      delivered: Math.round(totals.water_ml),
      target: targets.water_ml,
      unit: "ml",
      reason: hasDislikedCause ? "all_disliked" : "template_constraint",
    });
  }
  return out;
}

// ============================================================================
// Template Quantity Solver
// ============================================================================

/**
 * Generate during-phase food selection using a template.
 *
 * @param template - The selected template
 * @param foodsByName - Map of food name → FoodWithConstraints
 * @param targets - Macro targets for during phase
 * @param durationMinutes - Activity duration in minutes
 * @param gutTrainingLevel - Athlete gut training level
 * @returns TemplateSolverResult or null if validation fails
 */
export function generateDuringPhaseTemplate(
  template: DuringWorkoutTemplate,
  foodsByName: Map<string, FoodWithConstraints>,
  targets: MacroTargets,
  durationMinutes: number,
  gutTrainingLevel: GutTrainingLevel,
  dislikedFoods?: Set<string>,
  // See generateDuringPhaseTemplateBySearch: a pin-selected template accepts a
  // reported macro shortfall rather than returning null.
  pinOverride?: boolean,
): TemplateSolverResult | null {
  const carbTarget = targets.carbs_g;
  const sodiumTarget = targets.sodium_mg;
  const fluidTarget = targets.water_ml;
  const durationHours = durationMinutes / 60;
  const prioritizeCarbTarget = shouldPrioritizeMacroTarget(targets, "carbs");
  const defaultCarbUpper = carbTarget > 0
    ? carbTarget * (MACRO_CONSTRAINT_RANGES.carbs.during?.max ?? 1.1)
    : Number.POSITIVE_INFINITY;
  const carbUpper = prioritizeCarbTarget
    ? defaultCarbUpper
    : (targets.carbs_high_g ?? defaultCarbUpper);
  const sodiumLower = targets.sodium_low_mg ??
    (sodiumTarget > 0 ? sodiumTarget * 0.9 : 0);
  const sodiumUpper = targets.sodium_high_mg ??
    (sodiumTarget > 0 ? sodiumTarget * 1.1 : Number.POSITIVE_INFINITY);
  const fluidUpper = targets.water_high_ml ??
    (fluidTarget > 0 ? fluidTarget * 1.1 : Number.POSITIVE_INFINITY);

  console.log(
    `[DURING-TEMPLATE] Generating quantities for template ${template.template_number} (${template.name}): ` +
      `carbs=${carbTarget}g, sodium=${sodiumTarget}mg, fluid=${fluidTarget}ml, ` +
      `duration=${durationMinutes}min (${
        durationHours.toFixed(1)
      }hr), gut=${gutTrainingLevel}`,
  );

  const optimizedResult = generateDuringPhaseTemplateBySearch(
    template,
    foodsByName,
    targets,
    durationMinutes,
    gutTrainingLevel,
    dislikedFoods,
    pinOverride,
  );
  if (optimizedResult) {
    return optimizedResult;
  }

  console.log(
    `[DURING-TEMPLATE] Optimized quantity search failed for template ${template.template_number}; trying sequential fill`,
  );

  const carbRatios = template.component_carb_ratios ?? {};
  const isTripleSource = template.primary_to_secondary_ratio === "1:1";
  const resultFoods: FoodResult[] = [];
  let carbsAssigned = 0;
  let sodiumAssigned = 0;
  let fluidAssigned = 0;

  // ---- STEP 1: Compute ideal servings per component from carb ratios ----
  // Identify solid and gel for triple-source 1:1 templates
  let solidFoodName: string | null = null;
  let gelFoodName: string | null = null;

  if (isTripleSource) {
    // Triple-source templates (8, 10, 12, 14): solid + gel + sports_drink
    // The solid is bar/stroopwafel/banana/rice_cake; the gel is energy_gel
    for (const [name] of Object.entries(carbRatios)) {
      const food = foodsByName.get(name);
      if (!food) continue;
      if (food.product_type === "gel") {
        gelFoodName = name;
      } else if (!food.is_liquid) {
        solidFoodName = name;
      }
    }
  }

  // Build the serving plan for carb-contributing foods
  const servingPlan: {
    food: FoodWithConstraints;
    servings: number;
    name: string;
  }[] = [];

  for (const [foodName, ratio] of Object.entries(carbRatios)) {
    const food = foodsByName.get(foodName);
    if (!food || food.per_serving.carbs_g <= 0) continue;

    const carbAllocation = carbTarget * ratio;
    let idealServings = carbAllocation / food.per_serving.carbs_g;
    let maxAllowedServings = food.max_servings;

    // Apply max per hour constraint
    const maxPerHr = getMaxPerHour(food, gutTrainingLevel);
    if (maxPerHr !== null && maxPerHr >= 0) {
      maxAllowedServings = Math.min(
        maxAllowedServings,
        maxPerHr * durationHours,
      );
      if (idealServings > maxAllowedServings) {
        console.log(
          `[DURING-TEMPLATE] Clamping ${foodName} from ${
            idealServings.toFixed(1)
          } to ${maxAllowedServings.toFixed(1)} (max ${maxPerHr}/hr × ${
            durationHours.toFixed(1)
          }hr)`,
        );
      }
    }

    // Clamp to food min/max servings and round to increment
    idealServings = clampAndRound(idealServings, food, maxAllowedServings);

    servingPlan.push({ food, servings: idealServings, name: foodName });
  }

  // ---- STEP 2: Enforce 1:1 ratio for triple-source templates ----
  if (isTripleSource && solidFoodName && gelFoodName) {
    const solidEntry = servingPlan.find((e) => e.name === solidFoodName);
    const gelEntry = servingPlan.find((e) => e.name === gelFoodName);

    if (solidEntry && gelEntry) {
      const solidFood = solidEntry.food;
      const gelFood = gelEntry.food;

      // Binding constraint: min of both max_per_hr
      const solidMaxPerHr = getMaxPerHour(solidFood, gutTrainingLevel);
      const gelMaxPerHr = getMaxPerHour(gelFood, gutTrainingLevel);

      let bindingMax = Infinity;
      if (solidMaxPerHr !== null) {
        bindingMax = Math.min(bindingMax, solidMaxPerHr * durationHours);
      }
      if (gelMaxPerHr !== null) {
        bindingMax = Math.min(bindingMax, gelMaxPerHr * durationHours);
      }
      bindingMax = Math.min(
        bindingMax,
        solidFood.max_servings,
        gelFood.max_servings,
      );

      // Both must have equal unit count, capped at binding max
      let unitCount = Math.min(solidEntry.servings, gelEntry.servings);
      if (Number.isFinite(bindingMax)) {
        unitCount = Math.min(unitCount, bindingMax);
      }

      // Round to the more restrictive increment
      const solidIncrement = solidFood.min_increment ??
        (solidFood.is_indivisible ? 1 : 0.5);
      const gelIncrement = gelFood.min_increment ??
        (gelFood.is_indivisible ? 1 : 0.5);
      const bindingIncrement = Math.max(solidIncrement, gelIncrement);
      unitCount = Math.round(unitCount / bindingIncrement) * bindingIncrement;

      const ratioMin = Math.max(solidFood.min_servings, gelFood.min_servings);
      if (unitCount <= 0 || unitCount < ratioMin || bindingMax < ratioMin) {
        unitCount = 0;
      } else {
        unitCount = Math.max(ratioMin, Math.min(bindingMax, unitCount));
      }

      solidEntry.servings = unitCount;
      gelEntry.servings = unitCount;

      console.log(
        `[DURING-TEMPLATE] 1:1 ratio enforced: ${solidFoodName}=${unitCount}, ${gelFoodName}=${unitCount} (binding_max=${
          Number.isFinite(bindingMax) ? bindingMax.toFixed(1) : "∞"
        })`,
      );
    }
  }

  // ---- STEP 3: Build food results ----
  for (const { food, servings, name } of servingPlan) {
    if (servings <= 0) continue;

    const result = buildFoodResult(food, servings);
    resultFoods.push(result);
    carbsAssigned += result.carbs_grams;
    sodiumAssigned += result.sodium_mg;
    fluidAssigned += result.fluids_ml;

    console.log(
      `[DURING-TEMPLATE] ${name}: ${servings} servings = ${result.carbs_grams}g carbs, ${result.sodium_mg}mg sodium, ${result.fluids_ml}ml fluid`,
    );
  }

  // ---- STEP 4: Compensate carb shortfall via sports drink ----
  const carbShortfall = carbTarget - carbsAssigned;
  if (
    carbShortfall > carbTarget * 0.05 &&
    Object.prototype.hasOwnProperty.call(carbRatios, "sports_drink")
  ) {
    // Sports drink compensation is only allowed when sports drink is part of
    // the selected template's carb allocation.
    const sdFood = foodsByName.get("sports_drink");
    if (sdFood && sdFood.per_serving.carbs_g > 0) {
      const sdMaxPerHr = getMaxPerHour(sdFood, gutTrainingLevel);
      const sdMaxByDuration = sdMaxPerHr !== null
        ? Math.min(sdFood.max_servings, sdMaxPerHr * durationHours)
        : sdFood.max_servings;

      // Check if sports drink is already in the plan
      const existingSd = resultFoods.find((r) => r.food_id === sdFood.id);
      const existingSdServings = existingSd?.quantity ?? 0;
      const remainingCapacity = Math.max(
        0,
        sdMaxByDuration - existingSdServings,
      );

      if (remainingCapacity > 0) {
        let compensationServings = carbShortfall / sdFood.per_serving.carbs_g;
        compensationServings = Math.min(
          compensationServings,
          remainingCapacity,
        );
        compensationServings = clampAndRound(
          compensationServings,
          sdFood,
          remainingCapacity,
          false,
        );

        // Ensure won't exceed carb upper bound
        const carbsAfter = carbsAssigned +
          (sdFood.per_serving.carbs_g * compensationServings);
        if (carbsAfter > carbUpper) {
          compensationServings = Math.max(
            0,
            (carbUpper - carbsAssigned) / sdFood.per_serving.carbs_g,
          );
          compensationServings = clampAndRound(
            compensationServings,
            sdFood,
            remainingCapacity,
            false,
          );
        }

        if (compensationServings > 0) {
          if (existingSd) {
            // Add to existing sports drink entry
            const newQuantity = existingSdServings + compensationServings;
            existingSd.quantity = newQuantity;
            existingSd.carbs_grams =
              Math.round(sdFood.per_serving.carbs_g * newQuantity * 10) / 10;
            existingSd.sodium_mg = Math.round(
              sdFood.per_serving.sodium_mg * newQuantity,
            );
            existingSd.fluids_ml = Math.round(
              sdFood.per_serving.water_ml * newQuantity,
            );
            existingSd.calories = Math.round(
              sdFood.per_serving.calories * newQuantity,
            );
            existingSd.protein_grams =
              Math.round(sdFood.per_serving.protein_g * newQuantity * 10) / 10;
            existingSd.fat_grams =
              Math.round(sdFood.per_serving.fat_g * newQuantity * 10) / 10;

            carbsAssigned += sdFood.per_serving.carbs_g * compensationServings;
            sodiumAssigned += sdFood.per_serving.sodium_mg *
              compensationServings;
            fluidAssigned += sdFood.per_serving.water_ml * compensationServings;
          } else {
            const sdResult = buildFoodResult(sdFood, compensationServings);
            resultFoods.push(sdResult);
            carbsAssigned += sdResult.carbs_grams;
            sodiumAssigned += sdResult.sodium_mg;
            fluidAssigned += sdResult.fluids_ml;
          }

          console.log(
            `[DURING-TEMPLATE] Carb compensation: sports_drink +${compensationServings} servings (shortfall=${
              carbShortfall.toFixed(0)
            }g)`,
          );
        }
      }
    }
  }

  // ---- STEP 5: Fill fluid gap with water ----
  const remainingFluid = Math.max(0, fluidTarget - fluidAssigned);
  if (remainingFluid > 0) {
    const waterFood = foodsByName.get("water");
    if (waterFood && waterFood.per_serving.water_ml > 0) {
      let waterServings = remainingFluid / waterFood.per_serving.water_ml;
      waterServings = clampAndRound(
        waterServings,
        waterFood,
        waterFood.max_servings,
        false,
      );

      // Don't exceed fluid upper bound
      const fluidAfter = fluidAssigned +
        (waterFood.per_serving.water_ml * waterServings);
      if (fluidAfter > fluidUpper) {
        const maxByFluid = Math.max(
          0,
          (fluidUpper - fluidAssigned) / waterFood.per_serving.water_ml,
        );
        waterServings = clampAndRound(
          maxByFluid,
          waterFood,
          waterFood.max_servings,
          false,
        );
      }

      if (waterServings > 0) {
        const waterResult = buildFoodResult(waterFood, waterServings);
        resultFoods.push(waterResult);
        fluidAssigned += waterResult.fluids_ml;
        sodiumAssigned += waterResult.sodium_mg;

        console.log(
          `[DURING-TEMPLATE] Water: ${waterServings} servings = ${waterResult.fluids_ml}ml`,
        );
      }
    }
  }

  // ---- STEP 6: Fill sodium gap with electrolytes ----
  // Gather all electrolyte foods from the pool, excluding dislikes (issue #14).
  const electrolytePool: FoodWithConstraints[] = [];
  for (const [, food] of foodsByName) {
    if (!isSodiumTopUpFood(food)) continue;
    if (isFoodDisliked(food, dislikedFoods)) continue;
    electrolytePool.push(food);
  }

  if (electrolytePool.length > 0) {
    const elecBounds: ElectrolyteBounds = {
      sodiumTarget,
      sodiumLower,
      sodiumUpper,
      fluidTarget,
      fluidUpper,
      carbTarget,
      carbUpper,
    };
    const elecResult = fillElectrolytes(
      electrolytePool,
      resultFoods,
      sodiumAssigned,
      fluidAssigned,
      carbsAssigned,
      elecBounds,
      "[DURING-TEMPLATE]",
    );
    sodiumAssigned = elecResult.sodiumAssigned;
    fluidAssigned = elecResult.fluidAssigned;
    carbsAssigned = elecResult.carbsAssigned;
  }

  // ---- STEP 7: Validate against MACRO_CONSTRAINT_RANGES ----
  const totals = calculateTotals(resultFoods);
  const duringRanges = {
    carbs: MACRO_CONSTRAINT_RANGES.carbs.during,
    sodium: MACRO_CONSTRAINT_RANGES.sodium.during,
    water: MACRO_CONSTRAINT_RANGES.water.during,
  };
  const validationIssues: string[] = [];

  if (duringRanges.carbs && carbTarget > 0) {
    const ratio = totals.carbs_g / carbTarget;
    if (ratio < duringRanges.carbs.min || ratio > duringRanges.carbs.max) {
      validationIssues.push(
        `carbs ${(ratio * 100).toFixed(0)}% (${
          totals.carbs_g.toFixed(0)
        }g/${carbTarget}g)`,
      );
    }
  }
  if (duringRanges.sodium && sodiumTarget > 0) {
    const ratio = totals.sodium_mg / sodiumTarget;
    if (ratio < duringRanges.sodium.min || ratio > duringRanges.sodium.max) {
      validationIssues.push(
        `sodium ${(ratio * 100).toFixed(0)}% (${
          totals.sodium_mg.toFixed(0)
        }mg/${sodiumTarget}mg)`,
      );
    }
  }
  if (duringRanges.water && fluidTarget > 0) {
    const ratio = totals.water_ml / fluidTarget;
    if (ratio < duringRanges.water.min || ratio > duringRanges.water.max) {
      validationIssues.push(
        `water ${(ratio * 100).toFixed(0)}% (${
          totals.water_ml.toFixed(0)
        }ml/${fluidTarget}ml)`,
      );
    }
  }

  console.log(
    `[DURING-TEMPLATE] Final: ${resultFoods.length} foods, ` +
      `carbs=${totals.carbs_g.toFixed(0)}g/${carbTarget}g, ` +
      `sodium=${totals.sodium_mg.toFixed(0)}mg/${sodiumTarget}mg, ` +
      `fluid=${totals.water_ml.toFixed(0)}ml/${fluidTarget}ml`,
  );

  // Same shortfall escape hatch as the search path: with dislikes present OR a
  // pin override, accept the partial result and report shortfalls to the UI
  // rather than dropping the phase entirely.
  const allowShortfall = (!!dislikedFoods && dislikedFoods.size > 0) ||
    !!pinOverride;

  if (validationIssues.length > 0 && !allowShortfall) {
    console.warn(
      `[DURING-TEMPLATE] VALIDATION FAILED: ${
        validationIssues.join("; ")
      } — returning null (will fall back to rule solver)`,
    );
    return null;
  }

  console.log(
    "[DURING-TEMPLATE] VALIDATION PASSED: All macros within constraint ranges",
  );

  const shortfalls = collectShortfalls(totals, targets, dislikedFoods);

  return {
    foods: resultFoods,
    template_id: template.id,
    template_number: template.template_number,
    template_name: template.name,
    template_formula: template.formula,
    ...(shortfalls.length > 0 && { shortfalls }),
  };
}
