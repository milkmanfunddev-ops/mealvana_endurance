import { describe, it, expect, beforeEach, vi } from 'vitest';

// ============================================
// BARCODE LOOKUP UNIT TESTS
// ============================================
// Testing core barcode processing logic without external dependencies

// Mock cache implementation
class MockCache {
  private cache: Map<string, { data: any; timestamp: number }> = new Map();
  private ttl: number = 24 * 60 * 60 * 1000; // 24 hours

  get(key: string) {
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.timestamp < this.ttl) {
      return cached.data;
    }
    if (cached) {
      this.cache.delete(key);
    }
    return null;
  }

  set(key: string, data: any) {
    this.cache.set(key, { data, timestamp: Date.now() });
  }

  clear() {
    this.cache.clear();
  }
}

// Core validation functions from edge function
function validateBarcode(barcode: string): boolean {
  const cleanBarcode = barcode.replace(/\D/g, '');
  return [8, 12, 13].includes(cleanBarcode.length);
}

function cleanBarcodeString(barcode: string): string {
  return barcode.replace(/\D/g, '');
}

// Nutrient normalization functions
function normalizeOpenFoodFactsProduct(product: any): any {
  const nutriments = product.nutriments || {};

  // Convert sodium from various formats
  let sodium_mg_per_100g = nutriments.sodium_100g;
  if (nutriments.salt_100g && !sodium_mg_per_100g) {
    // Convert salt to sodium (salt = sodium * 2.5)
    sodium_mg_per_100g = nutriments.salt_100g * 1000 / 2.5;
  }
  if (sodium_mg_per_100g && sodium_mg_per_100g < 1) {
    // Likely in grams, convert to mg
    sodium_mg_per_100g *= 1000;
  }

  // Parse serving size
  let servingGrams = parseFloat(product.serving_quantity || "0");
  if (!servingGrams && product.serving_size) {
    const match = product.serving_size.match(/\(?\s*(\d+(?:\.\d+)?)\s*g\s*\)?/i);
    if (match) {
      servingGrams = parseFloat(match[1]);
    }
  }

  const hasPerServingData = nutriments["energy-kcal_serving"] !== undefined;

  return {
    barcode: product.code,
    product_name: product.product_name || "Unknown Product",
    brand_name: product.brands,
    image_url: product.image_front_url || product.image_url,
    serving_size: product.serving_size || product.quantity,
    calories_per_100g: nutriments["energy-kcal_100g"],
    carbohydrates_per_100g: nutriments["carbohydrates_100g"],
    protein_per_100g: nutriments["proteins_100g"],
    fat_per_100g: nutriments["fat_100g"],
    sodium_mg_per_100g: sodium_mg_per_100g,
    calories_per_serving: nutriments["energy-kcal_serving"],
    carbohydrates_per_serving: nutriments["carbohydrates_serving"],
    protein_per_serving: nutriments["proteins_serving"],
    fat_per_serving: nutriments["fat_serving"],
    sodium_mg_per_serving: nutriments["sodium_serving"] ?
      Math.round(nutriments["sodium_serving"] * 1000) : undefined,
    serving_grams: servingGrams > 0 ? servingGrams : undefined,
    nutrition_data_per: hasPerServingData ? "serving" : "100g",
    api_source: "open_food_facts",
    confidence_score: hasPerServingData ? 0.9 : 0.7
  };
}

// Mock API responses for testing
const mockOpenFoodFactsResponse = {
  status: 1,
  product: {
    code: "722252100900",
    product_name: "Clif Bar - Chocolate Chip",
    brands: "Clif Bar",
    image_front_url: "https://images.openfoodfacts.org/images/products/722252100900.jpg",
    serving_size: "68g (1 bar)",
    serving_quantity: "68",
    quantity: "68g",
    nutriments: {
      "energy-kcal_100g": 368,
      "carbohydrates_100g": 66.2,
      "proteins_100g": 13.2,
      "fat_100g": 8.8,
      "sodium_100g": 0.294,
      "energy-kcal_serving": 250,
      "carbohydrates_serving": 45,
      "proteins_serving": 9,
      "fat_serving": 6,
      "sodium_serving": 0.2
    }
  }
};

