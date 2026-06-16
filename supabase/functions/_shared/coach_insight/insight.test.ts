import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  buildInsightUserMessage,
  computeNutritionState,
  type InsightComponent,
  type InsightContext,
} from "./insight.ts";

function comp(overrides: Partial<InsightComponent>): InsightComponent {
  return {
    food_name: "Food",
    quantity: 1,
    carbs_per_serving: 0,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 0,
    fluid_ml_per_serving: 0,
    calories_per_serving: 0,
    ...overrides,
  };
}

function ctx(overrides: Partial<InsightContext>): InsightContext {
  return {
    phase: "before",
    components: [comp({ carbs_per_serving: 30 })],
    ...overrides,
  };
}

Deno.test("totals scale by component quantity", () => {
  const state = computeNutritionState(
    ctx({
      components: [
        comp({ carbs_per_serving: 30, protein_per_serving: 5, quantity: 2 }),
        comp({ carbs_per_serving: 10, sodium_mg: 100, quantity: 1 }),
      ],
    }),
  );
  assertEquals(state.carbsG, 70); // 30*2 + 10
  assertEquals(state.proteinG, 10); // 5*2
  assertEquals(state.sodiumMg, 100);
});

Deno.test("missing quantity defaults to 1x", () => {
  const state = computeNutritionState(
    ctx({ components: [comp({ carbs_per_serving: 25, quantity: 0 })] }),
  );
  // quantity 0 falls back to 1 (num(0)||1)
  assertEquals(state.carbsG, 25);
});

Deno.test("solid:liquid ratio is solid macro mass over fluid", () => {
  const state = computeNutritionState(
    ctx({
      components: [
        comp({ carbs_per_serving: 60, protein_per_serving: 20, fat_per_serving: 0 }),
        comp({ fluid_ml_per_serving: 400 }),
      ],
    }),
  );
  // solid mass = 80g, fluid = 400mL → 0.2 : 1
  assertEquals(state.solidLiquidRatio, 0.2);
});

Deno.test("solid:liquid ratio is null with no fluid", () => {
  const state = computeNutritionState(
    ctx({ components: [comp({ carbs_per_serving: 30 })] }),
  );
  assertEquals(state.solidLiquidRatio, null);
});

Deno.test("carbs/hour computed for during phase from longest duration bracket", () => {
  const state = computeNutritionState(
    ctx({
      phase: "during",
      durations: ["under_60", "90_plus"],
      components: [comp({ carbs_per_serving: 120 })],
    }),
  );
  // longest bracket 90_plus → 2h lower bound → 120 / 2 = 60 g/h
  assertEquals(state.carbsPerHour, 60);
});

Deno.test("carbs/hour is null for before phase", () => {
  const state = computeNutritionState(ctx({ phase: "before" }));
  assertEquals(state.carbsPerHour, null);
});

Deno.test("before top_up flagged poor when carb-heavy", () => {
  const state = computeNutritionState(
    ctx({ sub_phase: "top_up", components: [comp({ carbs_per_serving: 80 })] }),
  );
  assertEquals(state.subPhaseFit, "poor");
});

Deno.test("before meal with solid carbs reads as good fit", () => {
  const state = computeNutritionState(
    ctx({ sub_phase: "meal", components: [comp({ carbs_per_serving: 60 })] }),
  );
  assertEquals(state.subPhaseFit, "good");
});

Deno.test("user message injects macros and phase", () => {
  const context = ctx({
    phase: "during",
    durations: ["60_90"],
    name: "Race fuel",
    components: [comp({ carbs_per_serving: 50, sodium_mg: 200 })],
  });
  const state = computeNutritionState(context);
  const msg = buildInsightUserMessage(context, state);
  assertStringIncludes(msg, "PHASE: during");
  assertStringIncludes(msg, "WORKOUT_DURATIONS: 60_90");
  assertStringIncludes(msg, "NAME: Race fuel");
  assertStringIncludes(msg, "carbs:     50 g");
  assertStringIncludes(msg, "sodium:    200 mg");
  assertStringIncludes(msg, "carbs_per_hour:");
  assert(!msg.includes("sub_phase_fit:")); // during omits sub-phase fit
});

Deno.test("before user message includes sub_phase_fit, omits carbs/hour", () => {
  const context = ctx({ sub_phase: "snack", components: [comp({ carbs_per_serving: 40 })] });
  const state = computeNutritionState(context);
  const msg = buildInsightUserMessage(context, state);
  assertStringIncludes(msg, "SUB_PHASE: snack");
  assertStringIncludes(msg, "sub_phase_fit:");
  assert(!msg.includes("carbs_per_hour:"));
});
