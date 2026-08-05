// Window labels and feeding titles for the pre-workout (BEFORE) feeding
// cards — spec-settled copy from the ratified mockup (docs/pre-workout-macro.html)
// and the SSOT reference implementation's `whens=` derivation
// (docs/ssot/spec/fueling/pre-workout-ui.html). Digest §5.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_feeding_labels.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('preWorkoutWindowLabel', () {
    test('meal → FINISH BY 2H OUT regardless of meal-tier presence', () {
      expect(
        preWorkoutWindowLabel('meal', hasMealTier: true),
        'FINISH BY 2H OUT',
      );
      expect(
        preWorkoutWindowLabel('meal', hasMealTier: false),
        'FINISH BY 2H OUT',
      );
    });

    test('snack → 2H TO 30 MIN OUT when a meal tier exists', () {
      expect(
        preWorkoutWindowLabel('snack', hasMealTier: true),
        '2H TO 30 MIN OUT',
      );
    });

    test('snack → NOW – 30 MIN OUT when no meal tier exists', () {
      expect(
        preWorkoutWindowLabel('snack', hasMealTier: false),
        'NOW – 30 MIN OUT',
      );
    });

    test('top_up → LAST 30 MIN regardless of meal-tier presence', () {
      expect(preWorkoutWindowLabel('top_up', hasMealTier: true), 'LAST 30 MIN');
      expect(
        preWorkoutWindowLabel('top_up', hasMealTier: false),
        'LAST 30 MIN',
      );
    });

    test('unrecognised sub-phase type → null (no line, not a wrong one)', () {
      expect(preWorkoutWindowLabel('mystery', hasMealTier: true), isNull);
      expect(preWorkoutWindowLabel('mystery', hasMealTier: false), isNull);
    });
  });

  group('preWorkoutFeedingTitle', () {
    test('meal is sport-aware for running and cycling', () {
      expect(
        preWorkoutFeedingTitle('meal', sport: ActivityType.running),
        'Pre-Run Meal',
      );
      expect(
        preWorkoutFeedingTitle('meal', sport: ActivityType.cycling),
        'Pre-Ride Meal',
      );
    });

    test('meal falls back to generic for other or unknown sports', () {
      expect(
        preWorkoutFeedingTitle('meal', sport: ActivityType.swimming),
        'Pre-Workout Meal',
      );
      expect(
        preWorkoutFeedingTitle('meal', sport: ActivityType.brick),
        'Pre-Workout Meal',
      );
      expect(preWorkoutFeedingTitle('meal'), 'Pre-Workout Meal');
    });

    test('snack and top_up are sport-agnostic', () {
      expect(
        preWorkoutFeedingTitle('snack', sport: ActivityType.running),
        'Pre-Workout Snack',
      );
      expect(preWorkoutFeedingTitle('top_up'), 'Top-Off');
    });

    test('unrecognised sub-phase type falls through to the raw type', () {
      expect(preWorkoutFeedingTitle('mystery'), 'mystery');
    });
  });
}
