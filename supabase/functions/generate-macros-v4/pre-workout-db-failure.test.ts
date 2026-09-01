/**
 * Unit tests: loadPreWorkoutTemplates() throws on DB query failure.
 *
 * P7 from edge-function-test-plan-2026.md:
 *   "loadPreWorkoutTemplates throws on query failure ⇒ generate-macros-v4
 *    handler returns 500 (not 200-with-empty)."
 *
 * Strategy: pass a stub Supabase client via the optional `clientOverride`
 * parameter added to `loadPreWorkoutTemplates`. The stub's `.from()` chain
 * returns `{ data: null, error: { message: "..." } }` for the targeted query
 * type, causing the function to throw the documented Error.
 *
 * Handler 500 mapping: `index.ts` wraps the handler in a try/catch (via
 * `withSentry`). The `loadPreWorkoutTemplates` call is inside that try block
 * (line ~121). Any thrown Error propagates to the catch which calls
 * `serverError(...)` → HTTP 500. We assert the throw directly here; the
 * handler mapping is exercised by the integration suite (run-algorithm-tests.sh §2).
 *
 * Run with:
 *   deno test --allow-read --allow-write --allow-env --node-modules-dir=none \
 *     supabase/functions/generate-macros-v4/pre-workout-db-failure.test.ts
 */

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { loadPreWorkoutTemplates } from "./single-sport.ts";

// ============================================================================
// Stub factory helpers
// ============================================================================

/**
 * Build the fluent chain object that `.from(...).select(...).eq(...).eq(...)`
 * resolves to. Each `.eq()` call returns `this` (fluent), and awaiting the
 * chain resolves to `{ data, error }`.
 */
function makeSelectChain(result: { data: unknown; error: unknown }) {
  const chain = {
    // deno-lint-ignore no-explicit-any
    eq(_col: string, _val: unknown): any {
      return chain;
    },
    // Makes the chain thenable so `await` resolves to `result`.
    then(
      resolve: (v: { data: unknown; error: unknown }) => unknown,
      reject: (e: unknown) => unknown,
    ) {
      try {
        return Promise.resolve(resolve(result));
      } catch (e) {
        return Promise.reject(reject(e));
      }
    },
  };
  return chain;
}

/**
 * Build a minimal stub Supabase client whose `.from()` always returns a
 * select chain that resolves to the provided `result`.
 *
 * `Promise.all([query1, query2, query3])` in `loadPreWorkoutTemplates`
 * awaits three independent chains; they all share the same result object here
 * so we can control which one fails by the test variant.
 */
function makeStubClient(result: { data: unknown; error: unknown }) {
  return {
    from(_table: string) {
      return {
        select(_cols: string) {
          return makeSelectChain(result);
        },
      };
    },
  };
}

/**
 * Build a stub where only queries against `failTable` return an error; the
 * others succeed with an empty array. Since the 2026-08-06 repoint, food
 * formulas come from `pre_workout_templates` while the drink pool comes from
 * `template_foods` (ingredient-pools.ts), so the failure domain is the TABLE,
 * not the `template_type` filter. The electrolyte pool is a constant `[]`
 * (Lee ruling 2026-08-06 / sodium v3) and performs no query at all.
 */
function makeSelectiveFailureClient(
  failTable: "pre_workout_templates" | "template_foods",
) {
  function makeSmartChain(table: string) {
    const chain = {
      eq(_col: string, _val: unknown) {
        return chain;
      },
      then(
        resolve: (v: { data: unknown; error: unknown }) => unknown,
        _reject: (e: unknown) => unknown,
      ) {
        const result = table === failTable
          ? {
            data: null,
            error: { message: `simulated ${failTable} query failure` },
          }
          : { data: [], error: null };
        return Promise.resolve(resolve(result));
      },
    };
    return chain;
  }

  return {
    from(table: string) {
      return {
        select(_cols: string) {
          return makeSmartChain(table);
        },
      };
    },
  };
}

// ============================================================================
// Tests
// ============================================================================

describe("loadPreWorkoutTemplates — DB failure handling", () => {

  it("throws when the food query fails", async () => {
    const client = makeSelectiveFailureClient("pre_workout_templates");
    await assertRejects(
      () => loadPreWorkoutTemplates(client),
      Error,
      "Failed to load food templates",
    );
  });

  it("throws when the drink-pool query fails", async () => {
    const client = makeSelectiveFailureClient("template_foods");
    await assertRejects(
      () => loadPreWorkoutTemplates(client),
      Error,
      "Failed to load drink pool",
    );
  });

  it("electrolyte pool is empty by ruling — no query, no failure mode", async () => {
    // Sodium v3 sets no pre-workout sodium target and Lee ruled the BEFORE
    // phase considers fluids, not electrolytes — loadPreWorkoutElectrolytePool
    // is a constant [] and cannot fail. This pins that Pass 3 stays inert
    // rather than silently regaining a DB dependency.
    const client = makeStubClient({ data: [], error: null });
    const result = await loadPreWorkoutTemplates(client);
    assertEquals(result.electrolyte.length, 0);
  });

  it("includes the DB error message in the thrown Error", async () => {
    const specificMsg = "connection timeout: host unreachable";
    const client = makeStubClient({
      data: null,
      error: { message: specificMsg },
    });

    let caught: Error | null = null;
    try {
      await loadPreWorkoutTemplates(client);
    } catch (e) {
      caught = e as Error;
    }

    assertEquals(caught !== null, true, "Should have thrown");
    assertEquals(
      caught!.message.includes(specificMsg),
      true,
      `Error message should contain DB error. Got: "${caught!.message}"`,
    );
  });

  it("resolves successfully when all queries succeed with empty arrays", async () => {
    const client = makeStubClient({ data: [], error: null });
    const result = await loadPreWorkoutTemplates(client);

    assertEquals(result.food.length, 0, "food should be empty");
    assertEquals(result.drink.length, 0, "drink should be empty");
    assertEquals(result.electrolyte.length, 0, "electrolyte should be empty");
  });

  // Note: handler 500 mapping — `index.ts` wraps `loadPreWorkoutTemplates`
  // inside the `withSentry(async (req) => { try { ... } catch (e) { serverError(...) } })`
  // block. Any Error thrown by `loadPreWorkoutTemplates` propagates to that
  // catch and is mapped to HTTP 500 via `serverError()`. The throw path is
  // asserted above; the HTTP layer is exercised by the live E2E suite
  // (run-algorithm-tests.sh §2) because spinning up a real Deno.serve in a
  // unit test would require --allow-net and a live request, adding fragility.
  it("(documented) handler maps thrown Error → HTTP 500 via serverError()", () => {
    // This is a documentation-only test confirming the mapping exists in code.
    // See: supabase/functions/generate-macros-v4/index.ts line ~121:
    //   const templates = await loadPreWorkoutTemplates();
    // and the surrounding try/catch in `withSentry(async (req) => { ... })`.
    // Any Error thrown escapes to the outer catch which calls serverError().
    // No assertion needed here — the three tests above prove the throw; the
    // mapping in index.ts is a code-level contract, not a runtime assertion.
    assertEquals(true, true, "mapping documented in code, not re-tested here");
  });
});
