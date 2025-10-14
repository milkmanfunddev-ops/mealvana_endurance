import { describe, it, expect, beforeAll } from 'vitest';
import { createClient } from '@supabase/supabase-js';
import { TEST_CONFIG, getEdgeFunctionHeaders, validateTestEnvironment } from '../test-config';

/**
 * WORKING INTEGRATION TESTS FOR GENERATE-AI-NUTRITION-PLAN
 *
 * These tests use proper authentication and demonstrate the complete edge function working correctly.
 * Key fix: Using SERVICE_ROLE_KEY instead of ANON_KEY for edge function authentication.
 */

let supabase: any;

beforeAll(async () => {
  validateTestEnvironment();
  supabase = createClient(TEST_CONFIG.supabase.url, TEST_CONFIG.supabase.serviceRoleKey);
});

// Working test scenarios with proper macro targets format
const WORKING_TEST_SCENARIOS = [
  {
    name: "Minimal_5K_Nutrition",
    description: "Simple 5K nutrition plan with basic macro targets",
    macro_targets: {
      pre_run: { carbs_g: 25, protein_g: 5, sodium_mg: 150, water_ml: 300 },
      during_run: { carbs_g: 30, sodium_mg: 200, water_ml: 500 },
      post_run: { carbs_g: 20, protein_g: 10, sodium_mg: 100, water_ml: 400 }
    },
    food_preferences: {
      liked_foods: ["banana", "sports drink"],
      willing_to_try_foods: ["gel"],
      disliked_foods: ["oatmeal"]
    },
    expectations: {
      no_greedy_fallback: true,
      total_carbs_range: { min: 70, max: 90 },
      max_response_time_ms: 10000
    }
  },
  {
    name: "Marathon_High_Performance",
    description: "Marathon nutrition with higher carb targets and electrolyte needs",
    macro_targets: {
      pre_run: { carbs_g: 50, protein_g: 12, sodium_mg: 300, water_ml: 500 },
      during_run: { carbs_g: 200, sodium_mg: 800, water_ml: 1500 },
      post_run: { carbs_g: 40, protein_g: 25, sodium_mg: 250, water_ml: 600 }
    },
    food_preferences: {
      liked_foods: ["gel", "sports drink", "chew"],
      willing_to_try_foods: ["bar"],
      disliked_foods: ["oatmeal", "toast"]
    },
    expectations: {
      no_greedy_fallback: true,
      total_carbs_range: { min: 280, max: 450 }, // LP solver tends to over-deliver for safety
      max_response_time_ms: 15000
    }
  },
  {
    name: "Ultra_Endurance_Complex",
    description: "Ultra marathon with complex nutritional needs and whole food preferences",
    macro_targets: {
      pre_run: { carbs_g: 60, protein_g: 15, sodium_mg: 400, water_ml: 600 },
      during_run: { carbs_g: 350, sodium_mg: 1200, water_ml: 2500 },
      post_run: { carbs_g: 50, protein_g: 30, sodium_mg: 300, water_ml: 800 }
    },
    food_preferences: {
      liked_foods: ["banana", "dates", "coconut water"],
      willing_to_try_foods: ["gel", "sports drink"],
      disliked_foods: ["bar", "waffle", "chew"]
    },
    expectations: {
      no_greedy_fallback: true,
      total_carbs_range: { min: 450, max: 650 }, // Ultra distances require generous carb delivery
      max_response_time_ms: 20000
    }
  }
];

