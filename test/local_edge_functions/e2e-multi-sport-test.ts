/**
 * End-to-End Multi-Sport Test
 *
 * Tests all three sports (running, cycling, swimming) against the deployed dev environment
 * to verify that the edge functions work correctly with the activity_type parameter.
 */

const SUPABASE_URL = 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4NTI3OTAsImV4cCI6MjA3NTQyODc5MH0._7t1pjG_1zk4xkfseu2ACqYXdwEJKcRUWyvY4ZXs35o';

const TEST_DEVICE_ID = 'e2e-test-device-' + Date.now();

interface TestResult {
  sport: string;
  macrosSuccess: boolean;
  macrosError?: string;
  macrosData?: any;
  nutritionSuccess: boolean;
  nutritionError?: string;
  nutritionData?: any;
}

async function testRunning(): Promise<TestResult> {
  console.log('\n🏃 Testing RUNNING...');
  const result: TestResult = {
    sport: 'running',
    macrosSuccess: false,
    nutritionSuccess: false,
  };

  try {
    // Test generate-macros for running
    const macrosResponse = await fetch(`${SUPABASE_URL}/functions/v1/generate-macros`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({
        activity_type: 'running',
        weight: 70,
        weight_unit: 'kg',
        run_distance: 10,
        run_pace: '8:00',
        gut_training: 'moderate',
        temp_c: 20,
        humidity_pct: 50,
      }),
    });

    const macrosData = await macrosResponse.json();

    if (macrosResponse.ok && macrosData.success) {
      console.log('✅ Running macros generation: SUCCESS');
      console.log(`   Duration: ${macrosData.macros.duration_min} min`);
      console.log(`   MET: ${macrosData.macros.MET}`);
      console.log(`   During carbs: ${macrosData.macros.during_total_g}g`);
      result.macrosSuccess = true;
      result.macrosData = macrosData;
    } else {
      console.log('❌ Running macros generation: FAILED');
      result.macrosError = JSON.stringify(macrosData);
    }
  } catch (error) {
    console.log('❌ Running macros generation: ERROR');
    result.macrosError = error.message;
  }

  // Note: We're not testing nutrition plan generation here because it requires
  // food preferences to be set up in the database, which is complex for E2E testing

  return result;
}

async function testCycling(): Promise<TestResult> {
  console.log('\n🚴 Testing CYCLING...');
  const result: TestResult = {
    sport: 'cycling',
    macrosSuccess: false,
    nutritionSuccess: false,
  };

  try {
    // Test generate-macros for cycling
    const macrosResponse = await fetch(`${SUPABASE_URL}/functions/v1/generate-macros`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({
        activity_type: 'cycling',
        weight: 70,
        weight_unit: 'kg',
        distance_miles: 40,
        speed_mph: 20,
        terrain: 'rolling',
        indoor_outdoor: 'outdoor',
        elevation_gain_ft: 1500,
        time_before_min: 120,
        gut_training: 'moderate',
        temp_c: 22,
        humidity_pct: 60,
        sweat_sodium: 'medium',
      }),
    });

    const macrosData = await macrosResponse.json();

    if (macrosResponse.ok && macrosData.success && macrosData.activity_type === 'cycling') {
      console.log('✅ Cycling macros generation: SUCCESS');
      console.log(`   Duration: ${macrosData.macros.duration_min} min`);
      console.log(`   MET: ${macrosData.macros.MET}`);
      console.log(`   During carbs: ${macrosData.macros.during_ride_carbs_total}g`);
      result.macrosSuccess = true;
      result.macrosData = macrosData;
    } else {
      console.log('❌ Cycling macros generation: FAILED');
      result.macrosError = JSON.stringify(macrosData);
    }
  } catch (error) {
    console.log('❌ Cycling macros generation: ERROR');
    result.macrosError = error.message;
  }

  return result;
}

