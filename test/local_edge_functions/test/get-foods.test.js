// Local test for get-foods edge function
import { test, describe } from 'node:test';
import assert from 'node:assert';
import { getFoods, handleRequest } from '../functions/get-foods.js';

describe('Get Foods - Local Tests', () => {

  test('successfully returns complete foods database', async () => {
    const result = await getFoods();
    
    assert.strictEqual(result.success, true, 'Should return success: true');
    assert.ok(result.foods, 'Should have foods array');
    assert.ok(result.metadata, 'Should have metadata object');
    
    // Check foods structure
    assert.ok(Array.isArray(result.foods), 'Foods should be an array');
    assert.ok(result.foods.length > 0, 'Should have foods in database');
    
    // Check metadata
    assert.ok(result.metadata.total_count > 0, 'Should have total count');
    assert.ok(Array.isArray(result.metadata.categories), 'Should have categories array');
    assert.ok(result.metadata.last_updated, 'Should have last_updated timestamp');
    assert.ok(result.metadata.version, 'Should have version');
  });

  test('food items have correct structure', async () => {
    const result = await getFoods();
    
    assert.strictEqual(result.success, true);
    
    // Check first food item structure
    const firstFood = result.foods[0];
    assert.ok(firstFood.id, 'Should have id');
    assert.ok(firstFood.name, 'Should have name');
    assert.ok(Array.isArray(firstFood.categories), 'Should have categories array');
    assert.ok(firstFood.per_serving, 'Should have per_serving object');
    assert.ok(firstFood.serving_description, 'Should have serving_description');
    
    // Check per_serving structure
    const serving = firstFood.per_serving;
    assert.ok(typeof serving.carbs_g === 'number', 'Should have carbs_g as number');
    assert.ok(typeof serving.protein_g === 'number', 'Should have protein_g as number');
    assert.ok(typeof serving.fat_g === 'number', 'Should have fat_g as number');
    assert.ok(typeof serving.sodium_mg === 'number', 'Should have sodium_mg as number');
    assert.ok(typeof serving.water_ml === 'number', 'Should have water_ml as number');
  });

  test('filters foods by category', async () => {
    const beforeRunResult = await getFoods({ category: 'before_run' });
    const duringRunResult = await getFoods({ category: 'during_run' });
    const afterRunResult = await getFoods({ category: 'after_run' });
    
    assert.strictEqual(beforeRunResult.success, true);
    assert.strictEqual(duringRunResult.success, true);
    assert.strictEqual(afterRunResult.success, true);
    
    // Check that all foods in each category contain the requested category
    beforeRunResult.foods.forEach(food => {
      assert.ok(food.categories.includes('before_run'), 
        `Food ${food.name} should be in before_run category`);
    });
    
    duringRunResult.foods.forEach(food => {
      assert.ok(food.categories.includes('during_run'),
        `Food ${food.name} should be in during_run category`);
    });
    
    afterRunResult.foods.forEach(food => {
      assert.ok(food.categories.includes('after_run'),
        `Food ${food.name} should be in after_run category`);
    });
    
    // Should have different counts
    const totalCount = (await getFoods()).foods.length;
    assert.ok(beforeRunResult.foods.length < totalCount, 'Filtered result should be smaller');
    assert.ok(duringRunResult.foods.length < totalCount, 'Filtered result should be smaller');
    assert.ok(afterRunResult.foods.length < totalCount, 'Filtered result should be smaller');
  });

  test('includes brand information by default', async () => {
    const result = await getFoods();
    
    assert.strictEqual(result.success, true);
    
    // Find a food that should have a brand
    const sportsFood = result.foods.find(food => food.id === 'sports_drink');
    assert.ok(sportsFood, 'Should find sports drink');
    assert.ok(sportsFood.brand, 'Should include brand information by default');
  });

  test('excludes brand information when requested', async () => {
    const result = await getFoods({ include_brands: false });
    
    assert.strictEqual(result.success, true);
    
    // All foods should not have brand info
    result.foods.forEach(food => {
      assert.strictEqual(food.brand, undefined, 
        `Food ${food.name} should not have brand when include_brands is false`);
    });
  });

  test('returns valid category list in metadata', async () => {
    const result = await getFoods();
    
    assert.strictEqual(result.success, true);
    
    const categories = result.metadata.categories;
    assert.ok(categories.includes('before_run'), 'Should include before_run category');
    assert.ok(categories.includes('during_run'), 'Should include during_run category');  
    assert.ok(categories.includes('after_run'), 'Should include after_run category');
    
    // Should not have duplicates
    const uniqueCategories = [...new Set(categories)];
    assert.strictEqual(categories.length, uniqueCategories.length, 'Should not have duplicate categories');
  });

  test('handles empty requests gracefully', async () => {
    const result = await getFoods({});
    
    assert.strictEqual(result.success, true, 'Should handle empty request');
    assert.ok(result.foods.length > 0, 'Should return foods for empty request');
  });

  test('handles invalid category gracefully', async () => {
    const result = await getFoods({ category: 'invalid_category' });
    
    assert.strictEqual(result.success, true, 'Should not error on invalid category');
    assert.strictEqual(result.foods.length, 0, 'Should return empty array for invalid category');
    assert.strictEqual(result.metadata.total_count, 0, 'Should show 0 count for filtered results');
  });

  test('HTTP handler works correctly', async () => {
    const response = await handleRequest();
    
    assert.strictEqual(response.status, 200, 'Should return 200 status');
    assert.ok(response.data, 'Should have data object');
    assert.strictEqual(response.data.success, true, 'Data should indicate success');
    assert.ok(response.data.foods, 'Should have foods in response');
  });

  test('HTTP handler accepts parameters', async () => {
    const request = { body: { category: 'during_run' } };
    const response = await handleRequest(request);
    
    assert.strictEqual(response.status, 200, 'Should return 200 status');
    assert.strictEqual(response.data.success, true, 'Should succeed with parameters');
    
    // All returned foods should be during_run appropriate
    response.data.foods.forEach(food => {
      assert.ok(food.categories.includes('during_run'), 
        'Should only return during_run foods');
    });
  });

  test('foods have timing guidance', async () => {
    const result = await getFoods();
    
    assert.strictEqual(result.success, true);
    
    // Check that foods have timing notes
    result.foods.forEach(food => {
      assert.ok(food.timing_notes, `Food ${food.name} should have timing_notes`);
      assert.ok(typeof food.timing_notes === 'string', 'Timing notes should be string');
      assert.ok(food.timing_notes.length > 0, 'Timing notes should not be empty');
    });
  });

  test('nutritional values are reasonable', async () => {
    const result = await getFoods();
    
    assert.strictEqual(result.success, true);
    
    result.foods.forEach(food => {
      const serving = food.per_serving;
      
      // All values should be non-negative
      assert.ok(serving.carbs_g >= 0, `${food.name} carbs should be non-negative`);
      assert.ok(serving.protein_g >= 0, `${food.name} protein should be non-negative`);
      assert.ok(serving.fat_g >= 0, `${food.name} fat should be non-negative`);
      assert.ok(serving.sodium_mg >= 0, `${food.name} sodium should be non-negative`);
      assert.ok(serving.water_ml >= 0, `${food.name} water should be non-negative`);
      
      // Should have some nutritional value (at least carbs or protein)
      assert.ok(serving.carbs_g > 0 || serving.protein_g > 0,
        `${food.name} should have some carbs or protein`);
    });
  });

});

// Manual test runner for development
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log('Running manual test...');
  
  const allFoods = await getFoods();
  console.log('All Foods:', JSON.stringify(allFoods, null, 2));
  
  const duringRunFoods = await getFoods({ category: 'during_run' });
  console.log('\nDuring Run Foods:', JSON.stringify(duringRunFoods, null, 2));
  
  const noBrands = await getFoods({ include_brands: false });
  console.log('\nFoods without brands:', JSON.stringify(noBrands.foods.slice(0, 2), null, 2));
  
  console.log('\nTest completed successfully!');
}