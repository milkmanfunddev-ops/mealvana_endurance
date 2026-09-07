/**
 * Database queries for food retrieval from the curated `template_foods` table.
 *
 * LIVE DEPENDENCY OF generate-nutrition-plan-v3. (A previous header claimed this
 * file was "v2 only"; there is no v2 — `generate-nutrition-plan-v2` no longer
 * exists. Callers today: `after-phase.ts`, `lp-phase.ts`, `during-phase.ts`,
 * `brick-handler.ts`.)
 *
 * FOOD-SOURCE POLICY (2026-07-29): plan generation draws foods ONLY from the
 * curated `template_foods` catalog. `user_foods` — user-created / barcode-scanned
 * / branded grocery items — are NOT queried here and must not be reintroduced.
 * The single legitimate user-originating source is a pinned personal formula,
 * which is self-contained (its components carry their own macros and do NO
 * food-pool lookup — see `personal-formula-pins.ts`).
 *
 * Additionally, every pool built here excludes rows whose `product_type` is null
 * or `'import'` (unclassified / imported-branded), matching the gate in
 * `before-phase-substitution.ts` and the client `ClientFoodPoolService`.
 *
 * Column notes vs the legacy `foods` table (`food-queries.ts`, now only used for
 * water/salt essential backfill):
 * - Queries `template_foods` (not `foods`)
 * - Column names: carbs_g (not carbs_per_serving), fluid_ml (not fluid_ml_per_serving)
 * - Uses activityType as 3rd param (no userId needed)
 */

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { safe } from "../utils.ts";
import type { ActivityType, Food, Phase } from "./types.ts";
import {
  DEFAULT_MAX_SERVINGS,
  getCategoryForPhase,
  PREFERENCE_SCORE_MAP,
} from "./constants.ts";
import { buildPreferenceSet, matchesPreference } from "./food-utils.ts";
import type {
  DuringWorkoutTemplate,
  FoodWithConstraints,
} from "./during-template-solver.ts";
import type { PostWorkoutTemplate } from "./post-template-solver.ts";

/**
 * Resolve composite activity types to their constituent sports for
 * activity_types column filtering. Brick/triathlon/etc. aren't stored
 * in the activity_types array — the individual sports are.
 */
function resolveActivityTypesFilter(activityType: ActivityType): string {
  const COMPOSITE_SPORTS: Record<string, string[]> = {
    brick: ["running", "cycling", "swimming"],
    triathlon: ["running", "cycling", "swimming"],
    duathlon: ["running", "cycling"],
    multisport: ["running", "cycling", "swimming"],
  };

  const sports = COMPOSITE_SPORTS[activityType];
  if (sports) {
    // Build OR filter that matches any constituent sport
    const overlapClauses = sports.map((s) => `activity_types.ov.{${s}}`).join(
      ",",
    );
    return `activity_types.is.null,${overlapClauses}`;
  }

  return `activity_types.is.null,activity_types.ov.{${activityType}}`;
}

/**
 * True when a food row carries a real, classified product type.
 *
 * Anything null/empty (never classified) or `'import'` (a barcode-scanned or
 * otherwise imported branded grocery item) is NOT eligible for plan generation.
 * This is the same gate the before-phase substitution path applies in SQL
 * (`before-phase-substitution.ts`) and the client applies in
 * `ClientFoodPoolService`; it lives here so every pool built in this file
 * enforces it identically.
 */
export function isClassifiedProductType(productType: unknown): boolean {
  if (typeof productType !== "string") return false;
  const t = productType.trim().toLowerCase();
  return t.length > 0 && t !== "import";
}

/**
 * Build a Supabase category filter for the given categories
 * Uses the categories array column with overlaps operator
 */
function buildCategoryFilter(categories: string[]): string {
  return `{${categories.join(",")}}`;
}

/**
 * Get max servings for a food based on phase
 * Uses max_servings_before/during/after columns with fallback to default
 */
function getMaxServings(food: Record<string, unknown>, phase: Phase): number {
  switch (phase) {
    case "before":
      return (food.max_servings_before as number) ?? DEFAULT_MAX_SERVINGS;
    case "during":
      return (food.max_servings_during as number) ?? DEFAULT_MAX_SERVINGS;
    case "after":
      return (food.max_servings_after as number) ?? DEFAULT_MAX_SERVINGS;
  }
}

/**
 * Get foods suitable for a specific phase and activity type from template_foods.
 *
 * Curated catalog ONLY — `user_foods` is deliberately not consulted (food-source
 * policy, see file header). There is no `deviceId` parameter any more; it existed
 * solely to resolve the user id for the user_foods lookup.
 *
 * Note: Parameter order differs from food-queries.ts:
 *   food-queries.ts:          (supabase, phase, userId, liked, willing, disliked, activityType)
 *   template-food-queries.ts: (supabase, phase, activityType, liked, willing, disliked)
 */
