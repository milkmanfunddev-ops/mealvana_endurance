/**
 * Food-pool source policy tests.
 *
 * Policy (2026-07-29): nutrition-plan generation draws foods ONLY from the
 * curated `template_foods` catalog. `user_foods` — user-created, barcode-scanned
 * and branded grocery items — must never reach a generated plan, in any phase,
 * including fallbacks. The single legitimate user-originating source is a
 * pinned personal formula, which is self-contained and does no food-pool lookup.
 *
 * These tests pin that policy at the query layer by stubbing the Supabase client
 * and asserting on the set of TABLES touched — so a regression that re-adds a
 * `user_foods` (or `users` device-id lookup) read fails here even if the
 * resulting pool happens to look the same.
 *
 * They also cover:
 *   - the `product_type` classification gate (null / '' / 'import' excluded,
 *     essentials exempt), applied consistently across all three pool builders;
 *   - empty-pool behaviour: an empty catalog, and a catalog emptied *by* the
 *     classification gate, must both return `[]` rather than throw, so callers
 *     fall through to their normal shortfall/fallback handling.
 *
 * Run with:
 *   deno test --allow-read --allow-write --allow-env --node-modules-dir=none \
 *     supabase/functions/_shared/nutrition/food-pool-sources.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  describe,
  it,
} from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  getTemplateFoodsForDuringWithConstraints,
  getTemplateFoodsForPhase,
  getTransitionFoods,
  isClassifiedProductType,
} from "./template-food-queries.ts";
import { fetchUserFoodsForBefore } from "../../generate-nutrition-plan-v3/before-phase-substitution.ts";

// ============================================================================
// Supabase stub
// ============================================================================

type Row = Record<string, unknown>;

interface StubSupabase {
  // deno-lint-ignore no-explicit-any
  from(table: string): any;
  /** Every table name passed to `.from()`, in call order. */
  tablesQueried: string[];
}

/**
 * Minimal thenable query-builder stub. Every filter method returns `this`, and
 * awaiting the builder resolves to the rows configured for that table. Filters
 * are deliberately NOT simulated — SQL-side filtering is the database's job;
 * what these tests assert is which tables are read and what the in-Deno filter
 * layer does with the rows it gets back.
 */
function makeSupabase(rowsByTable: Record<string, Row[]>): StubSupabase {
  const tablesQueried: string[] = [];

  return {
    tablesQueried,
    from(table: string) {
      tablesQueried.push(table);
      const result = { data: rowsByTable[table] ?? [], error: null };
      const builder: Record<string, unknown> = {
        // deno-lint-ignore no-explicit-any
        then(onFulfilled: (v: unknown) => any, onRejected?: (e: unknown) => any) {
          return Promise.resolve(result).then(onFulfilled, onRejected);
        },
        // `.single()` is what the removed device-id → user-id lookup used.
        single: () => Promise.resolve(result),
      };
      for (
        const m of ["select", "eq", "neq", "filter", "or", "in", "not", "order"]
      ) {
        builder[m] = () => builder;
      }
      return builder;
    },
  };
}

// ============================================================================
// Row fixtures
// ============================================================================

function templateRow(overrides: Row = {}): Row {
  return {
    id: crypto.randomUUID(),
    name: "oatmeal",
    display_name: "Oatmeal",
    display_name_plural: "Oatmeal",
    description: null,
    image_address: null,
    calories: 150,
    carbs_g: 27,
    protein_g: 5,
    fat_g: 3,
    sodium_mg: 10,
    fluid_ml: 120,
    serving_amount: 1,
    serving_size: "1 cup",
    serving_unit: "cup",
    serving_qualifier: null,
    max_servings_before: 3,
    max_servings_during: 3,
    max_servings_after: 3,
    min_servings_during: 1,
    is_electrolyte: false,
    to_exclude_from_solver: false,
    is_essential: false,
    is_indivisible: false,
    categories: ["after_run"],
    activity_types: null,
    is_liquid: false,
    product_type: "real_food",
    default_during: true,
    allergens: [],
    excluded_diets: [],
    ...overrides,
  };
}

/** The shape `user_foods` rows used to arrive in. Configured on the stub so
 * that if any query layer reads that table again, the leak is visible in the
 * returned pool as well as in `tablesQueried`. */
