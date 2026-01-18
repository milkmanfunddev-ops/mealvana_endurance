/**
 * Sport Configuration Index
 *
 * Central export for all sport-specific nutrition configurations.
 * Use getSportConfig() to get the appropriate config for an activity type.
 *
 * NOTE: Food-specific phase suitability is handled by the expanded category_enum:
 * - before: Universal pre-activity
 * - during_run, during_bike, during_swim: Sport-specific during phases
 * - after: Universal post-activity
 * - transition: Triathlon transition zone
 *
 * The sport configs here only contain phase limits and optimization weights.
 */

import type { SportConfig, SportConfigMap } from './types.ts';
import type { ActivityType, Phase } from '../types.ts';
import { runningConfig } from './running.ts';
import { cyclingConfig } from './cycling.ts';
import { swimmingConfig } from './swimming.ts';

// Re-export types
export * from './types.ts';

// ============================================================================
// Multi-Sport Configurations
// ============================================================================

/**
 * Triathlon uses a blend of all three sports
 * Generally follows running rules for during (most restrictive)
 */
export const triathlonConfig: SportConfig = {
  name: 'Triathlon',
  activityType: 'triathlon',

  phases: {
    before: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['carbs', 'hydration'],
    },
    during: {
      // Bike leg allows more eating, but run leg restricts
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 4,
      priorities: ['carbs', 'sodium'],
    },
    after: {
      maxFoods: 4,
      defaultMaxServings: 2,
      maxServingsCap: 3,
      priorities: ['protein', 'carbs', 'hydration'],
    },
  },

  foodOverrides: [],

  optimizationWeights: {
    before: { carbs: 1.0, protein: 0.5, sodium: 0.3 },
    during: { carbs: 1.0, sodium: 0.8 },
    after: { carbs: 0.8, protein: 0.8, sodium: 0.4 },
  },
};

/**
 * Duathlon (run-bike-run) follows running rules
 */
export const duathlonConfig: SportConfig = {
  ...runningConfig,
  name: 'Duathlon',
  activityType: 'duathlon',
  foodOverrides: [],
};

/**
 * Multisport (generic) uses running rules as default
 */
export const multisportConfig: SportConfig = {
  ...runningConfig,
  name: 'Multisport',
  activityType: 'multisport',
  foodOverrides: [],
};

// ============================================================================
// Sport Config Registry
// ============================================================================

const sportConfigs: SportConfigMap = {
  running: runningConfig,
  cycling: cyclingConfig,
  swimming: swimmingConfig,
  triathlon: triathlonConfig,
  duathlon: duathlonConfig,
  multisport: multisportConfig,
};

/**
 * Get the sport configuration for a given activity type
 * Defaults to running if activity type is unknown
 */
export function getSportConfig(activityType: ActivityType | string | undefined): SportConfig {
  if (!activityType) {
    console.log('[SPORT_CONFIG] No activity type provided, defaulting to running');
    return runningConfig;
  }

  const config = sportConfigs[activityType as ActivityType];
  if (!config) {
    console.log(`[SPORT_CONFIG] Unknown activity type "${activityType}", defaulting to running`);
    return runningConfig;
  }

  return config;
}

/**
 * Get phase-specific limits for a sport
 */
export function getPhaseConfig(activityType: ActivityType | string | undefined, phase: Phase) {
  const config = getSportConfig(activityType);
  return config.phases[phase];
}

/**
 * Get optimization weights for a phase and sport
 */
export function getOptimizationWeights(activityType: ActivityType | string | undefined, phase: Phase) {
  const config = getSportConfig(activityType);
  return config.optimizationWeights[phase];
}
