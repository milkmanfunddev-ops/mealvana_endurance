/**
 * Cycling-specific nutrition configuration
 *
 * Cycling allows more food variety during activity because:
 * - Stable riding position reduces GI stress
 * - Jersey pockets can carry solid foods
 * - Easier to eat while pedaling
 * - Longer events = more calories needed
 *
 * NOTE: Food suitability is handled by the categories array using 'during_bike'.
 */

import type { SportConfig } from './types.ts';

export const cyclingConfig: SportConfig = {
  name: 'Cycling',
  activityType: 'cycling',

  phases: {
    before: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['carbs', 'hydration'],
    },
    during: {
      maxFoods: 5, // Cyclists can carry more variety
      defaultMaxServings: 3,
      maxServingsCap: 6, // More servings OK on long rides
      priorities: ['carbs', 'sodium', 'hydration'],
    },
    after: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['protein', 'carbs'],
    },
  },

  // Food-specific overrides are now in the food_sport_phases database table
  foodOverrides: [],

  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.5, sodium: 0.3 },
    during: { carbs: 1.0, sodium: 0.7 }, // Sodium important for long rides
    after: { carbs: 0.8, protein: 0.8, sodium: 0.3 },
  },
};
