/**
 * plan_generation_log ledger (testing-wave ticket 62, Finding 49-012).
 *
 * At 17:40Z on 2026-10-08 two ledger rows were lost to 22P02 ("invalid input
 * syntax for type integer: 18.64"): the dev cloud e2e suite sends macros-v4's
 * fractional `duration_min` as `duration_minutes`, and the column was integer.
 * These tests feed producer-shaped input (macros-v4's `duration_min`, phase
 * totals with one decimal) and check the row against the table's column types
 * as the migrations define them.
 *
 * Run with: deno test --allow-all supabase/functions/generate-nutrition-plan-v3/plan-generation-log.test.ts
 */

import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import type { FoodResult } from "../_shared/nutrition/index.ts";
import {
  buildPlanGenerationLogRow,
  insertPlanGenerationLog,
  type PlanGenerationLogRow,
} from "./plan-generation-log.ts";
import type { LPPhaseResult, PlanInputV2 } from "./types.ts";

const PLAN_ID = "0a3898ab-1111-4222-8333-444455556666";

function food(id: string, carbs: number, sodium: number, fluids: number): FoodResult {
  return {
    food_id: id,
    quantity: 1,
    carbs_grams: carbs,
    protein_grams: 0.4,
    fat_grams: 0,
    sodium_mg: sodium,
    fluids_ml: fluids,
    calories: carbs * 4,
  };
}

/** Input as the e2e suite sends it: duration from macros-v4's `duration_min`. */
function producerShapedRow(durationMin: number): PlanGenerationLogRow {
  const input = {
    device_id: "test-strict-e2e",
    activity_type: "run",
    hours_before: 2.0,
    weight_kg: 70,
    duration_minutes: durationMin,
    gut_training_level: "moderate",
    macro_targets: {
      pre_run: { carbs_g: 78.5, sodium_mg: 350, water_ml: 500 },
      during_run: { carbs_g: 52.3, sodium_mg: 410, water_ml: 620 },
      post_run: { carbs_g: 84.2, sodium_mg: 300, water_ml: 750, protein_g: 21.6 },
    },
  } as unknown as PlanInputV2;
  const during: LPPhaseResult = {
    foods: [food("gel", 22.5, 45.5, 0), food("drink", 29.8, 360.2, 590.4)],
    generation_path: "template",
  };
  const after: LPPhaseResult = {
    foods: [food("bagel", 48.3, 410.7, 0)],
    generation_path: "lp",
  };
  return buildPlanGenerationLogRow({
    planId: PLAN_ID,
    input,
    activityType: "run",
    beforeFoods: [food("banana", 26.9, 1.2, 0)],
    duringResult: during,
    afterResult: after,
    warnings: [],
    testSource: "dev_cloud_e2e",
  });
}

// ----------------------------------------------------------------------------
// Column types of public.plan_generation_log, read from the migrations in
// order: the create table, the funnel columns, then ticket 62's alter.
// ----------------------------------------------------------------------------

const MIGRATIONS = [
  "20260721090000_plan_generation_log.sql",
  "20260903121000_plan_generation_log_funnel_columns.sql",
  "20261008166200_plan_generation_log_numeric_duration.sql",
];

function stripComments(sql: string): string {
  return sql.split("\n").map((l) => l.replace(/--.*$/, "")).join("\n");
}

function columnTypes(): Map<string, string> {
  const types = new Map<string, string>();
  for (const name of MIGRATIONS) {
    const sql = stripComments(
      Deno.readTextFileSync(
        new URL(`../../migrations/${name}`, import.meta.url),
      ),
    );
    const create = sql.match(
      /create table if not exists public\.plan_generation_log \(([\s\S]*?)\);/i,
    );
    if (create) {
      for (const line of create[1].split(",")) {
        const m = line.trim().match(/^(\w+)\s+(\w+)/);
        if (m) types.set(m[1], m[2].toLowerCase());
      }
    }
    for (const m of sql.matchAll(/add column if not exists (\w+) (\w+)/gi)) {
      types.set(m[1], m[2].toLowerCase());
    }
    for (const m of sql.matchAll(/alter column (\w+) type (\w+)/gi)) {
      types.set(m[1], m[2].toLowerCase());
    }
  }
  return types;
}

