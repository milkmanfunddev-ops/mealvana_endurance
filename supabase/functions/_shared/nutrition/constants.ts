/**
 * Constants for nutrition planning algorithms
 */

import type { Phase, PreferenceCategory } from './types.ts';

// ============================================================================
// Optimization Weights
// ============================================================================

export interface MacroWeights {
  carbs: number;
  protein?: number;
  sodium: number;
}

export interface PhaseWeights {
  before: MacroWeights;
  during: MacroWeights;
  after: MacroWeights;
}

// Default weights - can be overridden by sport configs
export const DEFAULT_OPTIMIZATION_WEIGHTS: PhaseWeights = {
  before: {
    carbs: 1.0,
    protein: 0.6,
    sodium: 0.2,
  },
  during: {
    carbs: 1.0,
    sodium: 0.8,
  },
  after: {
    carbs: 0.9,
    protein: 0.7,
    sodium: 0.3,
  },
};

// ============================================================================
// Macro Constraint Ranges
// ============================================================================

export interface ConstraintRange {
  min: number;
  max: number;
}

export interface PhaseConstraints {
  before?: ConstraintRange;
  during?: ConstraintRange;
  after?: ConstraintRange;
}

export const MACRO_CONSTRAINT_RANGES: Record<string, PhaseConstraints> = {
  carbs: {
    before: { min: 0.9, max: 1.1 },
    during: { min: 0.9, max: 1.1 },
    after: { min: 0.9, max: 1.1 },
  },
  protein: {
    before: { min: 0.9, max: 1.1 },
    after: { min: 0.9, max: 1.1 },
  },
  sodium: {
    before: { min: 0.85, max: 1.1 },
    during: { min: 0.9, max: 1.1 },
    after: { min: 0.85, max: 1.1 },
  },
  water: {
    before: { min: 0.85, max: 1.1 },
    during: { min: 0.9, max: 1.1 },
    after: { min: 0.85, max: 1.1 },
  },
};

// ============================================================================
// Post-Processing Thresholds
// ============================================================================

export const POST_PROCESS_THRESHOLDS = {
  sodium_deficit_percent: 0.03,
  water_deficit_percent: 0.15,
  sodium_surplus_percent: 0.10,
  water_surplus_percent: 0.15,
};

// ============================================================================
// Preference Scoring
// ============================================================================

export const PREFERENCE_SCORE_MAP: Record<PreferenceCategory, number> = {
  liked: 200,
  willing: 80,
  essential: 50,
  neutral: 20,
};

// ============================================================================
// Default Limits
// ============================================================================

// Default max servings when no DB value or legacy column exists
export const DEFAULT_MAX_SERVINGS = 4;

export interface DefaultLimits {
  maxFoods: number;
  defaultMaxServings: number;
  maxServingsCap: number;
}

export const DEFAULT_PHASE_LIMITS: Record<Phase, DefaultLimits> = {
  before: {
    maxFoods: 4,
    defaultMaxServings: 2,
    maxServingsCap: 3,
  },
  during: {
    maxFoods: 4,
    defaultMaxServings: 2,
    maxServingsCap: 4,
  },
  after: {
    maxFoods: 4,
    defaultMaxServings: 2,
    maxServingsCap: 3,
  },
};

// ============================================================================
// Timing Labels
// ============================================================================

export const PHASE_TIMING_LABELS: Record<Phase, string> = {
  before: '2-3 hours before',
  during: 'Throughout activity',
  after: 'Within 30 minutes',
};

// ============================================================================
// Category Mappings
// ============================================================================

// Legacy mapping (for backward compatibility during migration)
export const PHASE_TO_CATEGORY: Record<Phase, string> = {
  before: 'before',
  during: 'during_run',
  after: 'after',
};

// Sport-specific category mapping for "during" phase
export const SPORT_DURING_CATEGORY: Record<string, string> = {
  running: 'during_run',
  cycling: 'during_bike',
  swimming: 'during_swim',
  triathlon: 'during_run', // Most restrictive for safety
  duathlon: 'during_run',
  multisport: 'during_run',
};

/**
 * Get the appropriate category for a phase and activity type
 * Handles both legacy (before_run, during_run, after_run) and new expanded categories
 */
export function getCategoryForPhase(phase: Phase, activityType: string = 'running'): string[] {
  switch (phase) {
    case 'before':
      // Include both old and new for compatibility during migration
      return ['before', 'before_run'];
    case 'during':
      // Get sport-specific during category
      const sportCategory = SPORT_DURING_CATEGORY[activityType] || 'during_run';
      // For cycling, also include foods marked for running (they're safe for cycling too)
      if (activityType === 'cycling') {
        return [sportCategory, 'during_run'];
      }
      return [sportCategory];
    case 'after':
      // Include both old and new for compatibility during migration
      return ['after', 'after_run'];
  }
}
