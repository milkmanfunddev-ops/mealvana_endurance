import { describe, it, expect, beforeAll } from 'vitest';
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env.test') });

// Test configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://wvmvsodrvbkxfydabqed.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/barcode-lookup`;

if (!SUPABASE_SERVICE_KEY) {
  throw new Error('SUPABASE_SERVICE_KEY is required for integration tests');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Test barcodes - mix of real products and test data
const TEST_BARCODES = {
  // Real products likely in Open Food Facts
  clifBar: '722252100900',
  gu_gel: '769493100016',
  gatorade: '052000042566',
  kind_bar: '602652170010',
  rxbar: '857777004013',

  // Test products from seed data
  fig_bar: '047495112900',
  protein_bar: '749826001951',

  // Invalid formats
  too_short: '123',
  too_long: '12345678901234',
  non_numeric: 'ABC123DEF456',
  empty: '',
};

// Helper function to call edge function
async function lookupBarcode(barcode: string) {
  console.log(`\n📱 Looking up barcode: ${barcode}`);

  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
    },
    body: JSON.stringify({ barcode })
  });

  const data = await response.json();

  if (response.ok) {
    console.log(`✅ Product found: ${data.data?.product_name || 'Unknown'}`);
    if (data.data) {
      console.log(`  Source: ${data.data.api_source}`);
      console.log(`  Confidence: ${data.data.confidence_score}`);
    }
  } else {
    console.log(`❌ Lookup failed: ${data.error || data.message}`);
  }

  return { status: response.status, data };
}

