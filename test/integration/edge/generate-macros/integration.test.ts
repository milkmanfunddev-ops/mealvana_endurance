import { describe, it, expect, beforeAll } from 'vitest';
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env.test') });

// Load golden dataset
const goldenDataPath = path.resolve(__dirname, '../../../local_edge_functions/functions/generate-macros/golden-dataset.json');
const goldenData = JSON.parse(fs.readFileSync(goldenDataPath, 'utf-8'));

// Test configuration from centralized config
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://wvmvsodrvbkxfydabqed.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/generate-macros`;

if (!SUPABASE_SERVICE_KEY) {
  throw new Error('SUPABASE_SERVICE_KEY is required for integration tests');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Helper function to call edge function
async function callGenerateMacros(params: any) {
  console.log('\n📤 Calling generate-macros with:', {
    weight: params.weight,
    distance: params.run_distance,
    pace: params.run_pace,
    gut_training: params.gut_training
  });

  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
    },
    body: JSON.stringify(params)
  });

  const data = await response.json();

  if (!response.ok) {
    console.error('❌ Edge function error:', data);
    throw new Error(`Edge function failed: ${data.message || response.statusText}`);
  }

  console.log('✅ Response received:', {
    success: data.success,
    duration_h: data.macros?.duration_h,
    MET: data.macros?.MET,
    during_rate_g_per_h: data.macros?.during_rate_g_per_h
  });

  return data;
}

// Helper to compare values within tolerance
function expectWithinTolerance(
  actual: number,
  expected: number,
  toleranceKey: string,
  label: string
) {
  const tolerance = goldenData.tolerances[toleranceKey] || 5;
  const diff = Math.abs(actual - expected);

  console.log(`  ${label}: actual=${actual}, expected=${expected}, diff=${diff.toFixed(2)}, tolerance=${tolerance}`);

  expect(diff).toBeLessThanOrEqual(tolerance);
}

