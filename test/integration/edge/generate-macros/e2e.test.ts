import { describe, it, expect, beforeAll } from 'vitest';
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env.test') });

// Test configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://wvmvsodrvbkxfydabqed.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/generate-macros`;

if (!SUPABASE_SERVICE_KEY) {
  throw new Error('SUPABASE_SERVICE_KEY is required for E2E tests');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Helper to call edge function with timing
async function callGenerateMacrosWithTiming(params: any) {
  const start = Date.now();

  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
    },
    body: JSON.stringify(params)
  });

  const duration = Date.now() - start;
  const data = await response.json();

  return { data, duration, status: response.status };
}

describe('Generate Macros - E2E Tests', () => {

  beforeAll(() => {
    console.log('\n🌐 E2E Test Configuration:');
    console.log(`  Environment: ${SUPABASE_URL.includes('local') ? 'Local' : 'Dev Cloud'}`);
    console.log(`  Edge Function: ${EDGE_FUNCTION_URL}`);
    console.log(`  Timestamp: ${new Date().toISOString()}`);
  });

  describe('🏃 Complete Runner Journey Tests', () => {

    it('should handle beginner runner progression', async () => {
      console.log('\n👟 Testing Beginner Runner Progression');

      // Week 1: First 5K
      console.log('\n  Week 1 - First 5K:');
      const week1 = await callGenerateMacrosWithTiming({
        weight: 75,
        weight_unit: 'kg',
        run_distance: 5,
        run_distance_unit: 'km',
        run_pace: '7:00',
        run_pace_unit: 'min_per_km',
        gut_training: 'low',
        time_before_run_min: 90,
        sweat_sodium: 'medium',
        temp_c: 20,
        humidity_pct: 60
      });

      expect(week1.data.success).toBe(true);
      console.log(`    Duration: ${week1.data.macros.duration_min} min`);
      console.log(`    Pre-run carbs: ${week1.data.macros.pre_run_carbs_g}g`);
      console.log(`    During carbs: ${week1.data.macros.during_total_g}g`);
      console.log(`    Response time: ${week1.duration}ms`);

      // Week 8: First 10K
      console.log('\n  Week 8 - First 10K:');
      const week8 = await callGenerateMacrosWithTiming({
        weight: 73, // Lost some weight
        weight_unit: 'kg',
        run_distance: 10,
        run_distance_unit: 'km',
        run_pace: '6:30',
        run_pace_unit: 'min_per_km',
        gut_training: 'moderate', // Improved gut training
        time_before_run_min: 120,
        sweat_sodium: 'medium',
        temp_c: 22,
        humidity_pct: 65
      });

      expect(week8.data.success).toBe(true);
      console.log(`    Duration: ${week8.data.macros.duration_min} min`);
      console.log(`    During carbs rate: ${week8.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Response time: ${week8.duration}ms`);

      // Week 16: First Half Marathon
      console.log('\n  Week 16 - First Half Marathon:');
      const week16 = await callGenerateMacrosWithTiming({
        weight: 71,
        weight_unit: 'kg',
        run_distance: 21.1,
        run_distance_unit: 'km',
        run_pace: '6:00',
        run_pace_unit: 'min_per_km',
        gut_training: 'moderate',
        time_before_run_min: 150,
        sweat_sodium: 'medium',
        optional_sweat_rate_lph: 0.7, // Now knows their sweat rate
        temp_c: 18,
        humidity_pct: 55
      });

      expect(week16.data.success).toBe(true);
      console.log(`    Duration: ${week16.data.macros.duration_h.toFixed(2)} hours`);
      console.log(`    Total carbs needed: ${week16.data.macros.during_total_g}g`);
      console.log(`    Hydration: ${week16.data.macros.during_water_total_ml}ml`);
      console.log(`    Response time: ${week16.duration}ms`);

      // Verify progression makes sense
      expect(week8.data.macros.during_rate_g_per_h).toBeGreaterThanOrEqual(
        week1.data.macros.during_rate_g_per_h
      );
      expect(week16.data.macros.during_rate_g_per_h).toBeGreaterThanOrEqual(
        week8.data.macros.during_rate_g_per_h
      );

      console.log('\n✅ Beginner progression validated!');
    });

    it('should handle race day scenarios with different conditions', async () => {
      console.log('\n🏁 Testing Race Day Scenarios');

      const baseRaceParams = {
        weight: 68,
        weight_unit: 'kg',
        run_distance: 26.2,
        run_distance_unit: 'mi',
        run_pace: '3:30:00', // 3:30 marathon
        run_pace_unit: 'total_time',
        gut_training: 'high',
        time_before_run_min: 180,
        sweat_sodium: 'medium',
        drink_sodium_mg_per_l: 600
      };

      // Boston Marathon (cool morning)
      console.log('\n  🌤️ Boston Marathon Conditions:');
      const boston = await callGenerateMacrosWithTiming({
        ...baseRaceParams,
        run_pace: '8:00',
        run_pace_unit: 'min_per_mile',
        temp_c: 12,
        humidity_pct: 50
      });

      expect(boston.data.success).toBe(true);
      console.log(`    Conditions: Cool (12°C, 50% humidity)`);
      console.log(`    Carb strategy: ${boston.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Hydration: ${boston.data.macros.during_water_rate_ml_per_h}ml/h`);
      console.log(`    Sodium: ${boston.data.macros.during_sodium_rate_mg_per_h}mg/h`);

      // Chicago Marathon (perfect conditions)
      console.log('\n  🌆 Chicago Marathon Conditions:');
      const chicago = await callGenerateMacrosWithTiming({
        ...baseRaceParams,
        run_pace: '7:45',
        run_pace_unit: 'min_per_mile',
        temp_c: 15,
        humidity_pct: 45
      });

      expect(chicago.data.success).toBe(true);
      console.log(`    Conditions: Ideal (15°C, 45% humidity)`);
      console.log(`    Carb strategy: ${chicago.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Hydration: ${chicago.data.macros.during_water_rate_ml_per_h}ml/h`);

      // Honolulu Marathon (hot and humid)
      console.log('\n  🌺 Honolulu Marathon Conditions:');
      const honolulu = await callGenerateMacrosWithTiming({
        ...baseRaceParams,
        run_pace: '8:30',
        run_pace_unit: 'min_per_mile',
        temp_c: 28,
        humidity_pct: 80,
        optional_sweat_rate_lph: 1.2
      });

      expect(honolulu.data.success).toBe(true);
      console.log(`    Conditions: Hot & Humid (28°C, 80% humidity)`);
      console.log(`    Carb strategy: ${honolulu.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Hydration: ${honolulu.data.macros.during_water_rate_ml_per_h}ml/h`);
      console.log(`    Sodium: ${honolulu.data.macros.during_sodium_rate_mg_per_h}mg/h`);

      // Verify environmental adjustments
      expect(honolulu.data.macros.during_water_rate_ml_per_h).toBeGreaterThan(
        boston.data.macros.during_water_rate_ml_per_h
      );
      expect(honolulu.data.macros.during_sodium_rate_mg_per_h).toBeGreaterThan(
        boston.data.macros.during_sodium_rate_mg_per_h
      );

      console.log('\n✅ Race day scenarios validated!');
    });

    it('should handle ultra marathon fueling strategies', async () => {
      console.log('\n🏔️ Testing Ultra Marathon Strategies');

      // 50K Trail Run
      console.log('\n  50K Trail Run:');
      const fiftyK = await callGenerateMacrosWithTiming({
        weight: 72,
        weight_unit: 'kg',
        run_distance: 50,
        run_distance_unit: 'km',
        run_pace: '7:00',
        run_pace_unit: 'min_per_km',
        gut_training: 'high',
        carb_source: 'dual',
        time_before_run_min: 240,
        sweat_sodium: 'high',
        optional_sweat_rate_lph: 1.0,
        temp_c: 20,
        humidity_pct: 60
      });

      expect(fiftyK.data.success).toBe(true);
      const duration50K = fiftyK.data.macros.duration_h;
      console.log(`    Duration: ${duration50K.toFixed(1)} hours`);
      console.log(`    Carbs: ${fiftyK.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Protein: ${fiftyK.data.macros.during_protein_per_h_g || 0}g/h`);
      console.log(`    Total carbs: ${fiftyK.data.macros.during_total_g}g`);

      // 100 Mile Ultra
      console.log('\n  100 Mile Ultra:');
      const hundredMiler = await callGenerateMacrosWithTiming({
        weight: 75,
        weight_unit: 'kg',
        run_distance: 100,
        run_distance_unit: 'mi',
        run_pace: '12:00',
        run_pace_unit: 'min_per_mile',
        gut_training: 'high',
        carb_source: 'dual',
        time_before_run_min: 240,
        sweat_sodium: 'medium',
        sweat_rate_category: 'medium',
        temp_c: 18,
        humidity_pct: 55
      });

      expect(hundredMiler.data.success).toBe(true);
      const duration100M = hundredMiler.data.macros.duration_h;
      console.log(`    Duration: ${duration100M.toFixed(1)} hours`);
      console.log(`    Carbs: ${hundredMiler.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Total carbs: ${hundredMiler.data.macros.during_total_g}g`);
      console.log(`    Total hydration: ${(hundredMiler.data.macros.during_water_total_ml / 1000).toFixed(1)}L`);

      // Verify ultra-specific adaptations
      expect(duration50K).toBeGreaterThan(3.5); // Should trigger protein/fat
      expect(duration100M).toBeGreaterThan(10); // Extreme duration

      console.log('\n✅ Ultra marathon strategies validated!');
    });

    it('should handle different athlete profiles', async () => {
      console.log('\n👥 Testing Different Athlete Profiles');

      const halfMarathonDistance = {
        run_distance: 13.1,
        run_distance_unit: 'mi',
        run_pace: '8:00',
        run_pace_unit: 'min_per_mile'
      };

      // Lightweight runner
      console.log('\n  🪶 Lightweight Runner (50kg):');
      const lightweight = await callGenerateMacrosWithTiming({
        ...halfMarathonDistance,
        weight: 50,
        weight_unit: 'kg',
        gut_training: 'moderate',
        time_before_run_min: 120,
        temp_c: 20,
        humidity_pct: 60
      });

      expect(lightweight.data.success).toBe(true);
      console.log(`    Calories: ${lightweight.data.macros.calories_net_kcal} kcal`);
      console.log(`    Carbs: ${lightweight.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Hydration: ${lightweight.data.macros.during_water_rate_ml_per_h}ml/h`);

      // Average runner
      console.log('\n  👤 Average Runner (70kg):');
      const average = await callGenerateMacrosWithTiming({
        ...halfMarathonDistance,
        weight: 70,
        weight_unit: 'kg',
        gut_training: 'moderate',
        time_before_run_min: 120,
        temp_c: 20,
        humidity_pct: 60
      });

      expect(average.data.success).toBe(true);
      console.log(`    Calories: ${average.data.macros.calories_net_kcal} kcal`);
      console.log(`    Carbs: ${average.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Hydration: ${average.data.macros.during_water_rate_ml_per_h}ml/h`);

      // Heavyweight runner
      console.log('\n  💪 Heavyweight Runner (90kg):');
      const heavyweight = await callGenerateMacrosWithTiming({
        ...halfMarathonDistance,
        weight: 90,
        weight_unit: 'kg',
        gut_training: 'moderate',
        time_before_run_min: 120,
        temp_c: 20,
        humidity_pct: 60
      });

      expect(heavyweight.data.success).toBe(true);
      console.log(`    Calories: ${heavyweight.data.macros.calories_net_kcal} kcal`);
      console.log(`    Carbs: ${heavyweight.data.macros.during_rate_g_per_h}g/h`);
      console.log(`    Hydration: ${heavyweight.data.macros.during_water_rate_ml_per_h}ml/h`);

      // Verify weight-based scaling
      expect(heavyweight.data.macros.calories_net_kcal).toBeGreaterThan(
        average.data.macros.calories_net_kcal
      );
      expect(average.data.macros.calories_net_kcal).toBeGreaterThan(
        lightweight.data.macros.calories_net_kcal
      );

      console.log('\n✅ Athlete profiles validated!');
    });

    it('should handle workout type variations', async () => {
      console.log('\n🏃 Testing Workout Type Variations');

      const athleteProfile = {
        weight: 70,
        weight_unit: 'kg',
        gut_training: 'moderate',
        time_before_run_min: 90,
        temp_c: 18,
        humidity_pct: 55
      };

      // Easy Recovery Run
      console.log('\n  😌 Easy Recovery Run:');
      const recovery = await callGenerateMacrosWithTiming({
        ...athleteProfile,
        run_distance: 5,
        run_distance_unit: 'mi',
        run_pace: '10:00',
        run_pace_unit: 'min_per_mile'
      });

      expect(recovery.data.success).toBe(true);
      console.log(`    MET: ${recovery.data.macros.MET}`);
      console.log(`    During carbs: ${recovery.data.macros.during_total_g}g`);

      // Tempo Run
      console.log('\n  💨 Tempo Run:');
      const tempo = await callGenerateMacrosWithTiming({
        ...athleteProfile,
        run_distance: 10,
        run_distance_unit: 'km',
        run_pace: '4:00',
        run_pace_unit: 'min_per_km'
      });

      expect(tempo.data.success).toBe(true);
      console.log(`    MET: ${tempo.data.macros.MET}`);
      console.log(`    During carbs: ${tempo.data.macros.during_rate_g_per_h}g/h`);

      // Long Run
      console.log('\n  ⏱️ Long Run:');
      const longRun = await callGenerateMacrosWithTiming({
        ...athleteProfile,
        run_distance: 20,
        run_distance_unit: 'mi',
        run_pace: '8:30',
        run_pace_unit: 'min_per_mile',
        time_before_run_min: 150 // More time before long run
      });

      expect(longRun.data.success).toBe(true);
      console.log(`    Duration: ${longRun.data.macros.duration_h.toFixed(2)} hours`);
      console.log(`    Total carbs: ${longRun.data.macros.during_total_g}g`);
      console.log(`    Pre-run carbs: ${longRun.data.macros.pre_run_carbs_g}g`);

      // Verify intensity differences
      expect(tempo.data.macros.MET).toBeGreaterThan(recovery.data.macros.MET);
      expect(longRun.data.macros.during_total_g).toBeGreaterThan(tempo.data.macros.during_total_g);

      console.log('\n✅ Workout variations validated!');
    });
  });

  describe('⚡ Performance Benchmarks', () => {
    it('should meet performance targets for all distances', async () => {
      console.log('\n⏱️ Performance Benchmark Test');

      const distances = [
        { name: '5K', distance: 5, unit: 'km', maxTime: 1000 },
        { name: '10K', distance: 10, unit: 'km', maxTime: 1500 },
        { name: 'Half Marathon', distance: 13.1, unit: 'mi', maxTime: 2000 },
        { name: 'Marathon', distance: 26.2, unit: 'mi', maxTime: 2500 },
        { name: '50K', distance: 50, unit: 'km', maxTime: 3000 },
        { name: '50 Mile', distance: 50, unit: 'mi', maxTime: 3500 },
        { name: '100K', distance: 100, unit: 'km', maxTime: 4000 },
        { name: '100 Mile', distance: 100, unit: 'mi', maxTime: 5000 }
      ];

      const results = [];

      for (const dist of distances) {
        const result = await callGenerateMacrosWithTiming({
          weight: 70,
          weight_unit: 'kg',
          run_distance: dist.distance,
          run_distance_unit: dist.unit,
          run_pace: dist.unit === 'km' ? '5:00' : '8:00',
          run_pace_unit: dist.unit === 'km' ? 'min_per_km' : 'min_per_mile',
          gut_training: 'moderate'
        });

        results.push({
          name: dist.name,
          time: result.duration,
          success: result.data.success,
          withinTarget: result.duration < dist.maxTime
        });

        console.log(`  ${dist.name}: ${result.duration}ms (target: <${dist.maxTime}ms) ${result.duration < dist.maxTime ? '✅' : '❌'}`);
      }

      // All should succeed
      expect(results.every(r => r.success)).toBe(true);

      // At least 90% should meet performance targets
      const withinTarget = results.filter(r => r.withinTarget).length;
      const targetPercentage = (withinTarget / results.length) * 100;

      console.log(`\n  Performance: ${withinTarget}/${results.length} (${targetPercentage.toFixed(0)}%) met targets`);
      expect(targetPercentage).toBeGreaterThanOrEqual(90);

      // Average response time
      const avgTime = results.reduce((sum, r) => sum + r.time, 0) / results.length;
      console.log(`  Average response time: ${avgTime.toFixed(0)}ms`);
      expect(avgTime).toBeLessThan(2500);

      console.log('\n✅ Performance benchmarks validated!');
    });
  });

  describe('🔐 Security and Validation', () => {
    it('should reject malicious inputs', async () => {
      console.log('\n🛡️ Testing Security Validations');

      // SQL injection attempt
      const sqlInjection = await callGenerateMacrosWithTiming({
        weight: "70; DROP TABLE users;--",
        run_distance: 10,
        run_pace: "5:00"
      });

      // Should handle gracefully (likely parsing as NaN and failing validation)
      expect(sqlInjection.status).toBe(400);

      // XSS attempt
      const xssAttempt = await callGenerateMacrosWithTiming({
        weight: 70,
        run_distance: 10,
        run_pace: "<script>alert('xss')</script>",
        weight_unit: 'kg'
      });

      // Should handle gracefully
      expect(xssAttempt.data.success).toBe(false);

      console.log('✅ Security validations working!');
    });

    it('should enforce reasonable limits', async () => {
      console.log('\n📏 Testing Limit Enforcement');

      // Unreasonably long distance
      const tooLong = await callGenerateMacrosWithTiming({
        weight: 70,
        weight_unit: 'kg',
        run_distance: 1000, // 1000 miles
        run_distance_unit: 'mi',
        run_pace: '10:00',
        run_pace_unit: 'min_per_mile',
        gut_training: 'high'
      });

      expect(tooLong.data.success).toBe(true);
      // Should cap recommendations at safe levels
      expect(tooLong.data.macros.during_rate_g_per_h).toBeLessThanOrEqual(100);

      // Unreasonably fast pace
      const tooFast = await callGenerateMacrosWithTiming({
        weight: 70,
        weight_unit: 'kg',
        run_distance: 10,
        run_distance_unit: 'km',
        run_pace: '2:00', // 2 min/km (world record pace)
        run_pace_unit: 'min_per_km',
        gut_training: 'high'
      });

      expect(tooFast.data.success).toBe(true);
      // MET should be high but reasonable
      expect(tooFast.data.macros.MET).toBeLessThan(30);

      console.log('✅ Limits enforced correctly!');
    });
  });
});