function userFoodRow(overrides: Row = {}): Row {
  return {
    id: crypto.randomUUID(),
    name: "costco_protein_bar",
    display_name: "Costco Protein Bar",
    display_name_plural: "Costco Protein Bars",
    description: null,
    image_address: null,
    calories_per_serving: 220,
    carbs_per_serving: 24,
    protein_per_serving: 20,
    fat_per_serving: 7,
    sodium_mg: 180,
    fluid_ml_per_serving: 0,
    serving_amount: 1,
    serving_unit: "bar",
    product_type: "bar",
    is_electrolyte: false,
    to_exclude_from_solver: false,
    is_deleted: false,
    categories: ["after_run"],
    activity_types: null,
    ...overrides,
  };
}

/** Rows for every table a leak could plausibly come from, all populated. */
function leakBaitTables(templateRows: Row[]): Record<string, Row[]> {
  return {
    template_foods: templateRows,
    user_foods: [
      userFoodRow(),
      userFoodRow({ name: "scanned_pop_tart", product_type: "import" }),
      userFoodRow({ name: "unclassified_thing", product_type: null }),
    ],
    users: [{ id: "user-1" }],
  };
}

const NAMES = (foods: { name: string }[]) => foods.map((f) => f.name).sort();

// ============================================================================
// isClassifiedProductType
// ============================================================================

describe("isClassifiedProductType", () => {
  it("accepts a real classified type", () => {
    assert(isClassifiedProductType("real_food"));
    assert(isClassifiedProductType("gel"));
    assert(isClassifiedProductType("beverage"));
  });

  it("rejects null, undefined, empty and 'import'", () => {
    assertEquals(isClassifiedProductType(null), false);
    assertEquals(isClassifiedProductType(undefined), false);
    assertEquals(isClassifiedProductType(""), false);
    assertEquals(isClassifiedProductType("   "), false);
    assertEquals(isClassifiedProductType("import"), false);
    assertEquals(isClassifiedProductType("  IMPORT  "), false);
  });

  it("rejects non-string values", () => {
    assertEquals(isClassifiedProductType(42), false);
    assertEquals(isClassifiedProductType({}), false);
  });
});

// ============================================================================
// getTemplateFoodsForPhase
// ============================================================================

describe("getTemplateFoodsForPhase — food source policy", () => {
  it("never reads user_foods or the users table", async () => {
    const supabase = makeSupabase(
      leakBaitTables([templateRow({ name: "oatmeal" })]),
    );

    // deno-lint-ignore no-explicit-any
    await getTemplateFoodsForPhase(supabase as any, "after", "running");

    assertEquals(
      [...new Set(supabase.tablesQueried)],
      ["template_foods"],
      "plan generation must query the curated catalog only",
    );
  });

  it("returns only curated foods, all flagged is_user_food=false", async () => {
    const supabase = makeSupabase(
      leakBaitTables([
        templateRow({ name: "oatmeal" }),
        templateRow({ name: "greek_yogurt", product_type: "whole_food" }),
      ]),
    );

    // deno-lint-ignore no-explicit-any
    const foods = await getTemplateFoodsForPhase(supabase as any, "after");

    assertEquals(NAMES(foods), ["greek_yogurt", "oatmeal"]);
    assert(
      foods.every((f) => f.is_user_food === false),
      "no pool member may be marked as a user food",
    );
  });

  it("excludes unclassified and imported rows, keeps essentials", async () => {
    const supabase = makeSupabase({
      template_foods: [
        templateRow({ name: "oatmeal", product_type: "real_food" }),
        templateRow({ name: "mystery_row", product_type: null }),
        templateRow({ name: "blank_row", product_type: "" }),
        templateRow({ name: "scanned_row", product_type: "import" }),
        // Essentials are exempt so hydration is never lost to a data gap.
        templateRow({
          name: "water",
          product_type: null,
          is_essential: true,
          carbs_g: 0,
          protein_g: 0,
          fat_g: 0,
          fluid_ml: 240,
        }),
      ],
    });

    // deno-lint-ignore no-explicit-any
    const foods = await getTemplateFoodsForPhase(supabase as any, "after");

    assertEquals(NAMES(foods), ["oatmeal", "water"]);
  });

  it("returns [] (does not throw) when the catalog is empty", async () => {
    const supabase = makeSupabase({ template_foods: [] });

    // deno-lint-ignore no-explicit-any
    const foods = await getTemplateFoodsForPhase(supabase as any, "after");

    assertEquals(foods, []);
  });

  it("returns [] (does not throw) when the gate empties the pool", async () => {
    // Every candidate is unclassified/imported: the phase must degrade to an
    // empty pool so the caller runs its normal fallback, not crash.
    const supabase = makeSupabase({
      template_foods: [
        templateRow({ name: "scanned_a", product_type: "import" }),
        templateRow({ name: "scanned_b", product_type: null }),
      ],
    });

    // deno-lint-ignore no-explicit-any
    const foods = await getTemplateFoodsForPhase(supabase as any, "after");

    assertEquals(foods, []);
  });

  it("still applies allergen filtering (no user-food bypass remains)", async () => {
    const supabase = makeSupabase({
      template_foods: [
        templateRow({ name: "oatmeal", allergens: [] }),
        templateRow({ name: "peanut_butter", allergens: ["peanut"] }),
      ],
    });

    const foods = await getTemplateFoodsForPhase(
      // deno-lint-ignore no-explicit-any
      supabase as any,
      "after",
      "running",
      undefined,
      undefined,
      undefined,
      false,
      ["peanut"],
    );

    assertEquals(NAMES(foods), ["oatmeal"]);
  });
});

