/**
 * Test Utilities for Nutrition Solver Unit Tests
 *
 * Provides log capture, mock food factories, and assertion helpers
 * so tests can run locally without Supabase.
 */

import type { Food, MacroTargets, PhaseSolution, FoodNutrition } from './types.ts';
import type { FoodWithConstraints } from './during-template-solver.ts';

// ============================================================================
// Log Capture
// ============================================================================

export interface LogEntry {
  timestamp: number;
  level: 'log' | 'warn' | 'error';
  prefix: string;
  message: string;
  raw: string;
}

/**
 * Captures console.log/warn/error calls during test execution.
 * Stores entries with parsed prefix (e.g. "[LP-SOLVER]") for filtering.
 */
export class LogCapture {
  entries: LogEntry[] = [];
  private _origLog = console.log;
  private _origWarn = console.warn;
  private _origError = console.error;
  private _active = false;

  /** Start intercepting console output */
  start(): void {
    if (this._active) return;
    this._active = true;

    const capture = (level: LogEntry['level']) => (...args: unknown[]) => {
      const raw = args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' ');
      const prefixMatch = raw.match(/^\[([A-Z0-9_-]+)\]/);
      this.entries.push({
        timestamp: Date.now(),
        level,
        prefix: prefixMatch ? prefixMatch[1] : '',
        message: prefixMatch ? raw.slice(prefixMatch[0].length).trim() : raw,
        raw,
      });
    };

    console.log = capture('log');
    console.warn = capture('warn');
    console.error = capture('error');
  }

  /** Stop intercepting and restore original console methods */
  stop(): void {
    if (!this._active) return;
    this._active = false;
    console.log = this._origLog;
    console.warn = this._origWarn;
    console.error = this._origError;
  }

  /** Get entries matching a prefix (e.g. "LP-SOLVER") */
  getByPrefix(prefix: string): LogEntry[] {
    return this.entries.filter(e => e.prefix === prefix);
  }

  /** Get entries at a specific level */
  getByLevel(level: LogEntry['level']): LogEntry[] {
    return this.entries.filter(e => e.level === level);
  }

  /** Dump all entries as formatted text */
  dump(): string {
    return this.entries
      .map(e => `[${e.level.toUpperCase()}] ${e.raw}`)
      .join('\n');
  }

  /** Clear captured entries */
  clear(): void {
    this.entries = [];
  }

  /** Write captured logs to a file in test-logs/ directory */
  async writeToFile(testName: string, header?: string): Promise<void> {
    const dir = new URL('./test-logs/', import.meta.url).pathname;
    try {
      await Deno.mkdir(dir, { recursive: true });
    } catch {
      // directory may already exist
    }
    const filename = `${dir}${testName}.log`;
    const lines: string[] = [];
    if (header) {
      lines.push('='.repeat(60));
      lines.push(header);
      lines.push('='.repeat(60));
      lines.push('');
    }
    lines.push(this.dump());
    await Deno.writeTextFile(filename, lines.join('\n'));
  }
}

// ============================================================================
// Food Factories
// ============================================================================

let _foodCounter = 0;

/** Create a Food object with sensible defaults; override any field */
export function makeFood(overrides: Partial<Food> & { name: string }): Food {
  _foodCounter++;
  return {
    id: overrides.id ?? `food-${_foodCounter}`,
    name: overrides.name,
    display_name: overrides.display_name ?? overrides.name,
    display_name_plural: overrides.display_name_plural ?? null,
    description: overrides.description ?? null,
    image_address: overrides.image_address ?? null,
    serving_size: overrides.serving_size ?? null,
    serving_unit: overrides.serving_unit ?? null,
    serving_qualifier: overrides.serving_qualifier ?? null,
    per_serving: overrides.per_serving ?? {
      carbs_g: 25,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 50,
      water_ml: 0,
      calories: 100,
    },
    serving_amount: overrides.serving_amount ?? 1,
    min_servings: overrides.min_servings ?? 1,
    max_servings: overrides.max_servings ?? 4,
    preference_score: overrides.preference_score ?? 80,
    is_electrolyte: overrides.is_electrolyte ?? false,
    is_liquid: overrides.is_liquid ?? false,
    is_essential: overrides.is_essential ?? false,
    is_user_food: overrides.is_user_food ?? false,
    is_indivisible: overrides.is_indivisible ?? false,
    product_type: overrides.product_type ?? 'food',
  };
}