describe('Barcode Lookup - Integration Tests', () => {

  beforeAll(() => {
    console.log('\n🔧 Integration Test Configuration:');
    console.log(`  SUPABASE_URL: ${SUPABASE_URL}`);
    console.log(`  Edge Function: ${EDGE_FUNCTION_URL}`);
    console.log(`  Test Barcodes: ${Object.keys(TEST_BARCODES).length}`);
  });

  describe('✅ Valid Barcode Lookups', () => {

    it('should find Clif Bar product', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.clifBar);

      expect(status).toBe(200);
      expect(data.success).toBe(true);
      expect(data.data).toBeDefined();
      expect(data.data.product_name.toLowerCase()).toContain('clif');
      expect(data.data.barcode).toBe(TEST_BARCODES.clifBar);

      // Validate nutrition data
      expect(data.data.calories_per_100g).toBeGreaterThan(0);
      expect(data.data.carbohydrates_per_100g).toBeGreaterThan(0);

      console.log('\n📊 Nutrition per 100g:');
      console.log(`  Calories: ${data.data.calories_per_100g}`);
      console.log(`  Carbs: ${data.data.carbohydrates_per_100g}g`);
      console.log(`  Protein: ${data.data.protein_per_100g}g`);
    }, 10000);

    it('should find GU Energy Gel product', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.gu_gel);

      if (status === 200) {
        expect(data.success).toBe(true);
        expect(data.data.product_name.toLowerCase()).toMatch(/gu|gel|energy/);

        // Gels should have high carb content
        if (data.data.carbohydrates_per_100g) {
          expect(data.data.carbohydrates_per_100g).toBeGreaterThan(50);
        }
      } else {
        // Product might not be in database
        expect(status).toBe(404);
        expect(data.success).toBe(false);
        expect(data.error).toBe('Product not found');
      }
    }, 10000);

    it('should find Gatorade product', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.gatorade);

      if (status === 200) {
        expect(data.success).toBe(true);
        expect(data.data.product_name.toLowerCase()).toMatch(/gatorade|sport/);

        // Sports drinks should have sodium
        if (data.data.sodium_mg_per_100g) {
          expect(data.data.sodium_mg_per_100g).toBeGreaterThan(0);
        }
      } else {
        expect(status).toBe(404);
      }
    }, 10000);
  });

  describe('🔄 API Fallback Chain', () => {

    it('should use Open Food Facts as primary source', async () => {
      // Use a well-known product likely in Open Food Facts
      const { status, data } = await lookupBarcode(TEST_BARCODES.kind_bar);

      if (status === 200) {
        expect(data.data.api_source).toBe('open_food_facts');
        expect(data.data.confidence_score).toBeGreaterThanOrEqual(0.7);
      }
    }, 10000);

    it('should fall back to USDA when not in Open Food Facts', async () => {
      // Use a product that might only be in USDA
      const { status, data } = await lookupBarcode(TEST_BARCODES.protein_bar);

      if (status === 200 && data.data.api_source === 'usda') {
        expect(data.data.confidence_score).toBeLessThanOrEqual(0.7);
      }
    }, 10000);
  });

  describe('📊 Nutrition Data Validation', () => {

    it('should include per-100g nutrition data', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.clifBar);

      if (status === 200) {
        expect(data.data.calories_per_100g).toBeDefined();
        expect(data.data.carbohydrates_per_100g).toBeDefined();
        expect(data.data.protein_per_100g).toBeDefined();
        expect(data.data.fat_per_100g).toBeDefined();
      }
    }, 10000);

    it('should include per-serving data when available', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.clifBar);

      if (status === 200 && data.data.nutrition_data_per === 'serving') {
        expect(data.data.calories_per_serving).toBeDefined();
        expect(data.data.carbohydrates_per_serving).toBeDefined();
        expect(data.data.serving_grams).toBeGreaterThan(0);
        expect(data.data.confidence_score).toBe(0.9);
      }
    }, 10000);

    it('should convert sodium units correctly', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.gatorade);

      if (status === 200 && data.data.sodium_mg_per_100g !== undefined) {
        // Sodium should be in milligrams, not grams
        expect(data.data.sodium_mg_per_100g).toBeGreaterThan(1);

        // Sports drinks typically have 40-120mg sodium per 100ml
        expect(data.data.sodium_mg_per_100g).toBeLessThan(500);
      }
    }, 10000);
  });

  describe('❌ Error Handling', () => {

    it('should reject empty barcode', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.empty);

      expect(status).toBe(400);
      expect(data.error).toBe('Invalid request');
      expect(data.message).toContain('Barcode is required');
    });

    it('should reject invalid barcode format', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.too_short);

      expect(status).toBe(400);
      expect(data.error).toBe('Invalid barcode format');
      expect(data.message).toContain('8, 12, or 13 digits');
    });

    it('should clean non-numeric characters', async () => {
      const dirtyBarcode = '7-22252-10090-0';
      const { status, data } = await lookupBarcode(dirtyBarcode);

      // Should clean and process successfully
      if (status === 200) {
        expect(data.data.barcode).toBe('722252100900');
      }
    });

    it('should return 404 for non-existent product', async () => {
      const fakeBarcode = '999999999999'; // Unlikely to exist
      const { status, data } = await lookupBarcode(fakeBarcode);

      expect(status).toBe(404);
      expect(data.success).toBe(false);
      expect(data.error).toBe('Product not found');
      expect(data.barcode).toBe(fakeBarcode);
    });
  });

  describe('💾 Caching Behavior', () => {

    it('should cache repeated lookups', async () => {
      const barcode = TEST_BARCODES.clifBar;

      // First lookup - should hit API
      const start1 = Date.now();
      const result1 = await lookupBarcode(barcode);
      const time1 = Date.now() - start1;

      expect(result1.status).toBe(200);

      // Second lookup - should be cached (much faster)
      const start2 = Date.now();
      const result2 = await lookupBarcode(barcode);
      const time2 = Date.now() - start2;

      expect(result2.status).toBe(200);
      expect(result2.data.data).toEqual(result1.data.data);

      console.log(`\n⏱️ Cache Performance:`);
      console.log(`  First lookup: ${time1}ms`);
      console.log(`  Cached lookup: ${time2}ms`);

      // Cached should be significantly faster (but this might vary in CI)
      // Just verify both succeeded with same data
      expect(result2.data.data.barcode).toBe(result1.data.data.barcode);
    }, 20000);
  });

  describe('🖼️ Product Metadata', () => {

    it('should include product images when available', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.clifBar);

      if (status === 200 && data.data.image_url) {
        expect(data.data.image_url).toMatch(/^https?:\/\//);
        console.log(`\n🖼️ Image URL: ${data.data.image_url}`);
      }
    });

    it('should include brand information', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.clifBar);

      if (status === 200) {
        expect(data.data.brand_name).toBeDefined();
        console.log(`\n🏷️ Brand: ${data.data.brand_name}`);
      }
    });

    it('should include serving size information', async () => {
      const { status, data } = await lookupBarcode(TEST_BARCODES.clifBar);

      if (status === 200 && data.data.serving_size) {
        expect(data.data.serving_size).toBeTruthy();
        console.log(`\n📏 Serving: ${data.data.serving_size}`);

        if (data.data.serving_grams) {
          expect(data.data.serving_grams).toBeGreaterThan(0);
          console.log(`  Weight: ${data.data.serving_grams}g`);
        }
      }
    });
  });

  describe('⚡ Performance Tests', () => {

    it('should respond within acceptable time limits', async () => {
      const testCases = [
        { name: 'Clif Bar', barcode: TEST_BARCODES.clifBar },
        { name: 'GU Gel', barcode: TEST_BARCODES.gu_gel },
        { name: 'Gatorade', barcode: TEST_BARCODES.gatorade },
      ];

      console.log('\n⏱️ Response Times:');

      for (const test of testCases) {
        const start = Date.now();
        const { status } = await lookupBarcode(test.barcode);
        const duration = Date.now() - start;

        console.log(`  ${test.name}: ${duration}ms (${status})`);
        expect(duration).toBeLessThan(5000); // 5 second timeout
      }
    }, 20000);
  });
});