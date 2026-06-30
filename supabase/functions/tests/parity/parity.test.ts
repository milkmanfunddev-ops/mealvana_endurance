/**
 * Corpus-Driven Parity Test Harness
 * ===================================
 *
 * PROBLEM THIS SOLVES:
 *   Production bug where the generated nutrition plan does NOT meet the macro
 *   targets produced by the macro-generation step. This harness runs every
 *   athlete scenario fixture through the pure plan solver phases and asserts
 *   the resulting foods hit the targets within documented tolerance.
 *
 * ARCHITECTURE NOTE — pure pipeline seams:
 *   Macro targets → plan solver is separated as follows:
 *
 *   During phase (pure):
 *     generateDuringPhaseRuleBased(foods, targets, activityType)
 *     → Food[] (in-memory; no DB)
 *
 *   After phase (pure — template solver only, not LP):
 *     renderPostTemplatePortion(template, foodMap)
 *     → rendered portion (in-memory; no DB)
 *
 *   Personal formula overlay (pure):
 *     matchPersonalFormulaPin(pins, phase, activityType, durationMinutes)
 *     + personalFormulaToFoodResults(match, timing)
 *     → Food[] (no DB; uses snapshotted macros from fixture)
 *
 *   Since both DB-backed paths (template queries, LP solver with DB fallback)
 *   require Supabase, we drive the pure rule-solver path for during and the
 *   personal-formula path for pins — exactly the code paths that are newly
 *   in-flight on fix/vdot-sync-parity. The template solver and LP solver are
 *   already covered by algorithm-audit.test.ts.
 *
 * TOLERANCE CONSTANTS (see comments for rationale):
 *
 *   RELATIVE_TOLERANCE = 0.15 (15%)
 *     Why 15% not 10%? The system's MACRO_CONSTRAINT_RANGES already allow
 *     ±10% from the solver's inner bounds; discrete servings add ~5% rounding
 *     on top. The parity test uses actual catalog foods with integer/half-
 *     integer servings, so 15% is the honest "end-to-end" tolerance that
 *     reflects what a production plan can deliver.
 *
 *   ABSOLUTE_CARBS_G = 8g
 *     Floor so 10g targets don't fail on 7g solutions — small targets have
 *     noisy percentage error. Sports science: ±8g is clinically irrelevant.
 *
 *   ABSOLUTE_SODIUM_MG = 100mg
 *     Floor matching real product rounding (tablets are 200-350mg each).
 *
 *   ABSOLUTE_FLUID_ML = 100ml
 *     Floor: one sip of water is ±100ml in the real world.
 *
 * HOW TO ADD A REGRESSION FIXTURE:
 *   1. Capture the production input that produced the bad plan.
 *   2. Add a JSON file to fixtures/ following the existing schema.
 *   3. If the current algorithm also fails it, set "knownFailure": true in
 *      the fixture and describe the violation in "knownFailureReason".
 *      The test will WARN instead of FAIL so CI stays green while the fix
 *      is being worked.
 *
 * Run with:
 *   deno test --no-check --allow-read --allow-write \
 *     supabase/functions/tests/parity/parity.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";

import { generateDuringPhaseRuleBased } from "../../_shared/nutrition/during-rule-solver.ts";
import {
  matchPersonalFormulaPin,
  personalFormulaToFoodResults,
} from "../../_shared/nutrition/personal-formula-pins.ts";
import type { PersonalFormulaPin } from "../../_shared/nutrition/pins.ts";
import type { Food, FoodResult, MacroTargets } from "../../_shared/nutrition/types.ts";
import {
  makeFood,
  makeDuringFoods,
  makeDuringFoodsExtended,
  makeAfterFoods,
  makeRealDevDuringFoods,
  makeRealDevDuringFoodsExtended,
  makeRealDevAfterFoods,
  makeRealDevDuringFoodsWithConstraints,
} from "../../_shared/nutrition/test-utils.ts";
import {
  type DuringWorkoutTemplate,
  type FoodWithConstraints,
  generateDuringPhaseTemplate,
  selectTemplate,
} from "../../_shared/nutrition/during-template-solver.ts";
import { buildLPModel, solveLPModel } from "../../_shared/nutrition/lp-solver.ts";
import { DEFAULT_OPTIMIZATION_WEIGHTS } from "../../_shared/nutrition/constants.ts";

// ============================================================================
// Tolerance Constants
// ============================================================================

/** 15% relative tolerance — the honest end-to-end parity window.
 *  Combines solver inner bounds (±10%) with discrete-serving rounding (~5%). */
const RELATIVE_TOLERANCE = 0.15;

/** Absolute floor for carbs (g). Prevents noisy failures on tiny targets. */
const ABSOLUTE_CARBS_G = 8;

/** Absolute floor for sodium (mg). Matches tablet/capsule discrete rounding. */
const ABSOLUTE_SODIUM_MG = 100;

/** Absolute floor for fluid (ml). One cup of water tolerance. */
const ABSOLUTE_FLUID_ML = 100;

/** Protein tolerance: used only when target > 0 and for after-phase. */
const RELATIVE_PROTEIN_TOLERANCE = 0.20; // after-phase templates vary more

// ============================================================================
// Fixture Schema
// ============================================================================