/** Whether Postgres would accept this JSON value for a column of `type`. */
function accepts(type: string, value: unknown): boolean {
  if (value === null || value === undefined) return true;
  switch (type) {
    case "integer":
      return typeof value === "number" && Number.isInteger(value);
    case "numeric":
      return typeof value === "number" && Number.isFinite(value);
    case "text":
    case "uuid":
      return typeof value === "string";
    case "jsonb":
      return true;
    default:
      return false;
  }
}

describe("buildPlanGenerationLogRow", () => {
  it("keeps a fractional duration_minutes as sent (no rounding)", () => {
    const row = producerShapedRow(18.64);
    assertEquals(row.duration_minutes, 18.64);
  });
});

describe("plan_generation_log column types", () => {
  it("accept every top-level field of a row built from producer-shaped fractional input", () => {
    const types = columnTypes();
    for (const durationMin of [18.64, 117.9]) {
      const row = producerShapedRow(durationMin);
      const rejected: string[] = [];
      for (const [field, value] of Object.entries(row)) {
        const type = types.get(field);
        if (type === undefined) {
          rejected.push(`${field}: no such column`);
        } else if (!accepts(type, value)) {
          rejected.push(`${field}=${JSON.stringify(value)} into ${type}`);
        }
      }
      assertEquals(rejected, [], rejected.join("; "));
    }
  });
});

// ----------------------------------------------------------------------------
// insertPlanGenerationLog: one structured warning per failed write (D9).
// ----------------------------------------------------------------------------

async function captureConsoleWarn(run: () => Promise<void>): Promise<string[]> {
  const lines: string[] = [];
  const original = console.warn;
  console.warn = (...args: unknown[]) => {
    lines.push(
      args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" "),
    );
  };
  try {
    await run();
  } finally {
    console.warn = original;
  }
  return lines;
}

function jsonPart(line: string): Record<string, unknown> {
  return JSON.parse(line.slice(line.indexOf("{")));
}

// deno-lint-ignore no-explicit-any
function fakeClient(insert: (row: unknown) => any): any {
  return { from: (_table: string) => ({ insert }) };
}

describe("insertPlanGenerationLog", () => {
  it("writes one structured warning when the insert returns an error", async () => {
    const row = producerShapedRow(18.64);
    const client = fakeClient(() =>
      Promise.resolve({
        error: {
          code: "22P02",
          message: 'invalid input syntax for type integer: "18.64"',
        },
      })
    );
    const lines = await captureConsoleWarn(() =>
      insertPlanGenerationLog(client, row)
    );
    assertEquals(lines.length, 1, lines.join("\n"));
    assertStringIncludes(lines[0], "[PLAN-V3] plan_generation_log insert failed");
    const json = jsonPart(lines[0]);
    assertEquals(json.plan_id, PLAN_ID);
    assertEquals(json.device_id, "test-strict-e2e");
    assertEquals(json.code, "22P02");
    assertEquals(json.duration_minutes, 18.64);
    assertStringIncludes(String(json.message), "18.64");
  });

  it("writes one structured warning with code threw when the insert throws", async () => {
    const row = producerShapedRow(117.9);
    const client = fakeClient(() => {
      throw new Error("connection reset");
    });
    const lines = await captureConsoleWarn(() =>
      insertPlanGenerationLog(client, row)
    );
    assertEquals(lines.length, 1, lines.join("\n"));
    assertStringIncludes(lines[0], "[PLAN-V3] plan_generation_log insert failed");
    const json = jsonPart(lines[0]);
    assertEquals(json.plan_id, PLAN_ID);
    assertEquals(json.code, "threw");
    assertStringIncludes(String(json.message), "connection reset");
    assertEquals(json.duration_minutes, 117.9);
  });

  it("writes nothing when the insert succeeds", async () => {
    const client = fakeClient(() => Promise.resolve({ error: null }));
    const lines = await captureConsoleWarn(() =>
      insertPlanGenerationLog(client, producerShapedRow(45))
    );
    assertEquals(lines, []);
  });
});
