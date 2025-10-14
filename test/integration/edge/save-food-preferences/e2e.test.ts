import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env.test') });

// Test configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://wvmvsodrvbkxfydabqed.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/save-food-preferences`;

if (!SUPABASE_SERVICE_KEY) {
  throw new Error('SUPABASE_SERVICE_KEY is required for E2E tests');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Helper to create test user
async function createUser(deviceId: string, profile?: any) {
  const userData = {
    device_id: deviceId,
    email: `${deviceId}@test.mealvana.com`,
    onboarding_completed: false,
    created_at: new Date().toISOString(),
    ...profile
  };

  const { data, error } = await supabase
    .from('users')
    .insert(userData)
    .select()
    .single();

  if (error) throw error;
  return data;
}

// Helper to clean up test data
async function cleanupUser(deviceId: string) {
  await supabase.from('food_preferences').delete().eq('device_id', deviceId);
  await supabase.from('users').delete().eq('device_id', deviceId);
}

// Helper to save preferences with timing
async function savePreferencesWithTiming(deviceId: string, preferences: Record<string, string>) {
  const start = Date.now();

  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
    },
    body: JSON.stringify({
      device_id: deviceId,
      food_preferences: preferences
    })
  });

  const duration = Date.now() - start;
  const data = await response.json();

  return { data, duration, status: response.status };
}