interface AthleteFixture {
  description: string;
  /** When true: test reports as WARNING instead of FAIL — known algorithm gap. */
  knownFailure?: boolean;
  knownFailureReason?: string;
  /**
   * Which solver path to exercise for the during phase.
   *
   * - "rule" (default): generateDuringPhaseRuleBased — the standard path.
   * - "personal_formula": personal formula pin overlay (legacy default when
   *   pins.personalFormulas is populated — still the default for back-compat).
   * - "template": generateDuringPhaseTemplate via selectTemplate — used when
   *   a templateFixture is provided in the fixture.
   * - "lp": solveLPModel on the during-phase food catalog — tests the LP path
   *   without DB (uses makeDuringFoodsExtended as the food pool).
   */
  solver?: "rule" | "template" | "lp" | "personal_formula";
  /**
   * For solver="template": the template definition to use.
   * The fixture supplies one concrete DuringWorkoutTemplate; the harness
   * builds the food-pool from makeDuringFoodsExtended mapped to
   * FoodWithConstraints with sensible constraint defaults.
   */
  templateFixture?: {
    template_number: number;
    name: string;
    formula?: string;
    food_form?: string;
    activity_types: string[];
    duration_brackets: string[];
    gut_training_levels: string[];
    component_food_names: string[];
    component_carb_ratios: Record<string, number>;
    primary_to_secondary_ratio?: string | null;
    allergens?: string[];
    excluded_diets?: string[];
    selection_priority?: number | null;
  };
  athlete: {
    weight_kg: number;
    sex: "male" | "female";
  };
  workout: {
    activity_type: string;
    duration_minutes: number;
    gut_training_level: "low" | "moderate" | "high";
  };
  targets: {
    during_run?: MacroTargets;
    post_run?: MacroTargets & { protein_g?: number };
  };
  preferences: {
    liked_foods: string[];
    willing_to_try_foods: string[];
    disliked_foods: string[];
    allergies: string[];
    dietary_preference: string;
  };
  pins: {
    beforePinIds?: string[];
    duringPinIds?: string[];
    afterPinIds?: string[];
    personalFormulas?: PersonalFormulaPin[];
  } | null;
}

// ============================================================================
// In-Memory Food Catalog (real dev Supabase snapshot)
// ============================================================================

/**
 * Build the during-phase catalog using the real dev `template_foods` snapshot
 * (92 active rows, dumped 2026-06-23). Mirrors the default running path:
 * categories contains 'during_run' AND default_during=true OR is_essential=true.
 *
 * REPLACES makeDuringFoodsExtended() in parity tests so knownFailure fixtures
 * are validated against production-reality catalog capacity, not the synthetic
 * 8-food catalog.
 */
function buildDuringCatalog(): Food[] {
  return makeRealDevDuringFoodsExtended();
}

/**
 * Build the after-phase catalog using the real dev `template_foods` snapshot.
 * Includes all 31 after_run-eligible foods.
 *
 * The after-phase parity tests only check personal formula structural
 * invariants (no LP/template solve without DB), so catalog richness does not
 * change pass/fail — but correct catalog data is included for completeness.
 */
function buildAfterCatalog(): Food[] {
  return makeRealDevAfterFoods();
}

// ============================================================================
// Template Food Pool Builder
// ============================================================================

/**
 * Build the template-solver FoodWithConstraints pool from the real dev catalog
 * snapshot. Uses makeRealDevDuringFoodsWithConstraints() which reads the
 * committed __fixtures__/dev-food-catalog.json and maps:
 *   max_per_hr_low/moderate/high, min_increment, sodium_top_up_eligible
 * directly from the DB columns (no synthetic defaults needed).
 *
 * Also preserves the legacy synthetic-name aliases used by existing fixture
 * templates (energy-gel, energy-chews, etc.) so those fixtures continue to
 * resolve correctly via the real catalog entries.
 */
function buildTemplateFoodPool(): Map<string, FoodWithConstraints> {
  // Real catalog keyed by name (primary) and id (secondary).
  const pool = makeRealDevDuringFoodsWithConstraints();

  // Synthetic-name aliases from the legacy fixtures. Map old synthetic names
  // (energy-gel, sports-drink, etc.) to their real-catalog counterparts so
  // fixture templateFixture.component_food_names still resolve.
  const legacyAliasMap: Record<string, string> = {
    "energy-gel": "energy_gel",
    "energy-chews": "energy_chews",
    "sports-drink": "sports_drink",
    "high-carb-mix": "high_carb_drink_mix",
    "electrolyte-tab": "electrolyte_tablet",
    "energy-bar": "energy_bar",        // not in real catalog during_run; tolerate missing
    "high-sodium-mix": "high_sodium_electrolyte_mix",
    "electrolyte-capsule": "electrolyte_capsule",
  };

  for (const [legacyKey, realName] of Object.entries(legacyAliasMap)) {
    const source = pool.get(realName);
    if (source && !pool.has(legacyKey)) {
      pool.set(legacyKey, source);
    }
  }

  return pool;
}

// ============================================================================
// Totals Helper
// ============================================================================

interface PhaseTotals {
  carbs_g: number;
  protein_g: number;
  sodium_mg: number;
  water_ml: number;
  calories: number;
}

function sumFoods(foods: FoodResult[]): PhaseTotals {
  return foods.reduce(
    (acc, f) => ({
      carbs_g: acc.carbs_g + f.carbs_grams,
      protein_g: acc.protein_g + f.protein_grams,
      sodium_mg: acc.sodium_mg + f.sodium_mg,
      water_ml: acc.water_ml + f.fluids_ml,
      calories: acc.calories + (f.calories ?? 0),
    }),
    { carbs_g: 0, protein_g: 0, sodium_mg: 0, water_ml: 0, calories: 0 },
  );
}

// ============================================================================
// Parity Assertion
// ============================================================================

interface ParityCheckResult {
  passed: boolean;
  issues: string[];
  warnings: string[];
}

/**
 * Check whether totals meet targets within the documented tolerance.
 *
 * Pass condition for each macro:
 *   |actual - target| <= max(RELATIVE_TOLERANCE × target, ABSOLUTE_FLOOR)
 *
 * When target is 0, we skip the check (0-target means "not required for this
 * phase"; emitting non-zero is fine).
 */
