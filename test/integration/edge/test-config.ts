/**
 * TEST CONFIGURATION UTILITY
 *
 * Provides centralized configuration for all test files to prevent authentication issues.
 * Automatically detects environment and uses correct Supabase keys.
 */

import fs from 'fs';
import path from 'path';

// Load environment variables from .env.test if it exists
const envTestPath = path.join(__dirname, '..', '.env.test');
if (fs.existsSync(envTestPath)) {
  const envContent = fs.readFileSync(envTestPath, 'utf8');
  envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=');
    if (key && value && !key.startsWith('#')) {
      process.env[key.trim()] = value.trim();
    }
  });
}

/**
 * Test configuration with proper authentication keys
 */
export const TEST_CONFIG = {
  // Local Supabase configuration
  supabase: {
    url: process.env.SUPABASE_URL || 'http://127.0.0.1:54321',
    anonKey: process.env.SUPABASE_ANON_KEY || 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || 'sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz'
  },

  // Edge function URLs
  edgeFunctions: {
    createNutritionPlan: `${process.env.SUPABASE_URL || 'http://127.0.0.1:54321'}/functions/v1/create-nutrition-plan`,
    generateAiNutritionPlan: `${process.env.SUPABASE_URL || 'http://127.0.0.1:54321'}/functions/v1/generate-ai-nutrition-plan`
  },

  // Test timeouts
  timeouts: {
    standard: 15000,
    integration: 30000,
    performance: 45000
  }
};

/**
 * Get headers for edge function requests
 * Automatically uses service role key for edge function authentication
 */
export function getEdgeFunctionHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${TEST_CONFIG.supabase.serviceRoleKey}`,
    'apikey': TEST_CONFIG.supabase.serviceRoleKey
  };
}

/**
 * Get headers for client requests
 * Uses anon key for client-side operations
 */
export function getClientHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${TEST_CONFIG.supabase.anonKey}`,
    'apikey': TEST_CONFIG.supabase.anonKey
  };
}

/**
 * Validate test environment setup
 */
export function validateTestEnvironment(): void {
  const requiredEnvVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_SERVICE_ROLE_KEY'
  ];

  const missing = requiredEnvVars.filter(key => !process.env[key]);

  if (missing.length > 0) {
    console.warn(`⚠️ Missing test environment variables: ${missing.join(', ')}`);
    console.warn('Using default values from supabase status');
  }

  console.log('✅ Test environment configuration loaded:');
  console.log(`  - Supabase URL: ${TEST_CONFIG.supabase.url}`);
  console.log(`  - Anon Key: ${TEST_CONFIG.supabase.anonKey.substring(0, 20)}...`);
  console.log(`  - Service Key: ${TEST_CONFIG.supabase.serviceRoleKey.substring(0, 20)}...`);
}

/**
 * Test if edge function is accessible with current configuration
 */
export async function testEdgeFunctionAuth(functionName: 'create-nutrition-plan' | 'generate-ai-nutrition-plan'): Promise<boolean> {
  const url = TEST_CONFIG.edgeFunctions[functionName === 'create-nutrition-plan' ? 'createNutritionPlan' : 'generateAiNutritionPlan'];

  try {
    const response = await fetch(url, {
      method: 'OPTIONS',
      headers: getEdgeFunctionHeaders()
    });

    return response.status === 200;
  } catch (error) {
    console.error(`❌ Edge function ${functionName} not accessible:`, error);
    return false;
  }
}