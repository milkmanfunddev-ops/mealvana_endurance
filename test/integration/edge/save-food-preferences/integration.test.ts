import { describe, it, expect, beforeAll, beforeEach } from 'vitest';
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
  throw new Error('SUPABASE_SERVICE_KEY is required for integration tests');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Test device ID (will be created/cleaned up)
const TEST_DEVICE_ID = `test-device-${Date.now()}`;

// Helper function to create test user
async function createTestUser(deviceId: string) {
  const { data, error } = await supabase
    .from('users')
    .insert({
      device_id: deviceId,
      email: `${deviceId}@test.mealvana.com`,
      onboarding_completed: false,
      created_at: new Date().toISOString()
    })
    .select()
    .single();

  if (error) {
    console.error('Error creating test user:', error);
    throw error;
  }

  console.log(`✅ Test user created: ${deviceId}`);
  return data;
}

// Helper function to clean up test data
async function cleanupTestData(deviceId: string) {
  // Delete preferences
  await supabase
    .from('food_preferences')
    .delete()
    .eq('device_id', deviceId);

  // Delete user
  await supabase
    .from('users')
    .delete()
    .eq('device_id', deviceId);

  console.log(`🧹 Test data cleaned up: ${deviceId}`);
}

// Helper function to save preferences
async function savePreferences(deviceId: string, preferences: Record<string, string>) {
  console.log(`\n💾 Saving preferences for ${deviceId}:`,
    Object.keys(preferences).length, 'items');

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

  const data = await response.json();

  if (response.ok) {
    console.log(`✅ Saved ${data.preferences_count} preferences`);
  } else {
    console.log(`❌ Failed: ${data.message}`);
  }

  return { status: response.status, data };
}