function checkParity(
  phase: "during" | "after",
  totals: PhaseTotals,
  targets: MacroTargets,
): ParityCheckResult {
  const issues: string[] = [];
  const warnings: string[] = [];

  function checkMacro(
    name: string,
    actual: number,
    target: number,
    relativeTol: number,
    absoluteFloor: number,
  ): void {
    if (target <= 0) return; // not required
    const delta = Math.abs(actual - target);
    const allowedDelta = Math.max(relativeTol * target, absoluteFloor);
    if (delta > allowedDelta) {
      issues.push(
        `[${phase}] ${name}: actual=${actual.toFixed(1)} target=${target} ` +
          `delta=${delta.toFixed(1)} allowed=${allowedDelta.toFixed(1)} ` +
          `(${(delta / target * 100).toFixed(1)}% off)`,
      );
    }
  }

  checkMacro("carbs", totals.carbs_g, targets.carbs_g, RELATIVE_TOLERANCE, ABSOLUTE_CARBS_G);
  checkMacro("sodium", totals.sodium_mg, targets.sodium_mg, RELATIVE_TOLERANCE, ABSOLUTE_SODIUM_MG);
  checkMacro("fluid", totals.water_ml, targets.water_ml, RELATIVE_TOLERANCE, ABSOLUTE_FLUID_ML);

  // protein: after-phase only (during targets typically have no protein_g)
  if (phase === "after" && (targets.protein_g ?? 0) > 0) {
    checkMacro(
      "protein",
      totals.protein_g,
      targets.protein_g!,
      RELATIVE_PROTEIN_TOLERANCE,
      5, // 5g absolute floor for protein
    );
  }

  return { passed: issues.length === 0, issues, warnings };
}

// ============================================================================
// Structural Invariant Checks
// ============================================================================

/**
 * Invariants that must hold for EVERY plan regardless of targets:
 *  - No NaN, Infinity, or negative quantities in any food result
 *  - Every food_id is a non-empty string
 *  - When a personal formula was used, its food names appear in the output
 */
function checkInvariants(
  phase: string,
  foods: FoodResult[],
  appliedPersonalFormula: PersonalFormulaPin | null,
): string[] {
  const violations: string[] = [];

  for (const f of foods) {
    const label = `${phase}/${f.food_id ?? "unknown"}`;
    if (!f.food_id || f.food_id.trim() === "") {
      violations.push(`${label}: food_id is empty`);
    }
    if (!isFinite(f.quantity) || f.quantity < 0) {
      violations.push(`${label}: quantity=${f.quantity} is invalid`);
    }
    if (!isFinite(f.carbs_grams) || f.carbs_grams < 0) {
      violations.push(`${label}: carbs_grams=${f.carbs_grams} is invalid`);
    }
    if (!isFinite(f.protein_grams) || f.protein_grams < 0) {
      violations.push(`${label}: protein_grams=${f.protein_grams} is invalid`);
    }
    if (!isFinite(f.fat_grams) || f.fat_grams < 0) {
      violations.push(`${label}: fat_grams=${f.fat_grams} is invalid`);
    }
    if (!isFinite(f.sodium_mg) || f.sodium_mg < 0) {
      violations.push(`${label}: sodium_mg=${f.sodium_mg} is invalid`);
    }
    if (!isFinite(f.fluids_ml) || f.fluids_ml < 0) {
      violations.push(`${label}: fluids_ml=${f.fluids_ml} is invalid`);
    }
    if (!isFinite(f.calories) || f.calories < 0) {
      violations.push(`${label}: calories=${f.calories} is invalid`);
    }
  }

  // If a personal formula was supposed to fire, its components must appear.
  if (appliedPersonalFormula !== null) {
    const outputIds = new Set(foods.map((f) => f.food_id));
    for (const c of appliedPersonalFormula.components) {
      const expectedId = (c.food_id as string | undefined) ??
        (c.food_name as string | undefined) ?? "";
      if (expectedId && !outputIds.has(expectedId)) {
        violations.push(
          `${phase}: personal formula "${appliedPersonalFormula.name}" component ` +
            `"${expectedId}" is missing from output foods`,
        );
      }
    }
  }

  return violations;
}

/**
 * Check disliked foods do not appear in the output.
 */
function checkNoDislikedFoods(
  phase: string,
  foods: FoodResult[],
  dislikedFoods: string[],
  appliedPersonalFormula: PersonalFormulaPin | null,
): string[] {
  if (dislikedFoods.length === 0) return [];
  // Personal formula components are explicitly exempt from dislike filtering
  // per the locked pin policy (2026-05-21). Only flag algorithmic foods.
  if (appliedPersonalFormula !== null) return [];

  const dislikedSet = new Set(dislikedFoods.map((d) => d.toLowerCase()));
  const violations: string[] = [];
  for (const f of foods) {
    const name = (f.display_name ?? f.food_id ?? "").toLowerCase();
    const id = (f.food_id ?? "").toLowerCase();
    if (dislikedSet.has(name) || dislikedSet.has(id)) {
      violations.push(
        `${phase}: disliked food "${f.display_name ?? f.food_id}" appeared in output`,
      );
    }
  }
  return violations;
}

// ============================================================================
// Fixture Loader
// ============================================================================

async function loadFixtures(): Promise<AthleteFixture[]> {
  const fixturesDir = new URL("./fixtures/", import.meta.url).pathname;
  const fixtures: AthleteFixture[] = [];

  for await (const entry of Deno.readDir(fixturesDir)) {
    if (!entry.name.endsWith(".json")) continue;
    const path = `${fixturesDir}${entry.name}`;
    const raw = await Deno.readTextFile(path);
    try {
      const fixture = JSON.parse(raw) as AthleteFixture;
      fixtures.push(fixture);
    } catch (e) {
      throw new Error(`Failed to parse fixture ${entry.name}: ${e}`);
    }
  }

  // Sort by filename for deterministic ordering
  return fixtures.sort((a, b) => a.description.localeCompare(b.description));
}