export async function getTemplateFoodsForPhase(
  supabase: SupabaseClient,
  phase: Phase,
  activityType: ActivityType = "running",
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  allowNonDefaultDuring: boolean = false,
  allergies?: string[],
  dietaryPreference?: string,
  /** Food names that are components of the user's in-scope pinned templates.
   * Per the honor-pin policy, these foods bypass dislike / allergen / diet
   * filters so the pinned template can be rendered even when its ingredients
   * conflict with the user's general preferences. Empty/undefined preserves
   * pre-pin behavior. Formula Kit PR 3 (After-phase parity with the During
   * `getTemplateFoodsForDuringWithConstraints` pattern, PR 2 5c). */
  pinnedComponentNames?: Set<string>,
  /** Additional component food names that must be pulled into the SQL fetch
   * even when they sit outside the phase's category/activity scope, WITHOUT
   * any filter bypass — they still face dislike/allergen/diet filtering at
   * STEP 4. Used by the after-phase no-pin path so pantry foods referenced
   * by post-workout templates (peanut_butter, jam, milk, granola, etc.) are
   * available to the template renderer even when their `template_foods.
   * categories` only includes `before_run`. Fixes #36 — the no-pin half of
   * the architectural gap addressed for the pin path by PR 3 #35. */
  extraComponentNames?: Set<string>,
): Promise<Food[]> {
  const likedSet = buildPreferenceSet(likedFoods);
  const willTrySet = buildPreferenceSet(willingToTryFoods);
  const dislikedSet = buildPreferenceSet(dislikedFoods);

  // Get the appropriate categories for this phase and sport
  const categories = getCategoryForPhase(phase, activityType);
  const categoryFilter = buildCategoryFilter(categories);

  // Resolve composite types (brick/triathlon/etc.) to constituent sports
  const activityFilter = resolveActivityTypesFilter(activityType);
  console.log(
    `[TMPL-FOODS-${phase.toUpperCase()}] Filtering template_foods for categories: ${
      categories.join(", ")
    }, activity_type: ${activityType}, filter: ${activityFilter}`,
  );

  // STEP 1: Get foods from template_foods table
  let templateFoods: Record<string, unknown>[] = [];
  const selectWithDefaultDuring = `
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      max_servings_before, max_servings_during, max_servings_after,
      min_servings_during, solvent_min_ml,
      is_electrolyte, to_exclude_from_solver, is_essential, is_indivisible,
      categories, activity_types, is_liquid, product_type, default_during,
      allergens, excluded_diets
    `;
  const selectWithoutDefaultDuring = `
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      max_servings_before, max_servings_during, max_servings_after,
      solvent_min_ml,
      is_electrolyte, to_exclude_from_solver, is_essential, is_indivisible,
      categories, activity_types, is_liquid, product_type,
      allergens, excluded_diets
    `;

  let foodsData: Record<string, unknown>[] | null = null;
  let foodsError: { message?: string } | null = null;
  {
    const { data, error } = await supabase
      .from("template_foods")
      .select(selectWithDefaultDuring)
      .eq("is_active", true)
      .filter("categories", "ov", categoryFilter)
      .or(activityFilter);
    foodsData = data as Record<string, unknown>[] | null;
    foodsError = error;
  }

  // Backward compatibility if DB has not yet added default_during.
  if (foodsError && foodsError.message?.includes("default_during")) {
    const fallback = await supabase
      .from("template_foods")
      .select(selectWithoutDefaultDuring)
      .eq("is_active", true)
      .filter("categories", "ov", categoryFilter)
      .or(activityFilter);
    foodsData = fallback.data as Record<string, unknown>[] | null;
    foodsError = fallback.error;
  }

  if (foodsError) {
    console.log(
      `[TMPL-FOODS-${phase.toUpperCase()}] Error fetching template foods:`,
      foodsError,
    );
  } else if (foodsData) {
    templateFoods = foodsData as Record<string, unknown>[];
    console.log(
      `[TMPL-FOODS-${phase.toUpperCase()}] Found ${templateFoods.length} template foods for ${activityType}`,
    );
  }

  // STEP 1b: SQL-widening for component foods that sit outside the phase's
  // category/activity scope. Without this, the categorically-filtered fetch
  // above misses pantry foods (e.g. Berries categorized only as `before_run`
  // but used by After templates), the template renderer sees missing
  // components, and either drops the template silently or — for pinned
  // templates — the honor-pin bypass at STEP 4 has nothing to bypass.
  //
  // Two sets of names get widened in:
  //   - `pinnedComponentNames` — components of in-scope pinned templates.
  //     These additionally bypass dislike/allergen/diet at STEP 4.
  //   - `extraComponentNames`  — any component the caller wants reachable
  //     even when out of scope (e.g. all post-template components in the
  //     no-pin After path). Still subject to STEP 4 filters.
  // Fixes PR 3 #35 (pin half) and #36 (no-pin half).
  const widenNames = new Set<string>();
  for (const n of pinnedComponentNames ?? []) widenNames.add(n);
  for (const n of extraComponentNames ?? []) widenNames.add(n);
  if (widenNames.size > 0) {
    const existingNames = new Set(
      templateFoods.map((f) => f.name as string),
    );
    const missingWidenNames = [...widenNames].filter(
      (n) => !existingNames.has(n),
    );
    if (missingWidenNames.length > 0) {
      let extraData: Record<string, unknown>[] | null = null;
      let extraError: { message?: string } | null = null;
      {
        const { data, error } = await supabase
          .from("template_foods")
          .select(selectWithDefaultDuring)
          .eq("is_active", true)
          .in("name", missingWidenNames);
        extraData = data as Record<string, unknown>[] | null;
        extraError = error;
      }
      if (extraError && extraError.message?.includes("default_during")) {
        const fallback = await supabase
          .from("template_foods")
          .select(selectWithoutDefaultDuring)
          .eq("is_active", true)
          .in("name", missingWidenNames);
        extraData = fallback.data as Record<string, unknown>[] | null;
        extraError = fallback.error;
      }
      if (extraError) {
        console.log(
          `[TMPL-FOODS-${phase.toUpperCase()}] Error widening fetch for out-of-scope components:`,
          extraError,
        );
      } else if (extraData && extraData.length > 0) {
        console.log(
          `[TMPL-FOODS-${phase.toUpperCase()}] Widening: fetched ${extraData.length} out-of-scope component foods (${
            missingWidenNames.join(", ")
          })`,
        );
        templateFoods = templateFoods.concat(extraData);
      }
    }
  }

  // STEP 2: Deduplicate. `user_foods` used to be merged in here — it no longer
  // is (food-source policy, see file header). The curated catalog is the only
  // source, so this step just guards against a row appearing twice via the
  // STEP 1b widening fetch.
  const allFoodsMap = new Map<string, Record<string, unknown>>();
  for (const food of templateFoods) {
    allFoodsMap.set(food.id as string, food);
  }

  const allEntries = Array.from(allFoodsMap.values());
  console.log(
    `[TMPL-FOODS-${phase.toUpperCase()}] ${allEntries.length} curated template foods in pool (user_foods excluded by policy)`,
  );

  if (allEntries.length === 0) return [];

  // Prepare allergen filtering sets (case-insensitive)
  const allergiesLower = (allergies ?? []).map((a) => a.toLowerCase());
  const dietPrefLower = dietaryPreference?.toLowerCase() ?? "";

  // STEP 4: Filter and transform to Food interface
  const totalCandidates = allEntries.length;
  let dislikeExcludedCount = 0;
  let unclassifiedExcludedCount = 0;
  const filteredFoods = allEntries
    .filter((f) => {
      // Branded / unclassified guard. Mirrors the SQL gate in
      // `before-phase-substitution.ts` (`product_type IS NOT NULL AND
      // product_type != 'import'`) and the client `ClientFoodPoolService`.
      // Curated rows are all classified today, so this is a forward guard: a
      // row that lands in `template_foods` without a product type (or flagged
      // as an import) never reaches a generated plan. Essentials (water/salt)
      // are exempt so hydration is never lost to a data-entry gap.
      if (f.is_essential !== true && !isClassifiedProductType(f.product_type)) {
        unclassifiedExcludedCount++;
        console.log(
          `[TMPL-FILTER-UNCLASSIFIED] Excluding food with product_type=${f.product_type}: ${f.name}`,
        );
        return false;
      }

      const isDisliked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        dislikedSet,
      );
      const isExcludedFromSolver = f.to_exclude_from_solver === true;
      const isLiked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        likedSet,
      );
      const isWilling = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        willTrySet,
      );
      const isPreferredDuring = isLiked || isWilling;
      const isDefaultDuring = f.default_during === true;
      const isEssential = f.is_essential === true;
      const isElectrolyte = f.is_electrolyte === true;
      // Honor-pin bypass: foods that are components of an in-scope pinned
      // template skip dislike/allergen/diet filters. Without this, a user who
      // pins a template containing a generally-disliked or allergen-bearing
      // food (e.g. chocolate milk marked disliked) would have that component
      // silently stripped from the food pool, and the template renderer would
      // return null → fall back to LP. See #35 / PR 3 substep 9 follow-up.
      const isPinnedComponent =
        pinnedComponentNames?.has(f.name as string) ?? false;

      // Filter disliked foods. Essentials (e.g. water/salt) bypass this so the
      // solver always has a fallback for safety-critical hydration. Electrolyte
      // *products* (capsules, drinks, powders) get NO essential-bypass — user
      // preference dominates so we don't ship a plan featuring foods they hate.
      if (
        isDisliked && !isPinnedComponent &&
        !(isEssential && !isElectrolyte)
      ) {
        dislikeExcludedCount++;
        console.log(
          `[TMPL-FILTER-DISLIKED] Excluding disliked food: ${f.name} (id: ${f.id})`,
        );
        return false;
      }

      // Allergen filtering — exclude template foods whose allergens overlap with user's allergies
      // Essential foods (water, salt) bypass allergen filtering
      if (
        allergiesLower.length > 0 && !isEssential &&
        !isPinnedComponent
      ) {
        const foodAllergens = (f.allergens as string[] | null) ?? [];
        const hasAllergen = foodAllergens.some((a: string) =>
          allergiesLower.includes(a.toLowerCase())
        );
        if (hasAllergen) {
          console.log(
            `[TMPL-FILTER-ALLERGEN] Excluding food with allergen: ${f.name} (allergens: ${
              foodAllergens.join(",")
            })`,
          );
          return false;
        }
      }

      // Allergen-based diet filtering (for -free diets like gluten-free, dairy-free, peanut-free)
      if (dietPrefLower && !isEssential && !isPinnedComponent) {
        const dietExcludedAllergens: string[] = [];
        if (dietPrefLower === "gluten-free" || dietPrefLower === "all-free") {
          dietExcludedAllergens.push("gluten");
        }
        if (dietPrefLower === "dairy-free" || dietPrefLower === "all-free") {
          dietExcludedAllergens.push("dairy");
        }
        if (dietPrefLower === "peanut-free" || dietPrefLower === "all-free") {
          dietExcludedAllergens.push("peanut");
        }

        if (dietExcludedAllergens.length > 0) {
          const foodAllergens = (f.allergens as string[] | null) ?? [];
          const hasDietAllergen = foodAllergens.some((a: string) =>
            dietExcludedAllergens.includes(a.toLowerCase())
          );
          if (hasDietAllergen) {
            console.log(
              `[TMPL-FILTER-DIET-ALLERGEN] Excluding food with allergen for diet '${dietaryPreference}': ${f.name} (allergens: ${
                foodAllergens.join(",")
              })`,
            );
            return false;
          }
        }
      }

      // Dietary preference filtering — exclude foods whose excluded_diets contains user's dietary preference
      if (dietPrefLower && !isEssential && !isPinnedComponent) {
        const excludedDiets = (f.excluded_diets as string[] | null) ?? [];
        const isDietExcluded = excludedDiets.some((d: string) =>
          d.toLowerCase() === dietPrefLower
        );
        if (isDietExcluded) {
          console.log(
            `[TMPL-FILTER-DIET] Excluding food for diet '${dietaryPreference}': ${f.name} (excluded_diets: ${
              excludedDiets.join(",")
            })`,
          );
          return false;
        }
      }

      // Running during default policy:
      // - include default_during foods
      // - include user-preferred foods (liked/willing_to_try)
      // - include essentials
      // - optionally include all during foods in fallback mode
      if (
        phase === "during" &&
        activityType === "running" &&
        !allowNonDefaultDuring &&
        !isEssential &&
        !isPreferredDuring &&
        !isDefaultDuring
      ) {
        return false;
      }

      return !isExcludedFromSolver;
    })
    .map((f): Food => {
      const isLiked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        likedSet,
      );
      const isWilling = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        willTrySet,
      );

      let preferenceCategory:
        | "liked"
        | "willing"
        | "essential"
        | "neutral" = "neutral";
      if (isLiked) preferenceCategory = "liked";
      else if (isWilling) preferenceCategory = "willing";

      const preference_score = PREFERENCE_SCORE_MAP[preferenceCategory];
      const effectiveMaxServings = getMaxServings(f, phase);

      const carbsG = safe(f.carbs_g as number);
      const proteinG = safe(f.protein_g as number);
      const fatG = safe(f.fat_g as number);
      const sodiumMg = safe(f.sodium_mg as number);
      const waterMl = safe(f.fluid_ml as number);
      const calories = safe(f.calories as number);

      const minServings = (f.min_servings_during as number) ?? 1.0;

      return {
        id: f.id as string,
        name: f.name as string,
        display_name: (f.display_name as string) ?? null,
        display_name_plural: (f.display_name_plural as string) ?? null,
        description: (f.description as string) ?? null,
        image_address: (f.image_address as string) ?? null,
        serving_size: (f.serving_size as string) ?? null,
        serving_unit: (f.serving_unit as string) ?? null,
        serving_qualifier: (f.serving_qualifier as string) ?? null,
        per_serving: {
          carbs_g: carbsG,
          protein_g: proteinG,
          fat_g: fatG,
          sodium_mg: sodiumMg,
          water_ml: waterMl,
          calories: calories,
        },
        serving_amount: (f.serving_amount as number) ?? null,
        min_servings: minServings,
        max_servings: effectiveMaxServings,
        preference_score,
        is_electrolyte: (f.is_electrolyte as boolean) || false,
        is_liquid: (f.is_liquid as boolean) || false,
        is_essential: (f.is_essential as boolean) || false,
        is_user_food: false,
        is_indivisible: (f.is_indivisible as boolean) || false,
        solvent_min_ml: (f.solvent_min_ml as number | null) ?? null,
        product_type: (f.product_type as string) ?? undefined,
      };
    });

  if (unclassifiedExcludedCount > 0) {
    console.warn(
      `[TMPL-FILTER-UNCLASSIFIED] Excluded ${unclassifiedExcludedCount} template food(s) with a null/'import' ` +
        `product_type for phase=${phase}, activity=${activityType}. Curated rows should always be classified — ` +
        `check template_foods data entry.`,
    );
  }

  // Guardrail: if the disliked filter removed most of the candidate pool, the
  // phase will almost certainly under-fuel (no carb sources survive). This is
  // the signature of a bad/stale disliked list rather than genuine preference.
  // Surface it instead of silently returning a near-empty pool.
  if (totalCandidates > 0 && dislikeExcludedCount / totalCandidates >= 0.5) {
    console.warn(
      `[TMPL-FILTER-DISLIKED] WARNING: dislike filter removed ${dislikeExcludedCount}/${totalCandidates} ` +
        `candidate foods (${Math.round((dislikeExcludedCount / totalCandidates) * 100)}%) for phase=${phase}, ` +
        `activity=${activityType}. ${filteredFoods.length} foods remain. A disliked list this large usually ` +
        `indicates a stale client preference cache — verify the [PLAN-V3-PREFS] payload.`,
    );
  }

  return filteredFoods;
}