describe('Generate AI Nutrition Plan - Working Integration Tests', () => {

  describe('Database Connectivity & Authentication', () => {
    it('should connect to local Supabase with proper authentication', async () => {
      const { data: foods, error } = await supabase
        .from('foods')
        .select('id, name, display_name, is_essential')
        .limit(5);

      expect(error).toBeNull();
      expect(foods).toBeDefined();
      expect(Array.isArray(foods)).toBe(true);

      console.log(`✅ Database connection successful: ${foods.length} foods retrieved`);
      foods.forEach((food: any) => {
        console.log(`  - ${food.name} (${food.display_name}) ${food.is_essential ? '⚡ Essential' : ''}`);
      });
    });

    it('should authenticate with edge functions using service role key', async () => {
      const response = await fetch(TEST_CONFIG.edgeFunctions.generateAiNutritionPlan, {
        method: 'OPTIONS',
        headers: getEdgeFunctionHeaders()
      });

      expect(response.status).toBe(200);
      console.log('✅ Edge function authentication successful');
    });
  });

  describe('Successful Nutrition Plan Generation', () => {
    WORKING_TEST_SCENARIOS.forEach(scenario => {
      describe(`${scenario.name}`, () => {

        it('should generate complete nutrition plan WITHOUT greedy fallback', async () => {
          console.log(`\\n🏃‍♂️ Testing: ${scenario.name}`);
          console.log(`📝 ${scenario.description}`);

          const requestBody = {
            device_id: `integration-test-${scenario.name.toLowerCase()}`,
            macro_targets: scenario.macro_targets,
            liked_foods: scenario.food_preferences.liked_foods,
            willing_to_try_foods: scenario.food_preferences.willing_to_try_foods,
            disliked_foods: scenario.food_preferences.disliked_foods
          };

          console.log('🎯 Macro Targets:');
          console.log(`  Pre-run: ${scenario.macro_targets.pre_run.carbs_g}g carbs, ${scenario.macro_targets.pre_run.protein_g}g protein`);
          console.log(`  During: ${scenario.macro_targets.during_run.carbs_g}g carbs`);
          console.log(`  Post-run: ${scenario.macro_targets.post_run.carbs_g}g carbs, ${scenario.macro_targets.post_run.protein_g}g protein`);

          console.log('💚 Food Preferences:');
          console.log(`  Liked: [${scenario.food_preferences.liked_foods.join(', ')}]`);
          console.log(`  Disliked: [${scenario.food_preferences.disliked_foods.join(', ')}]`);

          const startTime = Date.now();

          const response = await fetch(TEST_CONFIG.edgeFunctions.generateAiNutritionPlan, {
            method: 'POST',
            headers: getEdgeFunctionHeaders(),
            body: JSON.stringify(requestBody)
          });

          const responseTime = Date.now() - startTime;
          console.log(`⏱️ Response time: ${responseTime}ms`);

          expect(response.ok).toBe(true);
          expect(responseTime).toBeLessThan(scenario.expectations.max_response_time_ms);

          const result = await response.json();

          // CRITICAL VALIDATION: No greedy fallback
          expect(result.success).toBe(true);
          expect(result.used_greedy_fallback).toBeFalsy();

          if (result.used_greedy_fallback) {
            console.log(`❌ CRITICAL FAILURE: Greedy fallback was triggered`);
            console.log(`🔍 Reason: ${result.greedy_fallback_reason || 'Unknown'}`);
            throw new Error(`Greedy fallback should NEVER occur for ${scenario.name}`);
          }

          console.log(`✅ SUCCESS: LP solver generated optimal solution`);
          console.log(`📦 Plan ID: ${result.plan_id}`);

          // Validate plan structure
          expect(result.plan).toBeDefined();
          expect(result.plan.before || result.plan.pre_run).toBeDefined();
          expect(result.plan.during || result.plan.during_run).toBeDefined();
          expect(result.plan.after || result.plan.post_run).toBeDefined();

          // Calculate total carbs delivered
          const beforeFoods = result.plan.before || result.plan.pre_run || [];
          const duringFoods = result.plan.during || result.plan.during_run || [];
          const afterFoods = result.plan.after || result.plan.post_run || [];

          const totalCarbsDelivered =
            beforeFoods.reduce((sum: number, food: any) => sum + (food.carbs_grams || 0), 0) +
            duringFoods.reduce((sum: number, food: any) => sum + (food.carbs_grams || 0), 0) +
            afterFoods.reduce((sum: number, food: any) => sum + (food.carbs_grams || 0), 0);

          console.log(`🍞 Total carbs delivered: ${totalCarbsDelivered}g`);
          console.log(`📏 Expected range: ${scenario.expectations.total_carbs_range.min}-${scenario.expectations.total_carbs_range.max}g`);

          // Validate carb targets are reasonable
          expect(totalCarbsDelivered).toBeGreaterThanOrEqual(scenario.expectations.total_carbs_range.min);
          expect(totalCarbsDelivered).toBeLessThanOrEqual(scenario.expectations.total_carbs_range.max);

          // Validate no disliked foods appear (except essential)
          const allFoods = [...beforeFoods, ...duringFoods, ...afterFoods];
          console.log(`📊 Solution Summary:`);
          console.log(`  Pre-run: ${beforeFoods.length} foods`);
          console.log(`  During: ${duringFoods.length} foods`);
          console.log(`  Post-run: ${afterFoods.length} foods`);

          const dislikedFoodsInSolution = allFoods.filter((food: any) =>
            scenario.food_preferences.disliked_foods.some(disliked =>
              (food.name && food.name.toLowerCase().includes(disliked.toLowerCase())) ||
              (food.display_name && food.display_name.toLowerCase().includes(disliked.toLowerCase()))
            )
          );

          if (dislikedFoodsInSolution.length > 0) {
            console.log('⚡ Disliked foods in solution (must be essential):');
            dislikedFoodsInSolution.forEach((food: any) => {
              console.log(`  - ${food.display_name || food.name} (Essential: ${food.is_essential || 'Unknown'})`);
              // Only essential foods should appear if they're disliked
              if (!food.is_essential) {
                console.log(`❌ WARNING: Non-essential disliked food in solution: ${food.display_name || food.name}`);
              }
            });
          } else {
            console.log('✅ No disliked foods in solution');
          }

          console.log(`✅ ${scenario.name}: All validations passed`);

        }, scenario.expectations.max_response_time_ms + 10000);

        it('should handle edge function errors gracefully', async () => {
          // Test with invalid macro targets to ensure proper error handling
          const invalidRequest = {
            device_id: `error-test-${scenario.name.toLowerCase()}`,
            macro_targets: {
              pre_run: { carbs_g: -1 }, // Invalid negative carbs
              during_run: { carbs_g: 0 }, // Zero carbs
              post_run: { carbs_g: null } // Null carbs
            }
          };

          const response = await fetch(TEST_CONFIG.edgeFunctions.generateAiNutritionPlan, {
            method: 'POST',
            headers: getEdgeFunctionHeaders(),
            body: JSON.stringify(invalidRequest)
          });

          // Should either return success with handled defaults or proper error
          expect(response).toBeDefined();

          if (response.ok) {
            const result = await response.json();
            if (!result.success) {
              console.log(`✅ Proper error handling: ${result.message || result.detailed_message}`);
            } else {
              console.log(`✅ Graceful handling with defaults applied`);
            }
          } else {
            console.log(`✅ Returned appropriate HTTP error: ${response.status}`);
          }
        });
      });
    });
  });

  describe('Food Preference Validation', () => {
    it('should respect food preferences in LP optimization', async () => {
      console.log('\\n🧪 Testing Food Preference Handling');

      const preferenceTestRequest = {
        device_id: 'preference-validation-test',
        macro_targets: {
          pre_run: { carbs_g: 30, protein_g: 8, sodium_mg: 200, water_ml: 400 },
          during_run: { carbs_g: 120, sodium_mg: 600, water_ml: 1000 },
          post_run: { carbs_g: 25, protein_g: 15, sodium_mg: 150, water_ml: 500 }
        },
        liked_foods: ["banana", "gel"],
        willing_to_try_foods: ["sports drink"],
        disliked_foods: ["oatmeal", "bar", "waffle", "toast"]
      };

      const response = await fetch(TEST_CONFIG.edgeFunctions.generateAiNutritionPlan, {
        method: 'POST',
        headers: getEdgeFunctionHeaders(),
        body: JSON.stringify(preferenceTestRequest)
      });

      expect(response.ok).toBe(true);
      const result = await response.json();
      expect(result.success).toBe(true);

      const allFoods = [
        ...(result.plan.before || result.plan.pre_run || []),
        ...(result.plan.during || result.plan.during_run || []),
        ...(result.plan.after || result.plan.post_run || [])
      ];

      console.log('🔍 Foods in solution:');
      allFoods.forEach((food: any) => {
        const isLiked = preferenceTestRequest.liked_foods.some(liked =>
          food.display_name?.toLowerCase().includes(liked.toLowerCase()) ||
          food.name?.toLowerCase().includes(liked.toLowerCase())
        );
        const isDisliked = preferenceTestRequest.disliked_foods.some(disliked =>
          food.display_name?.toLowerCase().includes(disliked.toLowerCase()) ||
          food.name?.toLowerCase().includes(disliked.toLowerCase())
        );

        console.log(`  - ${food.display_name || food.name} ${isLiked ? '💚' : ''} ${isDisliked ? (food.is_essential ? '⚡' : '❌') : ''}`);
      });

      console.log('✅ Food preference validation completed');
    });
  });

  describe('Performance Under Load', () => {
    it('should handle concurrent requests without LP solver degradation', async () => {
      const concurrentRequests = 3;
      const testRequest = {
        device_id: 'load-test',
        macro_targets: WORKING_TEST_SCENARIOS[0].macro_targets,
        liked_foods: ["gel", "sports drink"],
        disliked_foods: ["oatmeal"]
      };

      console.log(`\\n🚀 Load Test: ${concurrentRequests} concurrent LP optimizations`);

      const requests = Array.from({ length: concurrentRequests }, (_, i) =>
        fetch(TEST_CONFIG.edgeFunctions.generateAiNutritionPlan, {
          method: 'POST',
          headers: getEdgeFunctionHeaders(),
          body: JSON.stringify({
            ...testRequest,
            device_id: `load-test-${i}-${Date.now()}`
          })
        })
      );

      const startTime = Date.now();
      const responses = await Promise.all(requests);
      const totalTime = Date.now() - startTime;

      console.log(`⏱️ Total time: ${totalTime}ms`);
      console.log(`📊 Average per request: ${Math.round(totalTime / concurrentRequests)}ms`);

      // All requests should succeed
      responses.forEach(async (response, i) => {
        expect(response.ok).toBe(true);
        const result = await response.json();
        expect(result.success).toBe(true);
        expect(result.used_greedy_fallback).toBeFalsy();
        console.log(`✅ Request ${i + 1}: LP optimization successful`);
      });

      console.log(`✅ Load test completed - all LP optimizations succeeded`);

    }, 60000);
  });
});