// ============================================================================
// During-Phase Parity Runner
// ============================================================================

/**
 * Run the during-phase parity check for a single fixture.
 *
 * Pipeline (solver routing):
 *   personal_formula (explicit or auto-detected from pins.personalFormulas):
 *     matchPersonalFormulaPin → personalFormulaToFoodResults
 *     → check invariants only (parity bypassed by design — user-authored formula)
 *
 *   rule (default):
 *     generateDuringPhaseRuleBased(in-memory catalog, targets, activity)
 *     → check parity + invariants
 *
 *   template (fixture.solver === "template"):
 *     selectTemplate → generateDuringPhaseTemplate(in-memory pool, targets)
 *     → check parity + invariants
 *     Requires fixture.templateFixture to be set. If selectTemplate returns
 *     null (template not compatible) the test fails unless knownFailure.
 *
 *   lp (fixture.solver === "lp"):
 *     buildLPModel + solveLPModel on makeDuringFoodsExtended()
 *     → check parity + invariants
 *     If LP returns null (infeasible), the test fails unless knownFailure.
 *
 * KEY DESIGN DECISION for personal formula fixtures:
 *   Personal formulas bypass macro targets BY DESIGN (locked pin policy
 *   2026-05-21). The user authored the formula; the algorithm honors it
 *   unconditionally. Therefore when a personal formula fires, we check:
 *     (a) structural invariants (no NaN/negative/empty food_id)
 *     (b) all formula components appear in the output
 *   but we SKIP macro parity against targets — this is not a bug.
 *   The caller (main test loop) is told `path="personal_formula"` and
 *   skips the parity assertion accordingly.
 */
function runDuringPhaseParity(
  fixture: AthleteFixture,
  catalog: Food[],
): { passed: boolean; issues: string[]; path: string; formulaFired: boolean } {
  const { workout, targets, preferences, pins } = fixture;
  const duringTargets = targets.during_run;
  if (!duringTargets) return { passed: true, issues: [], path: "skipped", formulaFired: false };

  const personalFormulas: PersonalFormulaPin[] = pins?.personalFormulas ?? [];

  // Determine effective solver: explicit field overrides auto-detection,
  // but personal formula match always wins when it fires (matching existing
  // behavior for back-compat with all existing fixtures).
  const explicitSolver = fixture.solver ?? "rule";

  // --- Step 1: personal formula override (fires regardless of explicit solver) ---
  const matchedFormula = personalFormulas.length > 0
    ? matchPersonalFormulaPin(
      personalFormulas,
      "during",
      workout.activity_type,
      workout.duration_minutes,
    )
    : null;

  let duringFoods: FoodResult[];
  let path: string;

  if (matchedFormula !== null) {
    // Personal formula always wins when in scope — matches production behavior.
    duringFoods = personalFormulaToFoodResults(matchedFormula, "Throughout activity");
    path = "personal_formula";
  } else if (explicitSolver === "template") {
    // --- Template solver path ---
    const tf = fixture.templateFixture;
    if (!tf) {
      return {
        passed: false,
        issues: ["solver='template' requires a templateFixture in the fixture JSON"],
        path: "template",
        formulaFired: false,
      };
    }

    const templatePool = buildTemplateFoodPool();
    const template: DuringWorkoutTemplate = {
      id: `parity-template-${tf.template_number}`,
      template_number: tf.template_number,
      name: tf.name,
      formula: tf.formula ?? tf.name,
      food_form: tf.food_form ?? "Mixed",
      activity_types: tf.activity_types,
      duration_brackets: tf.duration_brackets,
      gut_training_levels: tf.gut_training_levels as ("low" | "moderate" | "high")[],
      component_food_names: tf.component_food_names,
      component_carb_ratios: tf.component_carb_ratios,
      primary_to_secondary_ratio: tf.primary_to_secondary_ratio ?? null,
      allergens: tf.allergens ?? [],
      excluded_diets: tf.excluded_diets ?? [],
      notes: null,
      is_active: true,
      selection_priority: tf.selection_priority ?? null,
    };

    const templateResult = generateDuringPhaseTemplate(
      template,
      templatePool,
      duringTargets,
      workout.duration_minutes,
      workout.gut_training_level,
    );

    if (templateResult === null) {
      return {
        passed: false,
        issues: [
          `Template solver returned null for template "${tf.name}" — targets may exceed template capacity. ` +
            `carbs=${duringTargets.carbs_g}g sodium=${duringTargets.sodium_mg}mg fluid=${duringTargets.water_ml}ml ` +
            `duration=${workout.duration_minutes}min gut=${workout.gut_training_level}`,
        ],
        path: "template",
        formulaFired: false,
      };
    }

    duringFoods = templateResult.foods;
    path = "template";
  } else if (explicitSolver === "lp") {
    // --- LP solver path ---
    const lpFoods = catalog; // uses the passed-in during catalog (makeDuringFoodsExtended)
    const filteredLP = applyPreferenceFilters(lpFoods, preferences.disliked_foods);
    const weights = DEFAULT_OPTIMIZATION_WEIGHTS.during;
    const model = buildLPModel(filteredLP, duringTargets, "during", weights);
    const lpResult = solveLPModel(model, filteredLP, "during");

    if (lpResult === null) {
      return {
        passed: false,
        issues: [
          `LP solver returned null (infeasible) for during phase. ` +
            `carbs=${duringTargets.carbs_g}g sodium=${duringTargets.sodium_mg}mg fluid=${duringTargets.water_ml}ml`,
        ],
        path: "lp",
        formulaFired: false,
      };
    }

    // Map PhaseSolution.foods to FoodResult[]
    duringFoods = lpResult.foods;
    path = "lp";
  } else {
    // --- Default: rule-based solver ---
    const filteredCatalog = applyPreferenceFilters(
      catalog,
      preferences.disliked_foods,
    );
    const result = generateDuringPhaseRuleBased(
      filteredCatalog,
      duringTargets,
      workout.activity_type as Parameters<typeof generateDuringPhaseRuleBased>[2],
    );
    duringFoods = result.foods;
    path = "rule_solver";
  }

  const invariantViolations = checkInvariants("during", duringFoods, matchedFormula);
  const dislikedViolations = checkNoDislikedFoods(
    "during",
    duringFoods,
    preferences.disliked_foods,
    matchedFormula,
  );

  // Macro parity: skip for personal_formula (user-authored, bypasses targets by design).
  let parityIssues: string[] = [];
  if (path !== "personal_formula") {
    const totals = sumFoods(duringFoods);
    const parityResult = checkParity("during", totals, duringTargets);
    parityIssues = parityResult.issues;
  }

  const allIssues = [...parityIssues, ...invariantViolations, ...dislikedViolations];

  return {
    passed: allIssues.length === 0,
    issues: allIssues,
    path,
    formulaFired: matchedFormula !== null,
  };
}

