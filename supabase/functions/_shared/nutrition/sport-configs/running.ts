/**
 * Running-specific nutrition configuration
 *
 * Running has the most restrictions during activity due to:
 * - GI stress from bouncing motion
 * - Limited ability to carry/consume food
 * - Need for easily digestible, quick-energy foods
 *
 * NOTE: Food suitability is handled by the categories array using 'during_run'.
 */

import type { SportConfig } from './types.ts';

export const runningConfig: SportConfig = {
  name: 'Running',
  activityType: 'running',

  phases: {
    before: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['carbs', 'hydration'],
    },
    during: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 8,
      priorities: ['carbs', 'sodium'],
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
    before: { carbs: 1.0, protein: 0.6, sodium: 0.2 },
    during: { carbs: 1.0, sodium: 0.8 },
    after: { carbs: 0.9, protein: 0.7, sodium: 0.3 },
  },
};