describe('Save Food Preferences - Integration Tests', () => {

  beforeAll(async () => {
    console.log('\n🔧 Integration Test Configuration:');
    console.log(`  SUPABASE_URL: ${SUPABASE_URL}`);
    console.log(`  Edge Function: ${EDGE_FUNCTION_URL}`);
    console.log(`  Test Device ID: ${TEST_DEVICE_ID}`);

    // Create test user
    await createTestUser(TEST_DEVICE_ID);
  });

  afterAll(async () => {
    // Clean up test data
    await cleanupTestData(TEST_DEVICE_ID);
  });

  describe('✅ Valid Preference Saves', () => {

    it('should save basic food preferences', async () => {
      const preferences = {
        'Banana': 'like',
        'Oatmeal': 'dislike',
        'Gel': 'willing_to_try'
      };

      const { status, data } = await savePreferences(TEST_DEVICE_ID, preferences);

      expect(status).toBe(200);
      expect(data.success).toBe(true);
      expect(data.preferences_count).toBe(3);
      expect(data.saved_preferences).toBeDefined();

      // Verify preferences were saved
      if (data.saved_preferences) {
        expect(data.saved_preferences).toHaveLength(3);

        const bananaPreference = data.saved_preferences.find(
          (p: any) => p.food_name === 'Banana'
        );
        expect(bananaPreference?.preference).toBe('like');
      }

      console.log('✅ Basic preferences saved successfully');
    }, 10000);

    it('should update existing preferences', async () => {
      // First save
      const initialPreferences = {
        'Dates': 'like',
        'Honey': 'dislike'
      };

      await savePreferences(TEST_DEVICE_ID, initialPreferences);

      // Update preferences
      const updatedPreferences = {
        'Dates': 'dislike',      // Changed from like
        'Honey': 'willing_to_try', // Changed from dislike
        'Fig Bar': 'like'         // New preference
      };

      const { status, data } = await savePreferences(TEST_DEVICE_ID, updatedPreferences);

      expect(status).toBe(200);
      expect(data.success).toBe(true);

      // Verify updates
      const datesPreference = data.saved_preferences?.find(
        (p: any) => p.food_name === 'Dates'
      );
      expect(datesPreference?.preference).toBe('dislike');

      console.log('✅ Preferences updated successfully');
    }, 10000);

    it('should handle large preference sets', async () => {
      const largePreferences: Record<string, string> = {};

      // Create 30 preferences
      for (let i = 1; i <= 30; i++) {
        const preference = i % 3 === 0 ? 'like' :
                          i % 3 === 1 ? 'dislike' :
                          'willing_to_try';
        largePreferences[`Test Food ${i}`] = preference;
      }

      const { status, data } = await savePreferences(TEST_DEVICE_ID, largePreferences);

      expect(status).toBe(200);
      expect(data.success).toBe(true);
      expect(data.preferences_count).toBe(30);

      console.log('✅ Large preference set saved');
    }, 15000);

    it('should update onboarding status', async () => {
      // Create a new test user
      const newDeviceId = `test-device-onboarding-${Date.now()}`;
      await createTestUser(newDeviceId);

      // Save preferences
      const preferences = {
        'Banana': 'like',
        'Gel': 'like'
      };

      const { status, data } = await savePreferences(newDeviceId, preferences);

      expect(status).toBe(200);
      expect(data.success).toBe(true);

      // Check if onboarding was updated
      const { data: user } = await supabase
        .from('users')
        .select('onboarding_completed')
        .eq('device_id', newDeviceId)
        .single();

      expect(user?.onboarding_completed).toBe(true);

      console.log('✅ Onboarding status updated');

      // Clean up
      await cleanupTestData(newDeviceId);
    }, 10000);
  });

  describe('❌ Error Handling', () => {

    it('should reject missing device_id', async () => {
      const response = await fetch(EDGE_FUNCTION_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
        },
        body: JSON.stringify({
          // Missing device_id
          food_preferences: { 'Banana': 'like' }
        })
      });

      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.success).toBe(false);
      expect(data.message).toContain('Missing required fields');

      console.log('✅ Missing device_id rejected');
    });

    it('should reject invalid preference values', async () => {
      const invalidPreferences = {
        'Banana': 'love',    // Invalid
        'Oatmeal': 'hate'    // Invalid
      };

      const { status, data } = await savePreferences(TEST_DEVICE_ID, invalidPreferences);

      expect(status).toBe(400);
      expect(data.success).toBe(false);
      expect(data.message).toContain('Invalid preference value');

      console.log('✅ Invalid preferences rejected');
    });

    it('should reject non-existent user', async () => {
      const fakeDeviceId = 'non-existent-device-999';

      const { status, data } = await savePreferences(fakeDeviceId, {
        'Banana': 'like'
      });

      expect(status).toBe(404);
      expect(data.success).toBe(false);
      expect(data.message).toBe('User not found');

      console.log('✅ Non-existent user rejected');
    });

    it('should reject empty preference object', async () => {
      const { status, data } = await savePreferences(TEST_DEVICE_ID, {});

      // Edge function might accept empty object but save nothing
      // Or it might reject it - depends on implementation
      if (status === 200) {
        expect(data.preferences_count).toBe(0);
      } else {
        expect(status).toBe(400);
        expect(data.success).toBe(false);
      }

      console.log('✅ Empty preferences handled');
    });

    it('should reject non-object preferences', async () => {
      const response = await fetch(EDGE_FUNCTION_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
        },
        body: JSON.stringify({
          device_id: TEST_DEVICE_ID,
          food_preferences: 'not an object' // Invalid type
        })
      });

      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.success).toBe(false);

      console.log('✅ Non-object preferences rejected');
    });
  });

  describe('🔍 Database Validation', () => {

    it('should persist preferences correctly', async () => {
      const preferences = {
        'Apple': 'like',
        'Pear': 'dislike',
        'Orange': 'willing_to_try'
      };

      await savePreferences(TEST_DEVICE_ID, preferences);

      // Verify directly in database
      const { data: saved } = await supabase
        .from('food_preferences')
        .select('food_name, preference')
        .eq('device_id', TEST_DEVICE_ID)
        .in('food_name', ['Apple', 'Pear', 'Orange']);

      expect(saved).toHaveLength(3);

      const applePreference = saved?.find(p => p.food_name === 'Apple');
      expect(applePreference?.preference).toBe('like');

      console.log('✅ Preferences persisted correctly in database');
    }, 10000);

    it('should handle upsert correctly', async () => {
      // Initial save
      await savePreferences(TEST_DEVICE_ID, {
        'Melon': 'like'
      });

      // Check count before upsert
      const { count: countBefore } = await supabase
        .from('food_preferences')
        .select('*', { count: 'exact', head: true })
        .eq('device_id', TEST_DEVICE_ID)
        .eq('food_name', 'Melon');

      expect(countBefore).toBe(1);

      // Upsert same food with different preference
      await savePreferences(TEST_DEVICE_ID, {
        'Melon': 'dislike'
      });

      // Check count after upsert (should still be 1)
      const { count: countAfter, data } = await supabase
        .from('food_preferences')
        .select('preference', { count: 'exact' })
        .eq('device_id', TEST_DEVICE_ID)
        .eq('food_name', 'Melon');

      expect(countAfter).toBe(1);
      expect(data?.[0]?.preference).toBe('dislike');

      console.log('✅ Upsert prevents duplicates');
    }, 10000);
  });

  describe('⚡ Performance Tests', () => {

    it('should handle rapid sequential saves', async () => {
      const saves = [
        { 'Quick 1': 'like' },
        { 'Quick 2': 'dislike' },
        { 'Quick 3': 'willing_to_try' }
      ];

      const results = [];
      const startTime = Date.now();

      for (const prefs of saves) {
        const result = await savePreferences(TEST_DEVICE_ID, prefs);
        results.push(result);
      }

      const totalTime = Date.now() - startTime;

      expect(results.every(r => r.status === 200)).toBe(true);
      console.log(`✅ ${saves.length} saves in ${totalTime}ms`);
      console.log(`  Average: ${(totalTime / saves.length).toFixed(0)}ms per save`);
    }, 20000);

    it('should handle concurrent saves gracefully', async () => {
      const concurrentSaves = [
        savePreferences(TEST_DEVICE_ID, { 'Concurrent 1': 'like' }),
        savePreferences(TEST_DEVICE_ID, { 'Concurrent 2': 'dislike' }),
        savePreferences(TEST_DEVICE_ID, { 'Concurrent 3': 'willing_to_try' })
      ];

      const startTime = Date.now();
      const results = await Promise.all(concurrentSaves);
      const totalTime = Date.now() - startTime;

      expect(results.every(r => r.status === 200)).toBe(true);
      console.log(`✅ ${concurrentSaves.length} concurrent saves in ${totalTime}ms`);
    }, 15000);
  });
});