// ============================================================================
// After-Phase Parity Runner
// ============================================================================

/**
 * Run the after-phase parity check for a single fixture.
 *
 * Pipeline:
 *   1. Check for in-scope personal formula → emit its components.
 *   2. If no personal formula, skip deep parity (template solver needs DB).
 *
 * Macro parity is skipped for personal formula output — same rationale as
 * during phase (user-authored formulas bypass target constraints by design).
 */
function runAfterPhaseParity(
  fixture: AthleteFixture,
  _catalog: Food[],
): { passed: boolean; issues: string[]; path: string; formulaFired: boolean } {
  const { workout, targets, preferences, pins } = fixture;
  const postTargets = targets.post_run;
  if (!postTargets) return { passed: true, issues: [], path: "skipped", formulaFired: false };

  const personalFormulas: PersonalFormulaPin[] = pins?.personalFormulas ?? [];

  const matchedFormula = personalFormulas.length > 0
    ? matchPersonalFormulaPin(
      personalFormulas,
      "after",
      workout.activity_type,
    )
    : null;

  if (matchedFormula === null) {
    return { passed: true, issues: [], path: "no_personal_formula_skip", formulaFired: false };
  }

  const afterFoods = personalFormulaToFoodResults(matchedFormula, "Within 30 minutes");

  // Check structural invariants + dislike exclusions only; no macro parity.
  const invariantViolations = checkInvariants("after", afterFoods, matchedFormula);
  const dislikedViolations = checkNoDislikedFoods(
    "after",
    afterFoods,
    preferences.disliked_foods,
    matchedFormula,
  );

  const allIssues = [...invariantViolations, ...dislikedViolations];

  return {
    passed: allIssues.length === 0,
    issues: allIssues,
    path: "personal_formula",
    formulaFired: true,
  };
}

// ============================================================================
// Preference Filtering (lightweight approximation for catalog)
// ============================================================================

/**
 * Apply dislike filtering to the in-memory catalog. This is a lightweight
 * approximation of what the DB query does with SQL WHERE clauses. We only
 * filter by disliked_foods here — diet/allergy filtering is tested
 * separately in algorithm-audit.test.ts.
 */
function applyPreferenceFilters(
  catalog: Food[],
  dislikedFoods: string[],
): Food[] {
  if (dislikedFoods.length === 0) return catalog;
  const dislikedSet = new Set(dislikedFoods.map((d) => d.toLowerCase()));
  return catalog.filter((f) => {
    const name = f.name.toLowerCase();
    const id = f.id.toLowerCase();
    return !dislikedSet.has(name) && !dislikedSet.has(id);
  });
}

// ============================================================================
// Corpus-Driven Test Loop
// ============================================================================

/**
 * Format a detailed failure report so a failing CI run immediately shows
 * what fixture failed and what the full computed state was.
 */
function formatFailureReport(
  fixture: AthleteFixture,
  phase: string,
  issues: string[],
  foods: FoodResult[],
  targets: MacroTargets | undefined,
): string {
  const totals = sumFoods(foods);
  return [
    `\n${"═".repeat(70)}`,
    `PARITY FAILURE: ${fixture.description}`,
    `Phase: ${phase}`,
    `Fixture targets: ${JSON.stringify(targets)}`,
    `Actual totals: carbs=${totals.carbs_g.toFixed(1)}g protein=${totals.protein_g.toFixed(1)}g sodium=${totals.sodium_mg.toFixed(0)}mg fluid=${totals.water_ml.toFixed(0)}ml`,
    `Issues:`,
    ...issues.map((i) => `  - ${i}`),
    `Foods (${foods.length}):`,
    ...foods.map(
      (f) =>
        `  ${f.quantity}x ${f.display_name ?? f.food_id}: ` +
        `carbs=${f.carbs_grams.toFixed(1)}g protein=${f.protein_grams.toFixed(1)}g ` +
        `sodium=${f.sodium_mg.toFixed(0)}mg fluid=${f.fluids_ml.toFixed(0)}ml`,
    ),
    `Full fixture JSON: ${JSON.stringify(fixture, null, 2)}`,
    `${"═".repeat(70)}\n`,
  ].join("\n");
}

// ============================================================================
// MAIN TEST REGISTRATIONS
// ============================================================================