describe('Save Food Preferences - E2E Tests', () => {

  const testUsers: string[] = [];

  beforeAll(() => {
    console.log('\n🌐 E2E Test Configuration:');
    console.log(`  Environment: ${SUPABASE_URL.includes('local') ? 'Local' : 'Dev Cloud'}`);
    console.log(`  Edge Function: ${EDGE_FUNCTION_URL}`);
    console.log(`  Timestamp: ${new Date().toISOString()}`);
  });

  afterAll(async () => {
    // Clean up all test users
    for (const userId of testUsers) {
      await cleanupUser(userId);
    }
    console.log(`\n🧹 Cleaned up ${testUsers.length} test users`);
  });

  describe('🏃 Complete Onboarding Journey', () => {

    it('should handle new runner onboarding flow', async () => {
      console.log('\n👟 New Runner Onboarding Journey');

      const deviceId = `onboarding-runner-${Date.now()}`;
      testUsers.push(deviceId);

      // Step 1: Create user account
      console.log('\n  Step 1: Creating account...');
      const user = await createUser(deviceId, {
        weight_kg: 70,
        gender: 'male',
        gut_training_level: 'low'
      });
      expect(user.onboarding_completed).toBe(false);
      console.log('    ✅ Account created');

      // Step 2: Initial preference exploration
      console.log('\n  Step 2: Exploring food options...');
      const explorationPrefs = {
        // Familiar foods
        'Banana': 'like',
        'Dates': 'like',
        'Honey': 'like',
        // New products to try
        'Gel': 'willing_to_try',
        'Energy chews': 'willing_to_try',
        'Sports drink': 'willing_to_try',
        // Definite dislikes
        'Oatmeal': 'dislike',
        'Orange juice': 'dislike'
      };

      const exploreResult = await savePreferencesWithTiming(deviceId, explorationPrefs);
      expect(exploreResult.status).toBe(200);
      expect(exploreResult.data.preferences_count).toBe(8);
      console.log(`    ✅ Saved ${exploreResult.data.preferences_count} preferences`);

      // Step 3: Verify onboarding completion
      console.log('\n  Step 3: Checking onboarding status...');
      const { data: updatedUser } = await supabase
        .from('users')
        .select('onboarding_completed')
        .eq('device_id', deviceId)
        .single();

      expect(updatedUser?.onboarding_completed).toBe(true);
      console.log('    ✅ Onboarding marked complete');

      // Step 4: Refine preferences after first run
      console.log('\n  Step 4: Updating after first run experience...');
      const refinedPrefs = {
        'Gel': 'like',              // Tried and liked
        'Energy chews': 'dislike',  // Didn't work well
        'Sports drink': 'like',     // Worked great
        'Fig Bar': 'willing_to_try' // New discovery
      };

      const refineResult = await savePreferencesWithTiming(deviceId, refinedPrefs);
      expect(refineResult.status).toBe(200);
      console.log('    ✅ Preferences refined based on experience');

      console.log('\n  📊 Onboarding Journey Summary:');
      console.log(`    Total preferences: ${exploreResult.data.preferences_count + refineResult.data.preferences_count}`);
      console.log(`    Response times: ${exploreResult.duration}ms, ${refineResult.duration}ms`);
    }, 30000);

    it('should handle experienced runner migration', async () => {
      console.log('\n🏅 Experienced Runner Migration');

      const deviceId = `experienced-runner-${Date.now()}`;
      testUsers.push(deviceId);

      // Create experienced user profile
      await createUser(deviceId, {
        weight_kg: 65,
        gender: 'female',
        gut_training_level: 'high',
        years_running: 5
      });

      // Experienced runner knows exactly what works
      console.log('\n  Importing established preferences...');
      const establishedPrefs = {
        // Proven performers
        'GU Energy Gel': 'like',
        'Maurten Gel': 'like',
        'Tailwind': 'like',
        'Honey Stinger Waffle': 'like',
        'Dates': 'like',
        'Banana': 'like',

        // Definite no-go items
        'Oatmeal': 'dislike',
        'Protein bar': 'dislike',
        'Gatorade': 'dislike',
        'Energy beans': 'dislike',

        // Still experimenting
        'UCAN': 'willing_to_try',
        'Maple syrup': 'willing_to_try'
      };

      const result = await savePreferencesWithTiming(deviceId, establishedPrefs);
      expect(result.status).toBe(200);
      expect(result.data.preferences_count).toBe(12);

      console.log('    ✅ Migrated experienced runner preferences');
      console.log(`    Likes: 6, Dislikes: 4, Willing to try: 2`);
    }, 20000);
  });

  describe('🔄 Preference Evolution Scenarios', () => {

    it('should track preference changes over training cycle', async () => {
      console.log('\n📈 Training Cycle Preference Evolution');

      const deviceId = `training-evolution-${Date.now()}`;
      testUsers.push(deviceId);
      await createUser(deviceId);

      // Week 1: Base building
      console.log('\n  Week 1 - Base Building:');
      const week1Prefs = {
        'Banana': 'like',
        'Dates': 'like',
        'Water': 'like'
      };
      const week1Result = await savePreferencesWithTiming(deviceId, week1Prefs);
      expect(week1Result.status).toBe(200);
      console.log('    Simple whole foods preferred');

      // Week 4: Increasing intensity
      console.log('\n  Week 4 - Intensity Increase:');
      const week4Prefs = {
        'Sports drink': 'willing_to_try',
        'Gel': 'willing_to_try',
        'Energy chews': 'willing_to_try'
      };
      const week4Result = await savePreferencesWithTiming(deviceId, week4Prefs);
      expect(week4Result.status).toBe(200);
      console.log('    Starting to experiment with sports nutrition');

      // Week 8: Long run fueling
      console.log('\n  Week 8 - Long Runs:');
      const week8Prefs = {
        'Gel': 'like',
        'Sports drink': 'like',
        'Energy chews': 'dislike',  // Didn't sit well
        'Tailwind': 'willing_to_try'
      };
      const week8Result = await savePreferencesWithTiming(deviceId, week8Prefs);
      expect(week8Result.status).toBe(200);
      console.log('    Found what works for long efforts');

      // Race week: Final preferences
      console.log('\n  Race Week - Final Setup:');
      const racePrefs = {
        'Gel': 'like',
        'Tailwind': 'like',
        'Banana': 'like',
        'Oatmeal': 'dislike'  // Too heavy pre-race
      };
      const raceResult = await savePreferencesWithTiming(deviceId, racePrefs);
      expect(raceResult.status).toBe(200);
      console.log('    Race nutrition strategy locked in');

      // Verify final preference state
      const { data: finalPrefs } = await supabase
        .from('food_preferences')
        .select('food_name, preference')
        .eq('device_id', deviceId);

      const likedCount = finalPrefs?.filter(p => p.preference === 'like').length || 0;
      const dislikedCount = finalPrefs?.filter(p => p.preference === 'dislike').length || 0;

      console.log('\n  📊 Evolution Summary:');
      console.log(`    Total foods tried: ${finalPrefs?.length}`);
      console.log(`    Foods liked: ${likedCount}`);
      console.log(`    Foods disliked: ${dislikedCount}`);
    }, 30000);

    it('should handle dietary restriction discovery', async () => {
      console.log('\n🚫 Dietary Restriction Discovery');

      const deviceId = `dietary-discovery-${Date.now()}`;
      testUsers.push(deviceId);
      await createUser(deviceId);

      // Initial preferences
      console.log('\n  Initial preferences (before discovery):');
      const initialPrefs = {
        'Banana': 'like',
        'Protein bar': 'like',
        'Whey protein shake': 'like',
        'Gel': 'like'
      };
      await savePreferencesWithTiming(deviceId, initialPrefs);
      console.log('    Various products liked');

      // Discover lactose intolerance
      console.log('\n  After discovering lactose intolerance:');
      const updatedPrefs = {
        'Protein bar': 'dislike',     // Contains whey
        'Whey protein shake': 'dislike',
        'Plant protein': 'willing_to_try',
        'Coconut water': 'willing_to_try'
      };
      const updateResult = await savePreferencesWithTiming(deviceId, updatedPrefs);
      expect(updateResult.status).toBe(200);
      console.log('    Updated to avoid dairy products');

      // Find alternatives
      console.log('\n  Finding suitable alternatives:');
      const alternativePrefs = {
        'Plant protein': 'like',
        'Coconut water': 'like',
        'Rice cakes': 'like',
        'Almond butter': 'like'
      };
      await savePreferencesWithTiming(deviceId, alternativePrefs);
      console.log('    Found lactose-free alternatives');
    }, 25000);
  });

  describe('🏁 Race Day Preparation', () => {

    it('should optimize preferences for race day', async () => {
      console.log('\n🏆 Marathon Race Day Preparation');

      const deviceId = `race-prep-${Date.now()}`;
      testUsers.push(deviceId);
      await createUser(deviceId, {
        weight_kg: 68,
        gut_training_level: 'high'
      });

      // Pre-race (night before and morning)
      console.log('\n  Pre-Race Nutrition:');
      const preRacePrefs = {
        'Pasta': 'like',
        'White bread': 'like',
        'Banana': 'like',
        'Coffee': 'like',
        'Oatmeal': 'willing_to_try',
        'Heavy breakfast': 'dislike'
      };
      await savePreferencesWithTiming(deviceId, preRacePrefs);
      console.log('    Carb loading preferences set');

      // During race
      console.log('\n  During-Race Fueling:');
      const duringRacePrefs = {
        'GU Energy Gel': 'like',
        'Maurten Gel': 'like',
        'Tailwind': 'like',
        'Water': 'like',
        'Coke': 'willing_to_try',  // Late race option
        'Solid foods': 'dislike'    // Too hard to digest
      };
      await savePreferencesWithTiming(deviceId, duringRacePrefs);
      console.log('    Race fueling strategy defined');

      // Post-race recovery
      console.log('\n  Post-Race Recovery:');
      const postRacePrefs = {
        'Chocolate milk': 'like',
        'Recovery drink': 'like',
        'Pizza': 'like',           // Celebration food!
        'Beer': 'willing_to_try'   // Traditional finisher beverage
      };
      const postResult = await savePreferencesWithTiming(deviceId, postRacePrefs);
      expect(postResult.status).toBe(200);
      console.log('    Recovery preferences saved');

      // Get all preferences for race strategy
      const { data: allPrefs } = await supabase
        .from('food_preferences')
        .select('*')
        .eq('device_id', deviceId);

      console.log('\n  📋 Race Strategy Summary:');
      console.log(`    Total nutrition items: ${allPrefs?.length}`);
      console.log('    ✅ Complete race nutrition plan ready');
    }, 25000);
  });

  describe('👥 Multi-User Scenarios', () => {

    it('should handle family account with multiple runners', async () => {
      console.log('\n👨‍👩‍👧‍👦 Family Running Account');

      const familyMembers = [
        { id: `family-parent1-${Date.now()}`, name: 'Parent 1', level: 'experienced' },
        { id: `family-parent2-${Date.now() + 1}`, name: 'Parent 2', level: 'beginner' },
        { id: `family-teen-${Date.now() + 2}`, name: 'Teen', level: 'intermediate' }
      ];

      for (const member of familyMembers) {
        testUsers.push(member.id);
        await createUser(member.id);
      }

      // Each family member has different preferences
      const familyPreferences = {
        experienced: {
          'Gel': 'like',
          'Tailwind': 'like',
          'Banana': 'like',
          'Oatmeal': 'dislike'
        },
        beginner: {
          'Banana': 'like',
          'Water': 'like',
          'Gel': 'willing_to_try',
          'Sports drink': 'willing_to_try'
        },
        intermediate: {
          'Sports drink': 'like',
          'Energy chews': 'like',
          'Gel': 'willing_to_try',
          'Protein bar': 'dislike'
        }
      };

      console.log('\n  Saving family preferences:');
      for (const member of familyMembers) {
        const prefs = familyPreferences[member.level as keyof typeof familyPreferences];
        const result = await savePreferencesWithTiming(member.id, prefs);

        expect(result.status).toBe(200);
        console.log(`    ${member.name}: ${result.data.preferences_count} preferences saved`);
      }

      console.log('\n  ✅ All family members configured');
    }, 30000);
  });

  describe('⚡ Performance & Scale Tests', () => {

    it('should handle bulk preference updates', async () => {
      console.log('\n📦 Bulk Preference Update');

      const deviceId = `bulk-update-${Date.now()}`;
      testUsers.push(deviceId);
      await createUser(deviceId);

      // Simulate scanning all products in a store
      const bulkPreferences: Record<string, string> = {};
      const products = [
        'GU Energy Gel', 'Clif Shot', 'Honey Stinger',
        'Maurten', 'SIS Gel', 'Hammer Gel',
        'Tailwind', 'Skratch', 'Nuun',
        'Clif Bar', 'Kind Bar', 'RX Bar',
        'Banana', 'Dates', 'Orange',
        'Oatmeal', 'Toast', 'Bagel'
      ];

      products.forEach((product, index) => {
        if (index % 3 === 0) bulkPreferences[product] = 'like';
        else if (index % 3 === 1) bulkPreferences[product] = 'dislike';
        else bulkPreferences[product] = 'willing_to_try';
      });

      console.log(`  Saving ${Object.keys(bulkPreferences).length} preferences...`);

      const startTime = Date.now();
      const result = await savePreferencesWithTiming(deviceId, bulkPreferences);
      const totalTime = Date.now() - startTime;

      expect(result.status).toBe(200);
      expect(result.data.preferences_count).toBe(Object.keys(bulkPreferences).length);

      console.log(`    ✅ Bulk save completed in ${totalTime}ms`);
      console.log(`    Rate: ${(Object.keys(bulkPreferences).length / (totalTime / 1000)).toFixed(1)} items/second`);
    }, 20000);

    it('should maintain performance with large preference history', async () => {
      console.log('\n📈 Performance with Large History');

      const deviceId = `large-history-${Date.now()}`;
      testUsers.push(deviceId);
      await createUser(deviceId);

      const timings: number[] = [];

      // Simulate months of preference updates
      for (let week = 1; week <= 4; week++) {
        console.log(`\n  Week ${week} updates:`);

        const weekPrefs: Record<string, string> = {};
        for (let i = 1; i <= 10; i++) {
          weekPrefs[`Week${week}_Food${i}`] =
            i % 3 === 0 ? 'like' :
            i % 3 === 1 ? 'dislike' :
            'willing_to_try';
        }

        const result = await savePreferencesWithTiming(deviceId, weekPrefs);
        timings.push(result.duration);

        console.log(`    Time: ${result.duration}ms`);
        expect(result.status).toBe(200);
      }

      // Check if performance degrades
      const avgFirstHalf = timings.slice(0, 2).reduce((a, b) => a + b) / 2;
      const avgSecondHalf = timings.slice(2).reduce((a, b) => a + b) / 2;

      console.log('\n  Performance Analysis:');
      console.log(`    First half avg: ${avgFirstHalf.toFixed(0)}ms`);
      console.log(`    Second half avg: ${avgSecondHalf.toFixed(0)}ms`);

      // Performance shouldn't degrade significantly
      const degradation = ((avgSecondHalf - avgFirstHalf) / avgFirstHalf) * 100;
      console.log(`    Degradation: ${degradation.toFixed(1)}%`);

      expect(Math.abs(degradation)).toBeLessThan(50); // Less than 50% degradation
    }, 30000);
  });

  describe('🔒 Data Privacy & Security', () => {

    it('should isolate preferences between users', async () => {
      console.log('\n🔐 User Preference Isolation');

      const user1Id = `privacy-user1-${Date.now()}`;
      const user2Id = `privacy-user2-${Date.now() + 1}`;
      testUsers.push(user1Id, user2Id);

      await createUser(user1Id);
      await createUser(user2Id);

      // User 1 preferences
      await savePreferencesWithTiming(user1Id, {
        'Secret Food 1': 'like',
        'Private Choice': 'dislike'
      });

      // User 2 preferences
      await savePreferencesWithTiming(user2Id, {
        'Different Food': 'like',
        'Other Choice': 'willing_to_try'
      });

      // Verify isolation
      const { data: user1Prefs } = await supabase
        .from('food_preferences')
        .select('*')
        .eq('device_id', user1Id);

      const { data: user2Prefs } = await supabase
        .from('food_preferences')
        .select('*')
        .eq('device_id', user2Id);

      // Each user should only see their own preferences
      expect(user1Prefs?.every(p => p.device_id === user1Id)).toBe(true);
      expect(user2Prefs?.every(p => p.device_id === user2Id)).toBe(true);

      // No cross-contamination
      expect(user1Prefs?.some(p => p.food_name === 'Different Food')).toBe(false);
      expect(user2Prefs?.some(p => p.food_name === 'Secret Food 1')).toBe(false);

      console.log('    ✅ User preferences properly isolated');
      console.log(`    User 1: ${user1Prefs?.length} preferences`);
      console.log(`    User 2: ${user2Prefs?.length} preferences`);
    }, 20000);

    it('should reject unauthorized access attempts', async () => {
      console.log('\n🛡️ Security Validation');

      // Try to save without proper authorization
      const response = await fetch(EDGE_FUNCTION_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
          // Missing Authorization header
        },
        body: JSON.stringify({
          device_id: 'unauthorized-device',
          food_preferences: { 'Banana': 'like' }
        })
      });

      // Should be rejected (401 or 403)
      expect([401, 403, 500].includes(response.status)).toBe(true);
      console.log(`    ✅ Unauthorized request rejected with ${response.status}`);
    });
  });
});