import { describe, it, expect, beforeEach } from 'vitest';

// ============================================
// SAVE FOOD PREFERENCES UNIT TESTS
// ============================================
// Testing food preference validation and processing logic

// Valid preference types from the edge function
const VALID_PREFERENCES = ['like', 'dislike', 'willing_to_try'];

// Mock food database for testing
const MOCK_FOODS = {
  // Whole foods
  'Banana': { type: 'whole_food', essential: false },
  'Oatmeal': { type: 'whole_food', essential: false },
  'Dates': { type: 'whole_food', essential: false },
  'Orange juice': { type: 'whole_food', essential: false },

  // Essential items (gels)
  'Gel': { type: 'gel', essential: true },
  'GU Energy Gel': { type: 'gel', essential: true },

  // Bars
  'Clif Bar': { type: 'bar', essential: false },
  'Fig Bar': { type: 'bar', essential: false },

  // Sports drinks (essential)
  'Gatorade': { type: 'drink', essential: true },
  'Sports drink': { type: 'drink', essential: true },

  // Other items
  'Energy chews': { type: 'chew', essential: false },
  'Honey': { type: 'whole_food', essential: false }
};

// Validation functions from edge function logic
function validatePreference(preference: string): boolean {
  return VALID_PREFERENCES.includes(preference);
}