// Load fixtures synchronously via top-level await (Deno supports this).
// We register individual Deno.test() calls per fixture for clean CI output.

const _fixtures = await loadFixtures();

// Sanity check: make sure we loaded the expected minimum number of fixtures.
Deno.test("parity fixtures: minimum corpus size", () => {
  assert(
    _fixtures.length >= 30,
    `Expected at least 30 fixtures, found ${_fixtures.length}. ` +
      `Check that supabase/functions/tests/parity/fixtures/*.json files exist.`,
  );
  console.log(`[PARITY] Loaded ${_fixtures.length} athlete scenario fixtures.`);
});

// Register one test per fixture for clear per-scenario CI output.
for (const fixture of _fixtures) {
  const label = fixture.description.slice(0, 80);

  Deno.test(`parity: ${label}`, async () => {
    const duringCatalog = buildDuringCatalog();
    const afterCatalog = buildAfterCatalog();

    // --- During phase ---
    const duringResult = runDuringPhaseParity(fixture, duringCatalog);

    // --- After phase ---
    const afterResult = runAfterPhaseParity(fixture, afterCatalog);

    // --- Extra assertion: if the fixture HAS an in-scope personal formula,
    //     the formula MUST have fired (behavioral correctness of new behavior).
    const duringPersonalFormulas: PersonalFormulaPin[] = fixture.pins?.personalFormulas?.filter(
      (pf) => pf.phase === "during",
    ) ?? [];
    if (duringPersonalFormulas.length > 0) {
      // Check whether any is in scope
      const anyInScope = duringPersonalFormulas.some((pf) =>
        matchPersonalFormulaPin(
          [pf],
          "during",
          fixture.workout.activity_type,
          fixture.workout.duration_minutes,
        ) !== null
      );
      if (anyInScope && !duringResult.formulaFired) {
        throw new Error(
          `[PARITY] Fixture "${fixture.description}": expected during personal formula to fire but it did not. ` +
            `Check matchPersonalFormulaPin scope rules.`,
        );
      }
      if (!anyInScope && duringResult.formulaFired) {
        throw new Error(
          `[PARITY] Fixture "${fixture.description}": during personal formula fired but should be out of scope.`,
        );
      }
    }

    const afterPersonalFormulas: PersonalFormulaPin[] = fixture.pins?.personalFormulas?.filter(
      (pf) => pf.phase === "after",
    ) ?? [];
    if (afterPersonalFormulas.length > 0) {
      const anyInScope = afterPersonalFormulas.some((pf) =>
        matchPersonalFormulaPin(
          [pf],
          "after",
          fixture.workout.activity_type,
        ) !== null
      );
      if (anyInScope && !afterResult.formulaFired) {
        throw new Error(
          `[PARITY] Fixture "${fixture.description}": expected after personal formula to fire but it did not.`,
        );
      }
      if (!anyInScope && afterResult.formulaFired) {
        throw new Error(
          `[PARITY] Fixture "${fixture.description}": after personal formula fired but should be out of scope.`,
        );
      }
    }

    const allIssues = [...duringResult.issues, ...afterResult.issues];

    if (allIssues.length > 0) {
      if (fixture.knownFailure === true) {
        // Known gap: warn but don't fail CI. Include a clear TODO.
        console.warn(
          `[PARITY WARNING — KNOWN FAILURE] ${fixture.description}\n` +
            `Reason: ${fixture.knownFailureReason ?? "(none given)"}\n` +
            `TODO: Fix before removing knownFailure flag.\n` +
            `Issues:\n${allIssues.map((i) => `  - ${i}`).join("\n")}`,
        );
        return; // pass the test as a warning
      }

      // Build a detailed failure report for CI.
      // Re-use the already-computed result from runDuringPhaseParity so we don't
      // re-execute the solver. duringResult.issues already contains all failures.
      const duringFoods: FoodResult[] = (() => {
        // Re-invoke the same runner to get the foods for the report.
        // This is intentionally a second run (idempotent) — the solver is pure.
        const personalFormulas: PersonalFormulaPin[] = fixture.pins?.personalFormulas ?? [];
        const matchedFormula = personalFormulas.length > 0
          ? matchPersonalFormulaPin(
            personalFormulas,
            "during",
            fixture.workout.activity_type,
            fixture.workout.duration_minutes,
          )
          : null;
        if (matchedFormula) {
          return personalFormulaToFoodResults(matchedFormula, "Throughout activity");
        }
        if (!fixture.targets.during_run) return [];
        const explicitSolver = fixture.solver ?? "rule";
        if (explicitSolver === "template" && fixture.templateFixture) {
          const tf = fixture.templateFixture;
          const pool = buildTemplateFoodPool();
          const tmpl: DuringWorkoutTemplate = {
            id: `parity-template-${tf.template_number}`,
            template_number: tf.template_number,
            name: tf.name,
            formula: tf.formula ?? tf.name,
            food_form: tf.food_form ?? "Mixed",
            activity_types: tf.activity_types,
            duration_brackets: tf.duration_brackets,
            gut_training_levels: tf.gut_training_levels as ("low" | "moderate" | "high")[],
            component_food_names: tf.component_food_names,
            component_carb_ratios: tf.component_carb_ratios,
            primary_to_secondary_ratio: tf.primary_to_secondary_ratio ?? null,
            allergens: tf.allergens ?? [],
            excluded_diets: tf.excluded_diets ?? [],
            notes: null,
            is_active: true,
            selection_priority: tf.selection_priority ?? null,
          };
          return generateDuringPhaseTemplate(
            tmpl, pool, fixture.targets.during_run,
            fixture.workout.duration_minutes, fixture.workout.gut_training_level,
          )?.foods ?? [];
        }
        if (explicitSolver === "lp") {
          const filtered = applyPreferenceFilters(duringCatalog, fixture.preferences.disliked_foods);
          const weights = DEFAULT_OPTIMIZATION_WEIGHTS.during;
          const model = buildLPModel(filtered, fixture.targets.during_run, "during", weights);
          return solveLPModel(model, filtered, "during")?.foods ?? [];
        }
        const filtered = applyPreferenceFilters(duringCatalog, fixture.preferences.disliked_foods);
        return generateDuringPhaseRuleBased(
          filtered,
          fixture.targets.during_run,
          fixture.workout.activity_type as Parameters<typeof generateDuringPhaseRuleBased>[2],
        ).foods;
      })();

      const report = formatFailureReport(
        fixture,
        `during(${duringResult.path}) / after(${afterResult.path})`,
        allIssues,
        duringFoods,
        fixture.targets.during_run,
      );

      throw new Error(report);
    }

    const formulaSummary = duringResult.formulaFired || afterResult.formulaFired
      ? ` [formula:during=${duringResult.formulaFired} after=${afterResult.formulaFired}]`
      : "";
    console.log(
      `[PARITY OK] ${fixture.description.slice(0, 60)} | ` +
        `during=${duringResult.path} after=${afterResult.path}${formulaSummary}`,
    );
  });
}

