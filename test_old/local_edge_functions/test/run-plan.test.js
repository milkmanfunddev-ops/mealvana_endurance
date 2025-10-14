// Local test for run-plan edge function
import { test, describe } from 'node:test';
import assert from 'node:assert';
import { generateRunPlan, handleRequest } from '../functions/run-plan.js';

// Test data
const testRunPlanRequest = {
  device_id: 'test-device-run-plan',
  age: 30,
  gender: 'female',
  weight_kg: 60.0,
  height_cm: 165.0,
  gut_training_level: 'intermediate',
  distance_miles: 6.2, // 10K
  pace_minutes_per_mile: 8.5,
  time_before_run_hours: 2.0
};

const testHalfMarathonRequest = {
  ...testRunPlanRequest,
  distance_miles: 13.1,
  pace_minutes_per_mile: 9.0,
  gut_training_level: 'advanced'
};

const test5KRequest = {
  ...testRunPlanRequest,
  distance_miles: 3.1,
  pace_minutes_per_mile: 8.0,
  gut_training_level: 'beginner'
};

describe('Run Plan - Local Tests', () => {

  test('successfully generates macro targets for 10K run', async () => {
    const result = await generateRunPlan(testRunPlanRequest);
    
    assert.strictEqual(result.success, true, 'Should return success: true');
    assert.ok(result.macro_targets, 'Should have macro_targets object');
    assert.ok(result.energy_info, 'Should have energy_info object');
    assert.strictEqual(result.algorithm_used, 'ACSM_based', 'Should use ACSM algorithm');
    
    // Check macro_targets structure
    assert.ok(result.macro_targets.pre_run, 'Should have pre_run targets');
    assert.ok(result.macro_targets.during_run, 'Should have during_run targets');
    assert.ok(result.macro_targets.post_run, 'Should have post_run targets');
    
    // Validate pre-run targets
    const preRun = result.macro_targets.pre_run;
    assert.ok(preRun.carbs_g > 0, 'Pre-run should have carbs');
    assert.ok(preRun.protein_g > 0, 'Pre-run should have protein');
    assert.ok(preRun.water_ml > 0, 'Pre-run should have hydration');
    
    // Validate energy calculations
    assert.ok(result.energy_info.duration_minutes > 0, 'Should calculate duration');
    assert.ok(result.energy_info.total_kcal > 0, 'Should calculate calories');
    assert.ok(result.energy_info.vo2_ml_kg_min > 0, 'Should calculate VO2');
  });

  test('scales nutrition needs based on body weight', async () => {
    const lightRequest = { ...testRunPlanRequest, weight_kg: 50.0 };
    const heavyRequest = { ...testRunPlanRequest, weight_kg: 80.0 };
    
    const lightResult = await generateRunPlan(lightRequest);
    const heavyResult = await generateRunPlan(heavyRequest);
    
    assert.strictEqual(lightResult.success, true);
    assert.strictEqual(heavyResult.success, true);
    
    // Heavier person should need more carbs
    assert.ok(heavyResult.macro_targets.pre_run.carbs_g > lightResult.macro_targets.pre_run.carbs_g,
      'Heavier person should need more pre-run carbs');
      
    assert.ok(heavyResult.macro_targets.post_run.carbs_g > lightResult.macro_targets.post_run.carbs_g,
      'Heavier person should need more post-run carbs');
  });

  test('adjusts during-run needs based on gut training level', async () => {
    const beginnerRequest = { ...testRunPlanRequest, gut_training_level: 'beginner' };
    const advancedRequest = { ...testRunPlanRequest, gut_training_level: 'advanced' };
    
    const beginnerResult = await generateRunPlan(beginnerRequest);
    const advancedResult = await generateRunPlan(advancedRequest);
    
    assert.strictEqual(beginnerResult.success, true);
    assert.strictEqual(advancedResult.success, true);
    
    // Advanced should be able to handle more carbs during run
    assert.ok(advancedResult.macro_targets.during_run.carbs_total_g >= 
              beginnerResult.macro_targets.during_run.carbs_total_g,
      'Advanced gut training should allow more during-run carbs');
  });

  test('provides minimal during-run nutrition for short runs', async () => {
    const result = await generateRunPlan(test5KRequest);
    
    assert.strictEqual(result.success, true);
    
    // 5K should have minimal or no during-run carbs/sodium
    const duringRun = result.macro_targets.during_run;
    assert.strictEqual(duringRun.carbs_total_g, 0, 'Short runs should not need during-run carbs');
    assert.strictEqual(duringRun.sodium_total_mg, 0, 'Short runs should not need during-run sodium');
    
    // But should still have some hydration
    assert.ok(duringRun.water_total_ml > 0, 'Should still provide some hydration');
  });

  test('provides substantial during-run nutrition for long runs', async () => {
    const result = await generateRunPlan(testHalfMarathonRequest);
    
    assert.strictEqual(result.success, true);
    
    // Half marathon should have significant during-run needs
    const duringRun = result.macro_targets.during_run;
    assert.ok(duringRun.carbs_total_g > 50, 'Long runs should need substantial during-run carbs');
    assert.ok(duringRun.sodium_total_mg > 200, 'Long runs should need during-run sodium');
    assert.ok(duringRun.water_total_ml > 500, 'Long runs should need substantial hydration');
  });

  test('adjusts pre-run carbs based on timing', async () => {
    const earlyRequest = { ...testRunPlanRequest, time_before_run_hours: 4.0 };
    const lateRequest = { ...testRunPlanRequest, time_before_run_hours: 1.0 };
    
    const earlyResult = await generateRunPlan(earlyRequest);
    const lateResult = await generateRunPlan(lateRequest);
    
    assert.strictEqual(earlyResult.success, true);
    assert.strictEqual(lateResult.success, true);
    
    // Earlier timing allows more pre-run carbs
    assert.ok(earlyResult.macro_targets.pre_run.carbs_g >= lateResult.macro_targets.pre_run.carbs_g,
      'Earlier timing should allow more pre-run carbs');
  });

  test('validates required fields', async () => {
    const invalidRequest = {
      device_id: 'test-device',
      // Missing weight_kg, distance_miles, pace_minutes_per_mile
    };
    
    const result = await generateRunPlan(invalidRequest);
    
    assert.strictEqual(result.success, false, 'Should return success: false');
    assert.ok(result.error, 'Should have error message');
    assert.ok(result.error.includes('Missing required fields'), 'Should mention missing fields');
  });

  test('calculates reasonable energy expenditure', async () => {
    const result = await generateRunPlan(testRunPlanRequest);
    
    assert.strictEqual(result.success, true);
    
    const energyInfo = result.energy_info;
    
    // For 6.2 mile run at 8.5 min/mile pace:
    const expectedDuration = 6.2 * 8.5; // ~52.7 minutes
    assert.ok(Math.abs(energyInfo.duration_minutes - expectedDuration) < 1,
      `Duration should be ~${expectedDuration} minutes, got ${energyInfo.duration_minutes}`);
    
    // Should be reasonable VO2 for running
    assert.ok(energyInfo.vo2_ml_kg_min > 20 && energyInfo.vo2_ml_kg_min < 80,
      `VO2 should be reasonable for running (20-80), got ${energyInfo.vo2_ml_kg_min}`);
    
    // Should burn reasonable calories for distance
    assert.ok(energyInfo.total_kcal > 300 && energyInfo.total_kcal < 800,
      `Calories should be reasonable for 10K (~300-800), got ${energyInfo.total_kcal}`);
  });

  test('HTTP handler works correctly', async () => {
    const response = await handleRequest(testRunPlanRequest);
    
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

  test('handles default values gracefully', async () => {
    const minimalRequest = {
      device_id: 'test-device',
      weight_kg: 60.0,
      distance_miles: 5.0,
      pace_minutes_per_mile: 9.0
      // Missing gut_training_level and time_before_run_hours (should use defaults)
    };
    
    const result = await generateRunPlan(minimalRequest);
    
    assert.strictEqual(result.success, true, 'Should handle default values');
    assert.ok(result.macro_targets, 'Should still generate targets with defaults');
  });

});

// Manual test runner for development
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log('Running manual test...');
  
  const result = await generateRunPlan(testRunPlanRequest);
  console.log('10K Result:', JSON.stringify(result, null, 2));
  
  const halfResult = await generateRunPlan(testHalfMarathonRequest);
  console.log('\nHalf Marathon Result:', JSON.stringify(halfResult, null, 2));
  
  const fiveKResult = await generateRunPlan(test5KRequest);
  console.log('\n5K Result:', JSON.stringify(fiveKResult, null, 2));
  
  console.log('\nTest completed successfully!');
}