// ============================================================================
// Mock During-Phase Food Catalog
// ============================================================================

export function makeDuringFoods(): Food[] {
  return [
    makeFood({
      id: 'energy-gel',
      name: 'Energy Gel',
      per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 0, calories: 100 },
      preference_score: 200,
      is_indivisible: true,
      product_type: 'gel',
      min_servings: 1,
      max_servings: 6,
    }),
    makeFood({
      id: 'energy-chews',
      name: 'Energy Chews',
      per_serving: { carbs_g: 24, protein_g: 0, fat_g: 0, sodium_mg: 70, water_ml: 0, calories: 100 },
      preference_score: 80,
      is_indivisible: true,
      product_type: 'chew',
      min_servings: 1,
      max_servings: 6,
    }),
    makeFood({
      id: 'sports-drink',
      name: 'Sports Drink',
      per_serving: { carbs_g: 15, protein_g: 0, fat_g: 0, sodium_mg: 110, water_ml: 240, calories: 60 },
      preference_score: 80,
      is_liquid: true,
      product_type: 'sports_drink',
      min_servings: 1,
      max_servings: 4,
    }),
    makeFood({
      id: 'high-carb-mix',
      name: 'High Carb Drink Mix',
      per_serving: { carbs_g: 45, protein_g: 0, fat_g: 0, sodium_mg: 200, water_ml: 500, calories: 180 },
      preference_score: 80,
      is_liquid: true,
      product_type: 'drink_mix',
      min_servings: 0.5,
      max_servings: 3,
    }),
    makeFood({
      id: 'water',
      name: 'Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
      preference_score: 50,
      is_liquid: true,
      is_essential: true,
      product_type: 'beverage',
      min_servings: 1,
      max_servings: 6,
    }),
    makeFood({
      id: 'electrolyte-tab',
      name: 'Electrolyte Tablet',
      per_serving: { carbs_g: 1, protein_g: 0, fat_g: 0, sodium_mg: 350, water_ml: 0, calories: 10 },
      preference_score: 50,
      is_electrolyte: true,
      is_indivisible: true,
      product_type: 'supplement',
      min_servings: 1,
      max_servings: 4,
    }),
    makeFood({
      id: 'energy-bar',
      name: 'Energy Bar',
      per_serving: { carbs_g: 40, protein_g: 5, fat_g: 8, sodium_mg: 200, water_ml: 0, calories: 250 },
      preference_score: 80,
      product_type: 'bar',
      min_servings: 0.5,
      max_servings: 2,
    }),
    makeFood({
      id: 'stroopwafel',
      name: 'Stroopwafel',
      per_serving: { carbs_g: 30, protein_g: 1, fat_g: 5, sodium_mg: 65, water_ml: 0, calories: 160 },
      preference_score: 80,
      product_type: 'bar',
      min_servings: 0.5,
      max_servings: 3,
    }),
  ];
}

// ============================================================================
// Mock After-Phase Food Catalog
// ============================================================================