// ============================================================================
// Personal Formula: explicit behavioral assertions (new in-flight behavior)
// ============================================================================

Deno.test("personal formula: during — in-scope formula overrides solver", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-test-001",
    name: "Test Gel Stack",
    phase: "during",
    activities: ["running"],
    durations: ["90-150 min"],
    subPhase: null,
    components: [
      {
        food_id: "energy-gel",
        food_name: "Energy Gel",
        quantity: 3,
        serving_unit: "gel",
        source: "template",
        carbs_per_serving: 25,
        protein_per_serving: 0,
        fat_per_serving: 0,
        sodium_mg: 55,
        fluid_ml_per_serving: 0,
        calories_per_serving: 100,
      },
    ],
  };

  const match = matchPersonalFormulaPin([formula], "during", "running", 120);
  assertExists(match, "Formula in scope for running/120min should match");
  assertEquals(match!.id, "pf-test-001");

  const foods = personalFormulaToFoodResults(match!, "Throughout activity");
  assertEquals(foods.length, 1);
  assertEquals(foods[0].food_id, "energy-gel");
  assertEquals(foods[0].carbs_grams, 75); // 25 * 3
  assertEquals(foods[0].sodium_mg, 165); // 55 * 3
  assertEquals(foods[0].calories, 300); // 100 * 3
});

Deno.test("personal formula: during — out-of-scope activity does not match", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-cycling-only",
    name: "Cycling Only",
    phase: "during",
    activities: ["cycling"],
    durations: null,
    subPhase: null,
    components: [],
  };

  const match = matchPersonalFormulaPin([formula], "during", "running", 120);
  assertEquals(match, null, "Cycling-scoped formula must not match a running workout");
});

Deno.test("personal formula: during — wrong duration bracket does not match", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-ultra",
    name: "Ultra Only",
    phase: "during",
    activities: ["running"],
    durations: ["> 240 min"],
    subPhase: null,
    components: [],
  };

  // 120 min = "90-150 min" bracket — should NOT match "> 240 min"
  const noMatch = matchPersonalFormulaPin([formula], "during", "running", 120);
  assertEquals(noMatch, null, "120-min workout should not match >240 min bracket");

  // 300 min = "> 240 min" bracket — SHOULD match
  const match = matchPersonalFormulaPin([formula], "during", "running", 300);
  assertExists(match, "300-min workout should match >240 min bracket");
});

Deno.test("personal formula: after — in-scope activity matches", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-after-run",
    name: "Post Run Recovery",
    phase: "after",
    activities: ["running"],
    durations: null,
    subPhase: null,
    components: [
      {
        food_id: "protein-shake",
        food_name: "Protein Shake",
        quantity: 1,
        serving_unit: "scoop",
        source: "template",
        carbs_per_serving: 5,
        protein_per_serving: 25,
        fat_per_serving: 2,
        sodium_mg: 200,
        fluid_ml_per_serving: 350,
        calories_per_serving: 150,
      },
    ],
  };

  const match = matchPersonalFormulaPin([formula], "after", "running");
  assertExists(match, "After formula scoped to running should match running workout");

  const foods = personalFormulaToFoodResults(match!, "Within 30 minutes");
  assertEquals(foods.length, 1);
  assertEquals(foods[0].protein_grams, 25);
  assertEquals(foods[0].fluids_ml, 350);
  assertEquals(foods[0].timing, "Within 30 minutes");
});

Deno.test("personal formula: after — wrong activity does not match", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-after-swim",
    name: "Post Swim",
    phase: "after",
    activities: ["swimming"],
    durations: null,
    subPhase: null,
    components: [],
  };

  const match = matchPersonalFormulaPin([formula], "after", "running");
  assertEquals(match, null, "Swimming-scoped after formula must not match running");
});

Deno.test("personal formula: before — matches on phase only (ignores activity scope)", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-before-meal",
    name: "Pre Race Oats",
    phase: "before",
    activities: ["cycling"], // activity scope is ignored for before phase per spec
    durations: null,
    subPhase: "full_meal",
    components: [
      {
        food_id: "oatmeal",
        food_name: "Oatmeal",
        quantity: 2,
        serving_unit: "cup",
        source: "template",
        carbs_per_serving: 27,
        protein_per_serving: 5,
        fat_per_serving: 3,
        sodium_mg: 0,
        fluid_ml_per_serving: 100,
        calories_per_serving: 150,
      },
    ],
  };

  // Spec: before phase matches on phase only — activity scope is irrelevant.
  const match = matchPersonalFormulaPin([formula], "before", "running");
  assertExists(match, "Before formula should match regardless of activity scope");
  assertEquals(match!.id, "pf-before-meal");

  const foods = personalFormulaToFoodResults(match!, "3 hours before");
  assertEquals(foods.length, 1);
  assertEquals(foods[0].carbs_grams, 54); // 27 * 2
  assertEquals(foods[0].calories, 300); // 150 * 2
});

