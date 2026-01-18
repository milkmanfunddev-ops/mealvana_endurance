/**
 * Swimming-specific nutrition configuration
 *
 * Swimming is unique because:
 * - Cannot eat during activity (obviously!)
 * - Light pre-swim meal to avoid bloating
 * - Post-swim recovery is critical
 * - Chlorine exposure affects appetite
 *
 * NOTE: Food suitability is handled by the categories array using 'during_swim'.
 */

import type { SportConfig } from './types.ts';

export const swimmingConfig: SportConfig = {
  name: 'Swimming',
  activityType: 'swimming',

  phases: {
    before: {
      maxFoods: 3, // Lighter pre-swim
      defaultMaxServings: 2,
      maxServingsCap: 2,
      priorities: ['carbs'], // Light carbs, avoid heavy foods
    },
    during: {
      maxFoods: 2, // Limited - only at aid stations in open water
      defaultMaxServings: 1,
      maxServingsCap: 2,
      priorities: ['carbs'], // Gels/liquids only at aid stations
    },
    after: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['protein', 'carbs', 'hydration'],
    },
  },

  // Food-specific overrides are now in the food_sport_phases database table
  foodOverrides: [],

  optimizationWeights: {
    before: { carbs: 0.8, protein: 0.3, sodium: 0.2 },
    during: { carbs: 0.5, sodium: 0.3 }, // Limited intake at aid stations
    after: { carbs: 0.7, protein: 0.9, sodium: 0.4 },
  },
};
