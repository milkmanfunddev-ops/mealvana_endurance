/**
 * Test Utilities for Nutrition Solver Unit Tests
 *
 * Provides log capture, mock food factories, and assertion helpers
 * so tests can run locally without Supabase.
 */

import type { Food, MacroTargets, PhaseSolution, FoodNutrition } from './types.ts';

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
