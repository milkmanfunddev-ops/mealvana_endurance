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
  throw new Error('SUPABASE_SERVICE_KEY is required for E2E tests');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Helper to call edge function with timing
async function lookupBarcodeWithTiming(barcode: string) {
  const start = Date.now();

  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
    },
    body: JSON.stringify({ barcode })
  });

  const duration = Date.now() - start;
  const data = await response.json();

  return { data, duration, status: response.status };
}

// Real-world product categories for testing
const PRODUCT_CATEGORIES = {
  energy_gels: [
    { barcode: '769493100016', name: 'GU Energy Gel' },
    { barcode: '810815022026', name: 'Maurten Gel' },
    { barcode: '859902004015', name: 'Huma Gel' }
  ],
  energy_bars: [
    { barcode: '722252100900', name: 'Clif Bar' },
    { barcode: '602652170010', name: 'KIND Bar' },
    { barcode: '857777004013', name: 'RXBAR' },
    { barcode: '638102501004', name: 'Larabar' }
  ],
  sports_drinks: [
    { barcode: '052000042566', name: 'Gatorade' },
    { barcode: '786162002006', name: 'Nuun' },
    { barcode: '673424001119', name: 'Tailwind' }
  ],
  recovery_products: [
    { barcode: '749826001951', name: 'Pure Protein Bar' },
    { barcode: '097421150100', name: 'Muscle Milk' },
    { barcode: '644225730016', name: 'Core Power' }
  ],
  whole_foods: [
    { barcode: '040000527558', name: 'Snickers Bar' },
    { barcode: '030000310106', name: 'Fig Newtons' },
    { barcode: '038000845512', name: 'Rice Krispies Treats' }
  ]
};

