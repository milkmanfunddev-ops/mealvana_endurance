#!/usr/bin/env node

// Manual test runner for development and debugging
import { generateAINutritionPlan } from '../functions/generate-ai-nutrition-plan.js';
import { generateRunPlan } from '../functions/run-plan.js';
import { getFoods } from '../functions/get-foods.js';

// Test data
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

const testRequest = {
  device_id: 'manual-test-device',
  age: 30,
  gender: 'female',
  weight_kg: 60.0,
  height_cm: 165.0,
  gut_training_level: 'intermediate',
  distance_miles: 6.2, // 10K
  pace_minutes_per_mile: 8.5,
  time_before_run_hours: 2.0,
  macro_targets: testMacroTargets,
  liked_foods: ['oatmeal', 'banana', 'sports_drink'],
  willing_to_try_foods: ['energy_gel'],
  disliked_foods: ['coffee']
};

async function runAllTests() {
  console.log('🚀 Manual Edge Function Testing\n');
  
  // Test 1: Get Foods
  console.log('📋 Testing get-foods function...');
  try {
    const foodsResult = await getFoods();
    console.log(`✅ Found ${foodsResult.foods.length} foods in database`);
    console.log(`   Categories: ${foodsResult.metadata.categories.join(', ')}`);
    
    // Test category filtering
    const duringFoods = await getFoods({ category: 'during_run' });
    console.log(`   During-run foods: ${duringFoods.foods.map(f => f.name).join(', ')}`);
  } catch (error) {
    console.log('❌ get-foods failed:', error.message);
  }
  
  console.log('\n' + '='.repeat(50) + '\n');
  
  // Test 2: Generate Run Plan (Algorithmic)
  console.log('⚡ Testing run-plan function (algorithmic)...');
  try {
    const runPlanResult = await generateRunPlan(testRequest);
    console.log('✅ Run plan generated successfully');
    console.log(`   Algorithm: ${runPlanResult.algorithm_used}`);
    console.log(`   Duration: ${runPlanResult.energy_info.duration_minutes.toFixed(1)} minutes`);
    console.log(`   Calories: ${runPlanResult.energy_info.total_kcal.toFixed(0)} kcal`);
    console.log('\n   Macro Targets:');
    console.log(`   Pre-run: ${runPlanResult.macro_targets.pre_run.carbs_g}g carbs, ${runPlanResult.macro_targets.pre_run.protein_g}g protein`);
    console.log(`   During-run: ${runPlanResult.macro_targets.during_run.carbs_total_g}g carbs, ${runPlanResult.macro_targets.during_run.sodium_total_mg}mg sodium`);
    console.log(`   Post-run: ${runPlanResult.macro_targets.post_run.carbs_g}g carbs, ${runPlanResult.macro_targets.post_run.protein_g}g protein`);
  } catch (error) {
    console.log('❌ run-plan failed:', error.message);
  }
  
  console.log('\n' + '='.repeat(50) + '\n');
  
  // Test 3: Generate AI Nutrition Plan
  console.log('🤖 Testing generate-ai-nutrition-plan function...');
  try {
    const aiPlanResult = await generateAINutritionPlan(testRequest);
    
    if (aiPlanResult.success) {
      console.log('✅ AI nutrition plan generated successfully');
      
      // Display plan summary
      console.log('\n   🍽️  Generated Plan:');
      
      ['before', 'during', 'after'].forEach(phase => {
        const phaseTitle = phase.charAt(0).toUpperCase() + phase.slice(1) + '-run';
        console.log(`\n   ${phaseTitle}:`);
        
        const foods = aiPlanResult.plan[phase];
        if (foods && foods.length > 0) {
          foods.forEach(food => {
            console.log(`     • ${food.servings} ${food.description} (${food.carbs_grams?.toFixed(1) || 'N/A'}g carbs)`);
          });
          
          // Calculate phase totals
          const totalCarbs = foods.reduce((sum, food) => sum + (food.carbs_grams || 0), 0);
          const totalSodium = foods.reduce((sum, food) => sum + (food.sodium_mg || 0), 0);
          const totalFluids = foods.reduce((sum, food) => sum + (food.fluids_ml || 0), 0);
          
          console.log(`     Total: ${totalCarbs.toFixed(1)}g carbs, ${totalSodium.toFixed(0)}mg sodium, ${totalFluids.toFixed(0)}ml fluids`);
        } else {
          console.log('     No foods recommended for this phase');
        }
      });
      
      // Check food preferences adherence
      console.log('\n   🎯 Preference Analysis:');
      const allFoods = [
        ...aiPlanResult.plan.before,
        ...aiPlanResult.plan.during,
        ...aiPlanResult.plan.after
      ];
      
      const usedFoodNames = allFoods.map(f => f.food_name.toLowerCase());
      const likedUsed = testRequest.liked_foods.filter(f => 
        usedFoodNames.some(used => used.includes(f.toLowerCase()))
      );
      const dislikedUsed = testRequest.disliked_foods.filter(f => 
        usedFoodNames.some(used => used.includes(f.toLowerCase()))
      );
      
      console.log(`     Liked foods used: ${likedUsed.length}/${testRequest.liked_foods.length} (${likedUsed.join(', ') || 'none'})`);
      console.log(`     Disliked foods used: ${dislikedUsed.length} (${dislikedUsed.join(', ') || 'none'}) ${dislikedUsed.length === 0 ? '✅' : '❌'}`);
      
    } else {
      console.log('❌ AI nutrition plan failed:', aiPlanResult.error);
    }
  } catch (error) {
    console.log('❌ generate-ai-nutrition-plan failed:', error.message);
  }
  
  console.log('\n' + '='.repeat(50) + '\n');
  
  // Performance Test
  console.log('⏱️  Performance Testing...');
  const iterations = 5;
  const times = [];
  
  for (let i = 0; i < iterations; i++) {
    const start = performance.now();
    await generateAINutritionPlan(testRequest);
    const end = performance.now();
    times.push(end - start);
  }
  
  const avgTime = times.reduce((a, b) => a + b, 0) / times.length;
  console.log(`✅ Average generation time: ${avgTime.toFixed(1)}ms (${iterations} iterations)`);
  console.log(`   Range: ${Math.min(...times).toFixed(1)}ms - ${Math.max(...times).toFixed(1)}ms`);
  
  console.log('\n🎉 Manual testing completed!\n');
}

