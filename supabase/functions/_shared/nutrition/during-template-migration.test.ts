import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

const migrationPath = new URL(
  "../../../migrations/20260406320000_during_workout_templates_complete.sql",
  import.meta.url,
).pathname;

async function readMigration(path: string): Promise<string> {
  return await Deno.readTextFile(path);
}

function regexEscape(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

describe("During workout template migrations", () => {
  it("creates a public read-only during_workout_templates catalog", async () => {
    const sql = await readMigration(migrationPath);

    assertStringIncludes(
      sql,
      "CREATE TABLE IF NOT EXISTS public.during_workout_templates",
    );
    assertStringIncludes(sql, "template_number INTEGER NOT NULL UNIQUE");
    assertStringIncludes(sql, "component_food_names TEXT[] NOT NULL");
    assertStringIncludes(sql, "component_carb_ratios JSONB");
    assertStringIncludes(
      sql,
      "ALTER TABLE public.during_workout_templates ENABLE ROW LEVEL SECURITY",
    );
    assertStringIncludes(
      sql,
      'CREATE POLICY "during_workout_templates_select"',
    );
    assertStringIncludes(
      sql,
      "ON public.during_workout_templates FOR SELECT USING (true)",
    );
  });

  it("seeds every template number from 0 through 24", async () => {
    const sql = await readMigration(migrationPath);
    const templateNumbers = [...sql.matchAll(/^\s*\(\s*(\d+),\s*'/gm)].map((
      match,
    ) => Number(match[1]));
    const uniqueNumbers = [...new Set(templateNumbers)].sort((a, b) => a - b);

    assertEquals(uniqueNumbers.length, 25);
    assertEquals(
      uniqueNumbers,
      Array.from({ length: 25 }, (_, index) => index),
    );
  });

  it("preserves the documented activity, duration, and gut gates for every template", async () => {
    const sql = await readMigration(migrationPath);
    const expectations = [
      [
        0,
        "Quick Gel Module (T1/T2)",
        "{triathlon_transition}",
        "{90-150 min,150-240 min,> 240 min}",
        "{low,moderate,high}",
      ],
      [
        1,
        "Gel + Water",
        "{running,triathlon_run}",
        "{90-150 min}",
        "{low,moderate,high}",
      ],
      [
        2,
        "(Gel + Water) + Sports Drink",
        "{running,triathlon_run}",
        "{90-150 min,150-240 min,> 240 min}",
        "{moderate,high}",
      ],
      [
        3,
        "Chew + Water",
        "{running,triathlon_run}",
        "{90-150 min}",
        "{low,moderate,high}",
      ],
      [
        4,
        "Chew + Water + Sports Drink",
        "{running,triathlon_run}",
        "{90-150 min,150-240 min,> 240 min}",
        "{moderate,high}",
      ],
      [
        5,
        "Sports Drink Only",
        "{running,cycling,triathlon_bike,triathlon_run}",
        "{< 90 min}",
        "{low,moderate,high}",
      ],
      [
        6,
        "High Carb Drink Mix + Water",
        "{cycling,triathlon_bike}",
        "{90-150 min,150-240 min}",
        "{high}",
      ],
      [
        7,
        "Bar + Sports Drink + Water",
        "{cycling,triathlon_bike}",
        "{90-150 min}",
        "{low,moderate,high}",
      ],
      [
        8,
        "Bar + (Gel + Water) + Sports Drink",
        "{cycling,triathlon_bike}",
        "{150-240 min}",
        "{moderate,high}",
      ],
      [
        9,
        "Stroopwafel + Sports Drink + Water",
        "{cycling,triathlon_bike}",
        "{90-150 min}",
        "{low,moderate,high}",
      ],
      [
        10,
        "Stroopwafel + (Gel + Water) + Sports Drink",
        "{cycling,triathlon_bike}",
        "{150-240 min}",
        "{moderate,high}",
      ],
      [
        11,
        "Banana + Sports Drink + Water",
        "{cycling,triathlon_bike}",
        "{90-150 min}",
        "{low,moderate,high}",
      ],
      [
        12,
        "Banana + (Gel + Water) + Sports Drink",
        "{cycling,triathlon_bike}",
        "{150-240 min}",
        "{moderate,high}",
      ],
      [
        13,
        "Rice Cake + Sports Drink + Water",
        "{cycling,triathlon_bike}",
        "{90-150 min,150-240 min,> 240 min}",
        "{low,moderate,high}",
      ],
      [
        14,
        "Rice Cake + (Gel + Water) + Sports Drink",
        "{cycling,triathlon_bike}",
        "{150-240 min,> 240 min}",
        "{moderate,high}",
      ],
      [
        15,
        "Chew + Water (Cycling)",
        "{cycling,triathlon_bike}",
        "{90-150 min}",
        "{low,moderate,high}",
      ],
      [
        16,
        "Chew + Water + Sports Drink (Cycling)",
        "{cycling,triathlon_bike}",
        "{90-150 min,150-240 min,> 240 min}",
        "{moderate,high}",
      ],
      [
        17,
        "High Carb Drink Mix + Bar + Water",
        "{cycling,triathlon_bike}",
        "{150-240 min,> 240 min}",
        "{high}",
      ],
      [
        18,
        "High Carb Drink Mix + Stroopwafel + Water",
        "{cycling,triathlon_bike}",
        "{150-240 min,> 240 min}",
        "{high}",
      ],
      [
        19,
        "High Carb Drink Mix + Banana + Water",
        "{cycling,triathlon_bike}",
        "{150-240 min,> 240 min}",
        "{high}",
      ],
      [
        20,
        "High Carb Drink Mix + Rice Cake + Water",
        "{cycling,triathlon_bike}",
        "{150-240 min,> 240 min}",
        "{high}",
      ],
    ] as const;

    for (
      const [number, name, activityTypes, durationBrackets, gutLevels]
        of expectations
    ) {
      const pattern = new RegExp(
        `\\(${number}, '${regexEscape(name)}'[\\s\\S]*?'${
          regexEscape(activityTypes)
        }'[\\s\\S]*?'${regexEscape(durationBrackets)}'[\\s\\S]*?'${
          regexEscape(gutLevels)
        }'`,
      );
      assert(
        pattern.test(sql),
        `Expected template ${number} (${name}) to keep activity=${activityTypes}, duration=${durationBrackets}, gut=${gutLevels}`,
      );
    }
  });

  it("seeds the during-specific rice cake used by cycling templates", async () => {
    const sql = await readMigration(migrationPath);

    assertStringIncludes(sql, "'rice_cake_during'");
    assertStringIncludes(sql, "'{rice_cake_during,sports_drink,water}'");
    assertStringIncludes(sql, "'{high_carb_drink_mix,rice_cake_during,water}'");
    assertStringIncludes(
      sql,
      "max_per_hr_low, max_per_hr_moderate, max_per_hr_high, min_increment",
    );
    assertStringIncludes(sql, "1, 1, 2, 0.5");
  });

  it("adds and populates per-hour serving constraints for during products", async () => {
    const sql = await readMigration(migrationPath);

    for (
      const column of [
        "max_per_hr_low",
        "max_per_hr_moderate",
        "max_per_hr_high",
        "min_increment",
      ]
    ) {
      assertStringIncludes(sql, `ADD COLUMN IF NOT EXISTS ${column}`);
    }

    for (
      const foodName of [
        "energy_gel",
        "energy_chews",
        "energy_bar",
        "stroopwafel",
        "banana",
        "sports_drink",
        "high_carb_drink_mix",
        "water",
      ]
    ) {
      assert(
        sql.includes(`name = '${foodName}'`) ||
          sql.includes(`'${foodName}'`),
        `Expected constraint migration to mention ${foodName}`,
      );
    }

    assertStringIncludes(
      sql,
      "is_electrolyte = true AND is_indivisible = true",
    );
    assertStringIncludes(
      sql,
      "is_electrolyte = true AND is_indivisible = false",
    );
  });

  it("moves sodium top-up eligibility into template_foods data", async () => {
    const sql = await readMigration(migrationPath);

    assertStringIncludes(
      sql,
      "ADD COLUMN IF NOT EXISTS sodium_top_up_eligible",
    );
    assertStringIncludes(sql, "sodium_top_up_eligible = true");
    assertStringIncludes(sql, "is_electrolyte = true");
    assertStringIncludes(sql, "COALESCE(carbs_g, 0) <= 5");
    assertStringIncludes(sql, "sodium_top_up_eligible = false");
    assertStringIncludes(sql, "'sports_drink'");
    assertStringIncludes(sql, "'sports_drink_mix'");
    assertStringIncludes(sql, "'electrolyte_drink_mix'");
    assertStringIncludes(sql, "'high_carb_drink_mix'");
  });

  it("splits carb drink mix from high-carb drink mix in catalog data", async () => {
    const sql = await readMigration(migrationPath);

    assertStringIncludes(sql, "ADD COLUMN IF NOT EXISTS selection_priority");
    assertStringIncludes(sql, "'carb_drink_mix'");
    assertStringIncludes(sql, "'Carb Drink Mix'");
    assertStringIncludes(sql, "60.0");
    assertStringIncludes(sql, "max_per_hr_moderate");
    assertStringIncludes(sql, "max_per_hr_high");
    assertStringIncludes(sql, "WHERE name = 'high_carb_drink_mix'");
    assertStringIncludes(sql, "carbs_g = 90.0");
    assertStringIncludes(sql, "max_per_hr_moderate = 0");
    assertStringIncludes(sql, "max_per_hr_high = 1");
    assertStringIncludes(sql, "sodium_top_up_eligible = FALSE");
  });

  it("adds moderate/high carb-drink templates for long bike workouts", async () => {
    const sql = await readMigration(migrationPath);
    const expectations = [
      [21, "Carb Drink Mix + Bar + Water", "{carb_drink_mix,energy_bar,water}"],
      [
        22,
        "Carb Drink Mix + Stroopwafel + Water",
        "{carb_drink_mix,stroopwafel,water}",
      ],
      [23, "Carb Drink Mix + Banana + Water", "{carb_drink_mix,banana,water}"],
      [
        24,
        "Carb Drink Mix + Rice Cake + Water",
        "{carb_drink_mix,rice_cake_during,water}",
      ],
    ] as const;

    for (const [number, name, componentFoods] of expectations) {
      const pattern = new RegExp(
        `\\(${number}, '${
          regexEscape(name)
        }'[\\s\\S]*?'\\{cycling,triathlon_bike\\}'[\\s\\S]*?'\\{150-240 min,> 240 min\\}'[\\s\\S]*?'\\{moderate,high\\}'[\\s\\S]*?'${
          regexEscape(componentFoods)
        }'[\\s\\S]*?30\\)`,
      );
      assert(
        pattern.test(sql),
        `Expected template ${number} (${name}) to be a moderate/high long-bike carb drink mix template`,
      );
    }
  });
});