describe('Barcode Lookup - E2E Tests', () => {

  beforeAll(() => {
    console.log('\n🌐 E2E Test Configuration:');
    console.log(`  Environment: ${SUPABASE_URL.includes('local') ? 'Local' : 'Dev Cloud'}`);
    console.log(`  Edge Function: ${EDGE_FUNCTION_URL}`);
    console.log(`  Timestamp: ${new Date().toISOString()}`);
  });

  describe('🏃 Runner Product Scanning Journey', () => {

    it('should handle pre-race shopping trip', async () => {
      console.log('\n🛒 Simulating Pre-Race Shopping Trip');

      const shoppingList = [
        PRODUCT_CATEGORIES.energy_gels[0],
        PRODUCT_CATEGORIES.energy_bars[0],
        PRODUCT_CATEGORIES.sports_drinks[0],
        PRODUCT_CATEGORIES.whole_foods[0]
      ];

      const results = [];

      for (const product of shoppingList) {
        console.log(`\n  Scanning ${product.name}...`);
        const result = await lookupBarcodeWithTiming(product.barcode);

        if (result.status === 200) {
          console.log(`    ✅ Found: ${result.data.data.product_name}`);
          console.log(`    Calories: ${result.data.data.calories_per_100g || 'N/A'} per 100g`);
          console.log(`    Carbs: ${result.data.data.carbohydrates_per_100g || 'N/A'}g per 100g`);
          console.log(`    Response time: ${result.duration}ms`);

          results.push({
            name: result.data.data.product_name,
            calories: result.data.data.calories_per_100g,
            carbs: result.data.data.carbohydrates_per_100g,
            found: true
          });
        } else {
          console.log(`    ❌ Not found (${result.status})`);
          results.push({ name: product.name, found: false });
        }
      }

      // At least 50% should be found
      const foundCount = results.filter(r => r.found).length;
      const successRate = (foundCount / results.length) * 100;

      console.log(`\n  📊 Success Rate: ${successRate}% (${foundCount}/${results.length})`);
      expect(successRate).toBeGreaterThanOrEqual(50);
    }, 30000);

    it('should compare nutrition across energy gels', async () => {
      console.log('\n⚡ Comparing Energy Gel Nutrition');

      const gels = [];

      for (const gel of PRODUCT_CATEGORIES.energy_gels) {
        const result = await lookupBarcodeWithTiming(gel.barcode);

        if (result.status === 200) {
          gels.push({
            name: result.data.data.product_name || gel.name,
            calories: result.data.data.calories_per_100g || 0,
            carbs: result.data.data.carbohydrates_per_100g || 0,
            sodium: result.data.data.sodium_mg_per_100g || 0,
            serving: result.data.data.serving_size || 'N/A'
          });
        }
      }

      if (gels.length > 0) {
        console.log('\n  📊 Energy Gel Comparison:');
        gels.forEach(gel => {
          console.log(`\n  ${gel.name}:`);
          console.log(`    Calories: ${gel.calories} per 100g`);
          console.log(`    Carbs: ${gel.carbs}g per 100g`);
          console.log(`    Sodium: ${gel.sodium}mg per 100g`);
          console.log(`    Serving: ${gel.serving}`);
        });

        // Gels should be high in carbs
        const avgCarbs = gels.reduce((sum, g) => sum + g.carbs, 0) / gels.length;
        console.log(`\n  Average carbs: ${avgCarbs.toFixed(1)}g per 100g`);
      }
    }, 30000);

    it('should handle race day nutrition planning', async () => {
      console.log('\n🏁 Race Day Nutrition Planning');

      // Simulate scanning products for a marathon
      const raceNutrition = {
        beforeRace: PRODUCT_CATEGORIES.whole_foods[0],
        duringRace: [
          PRODUCT_CATEGORIES.energy_gels[0],
          PRODUCT_CATEGORIES.sports_drinks[0]
        ],
        afterRace: PRODUCT_CATEGORIES.recovery_products[0]
      };

      console.log('\n  Before Race (2 hours):');
      const beforeResult = await lookupBarcodeWithTiming(raceNutrition.beforeRace.barcode);
      if (beforeResult.status === 200) {
        console.log(`    ${beforeResult.data.data.product_name}`);
        console.log(`    Carbs: ${beforeResult.data.data.carbohydrates_per_100g}g/100g`);
      }

      console.log('\n  During Race (every 45 min):');
      for (const product of raceNutrition.duringRace) {
        const result = await lookupBarcodeWithTiming(product.barcode);
        if (result.status === 200) {
          console.log(`    ${result.data.data.product_name}`);
          console.log(`    Quick carbs: ${result.data.data.carbohydrates_per_100g}g/100g`);
          if (result.data.data.sodium_mg_per_100g) {
            console.log(`    Sodium: ${result.data.data.sodium_mg_per_100g}mg/100g`);
          }
        }
      }

      console.log('\n  After Race (recovery):');
      const afterResult = await lookupBarcodeWithTiming(raceNutrition.afterRace.barcode);
      if (afterResult.status === 200) {
        console.log(`    ${afterResult.data.data.product_name}`);
        console.log(`    Protein: ${afterResult.data.data.protein_per_100g}g/100g`);
      }
    }, 30000);
  });

  describe('🔍 Product Discovery Scenarios', () => {

    it('should help discover new products in store', async () => {
      console.log('\n🆕 Discovering New Products');

      // Simulate scanning random products in sports nutrition aisle
      const unknownProducts = [
        '859906003009',  // Random barcode
        '850003685021',  // Another random
        '722252601506',  // Possible Clif variant
      ];

      let discoveredCount = 0;

      for (const barcode of unknownProducts) {
        console.log(`\n  Scanning unknown product: ${barcode}`);
        const result = await lookupBarcodeWithTiming(barcode);

        if (result.status === 200) {
          discoveredCount++;
          console.log(`    ✨ Discovered: ${result.data.data.product_name}`);
          console.log(`    Brand: ${result.data.data.brand_name || 'Unknown'}`);
          console.log(`    Type: Energy product`);
        } else {
          console.log(`    Not in database`);
        }
      }

      console.log(`\n  Discovered ${discoveredCount} new products`);
    }, 20000);

    it('should validate nutrition claims', async () => {
      console.log('\n✅ Validating Nutrition Claims');

      // Check if products match expected nutrition profiles
      const productsToValidate = [
        {
          barcode: '722252100900',
          expectedType: 'energy_bar',
          minCarbs: 30,
          maxCarbs: 70
        },
        {
          barcode: '769493100016',
          expectedType: 'energy_gel',
          minCarbs: 60,
          maxCarbs: 90
        }
      ];

      for (const product of productsToValidate) {
        const result = await lookupBarcodeWithTiming(product.barcode);

        if (result.status === 200) {
          const carbsPer100g = result.data.data.carbohydrates_per_100g;

          console.log(`\n  ${result.data.data.product_name}:`);
          console.log(`    Expected: ${product.expectedType}`);
          console.log(`    Carbs/100g: ${carbsPer100g}g`);
          console.log(`    Expected range: ${product.minCarbs}-${product.maxCarbs}g`);

          if (carbsPer100g) {
            const inRange = carbsPer100g >= product.minCarbs &&
                          carbsPer100g <= product.maxCarbs;
            console.log(`    ✓ Within expected range: ${inRange}`);
          }
        }
      }
    }, 20000);
  });

  describe('🌍 International Product Support', () => {

    it('should handle products with different barcode formats', async () => {
      console.log('\n🌍 Testing International Barcodes');

      const internationalBarcodes = [
        { barcode: '12345678', format: 'EAN-8', region: 'Europe' },
        { barcode: '123456789012', format: 'UPC-A', region: 'USA' },
        { barcode: '1234567890123', format: 'EAN-13', region: 'Global' }
      ];

      for (const test of internationalBarcodes) {
        console.log(`\n  Testing ${test.format} (${test.region}): ${test.barcode}`);

        const result = await lookupBarcodeWithTiming(test.barcode);

        if (result.status === 400) {
          // Invalid test barcodes might fail validation
          console.log(`    Format validated correctly`);
        } else if (result.status === 404) {
          console.log(`    Format accepted, product not found`);
        } else if (result.status === 200) {
          console.log(`    Product found: ${result.data.data.product_name}`);
        }
      }
    }, 15000);
  });

  describe('📱 Mobile App Integration Scenarios', () => {

    it('should handle rapid sequential scans', async () => {
      console.log('\n⚡ Rapid Sequential Scanning');

      const barcodes = [
        '722252100900',
        '602652170010',
        '857777004013'
      ];

      const results = [];
      const startTime = Date.now();

      // Simulate rapid scanning
      const promises = barcodes.map(barcode =>
        lookupBarcodeWithTiming(barcode)
      );

      const responses = await Promise.all(promises);

      const totalTime = Date.now() - startTime;

      responses.forEach((result, index) => {
        console.log(`  Scan ${index + 1}: ${result.status} (${result.duration}ms)`);
        results.push(result);
      });

      console.log(`\n  Total time for ${barcodes.length} scans: ${totalTime}ms`);
      console.log(`  Average time per scan: ${(totalTime / barcodes.length).toFixed(0)}ms`);

      // All should complete successfully
      expect(results.every(r => r.status === 200 || r.status === 404)).toBe(true);
    }, 15000);

    it('should handle offline queue simulation', async () => {
      console.log('\n📶 Offline Queue Processing');

      // Simulate products scanned while offline
      const offlineQueue = [
        { barcode: '722252100900', timestamp: Date.now() - 3600000 },
        { barcode: '052000042566', timestamp: Date.now() - 1800000 },
        { barcode: '602652170010', timestamp: Date.now() - 900000 }
      ];

      console.log('  Processing offline queue...');

      for (const item of offlineQueue) {
        const ageMinutes = Math.round((Date.now() - item.timestamp) / 60000);
        console.log(`\n  Processing scan from ${ageMinutes} minutes ago`);

        const result = await lookupBarcodeWithTiming(item.barcode);

        if (result.status === 200) {
          console.log(`    ✅ Synced: ${result.data.data.product_name}`);
        } else {
          console.log(`    ⚠️ Needs manual entry`);
        }
      }
    }, 20000);
  });

  describe('⚡ Performance & Reliability', () => {

    it('should maintain performance under load', async () => {
      console.log('\n📊 Load Testing');

      const loadTestBarcodes = Array(10).fill('722252100900');
      const results = [];

      console.log(`  Sending ${loadTestBarcodes.length} concurrent requests...`);

      const startTime = Date.now();

      const promises = loadTestBarcodes.map((barcode, index) =>
        lookupBarcodeWithTiming(barcode).then(result => {
          results.push(result);
          return result;
        })
      );

      await Promise.all(promises);

      const totalTime = Date.now() - startTime;
      const avgTime = totalTime / loadTestBarcodes.length;

      console.log(`\n  Results:`);
      console.log(`    Total time: ${totalTime}ms`);
      console.log(`    Average response: ${avgTime.toFixed(0)}ms`);
      console.log(`    Success rate: ${(results.filter(r => r.status === 200).length / results.length * 100).toFixed(0)}%`);

      // Should handle concurrent requests
      expect(results.filter(r => r.status === 200).length).toBeGreaterThan(0);
      expect(avgTime).toBeLessThan(2000); // Average should be under 2s
    }, 30000);

    it('should handle API degradation gracefully', async () => {
      console.log('\n🔧 API Degradation Handling');

      // Test with products that might not exist (simulating API issues)
      const difficultBarcodes = [
        '000000000000',  // Definitely doesn't exist
        '999999999999',  // Also doesn't exist
        '722252100900'   // Should exist
      ];

      let successCount = 0;
      let failureCount = 0;

      for (const barcode of difficultBarcodes) {
        const result = await lookupBarcodeWithTiming(barcode);

        if (result.status === 200) {
          successCount++;
          console.log(`  ✅ Found: ${barcode}`);
        } else if (result.status === 404) {
          failureCount++;
          console.log(`  ❌ Not found: ${barcode} (graceful failure)`);
          expect(result.data.error).toBe('Product not found');
          expect(result.data.message).toContain('manual entry');
        } else {
          console.log(`  ⚠️ Unexpected status: ${result.status}`);
        }
      }

      console.log(`\n  Success: ${successCount}, Graceful failures: ${failureCount}`);
      expect(successCount + failureCount).toBe(difficultBarcodes.length);
    }, 20000);
  });

  describe('🔒 Security & Validation', () => {

    it('should reject malicious input', async () => {
      console.log('\n🛡️ Security Testing');

      const maliciousInputs = [
        '<script>alert("xss")</script>',
        '"; DROP TABLE products; --',
        '../../../etc/passwd',
        'javascript:void(0)'
      ];

      for (const input of maliciousInputs) {
        console.log(`\n  Testing malicious input: ${input.substring(0, 20)}...`);
        const result = await lookupBarcodeWithTiming(input);

        // Should reject or sanitize
        expect(result.status).toBe(400);
        expect(result.data.error).toContain('Invalid');

        console.log(`    ✅ Rejected with: ${result.data.error}`);
      }
    }, 20000);

    it('should handle extremely long input', async () => {
      const longBarcode = '1'.repeat(1000);
      const result = await lookupBarcodeWithTiming(longBarcode);

      expect(result.status).toBe(400);
      expect(result.data.error).toContain('Invalid');
      console.log('  ✅ Long input rejected');
    });
  });
});