export function makeAfterFoods(): Food[] {
  return [
    makeFood({
      id: 'protein-shake',
      name: 'Protein Shake',
      per_serving: { carbs_g: 5, protein_g: 25, fat_g: 2, sodium_mg: 200, water_ml: 350, calories: 150 },
      preference_score: 200,
      is_liquid: true,
      product_type: 'food',
      min_servings: 1,
      max_servings: 2,
    }),
    makeFood({
      id: 'banana',
      name: 'Banana',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 200,
      is_indivisible: true,
      product_type: 'food',
      min_servings: 1,
      max_servings: 2,
    }),
    makeFood({
      id: 'chocolate-milk',
      name: 'Chocolate Milk',
      per_serving: { carbs_g: 26, protein_g: 8, fat_g: 5, sodium_mg: 150, water_ml: 240, calories: 190 },
      preference_score: 80,
      is_liquid: true,
      product_type: 'food',
      min_servings: 1,
      max_servings: 2,
    }),
    makeFood({
      id: 'rice',
      name: 'White Rice',
      per_serving: { carbs_g: 45, protein_g: 4, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 200 },
      preference_score: 80,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 3,
    }),
    makeFood({
      id: 'chicken',
      name: 'Chicken Breast',
      per_serving: { carbs_g: 0, protein_g: 30, fat_g: 3, sodium_mg: 70, water_ml: 0, calories: 165 },
      preference_score: 80,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 2,
    }),
    makeFood({
      id: 'sweet-potato',
      name: 'Sweet Potato',
      per_serving: { carbs_g: 26, protein_g: 2, fat_g: 0, sodium_mg: 35, water_ml: 50, calories: 115 },
      preference_score: 80,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 2,
    }),
    makeFood({
      id: 'yogurt',
      name: 'Greek Yogurt',
      per_serving: { carbs_g: 7, protein_g: 15, fat_g: 4, sodium_mg: 60, water_ml: 100, calories: 130 },
      preference_score: 80,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 2,
    }),
    makeFood({
      id: 'recovery-drink',
      name: 'Recovery Drink Mix',
      per_serving: { carbs_g: 35, protein_g: 10, fat_g: 1, sodium_mg: 300, water_ml: 350, calories: 190 },
      preference_score: 80,
      is_liquid: true,
      product_type: 'food',
      min_servings: 1,
      max_servings: 2,
    }),
  ];
}

// ============================================================================
// Target Factories
// ============================================================================

/** Create MacroTargets with sensible defaults */
export function makeTargets(overrides: Partial<MacroTargets> = {}): MacroTargets {
  return {
    carbs_g: overrides.carbs_g ?? 60,
    protein_g: overrides.protein_g ?? 20,
    sodium_mg: overrides.sodium_mg ?? 500,
    water_ml: overrides.water_ml ?? 500,
  };
}

// Pre-built profiles matching E2E athlete scenarios

/** Light runner: 5K easy pace, 55kg, low sodium */
export const PROFILE_LIGHT: MacroTargets = {
  carbs_g: 30,
  protein_g: 15,
  sodium_mg: 300,
  water_ml: 400,
};

/** Average runner: 10-mile moderate, 70kg, medium sodium */
export const PROFILE_AVG: MacroTargets = {
  carbs_g: 60,
  protein_g: 25,
  sodium_mg: 800,
  water_ml: 800,
};

/** Heavy runner: marathon, 85kg, hot conditions, high sodium */
export const PROFILE_HEAVY: MacroTargets = {
  carbs_g: 95,
  protein_g: 35,
  sodium_mg: 1200,
  water_ml: 1500,
};

/** During targets — standard 10-mile run */
export const DURING_STANDARD: MacroTargets = {
  carbs_g: 45,
  sodium_mg: 600,
  water_ml: 700,
};

/** During targets — marathon, heavy sweater */
export const DURING_MARATHON: MacroTargets = {
  carbs_g: 80,
  sodium_mg: 1400,
  water_ml: 1200,
};

/** During targets — short 5K, minimal fueling */
export const DURING_SHORT: MacroTargets = {
  carbs_g: 10,
  sodium_mg: 200,
  water_ml: 300,
};

/** Ultra runner: 50mi, 75kg, high gut, hot conditions */
export const PROFILE_ULTRA: MacroTargets = {
  carbs_g: 140,
  protein_g: 40,
  sodium_mg: 2000,
  water_ml: 2500,
};

/** Very light female: 44kg, 10km, low gut */
export const PROFILE_VERY_LIGHT: MacroTargets = {
  carbs_g: 20,
  protein_g: 10,
  sodium_mg: 200,
  water_ml: 300,
};

/** During targets — ultra runner, 50mi, heavy sweater, hot */
export const DURING_ULTRA: MacroTargets = {
  carbs_g: 120,
  sodium_mg: 2000,
  water_ml: 2500,
};

/** During targets — cycling 60mi */
export const DURING_CYCLING_60: MacroTargets = {
  carbs_g: 90,
  sodium_mg: 1200,
  water_ml: 1400,
};

/** During targets — cycling 100mi */
export const DURING_CYCLING_100: MacroTargets = {
  carbs_g: 130,
  sodium_mg: 1800,
  water_ml: 2000,
};

