/**
 * Brick-specific nutrition configuration
 *
 * Brick workouts combine 2-3 consecutive sports (e.g., swim/run, bike/run, swim/bike/run).
 * They have unique nutritional challenges:
 * - Variable gastric tolerance across sports (swim: 0, bike: high, run: low)
 * - Critical transition windows (T1, T2) for quick fueling
 * - Total duration determines carb needs (cumulative calculation)
 * - Sport order affects phase-specific food selection but not totals
 *
 * Phase structure for brick workouts:
 * - before: Standard pre-workout nutrition
 * - during: Multi-segment phases (during_swim, during_bike, during_run)
 * - transitions: T1 (after segment 1), T2 (after segment 2, if 3 sports)
 * - after: Standard recovery nutrition
 *
 * NOTE: The edge function will handle multi-phase breakdown. This config provides
 * defaults that work across all brick combinations. Sport-specific food filtering
 * is handled by categories (during_swim, during_bike, during_run, transition).
 */

import type { SportConfig } from './types.ts';

export const brickConfig: SportConfig = {
  name: 'Brick',
  activityType: 'brick',

  phases: {
    before: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['carbs', 'hydration'],
    },
    during: {
      // During phase for brick is more complex (multiple segments + transitions)
      // Use cycling limits since bike leg typically allows most variety
      // Edge function will apply sport-specific restrictions per segment
      maxFoods: 6, // Higher to accommodate transition foods + segment foods
      defaultMaxServings: 3,
      maxServingsCap: 8, // Higher for longer brick workouts (e.g., 2hr bike + 1hr run)
      priorities: ['carbs', 'sodium', 'hydration'],
    },
    after: {
      maxFoods: 6,
      defaultMaxServings: 2,
      maxServingsCap: 5,
      priorities: ['protein', 'carbs', 'hydration'],
    },
  },

  // Food-specific overrides are now in the food_sport_phases database table
  foodOverrides: [],

  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.5, sodium: 0.3 },
    during: {
      // Balanced weights since brick includes multiple sports
      // Edge function will adjust per segment based on sport type
      carbs: 1.0,
      sodium: 0.8, // Sodium critical across longer multi-sport efforts
    },
    after: { carbs: 0.85, protein: 1.0, sodium: 0.4 },
  },
};