/**
 * Get electrolyte foods from template_foods for post-processing
 */
export async function getTemplateElectrolyteFoods(
  supabase: SupabaseClient,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
): Promise<Food[]> {
  const likedSet = buildPreferenceSet(likedFoods);
  const willTrySet = buildPreferenceSet(willingToTryFoods);
  const dislikedSet = buildPreferenceSet(dislikedFoods);

  const { data: electrolytes, error } = await supabase
    .from("template_foods")
    .select(`
      id, name, display_name, display_name_plural, description, image_address,
      sodium_mg, fluid_ml,
      serving_amount,
      serving_size, serving_unit, serving_qualifier,
      is_electrolyte, to_exclude_from_solver, is_essential
    `)
    .eq("is_active", true)
    .eq("is_electrolyte", true);

  if (error) {
    console.log("[TMPL-ELECTROLYTES] Error fetching electrolytes:", error);
    return [];
  }

  console.log(
    `[TMPL-ELECTROLYTES] Found ${electrolytes?.length || 0} electrolyte items`,
  );

  return (electrolytes || [])
    .filter((e: Record<string, unknown>) => {
      // Always exclude disliked electrolytes — user preference for these dominates.
      const isDisliked = matchesPreference(
        e as { id?: string; name?: string; display_name?: string | null },
        dislikedSet,
      );
      if (isDisliked) {
        console.log(
          `[TMPL-ELECTROLYTES] Excluding disliked electrolyte: ${e.name}`,
        );
        return false;
      }

      if (e.is_essential === true) return true;

      const isLiked = matchesPreference(
        e as { id?: string; name?: string; display_name?: string | null },
        likedSet,
      );
      const isWilling = matchesPreference(
        e as { id?: string; name?: string; display_name?: string | null },
        willTrySet,
      );

      return isLiked || isWilling;
    })
    .map((e: Record<string, unknown>): Food => ({
      id: e.id as string,
      name: e.name as string,
      display_name: (e.display_name as string) ?? null,
      display_name_plural: (e.display_name_plural as string) ?? null,
      description: (e.description as string) ?? null,
      image_address: (e.image_address as string) ?? null,
      serving_size: (e.serving_size as string) ?? null,
      serving_unit: (e.serving_unit as string) ?? null,
      serving_qualifier: (e.serving_qualifier as string) ?? null,
      per_serving: {
        carbs_g: 0,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: safe(e.sodium_mg as number),
        water_ml: safe(e.fluid_ml as number),
        calories: 0,
      },
      serving_amount: (e.serving_amount as number) ?? null,
      min_servings: 1.0,
      max_servings: DEFAULT_MAX_SERVINGS,
      preference_score: 50,
      is_electrolyte: true,
      is_liquid: false,
      is_essential: (e.is_essential as boolean) || false,
      is_user_food: false,
      is_indivisible: true, // electrolyte items (tablets, etc.) are indivisible
    }));
}

