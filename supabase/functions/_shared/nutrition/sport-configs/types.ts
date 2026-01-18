/**
 * Sport Configuration Types
 *
 * Each sport (running, cycling, swimming) has different nutritional needs
 * and food suitability rules. These configs allow customization per sport.
 */

import type { Phase, ActivityType } from '../types.ts';
import type { MacroWeights, DefaultLimits } from '../constants.ts';

// ============================================================================
// Phase Configuration
// ============================================================================

export interface PhaseConfig extends DefaultLimits {
  /** What matters most in this phase (for tie-breaking) */
  priorities: ('carbs' | 'protein' | 'sodium' | 'hydration')[];
}

// ============================================================================
// Food Override
// ============================================================================

export interface FoodOverride {
  /** How to match this food */
  match: {
    name?: string;           // Exact or partial name match (case insensitive)
    productType?: string;    // Match by product_type column
  };

  /** Override max servings for specific phases (null = use default) */
  maxServings?: {
    before?: number | null;
    during?: number | null;
    after?: number | null;
  };

  /** Override suitability for specific phases */
  suitable?: {
    before?: boolean;
    during?: boolean;
    after?: boolean;
  };
}

// ============================================================================
// Sport Configuration
// ============================================================================

export interface SportConfig {
  /** Display name */
  name: string;

  /** Activity type enum value */
  activityType: ActivityType;

  /** Phase-specific settings */
  phases: {
    before: PhaseConfig;
    during: PhaseConfig;
    after: PhaseConfig;
  };

  /** Sport-specific food overrides */
  foodOverrides: FoodOverride[];

  /** Optimization weights for LP solver */
  optimizationWeights: {
    before: MacroWeights;
    during: MacroWeights;
    after: MacroWeights;
  };
}

// ============================================================================
// Helper Types
// ============================================================================

export type SportConfigMap = Record<ActivityType, SportConfig>;