const mockUSDAResponse = {
  foods: [{
    fdcId: 1234567,
    description: "PROTEIN BAR, CHOCOLATE",
    brandName: "Pure Protein",
    gtinUpc: "749826001951",
    foodNutrients: [
      { nutrientName: "Energy", value: 380 },
      { nutrientName: "Carbohydrate, by difference", value: 34 },
      { nutrientName: "Protein", value: 38 },
      { nutrientName: "Total lipid (fat)", value: 12 },
      { nutrientName: "Sodium, Na", value: 300 }
    ]
  }]
};

describe('Barcode Lookup - Unit Tests', () => {

  describe('🔍 Barcode Validation', () => {
    it('should validate correct barcode formats', () => {
      // Valid formats
      expect(validateBarcode('12345678')).toBe(true);      // EAN-8
      expect(validateBarcode('123456789012')).toBe(true);  // UPC-A
      expect(validateBarcode('1234567890123')).toBe(true); // EAN-13

      console.log('✓ Valid barcode formats accepted');
    });

    it('should reject invalid barcode formats', () => {
      expect(validateBarcode('123')).toBe(false);          // Too short
      expect(validateBarcode('12345')).toBe(false);       // Wrong length
      expect(validateBarcode('12345678901234')).toBe(false); // Too long

      console.log('✓ Invalid barcode formats rejected');
    });

    it('should clean barcodes with non-numeric characters', () => {
      expect(cleanBarcodeString('123-456-789-012')).toBe('123456789012');
      expect(cleanBarcodeString('(123) 456789012')).toBe('123456789012');
      expect(cleanBarcodeString('UPC: 123456789012')).toBe('123456789012');
      expect(cleanBarcodeString('abc123def456ghi789jkl012')).toBe('123456789012');

      console.log('✓ Non-numeric characters removed correctly');
    });

    it('should handle edge cases in barcode cleaning', () => {
      expect(cleanBarcodeString('')).toBe('');
      expect(cleanBarcodeString('   ')).toBe('');
      expect(cleanBarcodeString('!@#$%')).toBe('');
      expect(cleanBarcodeString('00000000')).toBe('00000000');

      console.log('✓ Edge cases handled correctly');
    });
  });

  describe('🥫 Open Food Facts Normalization', () => {
    it('should normalize product data correctly', () => {
      const normalized = normalizeOpenFoodFactsProduct(mockOpenFoodFactsResponse.product);

      expect(normalized.product_name).toBe('Clif Bar - Chocolate Chip');
      expect(normalized.brand_name).toBe('Clif Bar');
      expect(normalized.barcode).toBe('722252100900');
      expect(normalized.api_source).toBe('open_food_facts');

      console.log('✓ Basic product info normalized');
    });

    it('should convert sodium from grams to milligrams', () => {
      const product = {
        ...mockOpenFoodFactsResponse.product,
        nutriments: {
          ...mockOpenFoodFactsResponse.product.nutriments,
          sodium_100g: 0.294 // In grams
        }
      };

      const normalized = normalizeOpenFoodFactsProduct(product);
      expect(normalized.sodium_mg_per_100g).toBeCloseTo(294, 0);

      console.log('✓ Sodium converted from g to mg');
    });

    it('should convert salt to sodium when sodium not available', () => {
      const product = {
        ...mockOpenFoodFactsResponse.product,
        nutriments: {
          ...mockOpenFoodFactsResponse.product.nutriments,
          sodium_100g: undefined,
          salt_100g: 0.735 // Salt in grams
        }
      };

      const normalized = normalizeOpenFoodFactsProduct(product);
      // Salt * 1000 / 2.5 = sodium in mg
      expect(normalized.sodium_mg_per_100g).toBeCloseTo(294, 0);

      console.log('✓ Salt converted to sodium correctly');
    });

    it('should parse serving size from various formats', () => {
      const testCases = [
        { serving_size: '68g (1 bar)', expected: 68 },
        { serving_size: '1 bar (68g)', expected: 68 },
        { serving_size: '(68 g)', expected: 68 },
        { serving_size: '68.5g', expected: 68.5 },
        { serving_quantity: '68', expected: 68 },
        { serving_size: '1 bar', serving_quantity: '68', expected: 68 }
      ];

      testCases.forEach(({ serving_size, serving_quantity, expected }) => {
        const product = {
          code: '123',
          serving_size,
          serving_quantity,
          nutriments: {}
        };

        const normalized = normalizeOpenFoodFactsProduct(product);
        expect(normalized.serving_grams).toBe(expected);
      });

      console.log('✓ Serving sizes parsed from various formats');
    });

    it('should determine nutrition data format correctly', () => {
      // With per-serving data
      const withServing = normalizeOpenFoodFactsProduct(mockOpenFoodFactsResponse.product);
      expect(withServing.nutrition_data_per).toBe('serving');
      expect(withServing.confidence_score).toBe(0.9);

      // Without per-serving data
      const withoutServing = {
        ...mockOpenFoodFactsResponse.product,
        nutriments: {
          "energy-kcal_100g": 368,
          "carbohydrates_100g": 66.2,
          "proteins_100g": 13.2,
          "fat_100g": 8.8
          // No _serving values
        }
      };

      const normalized = normalizeOpenFoodFactsProduct(withoutServing);
      expect(normalized.nutrition_data_per).toBe('100g');
      expect(normalized.confidence_score).toBe(0.7);

      console.log('✓ Nutrition data format detected correctly');
    });

    it('should handle missing or incomplete data', () => {
      const incomplete = {
        code: '123456789012',
        product_name: undefined,
        brands: undefined,
        nutriments: {}
      };

      const normalized = normalizeOpenFoodFactsProduct(incomplete);
      expect(normalized.product_name).toBe('Unknown Product');
      expect(normalized.brand_name).toBeUndefined();
      expect(normalized.calories_per_100g).toBeUndefined();
      expect(normalized.serving_grams).toBeUndefined();

      console.log('✓ Missing data handled gracefully');
    });
  });

  describe('💾 Cache Management', () => {
    let cache: MockCache;

    beforeEach(() => {
      cache = new MockCache();
    });

    it('should cache and retrieve results', () => {
      const testData = { barcode: '123', product_name: 'Test Product' };

      cache.set('123', testData);
      const retrieved = cache.get('123');

      expect(retrieved).toEqual(testData);
      console.log('✓ Cache storage and retrieval working');
    });

    it('should return null for non-existent keys', () => {
      const result = cache.get('nonexistent');
      expect(result).toBeNull();
      console.log('✓ Non-existent keys return null');
    });

    it('should expire old cache entries', () => {
      const testData = { barcode: '123', product_name: 'Test Product' };

      // Mock time to simulate expiration
      const originalNow = Date.now;
      let currentTime = Date.now();

      Date.now = vi.fn(() => currentTime);

      cache.set('123', testData);

      // Move time forward 25 hours
      currentTime += 25 * 60 * 60 * 1000;

      const retrieved = cache.get('123');
      expect(retrieved).toBeNull();

      // Restore original Date.now
      Date.now = originalNow;

      console.log('✓ Cache entries expire after TTL');
    });

    it('should clear all cache entries', () => {
      cache.set('123', { data: 'test1' });
      cache.set('456', { data: 'test2' });
      cache.set('789', { data: 'test3' });

      cache.clear();

      expect(cache.get('123')).toBeNull();
      expect(cache.get('456')).toBeNull();
      expect(cache.get('789')).toBeNull();

      console.log('✓ Cache clear removes all entries');
    });
  });

  describe('🌐 API Response Processing', () => {
    it('should identify successful Open Food Facts response', () => {
      const isSuccess = mockOpenFoodFactsResponse.status === 1 &&
                       mockOpenFoodFactsResponse.product !== null;
      expect(isSuccess).toBe(true);
      console.log('✓ Open Food Facts success identified');
    });

    it('should identify product not found responses', () => {
      const notFound = { status: 0, product: null };
      const isSuccess = notFound.status === 1 && notFound.product !== null;
      expect(isSuccess).toBe(false);
      console.log('✓ Product not found identified');
    });

    it('should extract USDA nutrient values', () => {
      const nutrients = mockUSDAResponse.foods[0].foodNutrients;

      const getNutrientValue = (name: string) => {
        const nutrient = nutrients.find(n =>
          n.nutrientName.toLowerCase().includes(name.toLowerCase())
        );
        return nutrient?.value;
      };

      expect(getNutrientValue("Energy")).toBe(380);
      expect(getNutrientValue("Carbohydrate")).toBe(34);
      expect(getNutrientValue("Protein")).toBe(38);
      expect(getNutrientValue("Sodium")).toBe(300);

      console.log('✓ USDA nutrients extracted correctly');
    });

    it('should match exact barcode in USDA results', () => {
      const targetBarcode = '749826001951';
      const foods = mockUSDAResponse.foods;

      const exactMatch = foods.find(food => food.gtinUpc === targetBarcode);
      expect(exactMatch).toBeDefined();
      expect(exactMatch?.brandName).toBe('Pure Protein');

      console.log('✓ Exact barcode match found in USDA');
    });
  });

  describe('🚨 Error Handling', () => {
    it('should handle API errors gracefully', () => {
      const handleError = (error: any) => {
        console.error("API error:", error.message);
        return null;
      };

      const result = handleError(new Error("Network timeout"));
      expect(result).toBeNull();
      console.log('✓ API errors handled gracefully');
    });

    it('should validate request payload', () => {
      const validateRequest = (payload: any) => {
        if (!payload.barcode || typeof payload.barcode !== 'string') {
          return {
            valid: false,
            error: "Barcode is required and must be a string"
          };
        }
        return { valid: true };
      };

      expect(validateRequest({})).toEqual({
        valid: false,
        error: "Barcode is required and must be a string"
      });

      expect(validateRequest({ barcode: 123 })).toEqual({
        valid: false,
        error: "Barcode is required and must be a string"
      });

      expect(validateRequest({ barcode: "123456789012" })).toEqual({
        valid: true
      });

      console.log('✓ Request validation working');
    });
  });

  describe('📊 Product Data Completeness', () => {
    it('should calculate data completeness score', () => {
      const calculateCompleteness = (product: any) => {
        const requiredFields = [
          'product_name', 'calories_per_100g', 'carbohydrates_per_100g',
          'protein_per_100g', 'fat_per_100g'
        ];

        const optionalFields = [
          'brand_name', 'image_url', 'serving_size', 'sodium_mg_per_100g',
          'calories_per_serving', 'serving_grams'
        ];

        let score = 0;
        let maxScore = requiredFields.length * 2 + optionalFields.length;

        requiredFields.forEach(field => {
          if (product[field] !== undefined && product[field] !== null) {
            score += 2;
          }
        });

        optionalFields.forEach(field => {
          if (product[field] !== undefined && product[field] !== null) {
            score += 1;
          }
        });

        return (score / maxScore) * 100;
      };

      const complete = normalizeOpenFoodFactsProduct(mockOpenFoodFactsResponse.product);
      const completenessScore = calculateCompleteness(complete);

      expect(completenessScore).toBeGreaterThan(70);
      console.log(`✓ Product completeness: ${completenessScore.toFixed(1)}%`);
    });
  });
});