/** After targets — ultra runner */
export const AFTER_ULTRA: MacroTargets = {
  carbs_g: 100,
  protein_g: 45,
  sodium_mg: 1500,
  water_ml: 2000,
};

/** After targets — very light female */
export const AFTER_VERY_LIGHT: MacroTargets = {
  carbs_g: 25,
  protein_g: 12,
  sodium_mg: 200,
  water_ml: 350,
};

/** 45kg extreme lightweight profile (during) */
export const DURING_45KG: MacroTargets = {
  carbs_g: 30,
  sodium_mg: 350,
  water_ml: 450,
};

/** 110kg extreme heavyweight profile (during) */
export const DURING_110KG: MacroTargets = {
  carbs_g: 90,
  sodium_mg: 1600,
  water_ml: 1800,
};

// ============================================================================
// Assertion Helpers
// ============================================================================

/**
 * Assert that a solution's totals fall within percentage ranges of targets.
 * Returns an object describing which macros are out of range.
 */
export function assertTotalsInRange(
  totals: FoodNutrition,
  targets: MacroTargets,
  ranges: { min: number; max: number } = { min: 0.7, max: 1.3 },
): { passed: boolean; issues: string[] } {
  const issues: string[] = [];

  const check = (name: string, actual: number, target: number) => {
    if (target <= 0) return;
    const ratio = actual / target;
    if (ratio < ranges.min || ratio > ranges.max) {
      issues.push(`${name}: ${actual.toFixed(0)}/${target}(${(ratio * 100).toFixed(0)}%)`);
    }
  };

  check('carbs', totals.carbs_g, targets.carbs_g);
  if (targets.protein_g) check('protein', totals.protein_g, targets.protein_g);
  check('sodium', totals.sodium_mg, targets.sodium_mg);
  check('water', totals.water_ml, targets.water_ml);

  return { passed: issues.length === 0, issues };
}

/**
 * Assert that the number of foods in a solution is within a range.
 */
export function assertFoodCount(
  solution: PhaseSolution,
  min: number,
  max: number,
): boolean {
  const count = solution.foods.length;
  return count >= min && count <= max;
}

/**
 * Format a summary line comparing totals to targets.
 */
export function formatSummary(totals: FoodNutrition, targets: MacroTargets): string {
  const pct = (a: number, t: number) => t > 0 ? `${(a / t * 100).toFixed(0)}%` : 'n/a';
  return `carbs=${totals.carbs_g.toFixed(0)}g/${targets.carbs_g}g(${pct(totals.carbs_g, targets.carbs_g)}) ` +
    `protein=${totals.protein_g.toFixed(0)}g/${targets.protein_g ?? 0}g(${pct(totals.protein_g, targets.protein_g ?? 0)}) ` +
    `sodium=${totals.sodium_mg.toFixed(0)}mg/${targets.sodium_mg}mg(${pct(totals.sodium_mg, targets.sodium_mg)}) ` +
    `water=${totals.water_ml.toFixed(0)}ml/${targets.water_ml}ml(${pct(totals.water_ml, targets.water_ml)})`;
}

/**
 * STRICT assertion: HARD FAIL if any macro falls outside the specified range.
 * Uses MACRO_CONSTRAINT_RANGES-style min/max ratios with a small rounding tolerance.
 * Throws an AssertionError with detailed diagnostics on failure.
 *
 * @param label - Test context label for error messages
 * @param totals - Actual nutrition totals from solver
 * @param targets - Target macros
 * @param ranges - Per-macro { min, max } ratio bounds (default: 90%-110%)
 * @param roundingTolerance - Extra tolerance for serving rounding (default: 5%)
 */