// Different test scenarios
async function runScenarioTests() {
  console.log('🎭 Testing Different Scenarios\n');
  
  const scenarios = [
    {
      name: '5K Run (Beginner)',
      request: {
        ...testRequest,
        distance_miles: 3.1,
        pace_minutes_per_mile: 10.0,
        gut_training_level: 'beginner'
      }
    },
    {
      name: 'Half Marathon (Advanced)',
      request: {
        ...testRequest,
        distance_miles: 13.1,
        pace_minutes_per_mile: 8.0,
        gut_training_level: 'advanced',
        weight_kg: 70.0
      }
    },
    {
      name: 'Ultra Distance (Expert)',
      request: {
        ...testRequest,
        distance_miles: 26.2,
        pace_minutes_per_mile: 9.5,
        gut_training_level: 'advanced',
        time_before_run_hours: 4.0
      }
    }
  ];
  
  for (const scenario of scenarios) {
    console.log(`📊 ${scenario.name}:`);
    
    try {
      const algorithmicResult = await generateRunPlan(scenario.request);
      const aiResult = await generateAINutritionPlan({
        ...scenario.request,
        macro_targets: algorithmicResult.macro_targets
      });
      
      console.log(`   Duration: ${algorithmicResult.energy_info.duration_hours.toFixed(1)} hours`);
      console.log(`   During-run carbs: ${algorithmicResult.macro_targets.during_run.carbs_total_g}g`);
      console.log(`   AI foods generated: ${aiResult.success ? 'Yes' : 'Failed'}`);
      
      if (aiResult.success) {
        const totalFoods = aiResult.plan.before.length + aiResult.plan.during.length + aiResult.plan.after.length;
        console.log(`   Total food items: ${totalFoods}`);
      }
      
    } catch (error) {
      console.log(`   ❌ Failed: ${error.message}`);
    }
    
    console.log('');
  }
}

// Main execution
async function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--scenarios')) {
    await runScenarioTests();
  } else {
    await runAllTests();
  }
  
  if (args.includes('--scenarios') || args.includes('--all')) {
    await runScenarioTests();
  }
}

main().catch(console.error);