async function testSwimming(): Promise<TestResult> {
  console.log('\n🏊 Testing SWIMMING...');
  const result: TestResult = {
    sport: 'swimming',
    macrosSuccess: false,
    nutritionSuccess: false,
  };

  try {
    // Test generate-macros for swimming
    const macrosResponse = await fetch(`${SUPABASE_URL}/functions/v1/generate-macros`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({
        activity_type: 'swimming',
        weight: 70,
        weight_unit: 'kg',
        distance_meters: 5000,
        pace_per_100m_seconds: 120, // 2:00 per 100m
        pool_or_open_water: 'pool',
        water_temp_c: 26,
        time_before_min: 120,
        gut_training: 'moderate',
        sweat_sodium: 'medium',
      }),
    });

    const macrosData = await macrosResponse.json();

    if (macrosResponse.ok && macrosData.success && macrosData.activity_type === 'swimming') {
      console.log('✅ Swimming macros generation: SUCCESS');
      console.log(`   Duration: ${macrosData.macros.duration_min} min`);
      console.log(`   MET: ${macrosData.macros.MET}`);
      console.log(`   During carbs: ${macrosData.macros.during_swim_carbs_total}g`);
      result.macrosSuccess = true;
      result.macrosData = macrosData;
    } else {
      console.log('❌ Swimming macros generation: FAILED');
      result.macrosError = JSON.stringify(macrosData);
    }
  } catch (error) {
    console.log('❌ Swimming macros generation: ERROR');
    result.macrosError = error.message;
  }

  return result;
}

async function testBackwardCompatibility(): Promise<boolean> {
  console.log('\n⏮️  Testing BACKWARD COMPATIBILITY (no activity_type specified)...');

  try {
    // Test generate-macros without activity_type (should default to running)
    const macrosResponse = await fetch(`${SUPABASE_URL}/functions/v1/generate-macros`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      },
      body: JSON.stringify({
        // NO activity_type specified
        weight: 70,
        weight_unit: 'kg',
        run_distance: 10,
        run_pace: '8:00',
        gut_training: 'moderate',
        temp_c: 20,
        humidity_pct: 50,
      }),
    });

    const macrosData = await macrosResponse.json();

    if (macrosResponse.ok && macrosData.success) {
      console.log('✅ Backward compatibility: SUCCESS (defaulted to running)');
      console.log(`   Activity type returned: ${macrosData.activity_type || 'running (implicit)'}`);
      return true;
    } else {
      console.log('❌ Backward compatibility: FAILED');
      console.log(`   Error: ${JSON.stringify(macrosData)}`);
      return false;
    }
  } catch (error) {
    console.log('❌ Backward compatibility: ERROR');
    console.log(`   Error: ${error.message}`);
    return false;
  }
}

async function runAllTests() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('   Multi-Sport Edge Function E2E Test Suite');
  console.log('   Dev Environment: vlmtsdzpnjnavdgytcmi.supabase.co');
  console.log('═══════════════════════════════════════════════════════');

  const results: TestResult[] = [];

  // Test all three sports
  results.push(await testRunning());
  results.push(await testCycling());
  results.push(await testSwimming());

  // Test backward compatibility
  const backwardCompatSuccess = await testBackwardCompatibility();

  // Print summary
  console.log('\n═══════════════════════════════════════════════════════');
  console.log('   TEST SUMMARY');
  console.log('═══════════════════════════════════════════════════════');

  let allSuccess = true;

  results.forEach(result => {
    const status = result.macrosSuccess ? '✅' : '❌';
    console.log(`${status} ${result.sport.toUpperCase()} macro generation: ${result.macrosSuccess ? 'PASS' : 'FAIL'}`);
    if (!result.macrosSuccess && result.macrosError) {
      console.log(`   Error: ${result.macrosError}`);
    }
    if (!result.macrosSuccess) allSuccess = false;
  });

  console.log(`${backwardCompatSuccess ? '✅' : '❌'} Backward compatibility: ${backwardCompatSuccess ? 'PASS' : 'FAIL'}`);
  if (!backwardCompatSuccess) allSuccess = false;

  console.log('\n═══════════════════════════════════════════════════════');
  if (allSuccess) {
    console.log('🎉 ALL TESTS PASSED! Multi-sport support is working!');
    console.log('═══════════════════════════════════════════════════════');
    process.exit(0);
  } else {
    console.log('❌ SOME TESTS FAILED. Please review errors above.');
    console.log('═══════════════════════════════════════════════════════');
    process.exit(1);
  }
}

// Run the tests
runAllTests().catch(error => {
  console.error('Fatal error running tests:', error);
  process.exit(1);
});