export function strictAssertMacrosInRange(
  label: string,
  totals: FoodNutrition,
  targets: MacroTargets,
  ranges: {
    carbs?: { min: number; max: number };
    protein?: { min: number; max: number };
    sodium?: { min: number; max: number };
    water?: { min: number; max: number };
  } = {},
  roundingTolerance = 0.05,
): void {
  const defaultRange = { min: 0.90, max: 1.10 };
  const failures: string[] = [];

  const check = (name: string, actual: number, target: number, range: { min: number; max: number }) => {
    if (target <= 0) return;
    const ratio = actual / target;
    const effectiveMin = range.min - roundingTolerance;
    const effectiveMax = range.max + roundingTolerance;
    if (ratio < effectiveMin || ratio > effectiveMax) {
      failures.push(
        `${name}: ${actual.toFixed(1)} / ${target} = ${(ratio * 100).toFixed(1)}% ` +
        `(allowed: ${(effectiveMin * 100).toFixed(0)}%-${(effectiveMax * 100).toFixed(0)}%)`
      );
    }
  };

  check('carbs', totals.carbs_g, targets.carbs_g, ranges.carbs ?? defaultRange);
  if (targets.protein_g && targets.protein_g > 0) {
    check('protein', totals.protein_g, targets.protein_g, ranges.protein ?? defaultRange);
  }
  check('sodium', totals.sodium_mg, targets.sodium_mg, ranges.sodium ?? defaultRange);
  check('water', totals.water_ml, targets.water_ml, ranges.water ?? defaultRange);

  if (failures.length > 0) {
    throw new Error(
      `[STRICT] ${label}: ${failures.length} macro(s) out of range:\n  - ${failures.join('\n  - ')}`
    );
  }
}

// ============================================================================
// Extended During-Phase Food Catalog (includes high-sodium sources)
// ============================================================================

/** Extended during-phase food catalog with additional electrolyte options.
 *  Includes a high-sodium drink mix and a capsule with inflated max_servings
 *  to test the capsule cap logic. */
export function makeDuringFoodsExtended(): Food[] {
  return [
    ...makeDuringFoods(),
    makeFood({
      id: 'high-sodium-mix',
      name: 'High-Sodium Electrolyte Mix',
      per_serving: { carbs_g: 3, protein_g: 0, fat_g: 0, sodium_mg: 500, water_ml: 500, calories: 15 },
      preference_score: 80,
      is_liquid: true,
      is_electrolyte: true,
      product_type: 'supplement',
      min_servings: 0.5,
      max_servings: 4,
    }),
    makeFood({
      id: 'electrolyte-capsule',
      name: 'Electrolyte Capsule',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 200, water_ml: 0, calories: 0 },
      preference_score: 50,
      is_electrolyte: true,
      is_indivisible: true,
      product_type: 'supplement',
      min_servings: 1,
      max_servings: 10,  // deliberately high to test cap
    }),
  ];
}

// ============================================================================
// Mock Before-Phase Food Catalog
// ============================================================================

export function makeBeforeFoods(): Food[] {
  return [
    makeFood({
      id: 'oatmeal',
      name: 'Oatmeal',
      per_serving: { carbs_g: 27, protein_g: 5, fat_g: 3, sodium_mg: 0, water_ml: 100, calories: 150 },
      preference_score: 200,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 3,
    }),
    makeFood({
      id: 'banana-before',
      name: 'Banana',
      per_serving: { carbs_g: 27, protein_g: 1, fat_g: 0, sodium_mg: 1, water_ml: 30, calories: 105 },
      preference_score: 200,
      is_indivisible: true,
      product_type: 'food',
      min_servings: 1,
      max_servings: 2,
    }),
    makeFood({
      id: 'toast',
      name: 'Toast with Jam',
      per_serving: { carbs_g: 30, protein_g: 3, fat_g: 1, sodium_mg: 150, water_ml: 10, calories: 140 },
      preference_score: 80,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 3,
    }),
    makeFood({
      id: 'yogurt-before',
      name: 'Greek Yogurt',
      per_serving: { carbs_g: 7, protein_g: 15, fat_g: 4, sodium_mg: 60, water_ml: 100, calories: 130 },
      preference_score: 80,
      product_type: 'food',
      min_servings: 0.5,
      max_servings: 2,
    }),
    makeFood({
      id: 'water-before',
      name: 'Water',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
      preference_score: 50,
      is_liquid: true,
      is_essential: true,
      product_type: 'beverage',
      min_servings: 1,
      max_servings: 4,
    }),
    makeFood({
      id: 'coffee',
      name: 'Coffee',
      per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 5, water_ml: 240, calories: 5 },
      preference_score: 80,
      is_liquid: true,
      product_type: 'beverage',
      min_servings: 1,
      max_servings: 2,
    }),
  ];
}