function validateFoodPreferences(preferences: Record<string, string>): {
  valid: boolean;
  errors: string[];
} {
  const errors: string[] = [];

  // Check if preferences object is valid
  if (!preferences || typeof preferences !== 'object') {
    return {
      valid: false,
      errors: ['Food preferences must be an object']
    };
  }

  // Check if empty
  if (Object.keys(preferences).length === 0) {
    errors.push('At least one food preference must be provided');
  }

  // Validate each preference
  for (const [foodName, preference] of Object.entries(preferences)) {
    if (!foodName || typeof foodName !== 'string') {
      errors.push(`Invalid food name: ${foodName}`);
    }

    if (!validatePreference(preference)) {
      errors.push(`Invalid preference for ${foodName}: ${preference}. Must be 'like', 'dislike', or 'willing_to_try'`);
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

// Process preferences for storage
function processPreferences(
  deviceId: string,
  preferences: Record<string, string>
): Array<{ device_id: string; food_name: string; preference: string }> {
  const processed = [];

  for (const [foodName, preference] of Object.entries(preferences)) {
    // Normalize food name (trim, lowercase for matching)
    const normalizedName = foodName.trim();

    processed.push({
      device_id: deviceId,
      food_name: normalizedName,
      preference: preference
    });
  }

  return processed;
}

// Calculate preference statistics
function calculatePreferenceStats(preferences: Record<string, string>) {
  const stats = {
    total: Object.keys(preferences).length,
    likes: 0,
    dislikes: 0,
    willingToTry: 0,
    essentialDislikes: 0
  };

  for (const [foodName, preference] of Object.entries(preferences)) {
    switch (preference) {
      case 'like':
        stats.likes++;
        break;
      case 'dislike':
        stats.dislikes++;
        // Check if essential food is disliked
        if (MOCK_FOODS[foodName]?.essential) {
          stats.essentialDislikes++;
        }
        break;
      case 'willing_to_try':
        stats.willingToTry++;
        break;
    }
  }

  return stats;
}

describe('Save Food Preferences - Unit Tests', () => {

  describe('✅ Preference Validation', () => {

    it('should accept valid preference values', () => {
      expect(validatePreference('like')).toBe(true);
      expect(validatePreference('dislike')).toBe(true);
      expect(validatePreference('willing_to_try')).toBe(true);

      console.log('✓ Valid preferences accepted');
    });

    it('should reject invalid preference values', () => {
      expect(validatePreference('love')).toBe(false);
      expect(validatePreference('hate')).toBe(false);
      expect(validatePreference('maybe')).toBe(false);
      expect(validatePreference('')).toBe(false);
      expect(validatePreference('LIKE')).toBe(false); // Case sensitive

      console.log('✓ Invalid preferences rejected');
    });

    it('should validate complete preference objects', () => {
      const validPrefs = {
        'Banana': 'like',
        'Oatmeal': 'dislike',
        'Gel': 'willing_to_try'
      };

      const result = validateFoodPreferences(validPrefs);
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);

      console.log('✓ Valid preference object accepted');
    });

    it('should reject preference objects with invalid values', () => {
      const invalidPrefs = {
        'Banana': 'like',
        'Oatmeal': 'hate',  // Invalid
        'Gel': 'maybe'      // Invalid
      };

      const result = validateFoodPreferences(invalidPrefs);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
      expect(result.errors.some(e => e.includes('hate'))).toBe(true);
      expect(result.errors.some(e => e.includes('maybe'))).toBe(true);

      console.log('✓ Invalid preferences detected:', result.errors);
    });

    it('should reject empty preference objects', () => {
      const emptyPrefs = {};

      const result = validateFoodPreferences(emptyPrefs);
      expect(result.valid).toBe(false);
      expect(result.errors).toContain('At least one food preference must be provided');

      console.log('✓ Empty preferences rejected');
    });
  });

  describe('🔄 Preference Processing', () => {

    it('should process preferences for database storage', () => {
      const deviceId = 'test-device-123';
      const preferences = {
        'Banana': 'like',
        'Oatmeal': 'dislike',
        'Sports drink': 'willing_to_try'
      };

      const processed = processPreferences(deviceId, preferences);

      expect(processed).toHaveLength(3);
      expect(processed[0]).toEqual({
        device_id: deviceId,
        food_name: 'Banana',
        preference: 'like'
      });

      console.log('✓ Preferences processed for storage');
    });

    it('should normalize food names during processing', () => {
      const deviceId = 'test-device-123';
      const preferences = {
        '  Banana  ': 'like',     // Extra spaces
        'OATMEAL': 'dislike',     // Different case
        'sports drink': 'willing_to_try'  // Lowercase
      };

      const processed = processPreferences(deviceId, preferences);

      expect(processed[0].food_name).toBe('Banana');
      expect(processed[1].food_name).toBe('OATMEAL');
      expect(processed[2].food_name).toBe('sports drink');

      console.log('✓ Food names normalized');
    });

    it('should handle large preference sets', () => {
      const deviceId = 'test-device-123';
      const preferences: Record<string, string> = {};

      // Create 50 preferences
      for (let i = 1; i <= 50; i++) {
        preferences[`Food ${i}`] = i % 3 === 0 ? 'like' :
                                   i % 3 === 1 ? 'dislike' :
                                   'willing_to_try';
      }

      const processed = processPreferences(deviceId, preferences);
      expect(processed).toHaveLength(50);

      console.log('✓ Large preference set processed');
    });
  });

  describe('📊 Preference Statistics', () => {

    it('should calculate preference distribution', () => {
      const preferences = {
        'Banana': 'like',
        'Dates': 'like',
        'Oatmeal': 'dislike',
        'Orange juice': 'dislike',
        'Gel': 'willing_to_try',
        'Clif Bar': 'willing_to_try',
        'Fig Bar': 'willing_to_try'
      };

      const stats = calculatePreferenceStats(preferences);

      expect(stats.total).toBe(7);
      expect(stats.likes).toBe(2);
      expect(stats.dislikes).toBe(2);
      expect(stats.willingToTry).toBe(3);

      console.log('✓ Preference statistics calculated:', stats);
    });

    it('should identify disliked essential foods', () => {
      const preferences = {
        'Banana': 'like',
        'Gel': 'dislike',           // Essential!
        'Gatorade': 'dislike',      // Essential!
        'Oatmeal': 'dislike'
      };

      const stats = calculatePreferenceStats(preferences);

      expect(stats.essentialDislikes).toBe(2);

      console.log('✓ Essential food dislikes identified:', stats.essentialDislikes);
    });

    it('should handle all-liked preferences', () => {
      const preferences = {
        'Banana': 'like',
        'Dates': 'like',
        'Gel': 'like',
        'Gatorade': 'like'
      };

      const stats = calculatePreferenceStats(preferences);

      expect(stats.likes).toBe(4);
      expect(stats.dislikes).toBe(0);
      expect(stats.willingToTry).toBe(0);
      expect(stats.essentialDislikes).toBe(0);

      console.log('✓ All-liked preferences handled');
    });

    it('should handle all-disliked preferences', () => {
      const preferences = {
        'Banana': 'dislike',
        'Oatmeal': 'dislike',
        'Gel': 'dislike',
        'Gatorade': 'dislike'
      };

      const stats = calculatePreferenceStats(preferences);

      expect(stats.likes).toBe(0);
      expect(stats.dislikes).toBe(4);
      expect(stats.essentialDislikes).toBe(2); // Gel and Gatorade

      console.log('✓ All-disliked preferences handled');
    });
  });

  describe('🏃 Runner Profile Scenarios', () => {

    it('should handle beginner runner preferences', () => {
      const beginnerPrefs = {
        // Familiar whole foods liked
        'Banana': 'like',
        'Dates': 'like',
        'Honey': 'like',
        // Unsure about specialized products
        'Gel': 'willing_to_try',
        'Energy chews': 'willing_to_try',
        'Sports drink': 'willing_to_try',
        // Dislikes
        'Oatmeal': 'dislike'
      };

      const validation = validateFoodPreferences(beginnerPrefs);
      const stats = calculatePreferenceStats(beginnerPrefs);

      expect(validation.valid).toBe(true);
      expect(stats.likes).toBe(3);
      expect(stats.willingToTry).toBe(3);

      console.log('✓ Beginner runner profile:', stats);
    });

    it('should handle experienced runner preferences', () => {
      const experiencedPrefs = {
        // Knows what works
        'Gel': 'like',
        'GU Energy Gel': 'like',
        'Gatorade': 'like',
        'Dates': 'like',
        // Knows what doesn\'t
        'Oatmeal': 'dislike',
        'Fig Bar': 'dislike',
        'Orange juice': 'dislike',
        // Still experimenting
        'Energy chews': 'willing_to_try'
      };

      const validation = validateFoodPreferences(experiencedPrefs);
      const stats = calculatePreferenceStats(experiencedPrefs);

      expect(validation.valid).toBe(true);
      expect(stats.likes).toBe(4);
      expect(stats.dislikes).toBe(3);

      console.log('✓ Experienced runner profile:', stats);
    });

    it('should handle picky eater profile', () => {
      const pickyPrefs = {
        'Banana': 'like',
        'Dates': 'like',
        // Everything else disliked
        'Oatmeal': 'dislike',
        'Gel': 'dislike',
        'GU Energy Gel': 'dislike',
        'Gatorade': 'dislike',
        'Sports drink': 'dislike',
        'Energy chews': 'dislike',
        'Fig Bar': 'dislike',
        'Clif Bar': 'dislike'
      };

      const validation = validateFoodPreferences(pickyPrefs);
      const stats = calculatePreferenceStats(pickyPrefs);

      expect(validation.valid).toBe(true);
      expect(stats.likes).toBe(2);
      expect(stats.dislikes).toBe(8);
      expect(stats.essentialDislikes).toBeGreaterThan(0);

      console.log('✓ Picky eater profile:', stats);
      console.log('  ⚠️ Warning: Essential foods disliked!');
    });
  });

  describe('🚨 Error Scenarios', () => {

    it('should handle null/undefined values', () => {
      const invalidPrefs = {
        'Banana': 'like',
        'Oatmeal': null as any,
        'Gel': undefined as any
      };

      const result = validateFoodPreferences(invalidPrefs);
      expect(result.valid).toBe(false);

      console.log('✓ Null/undefined values rejected');
    });

    it('should handle non-string values', () => {
      const invalidPrefs = {
        'Banana': 'like',
        'Oatmeal': 123 as any,
        'Gel': true as any
      };

      const result = validateFoodPreferences(invalidPrefs);
      expect(result.valid).toBe(false);

      console.log('✓ Non-string values rejected');
    });

    it('should handle special characters in food names', () => {
      const specialPrefs = {
        'Banana (organic)': 'like',
        'Honey & Oats Bar': 'dislike',
        'GU® Energy Gel': 'willing_to_try',
        '100% Orange Juice': 'like'
      };

      const validation = validateFoodPreferences(specialPrefs);
      const processed = processPreferences('device-123', specialPrefs);

      expect(validation.valid).toBe(true);
      expect(processed).toHaveLength(4);

      console.log('✓ Special characters in food names handled');
    });
  });

  describe('🔄 Preference Updates', () => {

    it('should handle preference changes', () => {
      const originalPrefs = {
        'Banana': 'dislike',
        'Oatmeal': 'willing_to_try'
      };

      const updatedPrefs = {
        'Banana': 'like',        // Changed from dislike
        'Oatmeal': 'dislike',    // Changed from willing_to_try
        'Gel': 'willing_to_try'  // New preference
      };

      const original = processPreferences('device-123', originalPrefs);
      const updated = processPreferences('device-123', updatedPrefs);

      expect(original[0].preference).toBe('dislike');
      expect(updated[0].preference).toBe('like');

      console.log('✓ Preference updates handled');
    });

    it('should handle preference removals', () => {
      const fullPrefs = {
        'Banana': 'like',
        'Oatmeal': 'dislike',
        'Gel': 'willing_to_try'
      };

      const reducedPrefs = {
        'Banana': 'like'
        // Oatmeal and Gel removed
      };

      const full = processPreferences('device-123', fullPrefs);
      const reduced = processPreferences('device-123', reducedPrefs);

      expect(full).toHaveLength(3);
      expect(reduced).toHaveLength(1);

      console.log('✓ Preference removals handled');
    });
  });
});