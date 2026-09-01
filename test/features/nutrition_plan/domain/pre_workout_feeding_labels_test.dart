// Feeding-card titles and window labels for the pre-workout BEFORE card.
//
// Contract: docs/ssot/spec/design/components/feeding-card.md v1 (RATIFIED
// Xuan 2026-08-26) — "Tier × title × window label" table and FC-1. Replaces
// the sport-varying titles the previous test pinned ("Pre-Ride Meal",
// "Pre-Workout Meal"): FC-1 as ratified is "Pre-Run Meal" for every sport
// (deferred-ledger P4 — the sport variant is retired for this surface).
//
// Manifest ids covered here at the unit level: fc_naming_threshold (the
// widget-level assertion lives in pre_workout_before_card_gestures_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_feeding_labels.dart';

void main() {
  group('preWorkoutFeedingTitle (FC-1)', () {
    test('MEAL is "Pre-Run Meal" — always, never renamed by size or sport', () {
      expect(
        preWorkoutFeedingTitle(PreWorkoutFeedingTier.meal),
        'Pre-Run Meal',
      );
      expect(
        preWorkoutFeedingTitle(
          PreWorkoutFeedingTier.meal,
          snackCarbAimG: 500,
          bodyWeightKg: 63,
        ),
        'Pre-Run Meal',
      );
    });

    test(
      'SNACK flips to "Light Meal" at LIGHT_MEAL_G_PER_KG·BW (1.0 g/kg)',
      () {
        // 63 kg ⇒ threshold 63 g.
        expect(
          preWorkoutFeedingTitle(
            PreWorkoutFeedingTier.snack,
            snackCarbAimG: 62.9,
            bodyWeightKg: 63,
          ),
          'Pre-Workout Snack',
        );
        expect(
          preWorkoutFeedingTitle(
            PreWorkoutFeedingTier.snack,
            snackCarbAimG: 63.0,
            bodyWeightKg: 63,
          ),
          'Light Meal',
        );
        expect(
          preWorkoutFeedingTitle(
            PreWorkoutFeedingTier.snack,
            snackCarbAimG: 75.6,
            bodyWeightKg: 63,
          ),
          'Light Meal',
        );
      },
    );

    test('SNACK with no weight / no aim cannot evaluate the threshold', () {
      expect(
        preWorkoutFeedingTitle(PreWorkoutFeedingTier.snack, snackCarbAimG: 90),
        'Pre-Workout Snack',
      );
      expect(
        preWorkoutFeedingTitle(PreWorkoutFeedingTier.snack, bodyWeightKg: 63),
        'Pre-Workout Snack',
      );
    });

    test('TOP_OFF is "Top-Off"', () {
      expect(preWorkoutFeedingTitle(PreWorkoutFeedingTier.topOff), 'Top-Off');
    });
  });

  group('PreWorkoutFeedingTier.parse', () {
    test('accepts the engine spelling and the plan sub-phase spelling', () {
      expect(
        PreWorkoutFeedingTier.parse('top_off'),
        PreWorkoutFeedingTier.topOff,
      );
      expect(
        PreWorkoutFeedingTier.parse('top_up'),
        PreWorkoutFeedingTier.topOff,
      );
      expect(PreWorkoutFeedingTier.parse('meal'), PreWorkoutFeedingTier.meal);
      expect(PreWorkoutFeedingTier.parse('snack'), PreWorkoutFeedingTier.snack);
      expect(PreWorkoutFeedingTier.parse('dinner'), isNull);
      expect(PreWorkoutFeedingTier.topOff.subPhaseType, 'top_up');
      expect(PreWorkoutFeedingTier.topOff.engineName, 'top_off');
    });
  });

  group('preWorkoutWindowLabel', () {
    test('meal → FINISH BY 2H OUT; (15 MIN WINDOW) only for 2 h – 2 h 15', () {
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.meal,
          timeBeforeMin: 180,
          isFirstFeeding: true,
        ),
        'FINISH BY 2H OUT',
      );
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.meal,
          timeBeforeMin: 135,
          isFirstFeeding: true,
        ),
        'FINISH BY 2H OUT (15 MIN WINDOW)',
      );
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.meal,
          timeBeforeMin: 120,
          isFirstFeeding: true,
        ),
        'FINISH BY 2H OUT (15 MIN WINDOW)',
      );
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.meal,
          timeBeforeMin: 150,
          isFirstFeeding: true,
        ),
        'FINISH BY 2H OUT',
      );
    });

    test('snack → 2H TO 30 MIN OUT, or NOW UNTIL 30 MIN OUT when first', () {
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.snack,
          timeBeforeMin: 180,
          isFirstFeeding: false,
        ),
        '2H TO 30 MIN OUT',
      );
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.snack,
          timeBeforeMin: 90,
          isFirstFeeding: true,
        ),
        'NOW UNTIL 30 MIN OUT',
      );
    });

    test('top-off → LAST 30 MIN / NOW UNTIL THE START / NOW', () {
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.topOff,
          timeBeforeMin: 180,
          isFirstFeeding: false,
        ),
        'LAST 30 MIN',
      );
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.topOff,
          timeBeforeMin: 20,
          isFirstFeeding: true,
        ),
        'NOW UNTIL THE START',
      );
      expect(
        preWorkoutWindowLabel(
          PreWorkoutFeedingTier.topOff,
          timeBeforeMin: 0,
          isFirstFeeding: true,
        ),
        'NOW',
      );
    });
  });
}