// ============================================================================
// getTransitionFoods (brick T1/T2)
// ============================================================================

describe("getTransitionFoods — food source policy", () => {
  it("never reads user_foods or the users table", async () => {
    const supabase = makeSupabase(
      leakBaitTables([templateRow({ name: "sports_drink", categories: ["transition"] })]),
    );

    // deno-lint-ignore no-explicit-any
    await getTransitionFoods(supabase as any);

    assertEquals([...new Set(supabase.tablesQueried)], ["template_foods"]);
  });

  it("excludes unclassified/imported rows and marks nothing a user food", async () => {
    const supabase = makeSupabase({
      template_foods: [
        templateRow({ name: "sports_drink", product_type: "sports_drink" }),
        templateRow({ name: "scanned_row", product_type: "import" }),
        templateRow({ name: "mystery_row", product_type: null }),
      ],
    });

    // deno-lint-ignore no-explicit-any
    const foods = await getTransitionFoods(supabase as any);

    assertEquals(NAMES(foods), ["sports_drink"]);
    assert(foods.every((f) => f.is_user_food === false));
  });

  it("returns [] (does not throw) when nothing survives", async () => {
    const supabase = makeSupabase({
      template_foods: [templateRow({ name: "scanned", product_type: "import" })],
    });

    // deno-lint-ignore no-explicit-any
    assertEquals(await getTransitionFoods(supabase as any), []);
  });
});

// ============================================================================
// getTemplateFoodsForDuringWithConstraints
// ============================================================================

describe("getTemplateFoodsForDuringWithConstraints — food source policy", () => {
  it("never reads user_foods, even when a deviceId is still passed", async () => {
    const supabase = makeSupabase(
      leakBaitTables([templateRow({ name: "gel", product_type: "gel" })]),
    );

    await getTemplateFoodsForDuringWithConstraints(
      // deno-lint-ignore no-explicit-any
      supabase as any,
      "running",
      undefined,
      undefined,
      undefined,
      "device-123", // legacy positional arg — must be inert
    );

    assertEquals([...new Set(supabase.tablesQueried)], ["template_foods"]);
  });

  it("excludes unclassified/imported rows", async () => {
    const supabase = makeSupabase({
      template_foods: [
        templateRow({ name: "gel", product_type: "gel" }),
        templateRow({ name: "scanned_row", product_type: "import" }),
        templateRow({ name: "mystery_row", product_type: null }),
      ],
    });

    const foods = await getTemplateFoodsForDuringWithConstraints(
      // deno-lint-ignore no-explicit-any
      supabase as any,
      "running",
    );

    assertEquals(NAMES(foods), ["gel"]);
    assert(foods.every((f) => f.is_user_food === false));
  });

  it("returns [] (does not throw) on an empty catalog", async () => {
    const supabase = makeSupabase({ template_foods: [] });
    assertEquals(
      // deno-lint-ignore no-explicit-any
      await getTemplateFoodsForDuringWithConstraints(supabase as any, "running"),
      [],
    );
  });
});

// ============================================================================
// Before-phase substitution
// ============================================================================

describe("fetchUserFoodsForBefore — disabled by policy", () => {
  it("returns [] and queries nothing at all", async () => {
    const supabase = makeSupabase(leakBaitTables([templateRow()]));

    const result = await fetchUserFoodsForBefore(
      // deno-lint-ignore no-explicit-any
      supabase as any,
      "device-123",
    );

    assertEquals(result, []);
    assertEquals(
      supabase.tablesQueried,
      [],
      "the before-phase substitution path must not read any table",
    );
  });
});
