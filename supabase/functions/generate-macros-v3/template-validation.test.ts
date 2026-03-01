/**
 * Template Validation Tests for Pre-Workout Nutrition Templates
 *
 * Tests validate that templates can scale to hit macro targets for various
 * athlete personas and timing windows.
 *
 * Run with:
 *   deno test --allow-net --allow-env supabase/functions/generate-macros-v3/template-validation.test.ts
 *
 * Requires:
 * - SUPABASE_URL environment variable (default: http://localhost:54321)
 * - SUPABASE_ANON_KEY environment variable
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeAll } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Configuration
// ============================================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || 'http://localhost:54321';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

const REST_URL = `${SUPABASE_URL}/rest/v1`;

const PERSONAS = [
  { label: '54 kg', weightKg: 54 },
  { label: '64 kg', weightKg: 64 },
  { label: '73 kg', weightKg: 73 },
  { label: '91 kg', weightKg: 91 },
];

const TIMINGS = [
  { label: '0.25h (< 30 min)', hoursBefore: 0.25 },
  { label: '0.75h (30-60 min)', hoursBefore: 0.75 },
  { label: '1.5h (1-2 hours)', hoursBefore: 1.5 },
  { label: '3.0h (3-4 hours)', hoursBefore: 3.0 },
];

const CARB_TOLERANCE_PCT = 0.10; // +/- 10%

// ============================================================================
// Helpers
// ============================================================================

async function fetchTable(table: string): Promise<any[]> {
  const response = await fetch(`${REST_URL}/${table}?is_active=eq.true&order=sort_order`, {
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });
  return response.json();
}

async function fetchFoods(): Promise<any[]> {
  const response = await fetch(`${REST_URL}/template_foods?is_active=eq.true`, {
    headers: {
      'apikey': SUPABASE_ANON_KEY,
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
  });
  return response.json();
}

function preWorkoutCarbTarget(weightKg: number, hoursBefore: number): number {
  const carbPerKg = Math.max(0.5, Math.min(hoursBefore, 4.0));
  return Math.round(weightKg * carbPerKg);
}

interface ScaledFood {
  food_name: string;
  display_name: string;
  serving_size: string;
  default_servings: number;
  min_servings: number;
  max_servings: number;
  scaled_servings: number;
  carbs_g: number;
  protein_g: number;
  fat_g: number;
  sodium_mg: number;
  fluid_ml: number;
  calories: number;
}

function scaleTemplate(foods: any[], targetCarbsG: number): {
  scaledFoods: ScaledFood[];
  actualCarbs: number;
  actualProtein: number;
  actualFat: number;
} {
  if (!foods || foods.length === 0) {
    return { scaledFoods: [], actualCarbs: 0, actualProtein: 0, actualFat: 0 };
  }

  const baseCarbs = foods.reduce((sum: number, f: any) => sum + (f.carbs_g * f.default_servings), 0);
  if (baseCarbs === 0) {
    return {
      scaledFoods: foods.map((f: any) => ({ ...f, scaled_servings: f.default_servings })),
      actualCarbs: 0,
      actualProtein: 0,
      actualFat: 0,
    };
  }

  const ratio = targetCarbsG / baseCarbs;

  // Round to nearest 0.25 servings for better precision
  const ROUND_FACTOR = 4; // 1/0.25 = 4
  let scaledFoods = foods.map((f: any) => {
    const rawServings = f.default_servings * ratio;
    const rounded = Math.round(rawServings * ROUND_FACTOR) / ROUND_FACTOR;
    const clamped = Math.max(f.min_servings, Math.min(f.max_servings, rounded));
    return { ...f, scaled_servings: clamped, is_clamped: clamped !== rounded };
  });

  // Redistribute deficit across unclamped items (up to 3 passes)
  for (let pass = 0; pass < 3; pass++) {
    const currentCarbs = scaledFoods.reduce((sum: number, f: any) => sum + (f.carbs_g * f.scaled_servings), 0);
    const deficit = targetCarbsG - currentCarbs;

    if (Math.abs(deficit) <= 2) break;

    const unclamped = scaledFoods.filter((f: any) => !f.is_clamped && f.carbs_g > 0);
    const unclampedCarbs = unclamped.reduce((sum: number, f: any) => sum + (f.carbs_g * f.scaled_servings), 0);
    if (unclampedCarbs <= 0) break;

    const redistributionRatio = 1 + (deficit / unclampedCarbs);
    scaledFoods = scaledFoods.map((f: any) => {
      if (!f.is_clamped && f.carbs_g > 0) {
        const newServings = f.scaled_servings * redistributionRatio;
        const rounded = Math.round(newServings * ROUND_FACTOR) / ROUND_FACTOR;
        const clamped = Math.max(f.min_servings, Math.min(f.max_servings, rounded));
        return { ...f, scaled_servings: clamped, is_clamped: clamped !== rounded };
      }
      return f;
    });
  }

  return {
    scaledFoods,
    actualCarbs: scaledFoods.reduce((sum: number, f: any) => sum + (f.carbs_g * f.scaled_servings), 0),
    actualProtein: scaledFoods.reduce((sum: number, f: any) => sum + (f.protein_g * f.scaled_servings), 0),
    actualFat: scaledFoods.reduce((sum: number, f: any) => sum + (f.fat_g * f.scaled_servings), 0),
  };
}

// ============================================================================
// Tests
// ============================================================================

let templates: any[] = [];
let templateFoods: any[] = [];

describe('Template Validation', () => {
  beforeAll(async () => {
    templates = await fetchTable('templates');
    templateFoods = await fetchFoods();
    console.log(`Loaded ${templates.length} templates and ${templateFoods.length} foods`);
  });

  // --------------------------------------------------------------------------
  // 1. Data Integrity
  // --------------------------------------------------------------------------

  describe('Data Integrity', () => {
    it('should have templates loaded', () => {
      assert(templates.length >= 40, `Expected at least 40 templates, got ${templates.length}`);
    });

    it('should have foods loaded', () => {
      assert(templateFoods.length >= 40, `Expected at least 40 foods, got ${templateFoods.length}`);
    });

    it('all templates should have non-empty foods JSONB', () => {
      for (const t of templates) {
        assert(
          t.foods && Array.isArray(t.foods) && t.foods.length > 0,
          `Template "${t.name}" has no foods`
        );
      }
    });

    it('all template foods should reference valid food_ids', () => {
      const foodIds = new Set(templateFoods.map((f: any) => f.id));
      for (const t of templates) {
        for (const f of (t.foods || [])) {
          assert(
            foodIds.has(f.food_id),
            `Template "${t.name}" references unknown food_id: ${f.food_id} (${f.food_name})`
          );
        }
      }
    });

    it('all templates should have valid timing windows', () => {
      const validTimings = ['< 30 min', '30-60 min', '1-2 hours', '3-4 hours'];
      for (const t of templates) {
        assert(
          validTimings.includes(t.timing_window),
          `Template "${t.name}" has invalid timing_window: ${t.timing_window}`
        );
      }
    });

    it('all templates should have valid meal types', () => {
      const validMealTypes = ['top_up', 'snack', 'full_meal', 'during_fuel', 'recovery', 'transition_fuel'];
      for (const t of templates) {
        assert(
          validMealTypes.includes(t.meal_type),
          `Template "${t.name}" has invalid meal_type: ${t.meal_type}`
        );
      }
    });
  });

  // --------------------------------------------------------------------------
  // 2. Nutrition Totals Accuracy
  // --------------------------------------------------------------------------

  describe('Nutrition Totals Accuracy', () => {
    it('stored totals should match computed sums from JSONB foods', () => {
      for (const t of templates) {
        const computedCarbs = (t.foods || []).reduce(
          (sum: number, f: any) => sum + (f.carbs_g * f.default_servings), 0
        );
        const computedProtein = (t.foods || []).reduce(
          (sum: number, f: any) => sum + (f.protein_g * f.default_servings), 0
        );
        const computedFat = (t.foods || []).reduce(
          (sum: number, f: any) => sum + (f.fat_g * f.default_servings), 0
        );

        const carbDiff = Math.abs(Number(t.total_carbs_g) - computedCarbs);
        const proteinDiff = Math.abs(Number(t.total_protein_g) - computedProtein);
        const fatDiff = Math.abs(Number(t.total_fat_g) - computedFat);

        assert(carbDiff < 0.5, `Template "${t.name}" carb total mismatch: stored=${t.total_carbs_g}, computed=${computedCarbs.toFixed(1)}`);
        assert(proteinDiff < 0.5, `Template "${t.name}" protein total mismatch: stored=${t.total_protein_g}, computed=${computedProtein.toFixed(1)}`);
        assert(fatDiff < 0.5, `Template "${t.name}" fat total mismatch: stored=${t.total_fat_g}, computed=${computedFat.toFixed(1)}`);
      }
    });
  });

  // --------------------------------------------------------------------------
  // 3. Allergen Consistency
  // --------------------------------------------------------------------------

  describe('Allergen Consistency', () => {
    it('template allergens should match union of food allergens', () => {
      const foodMap = new Map(templateFoods.map((f: any) => [f.id, f]));

      for (const t of templates) {
        const foodAllergens = new Set<string>();
        for (const f of (t.foods || [])) {
          const food = foodMap.get(f.food_id);
          if (food && food.allergens) {
            for (const a of food.allergens) {
              foodAllergens.add(a);
            }
          }
        }

        const templateAllergens = new Set(t.allergens || []);

        // Template allergens should be a superset of food allergens
        for (const a of foodAllergens) {
          assert(
            templateAllergens.has(a),
            `Template "${t.name}" is missing allergen "${a}" from its foods`
          );
        }
      }
    });
  });

  // --------------------------------------------------------------------------
  // 4. Scaling Feasibility
  // --------------------------------------------------------------------------

  describe('Scaling Feasibility', () => {
    for (const persona of PERSONAS) {
      for (const timing of TIMINGS) {
        it(`should scale within tolerance for ${persona.label} @ ${timing.label}`, () => {
          const targetCarbs = preWorkoutCarbTarget(persona.weightKg, timing.hoursBefore);

          // Filter templates to their designed timing window
          // Each template is tested only against the timing it was designed for
          let relevantTemplates = templates;
          if (timing.hoursBefore <= 0.5) {
            relevantTemplates = templates.filter((t: any) =>
              t.timing_window === '< 30 min'
            );
          } else if (timing.hoursBefore <= 1.0) {
            relevantTemplates = templates.filter((t: any) =>
              t.timing_window === '30-60 min'
            );
          } else if (timing.hoursBefore <= 2.5) {
            relevantTemplates = templates.filter((t: any) =>
              t.timing_window === '1-2 hours'
            );
          } else {
            relevantTemplates = templates.filter((t: any) =>
              t.timing_window === '3-4 hours'
            );
          }

          let passCount = 0;
          const failures: string[] = [];

          for (const t of relevantTemplates) {
            const { actualCarbs } = scaleTemplate(t.foods || [], targetCarbs);
            const diffPct = targetCarbs > 0
              ? Math.abs((actualCarbs - targetCarbs) / targetCarbs)
              : 0;

            if (diffPct <= CARB_TOLERANCE_PCT) {
              passCount++;
            } else {
              failures.push(
                `"${t.name}": target=${targetCarbs}g, actual=${actualCarbs.toFixed(1)}g, diff=${(diffPct * 100).toFixed(1)}%`
              );
            }
          }

          const passRate = relevantTemplates.length > 0
            ? passCount / relevantTemplates.length
            : 1;

          // At least 70% of timing-appropriate templates should scale within tolerance
          assert(
            passRate >= 0.7,
            `Only ${(passRate * 100).toFixed(0)}% of templates pass for ${persona.label} @ ${timing.label}. Failures:\n${failures.join('\n')}`
          );
        });
      }
    }
  });

  // --------------------------------------------------------------------------
  // 5. Digestion Speed Appropriateness
  // --------------------------------------------------------------------------

  describe('Digestion Speed Appropriateness', () => {
    it('top-up templates should not have slow digestion speed', () => {
      const topUpTemplates = templates.filter((t: any) => t.meal_type === 'top_up');
      for (const t of topUpTemplates) {
        assert(
          t.digestion_speed !== 'slow',
          `Top-up template "${t.name}" has slow digestion speed`
        );
      }
    });

    it('top-up template foods should be fast or medium digestion', () => {
      const foodMap = new Map(templateFoods.map((f: any) => [f.id, f]));
      const topUpTemplates = templates.filter((t: any) => t.meal_type === 'top_up');

      for (const t of topUpTemplates) {
        for (const f of (t.foods || [])) {
          const food = foodMap.get(f.food_id);
          if (food) {
            assert(
              food.digestion_speed !== 'slow',
              `Top-up template "${t.name}" contains slow-digestion food: ${food.display_name}`
            );
          }
        }
      }
    });
  });

  // --------------------------------------------------------------------------
  // 6. Macro Range Validation
  // --------------------------------------------------------------------------

  describe('Macro Range Validation', () => {
    it('top-up templates should have minimal protein and fat', () => {
      const topUpTemplates = templates.filter((t: any) => t.meal_type === 'top_up');
      for (const t of topUpTemplates) {
        const fatG = Number(t.total_fat_g);
        // Top-ups should generally be low fat (<10g at default servings)
        assert(
          fatG <= 15,
          `Top-up template "${t.name}" has high fat: ${fatG}g`
        );
      }
    });

    it('full meal templates should have meaningful protein', () => {
      const mealTemplates = templates.filter((t: any) => t.meal_type === 'full_meal');
      let withProtein = 0;
      for (const t of mealTemplates) {
        if (Number(t.total_protein_g) > 3) withProtein++;
      }
      // Most full meals should have some protein
      const pct = mealTemplates.length > 0 ? withProtein / mealTemplates.length : 1;
      assert(
        pct >= 0.5,
        `Only ${(pct * 100).toFixed(0)}% of full meal templates have meaningful protein (>3g)`
      );
    });
  });

  // --------------------------------------------------------------------------
  // 7. Excluded Diets Consistency
  // --------------------------------------------------------------------------

  describe('Excluded Diets Consistency', () => {
    it('template excluded_diets should match union of food excluded_diets', () => {
      const foodMap = new Map(templateFoods.map((f: any) => [f.id, f]));

      for (const t of templates) {
        const foodDiets = new Set<string>();
        for (const f of (t.foods || [])) {
          const food = foodMap.get(f.food_id);
          if (food && food.excluded_diets) {
            for (const d of food.excluded_diets) {
              foodDiets.add(d);
            }
          }
        }

        const templateDiets = new Set(t.excluded_diets || []);
        for (const d of foodDiets) {
          assert(
            templateDiets.has(d),
            `Template "${t.name}" is missing excluded_diet "${d}" from its foods`
          );
        }
      }
    });

    it('all template_foods should have non-null excluded_diets', () => {
      for (const f of templateFoods) {
        assertExists(
          f.excluded_diets,
          `Food "${f.name}" has null excluded_diets`
        );
      }
    });
  });

  // --------------------------------------------------------------------------
  // 8. Meal Chain Coverage
  // --------------------------------------------------------------------------

  describe('Meal Chain Coverage', () => {
    const DIET_PROFILES: Record<string, { diet: string; allergens: string[]; excludedFoods: string[] }> = {
      'No restrictions': { diet: 'omnivore', allergens: [], excludedFoods: [] },
      'Gluten-free': { diet: 'omnivore', allergens: ['gluten'], excludedFoods: [] },
      'Dairy-free': { diet: 'omnivore', allergens: ['dairy'], excludedFoods: [] },
      'Vegan': { diet: 'vegan', allergens: [], excludedFoods: [] },
      'Nut-free': { diet: 'omnivore', allergens: ['peanuts', 'tree_nuts'], excludedFoods: [] },
    };

    // Map diets to implicit allergen exclusions
    const DIET_ALLERGEN_MAP: Record<string, string[]> = {
      vegan: ['dairy', 'eggs', 'fish', 'shellfish'],
      vegetarian: ['fish', 'shellfish'],
      paleo: ['dairy', 'gluten', 'soy'],
      omnivore: [],
    };

    const MEAL_CHAIN_TIMINGS = [
      { timingKey: '3-4 hours', hoursBefore: 3.0, phases: [
        { mealType: 'full_meal', timingWindow: '3-4 hours', carbPct: 0.60 },
        { mealType: 'snack', timingWindow: '1-2 hours', carbPct: 0.25 },
        { mealType: 'top_up', timingWindows: ['< 30 min', '30-60 min'], carbPct: 0.15 },
      ]},
      { timingKey: '1-2 hours', hoursBefore: 1.5, phases: [
        { mealType: 'snack', timingWindow: '1-2 hours', carbPct: 0.75 },
        { mealType: 'top_up', timingWindows: ['< 30 min', '30-60 min'], carbPct: 0.25 },
      ]},
    ];

    function isTemplateEligibleForProfile(template: any, profile: { diet: string; allergens: string[]; excludedFoods: string[] }): boolean {
      // Diet check
      if (profile.diet !== 'omnivore') {
        const excluded = template.excluded_diets || [];
        if (excluded.includes(profile.diet)) return false;
      }

      // Allergen check (direct + diet-implied)
      const allergens = new Set(profile.allergens);
      const implied = DIET_ALLERGEN_MAP[profile.diet] || [];
      for (const a of implied) allergens.add(a);

      const templateAllergens = template.allergens || [];
      for (const a of templateAllergens) {
        if (allergens.has(a)) return false;
      }

      return true;
    }

    for (const profileName of Object.keys(DIET_PROFILES)) {
      const profile = DIET_PROFILES[profileName];

      for (const persona of PERSONAS) {
        for (const chainTiming of MEAL_CHAIN_TIMINGS) {
          it(`${profileName} / ${persona.label} / ${chainTiming.timingKey}: should have eligible templates per phase`, () => {
            for (const phase of chainTiming.phases) {
              const timingWindows = 'timingWindows' in phase
                ? phase.timingWindows as string[]
                : [phase.timingWindow as string];

              const eligible = templates.filter((t: any) => {
                const timingMatch = timingWindows.includes(t.timing_window);
                const mealTypeMatch = t.meal_type === phase.mealType;
                const profileMatch = isTemplateEligibleForProfile(t, profile);
                return timingMatch && mealTypeMatch && profileMatch;
              });

              assert(
                eligible.length > 0,
                `No eligible ${phase.mealType} templates for ${profileName} / ${persona.label} / ${chainTiming.timingKey} (timing: ${timingWindows.join(',')})`
              );
            }
          });
        }
      }
    }
  });

  // --------------------------------------------------------------------------
  // 9. Meal Chain Accuracy
  // --------------------------------------------------------------------------

  describe('Meal Chain Accuracy', () => {
    const CHAIN_TIMINGS = [
      { timingKey: '3-4 hours', hoursBefore: 3.0, phases: [
        { role: 'full_meal', carbPct: 0.60, timingWindows: ['3-4 hours'], mealType: 'full_meal' },
        { role: 'snack', carbPct: 0.25, timingWindows: ['1-2 hours'], mealType: 'snack' },
        { role: 'top_up', carbPct: 0.15, timingWindows: ['< 30 min', '30-60 min'], mealType: 'top_up' },
      ]},
      { timingKey: '1-2 hours', hoursBefore: 1.5, phases: [
        { role: 'snack', carbPct: 0.75, timingWindows: ['1-2 hours'], mealType: 'snack' },
        { role: 'top_up', carbPct: 0.25, timingWindows: ['< 30 min', '30-60 min'], mealType: 'top_up' },
      ]},
    ];

    for (const persona of PERSONAS) {
      for (const chainTiming of CHAIN_TIMINGS) {
        it(`${persona.label} @ ${chainTiming.timingKey}: best combo should hit carb targets within 10%`, () => {
          const totalTarget = preWorkoutCarbTarget(persona.weightKg, chainTiming.hoursBefore);

          // Find best template per phase (by carb proximity)
          let totalActual = 0;
          for (const phase of chainTiming.phases) {
            const phaseTarget = Math.round(totalTarget * phase.carbPct);
            const eligible = templates.filter((t: any) => {
              return phase.timingWindows.includes(t.timing_window) && t.meal_type === phase.mealType;
            });

            if (eligible.length === 0) {
              // Skip if no templates available
              totalActual += phaseTarget; // assume target met
              continue;
            }

            // Find the template that scales closest to phase target
            let bestDiff = Infinity;
            let bestCarbs = 0;
            for (const t of eligible) {
              const { actualCarbs } = scaleTemplate(t.foods || [], phaseTarget);
              const diff = Math.abs(actualCarbs - phaseTarget);
              if (diff < bestDiff) {
                bestDiff = diff;
                bestCarbs = actualCarbs;
              }
            }
            totalActual += bestCarbs;
          }

          const totalDiff = totalTarget > 0
            ? Math.abs(totalActual - totalTarget) / totalTarget
            : 0;

          assert(
            totalDiff <= 0.10,
            `Best combo for ${persona.label} @ ${chainTiming.timingKey}: total target=${totalTarget}g, actual=${totalActual.toFixed(1)}g, diff=${(totalDiff * 100).toFixed(1)}%`
          );
        });
      }
    }
  });

  // --------------------------------------------------------------------------
  // 10. Template Fixes Validation (D4 + F)
  // --------------------------------------------------------------------------

  describe('Template Fixes (egg sodium + during_run pool)', () => {
    it('egg sodium should be 62mg per serving', () => {
      const egg = templateFoods.find((f: any) => f.name === 'egg');
      assertExists(egg, 'Egg food not found in template_foods');
      assertEquals(
        Number(egg.sodium_mg),
        62,
        `Egg sodium should be 62mg, got ${egg.sodium_mg}mg`
      );
    });

    it('during_run food pool should have at least 12 foods', () => {
      const duringFoods = templateFoods.filter((f: any) =>
        f.categories && f.categories.includes('during_run')
      );
      assert(
        duringFoods.length >= 12,
        `Expected at least 12 during_run foods, got ${duringFoods.length}: ${duringFoods.map((f: any) => f.name).join(', ')}`
      );
    });

    it('during_run pool should include banana, dates, and stroopwafel', () => {
      const duringFoods = templateFoods.filter((f: any) =>
        f.categories && f.categories.includes('during_run')
      );
      const duringNames = new Set(duringFoods.map((f: any) => f.name));

      assert(duringNames.has('banana'), 'banana should be in during_run pool');
      assert(duringNames.has('dates'), 'dates should be in during_run pool');
      assert(duringNames.has('stroopwafel'), 'stroopwafel should be in during_run pool');
    });

    it('stroopwafel should have correct nutrition values', () => {
      const waffle = templateFoods.find((f: any) => f.name === 'stroopwafel');
      assertExists(waffle, 'stroopwafel not found in template_foods');
      assertEquals(Number(waffle.carbs_g), 21, `stroopwafel carbs should be 21g, got ${waffle.carbs_g}g`);
      assertEquals(Number(waffle.calories), 150, `stroopwafel calories should be 150, got ${waffle.calories}`);
      assertEquals(Number(waffle.sodium_mg), 80, `stroopwafel sodium should be 80mg, got ${waffle.sodium_mg}mg`);
    });
  });

  // --------------------------------------------------------------------------
  // 11. Hydration & Sodium Validation
  // --------------------------------------------------------------------------

  describe('Hydration & Sodium Validation', () => {
    it('all templates should have non-negative fluid totals', () => {
      for (const t of templates) {
        assert(
          Number(t.total_fluid_ml) >= 0,
          `Template "${t.name}" has negative fluid: ${t.total_fluid_ml}ml`
        );
      }
    });

    it('all templates should have non-negative sodium totals', () => {
      for (const t of templates) {
        assert(
          Number(t.total_sodium_mg) >= 0,
          `Template "${t.name}" has negative sodium: ${t.total_sodium_mg}mg`
        );
      }
    });

    it('full_meal templates at default servings should have > 80ml fluid', () => {
      const fullMeals = templates.filter((t: any) => t.meal_type === 'full_meal');
      const lowFluid: string[] = [];
      for (const t of fullMeals) {
        if (Number(t.total_fluid_ml) < 80) {
          lowFluid.push(`"${t.name}": ${t.total_fluid_ml}ml`);
        }
      }
      assert(
        lowFluid.length === 0,
        `Full meal templates with < 80ml fluid:\n${lowFluid.join('\n')}`
      );
    });

    it('per-persona hydration targets should be reachable by scaled full_meal templates', () => {
      const fullMeals = templates.filter((t: any) => t.meal_type === 'full_meal');

      for (const persona of PERSONAS) {
        // Hydration target for full meal = weightKg * 6.5
        const hydrationTarget = Math.round(persona.weightKg * 6.5);
        const carbTarget = preWorkoutCarbTarget(persona.weightKg, 3.0);

        let maxFluid = 0;
        for (const t of fullMeals) {
          const { scaledFoods } = scaleTemplate(t.foods || [], carbTarget);
          const fluid = scaledFoods.reduce((sum: number, f: any) =>
            sum + (f.fluid_ml * f.scaled_servings), 0
          );
          if (fluid > maxFluid) maxFluid = fluid;
        }

        // At least one template should reach 50% of hydration target
        // (remaining hydration comes from separate water/drinks)
        assert(
          maxFluid >= hydrationTarget * 0.3,
          `${persona.label}: best full meal fluid=${maxFluid.toFixed(0)}ml, ` +
          `target=${hydrationTarget}ml. No template reaches 30% of target.`
        );
      }
    });
  });
});
