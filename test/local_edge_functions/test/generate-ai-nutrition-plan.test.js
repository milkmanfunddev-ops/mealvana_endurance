// Local test for generate-ai-nutrition-plan edge function
import { test, describe } from 'node:test';
import assert from 'node:assert';
import { generateAINutritionPlan, handleRequest } from '../functions/generate-ai-nutrition-plan.js';

// Test data - mirrors Flutter test data structure
const testMacroTargets = {
  pre_run: {
    carbs_g: 50.0,
    protein_g: 10.0,
    fat_g: 5.0,
    sodium_mg: 100.0,
    water_ml: 200.0
  },
  during_run: {
    carbs_total_g: 60.0,
    sodium_total_mg: 300.0,
    water_total_ml: 500.0
  },
  post_run: {
    carbs_g: 40.0,
    protein_g: 20.0,
    fat_g: 5.0,
    sodium_mg: 150.0,
    water_ml: 300.0
  }
};

const testNutritionPlanRequest = {
  device_id: 'test-device-local',
  age: 30,
  gender: 'female',
  weight_kg: 60.0,
  height_cm: 165.0,
  gut_training_level: 'intermediate',
  distance_miles: 6.2, // 10K
  pace_minutes_per_mile: 8.5,
  time_before_run_hours: 2.0,
  macro_targets: testMacroTargets,
  liked_foods: ['oatmeal', 'banana'],
  willing_to_try_foods: ['sports_drink'],
  disliked_foods: []
};

describe('Generate AI Nutrition Plan - Local Tests', () => {

  test('successfully generates plan with valid request', async () => {
    const result = await generateAINutritionPlan(testNutritionPlanRequest);
    
    assert.strictEqual(result.success, true, 'Should return success: true');
    assert.ok(result.plan, 'Should have plan object');
    assert.ok(result.macro_targets, 'Should have macro_targets object');
    
    // Check plan structure
    assert.ok(result.plan.before, 'Should have before phase');
    assert.ok(result.plan.during, 'Should have during phase');
    assert.ok(result.plan.after, 'Should have after phase');
    
    // Check that phases contain arrays
    assert.ok(Array.isArray(result.plan.before), 'Before phase should be array');
    assert.ok(Array.isArray(result.plan.during), 'During phase should be array');
    assert.ok(Array.isArray(result.plan.after), 'After phase should be array');
  });

  test('validates required fields', async () => {
    const invalidRequest = {
      device_id: 'test-device',
      // Missing macro_targets and other required fields
    };
    
    const result = await generateAINutritionPlan(invalidRequest);
    
    assert.strictEqual(result.success, false, 'Should return success: false');
    assert.ok(result.error, 'Should have error message');
    assert.ok(result.error.includes('Missing required fields'), 'Should mention missing fields');
  });

  test('validates macro_targets structure', async () => {
    const invalidRequest = {
      ...testNutritionPlanRequest,
      macro_targets: {
        pre_run: { carbs_g: 50 },
        // Missing during_run and post_run
      }
    };
    
    const result = await generateAINutritionPlan(invalidRequest);
    
    assert.strictEqual(result.success, false, 'Should return success: false');
    assert.ok(result.error, 'Should have error message');
    assert.ok(result.error.includes('Missing macro_targets'), 'Should mention missing macro_targets phases');
  });

  test('respects food preferences', async () => {
    const requestWithPrefs = {
      ...testNutritionPlanRequest,
      liked_foods: ['oatmeal', 'banana'],
      disliked_foods: ['sports_drink']
    };
    
    const result = await generateAINutritionPlan(requestWithPrefs);
    
    assert.strictEqual(result.success, true, 'Should return success: true');
    
    // Check that disliked foods are not included
    const allFoods = [
      ...result.plan.before,
      ...result.plan.during,
      ...result.plan.after
    ];
    
    const hasSportsDrink = allFoods.some(food => 
      food.food_name && food.food_name.toLowerCase().includes('sports drink')
    );
    
    assert.strictEqual(hasSportsDrink, false, 'Should not include disliked sports drink');
  });

  test('generates foods with proper serving sizes', async () => {
    const result = await generateAINutritionPlan(testNutritionPlanRequest);
    
    assert.strictEqual(result.success, true, 'Should return success: true');
    
    // Check all food items for proper serving increments
    const allFoods = [
      ...result.plan.before,
      ...result.plan.during,
      ...result.plan.after
    ];
    
    for (const food of allFoods) {
      assert.ok(food.servings, 'Should have servings');
      assert.ok(food.food_name, 'Should have food_name');
      assert.ok(food.description, 'Should have description');
      
      // Check servings are in 0.5 increments
      const remainder = (food.servings * 2) % 1;
      assert.ok(Math.abs(remainder) < 0.01, 
        `Food "${food.food_name}" has servings of ${food.servings} - should be in 0.5 increments`);
      
      // Check minimum serving
      assert.ok(food.servings >= 0.5, 
        `Food "${food.food_name}" has servings of ${food.servings} - should be at least 0.5`);
    }
  });

  test('HTTP handler works correctly', async () => {
    const response = await handleRequest(testNutritionPlanRequest);
    
    assert.strictEqual(response.status, 200, 'Should return 200 status');
    assert.ok(response.data, 'Should have data object');
    assert.strictEqual(response.data.success, true, 'Data should indicate success');
  });

  test('HTTP handler handles errors gracefully', async () => {
    const invalidRequest = { device_id: 'test' }; // Missing required fields
    
    const response = await handleRequest(invalidRequest);
    
    assert.ok(response.status >= 400, 'Should return error status');
    assert.ok(response.data, 'Should have data object');
    assert.strictEqual(response.data.success, false, 'Data should indicate failure');
    assert.ok(response.data.error, 'Should have error message');
  });

  test('handles empty food preferences', async () => {
    const requestWithEmptyPrefs = {
      ...testNutritionPlanRequest,
      liked_foods: [],
      willing_to_try_foods: [],
      disliked_foods: []
    };
    
    const result = await generateAINutritionPlan(requestWithEmptyPrefs);
    
    assert.strictEqual(result.success, true, 'Should handle empty preferences');
    assert.ok(result.plan, 'Should still generate a plan');
  });

  test('phase constraints are respected', async () => {
    const result = await generateAINutritionPlan(testNutritionPlanRequest);
    
    assert.strictEqual(result.success, true, 'Should return success: true');
    
    // Check that during phase only has during-appropriate foods
    const duringFoods = result.plan.during;
    
    for (const food of duringFoods) {
      const foodName = food.food_name.toLowerCase();
      
      // Should not have pre-run only foods during run
      assert.ok(!foodName.includes('oatmeal'), 
        'Oatmeal should not appear during runs - safety constraint');
    }
    
    // Should have some suitable during-run foods if available
    const hasDuringFoods = duringFoods.some(food => {
      const foodName = food.food_name.toLowerCase();
      return foodName.includes('sports') || foodName.includes('gel') || foodName.includes('energy');
    });
    
    // Only check if we have during foods (depends on targets)
    if (duringFoods.length > 0) {
      assert.ok(hasDuringFoods, 'Should include suitable during-run foods when needed');
    }
  });

});

// Manual test runner for development
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log('Running manual test...');
  
  const result = await generateAINutritionPlan(testNutritionPlanRequest);
  console.log('Result:', JSON.stringify(result, null, 2));
  
  console.log('\nTest completed successfully!');
}