Deno.test("personal formula: zero-quantity components are skipped", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-zero-qty",
    name: "Zero Test",
    phase: "during",
    activities: null,
    durations: null,
    subPhase: null,
    components: [
      { food_id: "gel", food_name: "Gel", quantity: 0, carbs_per_serving: 25 },
      { food_id: "drink", food_name: "Drink", quantity: 2, carbs_per_serving: 15, sodium_mg: 100, fluid_ml_per_serving: 200 },
    ],
  };

  const foods = personalFormulaToFoodResults(formula, "x");
  assertEquals(foods.length, 1, "Zero-quantity component must be skipped");
  assertEquals(foods[0].food_id, "drink");
});

Deno.test("personal formula: triathlon maps to triathlon_bike sub-activity", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-tri-bike",
    name: "Tri Bike",
    phase: "during",
    activities: ["triathlon_bike"],
    durations: null,
    subPhase: null,
    components: [{ food_id: "f", food_name: "F", quantity: 1, carbs_per_serving: 10 }],
  };

  // triathlon activity type maps to ["running","cycling","swimming","triathlon_bike","triathlon_run",...]
  const match = matchPersonalFormulaPin([formula], "during", "triathlon", 150);
  assertExists(match, "triathlon_bike pin should match triathlon activity");
});

Deno.test("personal formula: null activities/durations matches any workout", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-universal",
    name: "Universal Formula",
    phase: "during",
    activities: null,
    durations: null,
    subPhase: null,
    components: [{ food_id: "g", food_name: "G", quantity: 1, carbs_per_serving: 20 }],
  };

  assertEquals(matchPersonalFormulaPin([formula], "during", "running", 60)?.id, "pf-universal");
  assertEquals(matchPersonalFormulaPin([formula], "during", "cycling", 180)?.id, "pf-universal");
  assertEquals(matchPersonalFormulaPin([formula], "during", "swimming", 45)?.id, "pf-universal");
});

// ============================================================================
// Duration Bracket Edge Cases
// ============================================================================

Deno.test("duration bracket: 89 min maps to <90 min", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-short",
    name: "Short Bracket",
    phase: "during",
    activities: ["running"],
    durations: ["< 90 min"],
    subPhase: null,
    components: [{ food_id: "g", food_name: "G", quantity: 1, carbs_per_serving: 10 }],
  };

  assertExists(matchPersonalFormulaPin([formula], "during", "running", 89));
  assertEquals(matchPersonalFormulaPin([formula], "during", "running", 90), null);
});

Deno.test("duration bracket: 90 min maps to 90-150 min", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-90",
    name: "90-150 Bracket",
    phase: "during",
    activities: ["running"],
    durations: ["90-150 min"],
    subPhase: null,
    components: [{ food_id: "g", food_name: "G", quantity: 1, carbs_per_serving: 10 }],
  };

  assertExists(matchPersonalFormulaPin([formula], "during", "running", 90));
  assertExists(matchPersonalFormulaPin([formula], "during", "running", 150));
  assertEquals(matchPersonalFormulaPin([formula], "during", "running", 151), null);
});

Deno.test("duration bracket: 241 min maps to >240 min", () => {
  const formula: PersonalFormulaPin = {
    id: "pf-ultra",
    name: "Ultra Bracket",
    phase: "during",
    activities: ["running"],
    durations: ["> 240 min"],
    subPhase: null,
    components: [{ food_id: "g", food_name: "G", quantity: 1, carbs_per_serving: 10 }],
  };

  assertEquals(matchPersonalFormulaPin([formula], "during", "running", 240), null);
  assertExists(matchPersonalFormulaPin([formula], "during", "running", 241));
});

// ============================================================================
// Rule Solver Invariants (standalone, no fixture loop)
// ============================================================================

Deno.test("rule solver: no NaN or negative quantities on standard target", () => {
  const catalog = buildDuringCatalog();
  const targets: MacroTargets = {
    carbs_g: 60,
    sodium_mg: 900,
    water_ml: 900,
  };
  const result = generateDuringPhaseRuleBased(catalog, targets, "running");
  const violations = checkInvariants("during", result.foods, null);
  assertEquals(
    violations,
    [],
    `Rule solver produced invalid values: ${violations.join("; ")}`,
  );
});

Deno.test("rule solver: no NaN or negative quantities on ultra target", () => {
  const catalog = buildDuringCatalog();
  const targets: MacroTargets = {
    carbs_g: 120,
    sodium_mg: 2000,
    water_ml: 2500,
  };
  const result = generateDuringPhaseRuleBased(catalog, targets, "running");
  const violations = checkInvariants("during", result.foods, null);
  assertEquals(
    violations,
    [],
    `Rule solver produced invalid values on ultra target: ${violations.join("; ")}`,
  );
});

Deno.test("rule solver: zero carb target returns empty or minimal foods", () => {
  const catalog = buildDuringCatalog();
  const targets: MacroTargets = {
    carbs_g: 0,
    sodium_mg: 200,
    water_ml: 300,
  };
  const result = generateDuringPhaseRuleBased(catalog, targets, "running");
  // Should not error and should not return NaN
  const violations = checkInvariants("during", result.foods, null);
  assertEquals(violations, [], "Zero-carb target must not produce invalid values");
});