/** Sum FoodResult[] totals (convenience for tests that use during-rule-solver output) */
export function sumFoodResults(foods: Array<{ carbs_grams: number; sodium_mg: number; fluids_ml: number; protein_grams: number; fat_grams?: number; calories?: number }>): FoodNutrition {
  return foods.reduce(
    (acc, f) => ({
      carbs_g: acc.carbs_g + f.carbs_grams,
      protein_g: acc.protein_g + f.protein_grams,
      fat_g: acc.fat_g + (f.fat_grams ?? 0),
      sodium_mg: acc.sodium_mg + f.sodium_mg,
      water_ml: acc.water_ml + f.fluids_ml,
      calories: acc.calories + (f.calories ?? 0),
    }),
    { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 0 },
  );
}

// ============================================================================
// Real Dev Catalog Builders
// ============================================================================
//
// These builders load the committed snapshot of the dev Supabase
// `template_foods` table (92 active rows as of 2026-06-23) and convert rows
// into the Food / FoodWithConstraints shapes the solvers expect.
//
// Phase eligibility mirrors template-food-queries.ts:
//   DURING (default/running): categories contains 'during_run'
//     AND (default_during=true OR is_essential=true)
//     (same as the default allowNonDefaultDuring=false running path)
//   DURING extended: ALL 'during_run' rows (allowNonDefaultDuring=true)
//   AFTER: categories contains 'after_run'
//
// Column mapping mirrors template-food-queries.ts STEP 4:
//   carbs_g        → per_serving.carbs_g
//   protein_g      → per_serving.protein_g
//   fat_g          → per_serving.fat_g
//   sodium_mg      → per_serving.sodium_mg
//   fluid_ml       → per_serving.water_ml
//   calories       → per_serving.calories
//   max_servings_during / max_servings_after → max_servings
//   min_servings_during (default 1.0)        → min_servings
//
// PREFERENCE SCORES: all catalog foods score as "neutral" (20) here unless
// their is_essential flag is set (→ score=50). Preference overlays (liked /
// willing_to_try) are not simulated — tests that need custom scores should
// use makeFood() directly.

type RawCatalogRow = {
  id: string;
  name: string;
  display_name?: string | null;
  display_name_plural?: string | null;
  serving_size?: string | null;
  serving_unit?: string | null;
  serving_qualifier?: string | null;
  serving_amount?: number | null;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  calories: number;
  max_servings_during?: number | null;
  max_servings_after?: number | null;
  min_servings_during?: number | null;
  is_electrolyte?: boolean;
  is_liquid?: boolean;
  is_essential?: boolean;
  is_indivisible?: boolean;
  to_exclude_from_solver?: boolean;
  product_type?: string | null;
  categories?: string[];
  activity_types?: string[] | null;
  default_during?: boolean | null;
  max_per_hr_low?: number | null;
  max_per_hr_moderate?: number | null;
  max_per_hr_high?: number | null;
  min_increment?: number | null;
  sodium_top_up_eligible?: boolean | null;
  allergens?: string[] | null;
  excluded_diets?: string[] | null;
};

/** Load and parse the committed dev catalog snapshot synchronously. */
function loadCatalogSnapshot(): RawCatalogRow[] {
  const snapshotPath = new URL(
    './__fixtures__/dev-food-catalog.json',
    import.meta.url,
  ).pathname;
  const raw = Deno.readTextFileSync(snapshotPath);
  return JSON.parse(raw) as RawCatalogRow[];
}

/** Convert one raw catalog row to a Food object, using the same mapping as
 *  template-food-queries.ts STEP 4 (template-food path, not user-food). */