/**
 * Get transition foods from template_foods for brick workout T1/T2 phases.
 * Queries foods with 'transition' category — these are quick-consume items
 * (gels, sports drinks, water) suitable for brief transition periods.
 * No activity_type filter — transition foods are universal across sports.
 *
 * Curated catalog ONLY — `user_foods` is deliberately not consulted (food-source
 * policy, see file header). The former `deviceId` parameter existed solely to
 * resolve the user id for that lookup and has been removed.
 */
export async function getTransitionFoods(
  supabase: SupabaseClient,
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  allergies?: string[],
  dietaryPreference?: string,
): Promise<Food[]> {
  const likedSet = buildPreferenceSet(likedFoods);
  const willTrySet = buildPreferenceSet(willingToTryFoods);
  const dislikedSet = buildPreferenceSet(dislikedFoods);

  // Fetch template_foods with 'transition' category
  const { data: templateData, error: templateError } = await supabase
    .from("template_foods")
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      max_servings_during,
      is_electrolyte, to_exclude_from_solver, is_essential, is_indivisible,
      is_liquid, product_type,
      allergens, excluded_diets
    `)
    .eq("is_active", true)
    .filter("categories", "ov", "{transition}");

  if (templateError) {
    console.log(
      "[TRANSITION-FOODS] Error fetching transition foods:",
      templateError,
    );
    return [];
  }

  const templateFoods = (templateData ?? []) as Record<string, unknown>[];
  console.log(
    `[TRANSITION-FOODS] Found ${templateFoods.length} transition template foods`,
  );

  // Deduplicate. `user_foods` used to be merged in here — it no longer is
  // (food-source policy, see file header).
  const allFoodsMap = new Map<string, Record<string, unknown>>();
  for (const food of templateFoods) {
    allFoodsMap.set(food.id as string, food);
  }

  const allEntries = Array.from(allFoodsMap.values());

  // Prepare allergen filtering sets (case-insensitive)
  const transAllergiesLower = (allergies ?? []).map((a) => a.toLowerCase());
  const transDietPrefLower = dietaryPreference?.toLowerCase() ?? "";

  return allEntries
    .filter((f) => {
      const isEssential = f.is_essential === true;

      // Branded / unclassified guard — same gate as getTemplateFoodsForPhase.
      if (!isEssential && !isClassifiedProductType(f.product_type)) {
        console.log(
          `[TRANSITION-FILTER-UNCLASSIFIED] Excluding food with product_type=${f.product_type}: ${f.name}`,
        );
        return false;
      }

      const isDisliked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        dislikedSet,
      );
      if (isDisliked && !isEssential) return false;
      if (f.to_exclude_from_solver === true) return false;

      // Allergen filtering — essential foods bypass
      if (transAllergiesLower.length > 0 && !isEssential) {
        const foodAllergens = (f.allergens as string[] | null) ?? [];
        const hasAllergen = foodAllergens.some((a: string) =>
          transAllergiesLower.includes(a.toLowerCase())
        );
        if (hasAllergen) {
          console.log(
            `[TRANSITION-FILTER-ALLERGEN] Excluding food with allergen: ${f.name} (allergens: ${
              foodAllergens.join(",")
            })`,
          );
          return false;
        }
      }

      // Dietary preference filtering
      if (transDietPrefLower && !isEssential) {
        const excludedDiets = (f.excluded_diets as string[] | null) ?? [];
        const isDietExcluded = excludedDiets.some((d: string) =>
          d.toLowerCase() === transDietPrefLower
        );
        if (isDietExcluded) {
          console.log(
            `[TRANSITION-FILTER-DIET] Excluding food for diet '${dietaryPreference}': ${f.name}`,
          );
          return false;
        }
      }

      return true;
    })
    .map((f): Food => {
      const isLiked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        likedSet,
      );
      const isWilling = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        willTrySet,
      );

      let preferenceCategory: "liked" | "willing" | "essential" | "neutral" =
        "neutral";
      if (isLiked) preferenceCategory = "liked";
      else if (isWilling) preferenceCategory = "willing";

      const carbsG = safe(f.carbs_g as number);
      const proteinG = safe(f.protein_g as number);
      const fatG = safe(f.fat_g as number);
      const sodiumMg = safe(f.sodium_mg as number);
      const waterMl = safe(f.fluid_ml as number);
      const calories = safe(f.calories as number);

      return {
        id: f.id as string,
        name: f.name as string,
        display_name: (f.display_name as string) ?? null,
        display_name_plural: (f.display_name_plural as string) ?? null,
        description: (f.description as string) ?? null,
        image_address: (f.image_address as string) ?? null,
        serving_size: (f.serving_size as string) ?? null,
        serving_unit: (f.serving_unit as string) ?? null,
        serving_qualifier: null,
        per_serving: {
          carbs_g: carbsG,
          protein_g: proteinG,
          fat_g: fatG,
          sodium_mg: sodiumMg,
          water_ml: waterMl,
          calories: calories,
        },
        serving_amount: (f.serving_amount as number) ?? null,
        min_servings: 0.5,
        max_servings: (f.max_servings_during as number) ?? DEFAULT_MAX_SERVINGS,
        preference_score: PREFERENCE_SCORE_MAP[preferenceCategory],
        is_electrolyte: (f.is_electrolyte as boolean) || false,
        is_liquid: (f.is_liquid as boolean) || false,
        is_essential: (f.is_essential as boolean) || false,
        is_user_food: false,
        is_indivisible: (f.is_indivisible as boolean) || false,
        solvent_min_ml: (f.solvent_min_ml as number | null) ?? null,
        product_type: (f.product_type as string) ?? undefined,
      };
    });
}

/**
 * Get essential foods (water, salt) from template_foods for post-processing
 */
export async function getTemplateEssentialFoods(
  supabase: SupabaseClient,
): Promise<Food[]> {
  const { data: essentialFoods, error } = await supabase
    .from("template_foods")
    .select(`
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      is_electrolyte, is_essential
    `)
    .eq("is_active", true)
    .eq("is_essential", true);

  if (error) {
    console.log("[TMPL-ESSENTIAL] Error fetching essential foods:", error);
    return [];
  }

  return (essentialFoods || []).map((f: Record<string, unknown>): Food => ({
    id: f.id as string,
    name: f.name as string,
    display_name: (f.display_name as string) ?? null,
    display_name_plural: (f.display_name_plural as string) ?? null,
    description: (f.description as string) ?? null,
    image_address: (f.image_address as string) ?? null,
    serving_size: (f.serving_size as string) ?? null,
    serving_unit: (f.serving_unit as string) ?? null,
    serving_qualifier: (f.serving_qualifier as string) ?? null,
    per_serving: {
      calories: safe(f.calories as number),
      carbs_g: safe(f.carbs_g as number),
      protein_g: safe(f.protein_g as number),
      fat_g: safe(f.fat_g as number),
      sodium_mg: safe(f.sodium_mg as number),
      water_ml: safe(f.fluid_ml as number),
    },
    serving_amount: (f.serving_amount as number) ?? null,
    min_servings: 1.0,
    max_servings: 10,
    preference_score: 50,
    is_essential: true,
    is_electrolyte: (f.is_electrolyte as boolean) || false,
    is_liquid: false,
    is_user_food: false,
    is_indivisible: false,
  }));
}

// ============================================================================
// During-Workout Template Queries
// ============================================================================

/**
 * Fetch all active during_workout_templates from the database.
 */
export async function getDuringWorkoutTemplates(
  supabase: SupabaseClient,
): Promise<DuringWorkoutTemplate[]> {
  const { data, error } = await supabase
    .from("during_workout_templates")
    .select(`
      id, template_number, name, formula, food_form,
      activity_types, duration_brackets, gut_training_levels,
      component_food_names, component_carb_ratios,
      primary_to_secondary_ratio,
      allergens, excluded_diets, notes, is_active,
      selection_priority
    `)
    .eq("is_active", true)
    .order("template_number");

  if (error) {
    console.log("[DWT-QUERY] Error fetching during_workout_templates:", error);
    return [];
  }

  const templates = (data ?? []) as DuringWorkoutTemplate[];
  console.log(
    `[DWT-QUERY] Fetched ${templates.length} active during workout templates`,
  );
  return templates;
}

/**
 * Fetch during-phase foods with per-hour max constraint columns.
 * Returns FoodWithConstraints[] — the standard Food fields plus
 * max_per_hr_low, max_per_hr_moderate, max_per_hr_high, min_increment,
 * sodium_top_up_eligible.
 *
 * Curated `template_foods` ONLY — `user_foods` is never consulted (food-source
 * policy, see file header). Same preference scoring and filtering as
 * getTemplateFoodsForPhase.
 */
export async function getTemplateFoodsForDuringWithConstraints(
  supabase: SupabaseClient,
  activityType: ActivityType = "running",
  likedFoods?: string[],
  willingToTryFoods?: string[],
  dislikedFoods?: string[],
  /** @deprecated Ignored. Retained only to keep the positional signature stable
   * for existing callers; it used to resolve a user id for a `user_foods`
   * lookup that no longer exists. Do not reintroduce. */
  _deviceId?: string,
  allergies?: string[],
  dietaryPreference?: string,
  /** Food names that are components of the user's pinned during-templates.
   * Per the honor-pin policy, these foods bypass dislike / allergen / diet
   * filters so the pinned template can be assembled even when its ingredients
   * conflict with the user's general preferences. Empty/undefined preserves
   * pre-pin behavior. Formula Kit PR 2 substep 5c. */
  pinnedComponentNames?: Set<string>,
): Promise<FoodWithConstraints[]> {
  const likedSet = buildPreferenceSet(likedFoods);
  const willTrySet = buildPreferenceSet(willingToTryFoods);
  const dislikedSet = buildPreferenceSet(dislikedFoods);

  const categories = getCategoryForPhase("during", activityType);
  const categoryFilter = buildCategoryFilter(categories);
  const activityFilter = resolveActivityTypesFilter(activityType);

  console.log(
    `[TMPL-FOODS-DURING-CONSTRAINTS] Filtering for categories: ${
      categories.join(", ")
    }, activity: ${activityType}`,
  );

  const constraintColumns = `
      id, name, display_name, display_name_plural, image_address, description,
      calories, carbs_g, protein_g, fat_g, sodium_mg, fluid_ml,
      serving_amount, serving_size, serving_unit, serving_qualifier,
      max_servings_before, max_servings_during, max_servings_after,
      min_servings_during, solvent_min_ml,
      is_electrolyte, to_exclude_from_solver, is_essential, is_indivisible,
      categories, activity_types, is_liquid, product_type, default_during,
      allergens, excluded_diets,
      max_per_hr_low, max_per_hr_moderate, max_per_hr_high, min_increment,
      sodium_top_up_eligible
    `;

  const { data, error } = await supabase
    .from("template_foods")
    .select(constraintColumns)
    .eq("is_active", true)
    .filter("categories", "ov", categoryFilter)
    .or(activityFilter);

  if (error) {
    console.log("[TMPL-FOODS-DURING-CONSTRAINTS] Error:", error);
    return [];
  }

  let templateFoods = (data ?? []) as Record<string, unknown>[];
  console.log(
    `[TMPL-FOODS-DURING-CONSTRAINTS] Found ${templateFoods.length} template foods`,
  );

  // SQL-widening for pinned-component foods that sit outside the during
  // category/activity scope (mirrors getTemplateFoodsForPhase). The in-Deno
  // filter bypass below only helps if the row actually made it into the
  // query result. See PR 3 #35 follow-up #2.
  if (pinnedComponentNames && pinnedComponentNames.size > 0) {
    const existingNames = new Set(
      templateFoods.map((f) => f.name as string),
    );
    const missingPinnedNames = [...pinnedComponentNames].filter(
      (n) => !existingNames.has(n),
    );
    if (missingPinnedNames.length > 0) {
      const { data: extraData, error: extraError } = await supabase
        .from("template_foods")
        .select(constraintColumns)
        .eq("is_active", true)
        .in("name", missingPinnedNames);
      if (extraError) {
        console.log(
          "[TMPL-FOODS-DURING-CONSTRAINTS] Error widening fetch for pinned components:",
          extraError,
        );
      } else if (extraData && extraData.length > 0) {
        console.log(
          `[TMPL-FOODS-DURING-CONSTRAINTS] Widening: fetched ${extraData.length} pinned-component foods out of during/activity scope (${
            missingPinnedNames.join(", ")
          })`,
        );
        templateFoods = templateFoods.concat(
          extraData as Record<string, unknown>[],
        );
      }
    }
  }

  const allergiesLower = (allergies ?? []).map((a) => a.toLowerCase());
  const dietPrefLower = dietaryPreference?.toLowerCase() ?? "";

  return templateFoods
    .filter((f) => {
      if (f.to_exclude_from_solver === true) return false;

      const isEssential = f.is_essential === true;
      const isElectrolyte = f.is_electrolyte === true;

      // Branded / unclassified guard — same gate as getTemplateFoodsForPhase.
      if (!isEssential && !isClassifiedProductType(f.product_type)) {
        console.log(
          `[TMPL-FOODS-DURING-CONSTRAINTS] Excluding food with product_type=${f.product_type}: ${f.name}`,
        );
        return false;
      }

      // Honor-pin bypass: foods that are components of an in-scope pinned
      // template skip dislike/allergen/diet filters. Without this, a user who
      // pins a template containing a generally-disliked or allergen-bearing
      // food (e.g. stroopwafel marked disliked) would have that component
      // silently stripped from the food pool, and the template solver would
      // produce an output that omits the pinned hero food. See PR 2 5c.
      const isPinnedComponent =
        pinnedComponentNames?.has(f.name as string) ?? false;

      // Disliked filter. Essentials bypass for hydration safety, but electrolyte
      // products do NOT — user preference for capsules/powders/drinks dominates.
      const isDisliked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        dislikedSet,
      );
      if (
        isDisliked && !isPinnedComponent &&
        !(isEssential && !isElectrolyte)
      ) return false;

      // Allergen filter
      if (allergiesLower.length > 0 && !isEssential && !isPinnedComponent) {
        const foodAllergens = (f.allergens as string[] | null) ?? [];
        if (
          foodAllergens.some((a) =>
            allergiesLower.includes((a as string).toLowerCase())
          )
        ) return false;
      }

      // Diet filter
      if (dietPrefLower && !isEssential && !isPinnedComponent) {
        // Allergen-based diet filtering
        const dietExcludedAllergens: string[] = [];
        if (dietPrefLower === "gluten-free" || dietPrefLower === "all-free") {
          dietExcludedAllergens.push("gluten");
        }
        if (dietPrefLower === "dairy-free" || dietPrefLower === "all-free") {
          dietExcludedAllergens.push("dairy");
        }
        if (dietPrefLower === "peanut-free" || dietPrefLower === "all-free") {
          dietExcludedAllergens.push("peanut");
        }

        if (dietExcludedAllergens.length > 0) {
          const foodAllergens = (f.allergens as string[] | null) ?? [];
          if (
            foodAllergens.some((a) =>
              dietExcludedAllergens.includes((a as string).toLowerCase())
            )
          ) return false;
        }

        const excludedDiets = (f.excluded_diets as string[] | null) ?? [];
        if (
          excludedDiets.some((d) =>
            (d as string).toLowerCase() === dietPrefLower
          )
        ) return false;
      }

      return true;
    })
    .map((f): FoodWithConstraints => {
      const isLiked = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        likedSet,
      );
      const isWilling = matchesPreference(
        f as { id?: string; name?: string; display_name?: string | null },
        willTrySet,
      );

      let preferenceCategory: "liked" | "willing" | "essential" | "neutral" =
        "neutral";
      if (isLiked) preferenceCategory = "liked";
      else if (isWilling) preferenceCategory = "willing";

      const maxServings = (f.max_servings_during as number) ??
        DEFAULT_MAX_SERVINGS;
      const minServings = (f.min_servings_during as number) ?? 1.0;

      return {
        id: f.id as string,
        name: f.name as string,
        display_name: (f.display_name as string) ?? null,
        display_name_plural: (f.display_name_plural as string) ?? null,
        description: (f.description as string) ?? null,
        image_address: (f.image_address as string) ?? null,
        serving_size: (f.serving_size as string) ?? null,
        serving_unit: (f.serving_unit as string) ?? null,
        serving_qualifier: (f.serving_qualifier as string) ?? null,
        per_serving: {
          carbs_g: safe(f.carbs_g as number),
          protein_g: safe(f.protein_g as number),
          fat_g: safe(f.fat_g as number),
          sodium_mg: safe(f.sodium_mg as number),
          water_ml: safe(f.fluid_ml as number),
          calories: safe(f.calories as number),
        },
        serving_amount: (f.serving_amount as number) ?? null,
        min_servings: minServings,
        max_servings: maxServings,
        preference_score: PREFERENCE_SCORE_MAP[preferenceCategory],
        is_electrolyte: (f.is_electrolyte as boolean) || false,
        is_liquid: (f.is_liquid as boolean) || false,
        is_essential: (f.is_essential as boolean) || false,
        is_user_food: false,
        is_indivisible: (f.is_indivisible as boolean) || false,
        solvent_min_ml: (f.solvent_min_ml as number | null) ?? null,
        product_type: (f.product_type as string) ?? undefined,
        // Constraint columns
        max_per_hr_low: f.max_per_hr_low as number | null ?? null,
        max_per_hr_moderate: f.max_per_hr_moderate as number | null ?? null,
        max_per_hr_high: f.max_per_hr_high as number | null ?? null,
        min_increment: f.min_increment as number | null ?? null,
        sodium_top_up_eligible: f.sodium_top_up_eligible as boolean | null ??
          null,
      };
    });
}

/**
 * Build a Map<food.name, FoodWithConstraints> for template solver lookups.
 */
export function buildFoodsByNameMap(
  foods: FoodWithConstraints[],
): Map<string, FoodWithConstraints> {
  const map = new Map<string, FoodWithConstraints>();
  for (const food of foods) {
    map.set(food.name, food);
  }
  return map;
}

/**
 * Build a Map<food.name, Food> for the post-workout template solver
 * (post solver works with the plain Food shape, not FoodWithConstraints).
 */
export function buildFoodMap(foods: Food[]): Map<string, Food> {
  const map = new Map<string, Food>();
  for (const food of foods) {
    map.set(food.name, food);
  }
  return map;
}

// ============================================================================
// Post-Workout Template Queries
// ============================================================================

/**
 * Fetch all active post_workout_templates from the database.
 */
export async function getPostWorkoutTemplates(
  supabase: SupabaseClient,
): Promise<PostWorkoutTemplate[]> {
  const { data, error } = await supabase
    .from("post_workout_templates")
    .select(`
      id, template_number, name, formula, portions,
      activity_types, component_food_names, component_ratios,
      default_servings, target_carb_protein_ratio,
      allergens, excluded_diets,
      travel_friendliness, flavor_profile, prep_effort, protein_anchor,
      carb_sources, selection_priority,
      notes, is_active
    `)
    .eq("is_active", true)
    .order("template_number");

  if (error) {
    console.log(
      "[PWT-QUERY] Error fetching post_workout_templates:",
      error,
    );
    return [];
  }

  const templates = (data ?? []) as PostWorkoutTemplate[];
  console.log(
    `[PWT-QUERY] Fetched ${templates.length} active post-workout templates`,
  );
  return templates;
}

