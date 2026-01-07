/**
 * Edge Function Tests for sync-final-surge
 *
 * These tests validate the data transformation and business logic
 * without requiring live API calls or Supabase connection.
 *
 * Run with: deno test --allow-env supabase/functions/sync-final-surge/index.test.ts
 */

import {
  assertEquals,
  assertExists,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// TEST FIXTURES
// ============================================================================

const fixtures = {
  // Running workout with all fields
  runningWorkoutComplete: {
    workoutId: 'w-123',
    workoutName: 'Marathon Tempo',
    workoutDate: '2025-12-23',
    sport: 'RUNNING',
    workoutIcon: 1,
    steps: [
      {
        stepType: 'WorkoutStep' as const,
        intensity: 'WARMUP' as const,
        durationType: 'TIME' as const,
        durationValue: 600, // 10 min warmup in seconds
      },
      {
        stepType: 'WorkoutStep' as const,
        intensity: 'ACTIVE' as const,
        durationType: 'TIME' as const,
        durationValue: 3600, // 60 min main set in seconds
      },
      {
        stepType: 'WorkoutStep' as const,
        intensity: 'COOLDOWN' as const,
        durationType: 'TIME' as const,
        durationValue: 600, // 10 min cooldown in seconds
      },
    ],
  },

  // Workout with repeat steps
  workoutWithRepeats: {
    workoutId: 'w-456',
    workoutName: 'Track Intervals',
    workoutDate: '2025-12-24',
    sport: 'RUNNING',
    workoutIcon: 1,
    steps: [
      {
        stepType: 'WorkoutStep' as const,
        intensity: 'WARMUP' as const,
        durationType: 'TIME' as const,
        durationValue: 600, // 10 min warmup
      },
      {
        stepType: 'WorkoutRepeatStep' as const,
        repeatCount: 4,
        childSteps: [
          {
            stepType: 'WorkoutStep' as const,
            intensity: 'ACTIVE' as const,
            durationType: 'TIME' as const,
            durationValue: 300, // 5 min hard
          },
          {
            stepType: 'WorkoutStep' as const,
            intensity: 'REST' as const,
            durationType: 'TIME' as const,
            durationValue: 120, // 2 min rest
          },
        ],
      },
      {
        stepType: 'WorkoutStep' as const,
        intensity: 'COOLDOWN' as const,
        durationType: 'TIME' as const,
        durationValue: 600, // 10 min cooldown
      },
    ],
  },

  // Workout with distance-based steps
  workoutWithDistance: {
    workoutId: 'w-789',
    workoutName: 'Long Run',
    workoutDate: '2025-12-25',
    sport: 'RUNNING',
    workoutIcon: 1,
    steps: [
      {
        stepType: 'WorkoutStep' as const,
        intensity: 'ACTIVE' as const,
        durationType: 'DISTANCE' as const,
        durationValue: 16093.4, // 10 miles in meters
      },
    ],
  },

  // Cycling workout (should be filtered out in current implementation)
  cyclingWorkout: {
    workoutId: 'w-bike',
    workoutName: 'Endurance Ride',
    workoutDate: '2025-12-26',
    sport: 'CYCLING',
    workoutIcon: 2,
    steps: [],
  },

  // Swimming workout (should be filtered out in current implementation)
  swimmingWorkout: {
    workoutId: 'w-swim',
    workoutName: 'Pool Session',
    workoutDate: '2025-12-27',
    sport: 'SWIMMING',
    workoutIcon: 3,
    poolLength: 25,
    poolLengthUnit: 'm',
    steps: [],
  },

  // Workout with no steps
  workoutNoSteps: {
    workoutId: 'w-empty',
    workoutName: 'Easy Run',
    workoutDate: '2025-12-28',
    sport: 'RUNNING',
    workoutIcon: 1,
    steps: [],
  },
};

// ============================================================================
// HELPER FUNCTIONS (copied from index.ts for testing)
// ============================================================================

interface FinalSurgeWorkout {
  workoutId: string;
  workoutName: string;
  workoutDate: string;
  sport: 'RUNNING' | 'CYCLING' | 'SWIMMING' | string;
  workoutIcon: number;
  steps?: FinalSurgeStep[];
  poolLength?: number;
  poolLengthUnit?: string;
}

interface FinalSurgeStep {
  stepType: 'WorkoutStep' | 'WorkoutRampStep' | 'WorkoutRepeatStep';
  intensity?: 'ACTIVE' | 'REST' | 'WARMUP' | 'COOLDOWN';
  durationType?: 'TIME' | 'DISTANCE' | 'OPEN';
  durationValue?: number;
  durationUnit?: string;
  targetType?: 'POWER' | 'HEART_RATE' | 'PACE';
  targetValueLow?: number;
  targetValueHigh?: number;
  repeatCount?: number;
  childSteps?: FinalSurgeStep[];
}

/**
 * Parse workout steps to extract total duration/distance
 */
function parseWorkoutDetails(workout: FinalSurgeWorkout): {
  estimated_duration_minutes?: number;
  estimated_distance_meters?: number;
} {
  if (!workout.steps || workout.steps.length === 0) {
    return {};
  }

  let totalDurationSeconds = 0;
  let totalDistanceMeters = 0;

  function processStep(step: FinalSurgeStep, repeatMultiplier = 1) {
    if (step.stepType === 'WorkoutRepeatStep') {
      const repeatCount = step.repeatCount || 1;
      for (const childStep of step.childSteps || []) {
        processStep(childStep, repeatMultiplier * repeatCount);
      }
    } else if (step.durationType === 'TIME' && step.durationValue) {
      // Duration is in seconds
      totalDurationSeconds += step.durationValue * repeatMultiplier;
    } else if (step.durationType === 'DISTANCE' && step.durationValue) {
      // Distance is in meters
      totalDistanceMeters += step.durationValue * repeatMultiplier;
    }
  }

  for (const step of workout.steps) {
    processStep(step);
  }

  const result: {
    estimated_duration_minutes?: number;
    estimated_distance_meters?: number;
  } = {};

  if (totalDurationSeconds > 0) {
    result.estimated_duration_minutes = Math.round(totalDurationSeconds / 60);
  }

  if (totalDistanceMeters > 0) {
    result.estimated_distance_meters = totalDistanceMeters;
  }

  return result;
}

/**
 * Filter and transform workouts (simplified from index.ts)
 */
function filterAndTransformWorkouts(workouts: FinalSurgeWorkout[]): {
  external_id: string;
  source: string;
  name: string;
  date: string;
  sport_type: string;
  estimated_duration_minutes?: number;
  estimated_distance_meters?: number;
}[] {
  return workouts
    .filter((w) => w.sport === 'RUNNING')
    .map((w) => ({
      external_id: w.workoutId,
      source: 'final_surge',
      name: w.workoutName,
      date: w.workoutDate,
      sport_type: 'running',
      ...parseWorkoutDetails(w),
    }));
}

// ============================================================================
// TESTS
// ============================================================================

describe('sync-final-surge Edge Function', () => {
  describe('parseWorkoutDetails', () => {
    it('calculates total duration from time-based steps', () => {
      const result = parseWorkoutDetails(fixtures.runningWorkoutComplete);

      // 10 + 60 + 10 = 80 minutes
      assertEquals(result.estimated_duration_minutes, 80);
      assertEquals(result.estimated_distance_meters, undefined);
    });

    it('handles repeat steps correctly', () => {
      const result = parseWorkoutDetails(fixtures.workoutWithRepeats);

      // 10 min warmup + (4 repeats * (5 + 2 min)) + 10 min cooldown
      // = 10 + 28 + 10 = 48 minutes
      assertEquals(result.estimated_duration_minutes, 48);
    });

    it('calculates distance from distance-based steps', () => {
      const result = parseWorkoutDetails(fixtures.workoutWithDistance);

      assertEquals(result.estimated_distance_meters, 16093.4);
      assertEquals(result.estimated_duration_minutes, undefined);
    });

    it('returns empty object for workouts with no steps', () => {
      const result = parseWorkoutDetails(fixtures.workoutNoSteps);

      assertEquals(result.estimated_duration_minutes, undefined);
      assertEquals(result.estimated_distance_meters, undefined);
    });

    it('returns empty object for workouts with undefined steps', () => {
      const workout = { ...fixtures.workoutNoSteps, steps: undefined };
      const result = parseWorkoutDetails(workout);

      assertEquals(result.estimated_duration_minutes, undefined);
      assertEquals(result.estimated_distance_meters, undefined);
    });
  });

  describe('filterAndTransformWorkouts', () => {
    it('filters to running workouts only', () => {
      const workouts = [
        fixtures.runningWorkoutComplete,
        fixtures.cyclingWorkout,
        fixtures.swimmingWorkout,
      ];

      const result = filterAndTransformWorkouts(workouts);

      assertEquals(result.length, 1);
      assertEquals(result[0].sport_type, 'running');
      assertEquals(result[0].name, 'Marathon Tempo');
    });

    it('transforms workout with correct fields', () => {
      const workouts = [fixtures.runningWorkoutComplete];
      const result = filterAndTransformWorkouts(workouts);

      assertExists(result[0]);
      assertEquals(result[0].external_id, 'w-123');
      assertEquals(result[0].source, 'final_surge');
      assertEquals(result[0].name, 'Marathon Tempo');
      assertEquals(result[0].date, '2025-12-23');
      assertEquals(result[0].sport_type, 'running');
      assertEquals(result[0].estimated_duration_minutes, 80);
    });

    it('handles empty workout list', () => {
      const result = filterAndTransformWorkouts([]);
      assertEquals(result.length, 0);
    });

    it('handles all non-running workouts', () => {
      const workouts = [fixtures.cyclingWorkout, fixtures.swimmingWorkout];
      const result = filterAndTransformWorkouts(workouts);

      assertEquals(result.length, 0);
    });
  });

  describe('Nested repeat steps', () => {
    it('handles nested repeat steps correctly', () => {
      const nestedRepeats: FinalSurgeWorkout = {
        workoutId: 'nested',
        workoutName: 'Complex Workout',
        workoutDate: '2025-12-29',
        sport: 'RUNNING',
        workoutIcon: 1,
        steps: [
          {
            stepType: 'WorkoutRepeatStep',
            repeatCount: 2,
            childSteps: [
              {
                stepType: 'WorkoutRepeatStep',
                repeatCount: 3,
                childSteps: [
                  {
                    stepType: 'WorkoutStep',
                    intensity: 'ACTIVE',
                    durationType: 'TIME',
                    durationValue: 60, // 1 min
                  },
                ],
              },
            ],
          },
        ],
      };

      const result = parseWorkoutDetails(nestedRepeats);

      // 2 outer repeats * 3 inner repeats * 60 seconds = 360 seconds = 6 minutes
      assertEquals(result.estimated_duration_minutes, 6);
    });
  });

  describe('Edge cases', () => {
    it('handles step with zero duration value', () => {
      const workout: FinalSurgeWorkout = {
        workoutId: 'zero',
        workoutName: 'Zero Duration',
        workoutDate: '2025-12-30',
        sport: 'RUNNING',
        workoutIcon: 1,
        steps: [
          {
            stepType: 'WorkoutStep',
            intensity: 'ACTIVE',
            durationType: 'TIME',
            durationValue: 0,
          },
        ],
      };

      const result = parseWorkoutDetails(workout);

      // Should not add zero duration
      assertEquals(result.estimated_duration_minutes, undefined);
    });

    it('handles step with OPEN duration type', () => {
      const workout: FinalSurgeWorkout = {
        workoutId: 'open',
        workoutName: 'Open Duration',
        workoutDate: '2025-12-31',
        sport: 'RUNNING',
        workoutIcon: 1,
        steps: [
          {
            stepType: 'WorkoutStep',
            intensity: 'ACTIVE',
            durationType: 'OPEN',
            // No durationValue for open-ended steps
          },
        ],
      };

      const result = parseWorkoutDetails(workout);

      // OPEN type should not contribute to duration
      assertEquals(result.estimated_duration_minutes, undefined);
    });

    it('handles repeat step with repeatCount of 0 (defaults to 1)', () => {
      const workout: FinalSurgeWorkout = {
        workoutId: 'zero-repeat',
        workoutName: 'Zero Repeats',
        workoutDate: '2026-01-01',
        sport: 'RUNNING',
        workoutIcon: 1,
        steps: [
          {
            stepType: 'WorkoutRepeatStep',
            repeatCount: 0, // Edge case: 0 repeats (treated as 1 due to || 1 fallback)
            childSteps: [
              {
                stepType: 'WorkoutStep',
                intensity: 'ACTIVE',
                durationType: 'TIME',
                durationValue: 300,
              },
            ],
          },
        ],
      };

      const result = parseWorkoutDetails(workout);

      // 0 is falsy, so repeatCount || 1 defaults to 1 repeat
      // 1 * 300 seconds = 300 seconds = 5 minutes
      assertEquals(result.estimated_duration_minutes, 5);
    });

    it('handles mixed time and distance steps', () => {
      const workout: FinalSurgeWorkout = {
        workoutId: 'mixed',
        workoutName: 'Mixed Steps',
        workoutDate: '2026-01-02',
        sport: 'RUNNING',
        workoutIcon: 1,
        steps: [
          {
            stepType: 'WorkoutStep',
            intensity: 'WARMUP',
            durationType: 'TIME',
            durationValue: 600, // 10 min
          },
          {
            stepType: 'WorkoutStep',
            intensity: 'ACTIVE',
            durationType: 'DISTANCE',
            durationValue: 5000, // 5 km
          },
          {
            stepType: 'WorkoutStep',
            intensity: 'COOLDOWN',
            durationType: 'TIME',
            durationValue: 300, // 5 min
          },
        ],
      };

      const result = parseWorkoutDetails(workout);

      assertEquals(result.estimated_duration_minutes, 15); // 10 + 5
      assertEquals(result.estimated_distance_meters, 5000);
    });
  });

  describe('Sport type filtering', () => {
    it('correctly identifies RUNNING sport', () => {
      const workouts = [{ ...fixtures.runningWorkoutComplete, sport: 'RUNNING' }];
      const result = filterAndTransformWorkouts(workouts);
      assertEquals(result.length, 1);
    });

    it('filters out CYCLING sport', () => {
      const workouts = [{ ...fixtures.runningWorkoutComplete, sport: 'CYCLING' }];
      const result = filterAndTransformWorkouts(workouts);
      assertEquals(result.length, 0);
    });

    it('filters out SWIMMING sport', () => {
      const workouts = [{ ...fixtures.runningWorkoutComplete, sport: 'SWIMMING' }];
      const result = filterAndTransformWorkouts(workouts);
      assertEquals(result.length, 0);
    });

    it('filters out unknown sport types', () => {
      const workouts = [{ ...fixtures.runningWorkoutComplete, sport: 'TRIATHLON' }];
      const result = filterAndTransformWorkouts(workouts);
      assertEquals(result.length, 0);
    });
  });
});

// Run tests if executed directly
if (import.meta.main) {
  console.log('Running sync-final-surge edge function tests...');
}
