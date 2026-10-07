/**
 * Unit tests for template-food-queries: the shape of the constrained during
 * pool the template solver receives.
 *
 * Run with:
 *   deno test --allow-all --no-check --node-modules-dir=none \
 *     supabase/functions/_shared/nutrition/template-food-queries.test.ts
 */

import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { getTemplateFoodsForDuringWithConstraints } from "./template-food-queries.ts";
import { fakeSupabase } from "./test-fake-supabase.ts";

function gelRow(overrides: Record<string, unknown> = {}) {
  return {
    id: "gel-id",
    name: "energy_gel",
    display_name: "Energy Gel",
    carbs_g: 25,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 55,
    fluid_ml: 20,
    calories: 100,
    serving_amount: 1,
    serving_size: "1",
    serving_unit: "gel",
    is_active: true,
    is_electrolyte: false,
    is_liquid: false,
    is_essential: false,
    is_indivisible: true,
    product_type: "gel",
    categories: ["during_run"],
    activity_types: ["running"],
    max_servings_during: 15,
    min_servings_during: 0.5,
    max_per_hr_low: 2,
    max_per_hr_moderate: 3,
    max_per_hr_high: 3,
    min_increment: 1,
    sodium_top_up_eligible: false,
    ...overrides,
  };
}

describe("getTemplateFoodsForDuringWithConstraints", () => {
  // Finding 117-016: Postgres `numeric` columns reach Deno as strings through
  // some clients and every catalog snapshot fixture. The solver steps its
  // serving search with `servings += min_increment`; a string there is a
  // concatenation, the loop ends after one step, and the search space is
  // {0, one serving} for every component.
  it("coerces numeric constraint columns to numbers, even when the row carries strings", async () => {
    const client = fakeSupabase({
      template_foods: [
        gelRow({
          min_servings_during: "0.5",
          max_servings_during: 15,
          max_per_hr_low: "2.00",
          max_per_hr_moderate: "3.00",
          max_per_hr_high: "3.00",
          min_increment: "1.00",
          carbs_g: "25.0",
        }),
      ],
    });

    const foods = await getTemplateFoodsForDuringWithConstraints(
      client,
      "running",
    );
    const gel = foods.find((f) => f.name === "energy_gel");
    assertExists(gel);
    assertEquals(gel.min_servings, 0.5);
    assertEquals(gel.max_servings, 15);
    assertEquals(gel.min_increment, 1);
    assertEquals(gel.max_per_hr_low, 2);
    assertEquals(gel.max_per_hr_moderate, 3);
    assertEquals(gel.max_per_hr_high, 3);
    assertEquals(gel.per_serving.carbs_g, 25);
    for (
      const [field, value] of Object.entries({
        min_servings: gel.min_servings,
        max_servings: gel.max_servings,
        min_increment: gel.min_increment,
        max_per_hr_low: gel.max_per_hr_low,
        max_per_hr_moderate: gel.max_per_hr_moderate,
        max_per_hr_high: gel.max_per_hr_high,
      })
    ) {
      assertEquals(typeof value, "number", `${field} must be a number`);
    }
  });

  it("keeps null constraints null and applies the serving defaults", async () => {
    const client = fakeSupabase({
      template_foods: [
        gelRow({
          min_servings_during: null,
          max_servings_during: null,
          max_per_hr_low: null,
          max_per_hr_moderate: null,
          max_per_hr_high: null,
          min_increment: null,
        }),
      ],
    });

    const foods = await getTemplateFoodsForDuringWithConstraints(
      client,
      "running",
    );
    const gel = foods.find((f) => f.name === "energy_gel");
    assertExists(gel);
    assertEquals(gel.min_servings, 1);
    assertEquals(gel.max_servings, 4);
    assertEquals(gel.min_increment, null);
    assertEquals(gel.max_per_hr_low, null);
    assertEquals(gel.max_per_hr_moderate, null);
    assertEquals(gel.max_per_hr_high, null);
  });
});
