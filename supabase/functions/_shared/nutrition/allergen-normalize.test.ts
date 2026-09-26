/**
 * Ticket 138, Finding 116-001: "Peanut" must match `peanuts`.
 * Run with: deno test --allow-all supabase/functions/_shared/nutrition/allergen-normalize.test.ts
 */
import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";
import { allergensConflict, normalizeAllergen } from "./allergen-normalize.ts";

describe("normalizeAllergen", () => {
  it("folds the catalog's forms onto the app's dbValues", () => {
    assertEquals(normalizeAllergen("Peanut"), "peanuts");
    assertEquals(normalizeAllergen("peanuts"), "peanuts");
    assertEquals(normalizeAllergen("Tree nut"), "tree_nuts");
    assertEquals(normalizeAllergen("Tree Nuts"), "tree_nuts");
    assertEquals(normalizeAllergen("tree_nuts"), "tree_nuts");
    assertEquals(normalizeAllergen("Egg"), "eggs");
    assertEquals(normalizeAllergen("Milk"), "dairy");
    assertEquals(normalizeAllergen("Dairy"), "dairy");
    assertEquals(normalizeAllergen("Soy"), "soy");
    assertEquals(normalizeAllergen("Shellfish"), "shellfish");
    assertEquals(normalizeAllergen("Sesame seeds"), "sesame");
  });

  it("keeps an unknown allergen comparable with itself", () => {
    assertEquals(normalizeAllergen("Mustard"), normalizeAllergen("mustard"));
    assertEquals(normalizeAllergen("Celery"), "celery");
    assertEquals(normalizeAllergen("Lupins"), normalizeAllergen("Lupin"));
  });

  it("does not confuse fish with shellfish", () => {
    assertEquals(normalizeAllergen("Fish") === normalizeAllergen("Shellfish"), false);
  });
});

describe("allergensConflict", () => {
  it("flags a Peanut template for a peanuts allergy", () => {
    assertEquals(allergensConflict(["Peanut"], ["peanuts"]), true);
    assertEquals(allergensConflict(["Tree nut"], ["tree_nuts"]), true);
  });

  it("passes a template that carries none of the athlete's allergens", () => {
    assertEquals(allergensConflict(["Dairy"], ["peanuts"]), false);
    assertEquals(allergensConflict([], ["peanuts"]), false);
    assertEquals(allergensConflict(["Peanut"], []), false);
  });
});