describe('Generate Macros - Integration Tests', () => {

  beforeAll(() => {
    console.log('\n🔧 Test Configuration:');
    console.log(`  SUPABASE_URL: ${SUPABASE_URL}`);
    console.log(`  Edge Function: ${EDGE_FUNCTION_URL}`);
    console.log(`  Golden Scenarios: ${goldenData.scenarios.length}`);
  });

  describe('🎯 Golden Dataset Validation', () => {
    // Test first 3 scenarios for quick validation
    const testScenarios = goldenData.scenarios.slice(0, 3);

    testScenarios.forEach(scenario => {
      it(`should match golden data for ${scenario.name}`, async () => {
        console.log(`\n🏃 Testing: ${scenario.name}`);
        console.log(`  ${scenario.description}`);

        const result = await callGenerateMacros(scenario.input);

        expect(result.success).toBe(true);
        expect(result.macros).toBeDefined();

        const macros = result.macros;
        const expected = scenario.expected;

        // Core metrics validation
        console.log('\n📊 Validating core metrics:');
        expectWithinTolerance(macros.duration_h, expected.duration_h, 'duration_h', 'Duration (h)');
        expectWithinTolerance(macros.MET, expected.MET, 'MET', 'MET');

        // Calorie validation
        console.log('\n🔥 Validating calories:');
        expectWithinTolerance(macros.calories_net_kcal, expected.calories_net_kcal, 'calories_kcal', 'Net calories');
        expectWithinTolerance(macros.calories_gross_kcal, expected.calories_gross_kcal, 'calories_kcal', 'Gross calories');

        // Carbohydrate validation
        console.log('\n🍞 Validating carbohydrates:');
        expectWithinTolerance(macros.pre_run_carbs_g, expected.pre_run_carbs_g, 'macros_g', 'Pre-run carbs');
        expectWithinTolerance(macros.during_rate_g_per_h, expected.during_rate_g_per_h, 'macros_per_h', 'During rate');
        expectWithinTolerance(macros.during_total_g, expected.during_total_g, 'macros_g', 'During total');

        // Hydration validation
        console.log('\n💧 Validating hydration:');
        expectWithinTolerance(macros.during_water_rate_ml_per_h, expected.during_water_rate_ml_per_h, 'fluids_ml_per_h', 'Water rate');
        expectWithinTolerance(macros.during_water_total_ml, expected.during_water_total_ml, 'fluids_ml', 'Water total');

        // Sodium validation
        console.log('\n🧂 Validating sodium:');
        expectWithinTolerance(macros.during_sodium_rate_mg_per_h, expected.during_sodium_rate_mg_per_h, 'sodium_mg_per_h', 'Sodium rate');
        expectWithinTolerance(macros.during_sodium_total_mg, expected.during_sodium_total_mg, 'sodium_mg', 'Sodium total');

        console.log('\n✅ Scenario passed!');
      }, 30000); // 30 second timeout
    });
  });

  describe('🚨 Edge Cases', () => {
    it('should handle missing required fields', async () => {
      console.log('\n🧪 Testing missing required fields');

      const result = await callGenerateMacros({
        weight: 70
        // Missing run_distance and run_pace
      });

      expect(result.success).toBe(false);
      expect(result.message).toContain('required');
    });

    it('should handle extreme values safely', async () => {
      console.log('\n🧪 Testing extreme values');

      const result = await callGenerateMacros({
        weight: 150,
        weight_unit: 'kg',
        run_distance: 100,
        run_distance_unit: 'mi',
        run_pace: '15:00',
        run_pace_unit: 'min_per_mile',
        gut_training: 'high',
        temp_c: 40,
        humidity_pct: 95
      });

      expect(result.success).toBe(true);
      expect(result.macros).toBeDefined();

      // Check safety caps are applied
      expect(result.macros.during_rate_g_per_h).toBeLessThanOrEqual(100); // Max absorption
      expect(result.macros.during_sodium_rate_mg_per_h).toBeLessThanOrEqual(1200); // Max sodium

      console.log('✅ Extreme values handled safely');
    });

    it('should handle unit conversions correctly', async () => {
      console.log('\n🧪 Testing unit conversions');

      // Test metric units
      const metricResult = await callGenerateMacros({
        weight: 70,
        weight_unit: 'kg',
        run_distance: 10,
        run_distance_unit: 'km',
        run_pace: '5:00',
        run_pace_unit: 'min_per_km',
        gut_training: 'moderate'
      });

      // Test imperial units for same workout
      const imperialResult = await callGenerateMacros({
        weight: 154.32,
        weight_unit: 'lbs',
        run_distance: 6.21,
        run_distance_unit: 'mi',
        run_pace: '8:03',
        run_pace_unit: 'min_per_mile',
        gut_training: 'moderate'
      });

      expect(metricResult.success).toBe(true);
      expect(imperialResult.success).toBe(true);

      // Results should be very similar
      const metricMET = metricResult.macros.MET;
      const imperialMET = imperialResult.macros.MET;

      console.log(`  Metric MET: ${metricMET}`);
      console.log(`  Imperial MET: ${imperialMET}`);

      expect(Math.abs(metricMET - imperialMET)).toBeLessThan(0.5);

      console.log('✅ Unit conversions working correctly');
    });
  });

  describe('⚡ Performance Tests', () => {
    it('should respond within acceptable time limits', async () => {
      console.log('\n⏱️ Testing response times');

      const scenarios = [
        { name: '5K', distance: 5, unit: 'km' },
        { name: 'Marathon', distance: 26.2, unit: 'mi' },
        { name: 'Ultra', distance: 50, unit: 'mi' }
      ];

      for (const scenario of scenarios) {
        const start = Date.now();

        const result = await callGenerateMacros({
          weight: 70,
          weight_unit: 'kg',
          run_distance: scenario.distance,
          run_distance_unit: scenario.unit,
          run_pace: '5:00',
          run_pace_unit: scenario.unit === 'km' ? 'min_per_km' : 'min_per_mile',
          gut_training: 'moderate'
        });

        const duration = Date.now() - start;

        console.log(`  ${scenario.name}: ${duration}ms`);

        expect(result.success).toBe(true);
        expect(duration).toBeLessThan(5000); // Should respond within 5 seconds
      }

      console.log('✅ All scenarios responded within time limits');
    });
  });

  describe('🔄 Environment Factor Tests', () => {
    it('should adjust for temperature correctly', async () => {
      console.log('\n🌡️ Testing temperature adjustments');

      const baseParams = {
        weight: 70,
        weight_unit: 'kg',
        run_distance: 13.1,
        run_distance_unit: 'mi',
        run_pace: '8:00',
        run_pace_unit: 'min_per_mile',
        gut_training: 'moderate',
        sweat_sodium: 'medium'
      };

      // Cool conditions
      const coolResult = await callGenerateMacros({
        ...baseParams,
        temp_c: 5,
        humidity_pct: 40
      });

      // Hot conditions
      const hotResult = await callGenerateMacros({
        ...baseParams,
        temp_c: 30,
        humidity_pct: 80
      });

      console.log(`  Cool hydration: ${coolResult.macros.during_water_rate_ml_per_h} ml/h`);
      console.log(`  Hot hydration: ${hotResult.macros.during_water_rate_ml_per_h} ml/h`);
      console.log(`  Cool sodium: ${coolResult.macros.during_sodium_rate_mg_per_h} mg/h`);
      console.log(`  Hot sodium: ${hotResult.macros.during_sodium_rate_mg_per_h} mg/h`);

      // Hot conditions should require more hydration and sodium
      expect(hotResult.macros.during_water_rate_ml_per_h).toBeGreaterThan(
        coolResult.macros.during_water_rate_ml_per_h
      );
      expect(hotResult.macros.during_sodium_rate_mg_per_h).toBeGreaterThan(
        coolResult.macros.during_sodium_rate_mg_per_h
      );

      console.log('✅ Temperature adjustments working correctly');
    });

    it('should adjust for gut training levels', async () => {
      console.log('\n🎯 Testing gut training adjustments');

      const baseParams = {
        weight: 70,
        weight_unit: 'kg',
        run_distance: 26.2,
        run_distance_unit: 'mi',
        run_pace: '8:00',
        run_pace_unit: 'min_per_mile',
        carb_source: 'dual'
      };

      // Low gut training
      const lowResult = await callGenerateMacros({
        ...baseParams,
        gut_training: 'low'
      });

      // High gut training
      const highResult = await callGenerateMacros({
        ...baseParams,
        gut_training: 'high'
      });

      console.log(`  Low gut training: ${lowResult.macros.during_rate_g_per_h} g/h`);
      console.log(`  High gut training: ${highResult.macros.during_rate_g_per_h} g/h`);

      // High gut training should allow more carbs
      expect(highResult.macros.during_rate_g_per_h).toBeGreaterThan(
        lowResult.macros.during_rate_g_per_h
      );

      // But both should respect absorption caps
      expect(lowResult.macros.during_rate_g_per_h).toBeLessThanOrEqual(80);
      expect(highResult.macros.during_rate_g_per_h).toBeLessThanOrEqual(100);

      console.log('✅ Gut training adjustments working correctly');
    });
  });
});