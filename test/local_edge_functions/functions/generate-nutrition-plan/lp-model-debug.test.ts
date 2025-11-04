import { describe, it, expect, beforeAll } from 'vitest';

// Debug test to understand why LP solver is failing
let solver: any;

beforeAll(async () => {
  const solverModule = await import('javascript-lp-solver');
  solver = solverModule.default;
});

const SIMPLE_FOOD = {
  id: "f1",
  name: "TEST: Banana",
  display_name: "banana",
  carbs_per_serving: 27.0,
  protein_per_serving: 1.3,
  sodium_mg: 1,
  max_servings: 2,
  preference_score: 200,
  per_serving: {
    carbs_g: 27.0,
    protein_g: 1.3,
    sodium_mg: 1,
    water_ml: 88.0
  }
};

describe('Debug LP Model', () => {
  it('should debug simple LP model structure', () => {
    const targets = { carbs_g: 30, protein_g: 0, sodium_mg: 0 };
    const foods = [SIMPLE_FOOD];

    const model: any = {
      optimize: "score",
      opType: "max",
      constraints: {},
      variables: {},
      ints: {}
    };

    // Use corrected constraint structure
    model.constraints.carbs_constraint = {};

    // Add variables
    const varName = 'choose_0';
    const maxServings = 2;

    model.variables[varName] = { score: SIMPLE_FOOD.preference_score };
    model.ints[varName] = 1;

    // Bounds
    model.constraints[`${varName}_bound`] = { max: maxServings };

    // Macro constraints
    model.constraints.carbs_constraint[varName] = SIMPLE_FOOD.per_serving.carbs_g; // 27g per serving

    // Target ranges
    const carbsTolerance = Math.max(10, targets.carbs_g * 0.2); // 10g tolerance
    model.constraints.carbs_constraint.min = Math.max(1, targets.carbs_g - carbsTolerance); // 20g
    model.constraints.carbs_constraint.max = targets.carbs_g + carbsTolerance; // 40g

    console.log('Debug LP Model:', JSON.stringify(model, null, 2));

    // Try to solve
    const solution = solver.Solve(model);
    console.log('Debug Solution:', solution);

    expect(solution).toBeDefined();
    if (solution.feasible) {
      console.log('✅ Simple model solved successfully');
      console.log('Solution details:', solution);
    } else {
      console.log('❌ Simple model failed - constraint issue persists');
    }
  });

  it('should test minimal viable LP model', () => {
    // Absolute minimal model to test LP solver
    const model = {
      optimize: "x",
      opType: "max",
      constraints: {
        constraint1: { max: 10 }
      },
      variables: {
        x: { constraint1: 1 }
      }
    };

    console.log('Minimal model:', JSON.stringify(model, null, 2));

    const solution = solver.Solve(model);
    console.log('Minimal solution:', solution);

    expect(solution).toBeDefined();
    expect(solution.feasible).toBe(true);
  });
});