function rowToFood(row: RawCatalogRow, phase: 'during' | 'after'): Food {
  const maxServings = phase === 'during'
    ? (row.max_servings_during ?? 4)
    : (row.max_servings_after ?? 4);
  const minServings = row.min_servings_during ?? 1.0;
  const prefScore = row.is_essential ? 50 : 20; // neutral baseline

  return {
    id: row.id,
    name: row.name,
    display_name: row.display_name ?? null,
    display_name_plural: row.display_name_plural ?? null,
    description: null, // dropped from snapshot
    image_address: null, // dropped from snapshot
    serving_size: row.serving_size ?? null,
    serving_unit: row.serving_unit ?? null,
    serving_qualifier: row.serving_qualifier ?? null,
    serving_amount: row.serving_amount ?? null,
    per_serving: {
      carbs_g: row.carbs_g ?? 0,
      protein_g: row.protein_g ?? 0,
      fat_g: row.fat_g ?? 0,
      sodium_mg: row.sodium_mg ?? 0,
      water_ml: row.fluid_ml ?? 0,
      calories: row.calories ?? 0,
    },
    min_servings: minServings,
    max_servings: maxServings,
    preference_score: prefScore,
    is_electrolyte: row.is_electrolyte ?? false,
    is_liquid: row.is_liquid ?? false,
    is_essential: row.is_essential ?? false,
    is_user_food: false,
    is_indivisible: row.is_indivisible ?? false,
    product_type: row.product_type ?? undefined,
  };
}

/**
 * Build the during-phase food pool from the real dev catalog.
 *
 * Mirrors the default running path in template-food-queries.ts:
 *   - categories includes 'during_run'
 *   - default_during=true OR is_essential=true (allowNonDefaultDuring=false)
 *   - to_exclude_from_solver=false
 *
 * This is the default food pool for running during-phase, which excludes
 * real/whole foods that are not default during foods (banana, dates, etc.)
 * to match what a standard Mealvana user would see.
 */
export function makeRealDevDuringFoods(): Food[] {
  const rows = loadCatalogSnapshot();
  return rows
    .filter(r =>
      Array.isArray(r.categories) &&
      r.categories.includes('during_run') &&
      !r.to_exclude_from_solver &&
      (r.default_during === true || r.is_essential === true)
    )
    .map(r => rowToFood(r, 'during'));
}

/**
 * Build the extended during-phase food pool from the real dev catalog.
 *
 * Mirrors allowNonDefaultDuring=true: ALL during_run foods regardless of
 * default_during flag. Includes real/whole foods like banana, dates, etc.
 * Used when the user has liked/willing-to-try preferences or for cycling/bike.
 */
export function makeRealDevDuringFoodsExtended(): Food[] {
  const rows = loadCatalogSnapshot();
  return rows
    .filter(r =>
      Array.isArray(r.categories) &&
      r.categories.includes('during_run') &&
      !r.to_exclude_from_solver
    )
    .map(r => rowToFood(r, 'during'));
}

/**
 * Build the after-phase food pool from the real dev catalog.
 *
 * Includes all foods with categories containing 'after_run',
 * excluding to_exclude_from_solver=true.
 */
export function makeRealDevAfterFoods(): Food[] {
  const rows = loadCatalogSnapshot();
  return rows
    .filter(r =>
      Array.isArray(r.categories) &&
      r.categories.includes('after_run') &&
      !r.to_exclude_from_solver
    )
    .map(r => rowToFood(r, 'after'));
}

/**
 * Build the during-phase food pool as FoodWithConstraints from the real dev
 * catalog. Used by the template solver (parity.test.ts buildTemplateFoodPool).
 *
 * Includes ALL during_run foods (allowNonDefaultDuring=true equivalent)
 * plus the FoodWithConstraints columns from the DB:
 *   max_per_hr_low/moderate/high, min_increment, sodium_top_up_eligible.
 */
export function makeRealDevDuringFoodsWithConstraints(): Map<string, FoodWithConstraints> {
  const rows = loadCatalogSnapshot();
  const pool = new Map<string, FoodWithConstraints>();

  const duringRows = rows.filter(r =>
    Array.isArray(r.categories) &&
    r.categories.includes('during_run') &&
    !r.to_exclude_from_solver
  );

  for (const row of duringRows) {
    const base = rowToFood(row, 'during');
    const withConstraints: FoodWithConstraints = {
      ...base,
      max_per_hr_low: row.max_per_hr_low ?? null,
      max_per_hr_moderate: row.max_per_hr_moderate ?? null,
      max_per_hr_high: row.max_per_hr_high ?? null,
      min_increment: row.min_increment ?? null,
      sodium_top_up_eligible: row.sodium_top_up_eligible ?? null,
    };
    // Key by name (primary key used by template solver)
    pool.set(row.name, withConstraints);
    // Also key by id for lookup flexibility
    pool.set(row.id, withConstraints);
  }

  return pool;
}
