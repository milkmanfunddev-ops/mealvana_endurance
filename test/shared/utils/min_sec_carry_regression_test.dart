/// Regression net for the "3:60" family of M:SS formatting bugs.
///
/// bf0b591f fixed the headline case (pace rendering `3:60/mi`) by adding
/// [UnitFormatter.formatMinutesAsMinSec] and routing four call sites through
/// it. This suite asserts the invariant on *every* remaining M:SS formatter in
/// the app, because the same open-coded pattern survives in several domain
/// objects that the fix did not reach:
///
/// ```dart
/// final minutes = value.floor();                     // rounds DOWN
/// final seconds = ((value - minutes) * 60).round();  // rounds UP -> 60
/// ```
///
/// The two halves round in opposite directions, so any value whose fractional
/// part is ≥ 59.5/60 of a minute overflows the seconds field instead of
/// carrying into the minute. 7.9999 min renders "7:60" instead of "8:00".
///
/// The invariant under test is simply: **the seconds field is never 60.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/activity_completion.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';

/// Fractional minute values that sit inside the last half-second of a minute.
/// Each one rounds up to a whole minute and must therefore carry.
const _carryValues = <double>[
  3.9999, // the reported case
  7.99999,
  5.999,
  0.9999,
  12.99917, // 12 min 59.95 s
];

/// Extracts the `SS` field from any `…M:SS…` string.
int _secondsFieldOf(String formatted) {
  final match = RegExp(r'(\d+):(\d{2})').firstMatch(formatted);
  expect(
    match,
    isNotNull,
    reason: 'Expected an M:SS pair somewhere in "$formatted".',
  );
  return int.parse(match!.group(2)!);
}

void main() {
  group('UnitFormatter.formatMinutesAsMinSec (the fixed reference impl)', () {
    test('carries instead of rendering :60', () {
      for (final v in _carryValues) {
        final out = UnitFormatter.formatMinutesAsMinSec(v);
        expect(
          _secondsFieldOf(out),
          lessThan(60),
          reason: '$v min rendered "$out" — seconds field must carry.',
        );
      }
    });

    test('3.9999 min is 4:00', () {
      expect(UnitFormatter.formatMinutesAsMinSec(3.9999), '4:00');
    });

    test('ordinary values are unaffected', () {
      expect(UnitFormatter.formatMinutesAsMinSec(8.5), '8:30');
      expect(UnitFormatter.formatMinutesAsMinSec(7.0), '7:00');
      expect(UnitFormatter.formatMinutesAsMinSec(0.25), '0:15');
    });
  });

  group('Activity.formattedPace', () {
    Activity activityWithPace(double pace) => Activity(
      id: 'a1',
      userId: 'u1',
      title: 'Tempo run',
      activityType: ActivityType.running,
      scheduledDateTime: DateTime(2026, 7, 31, 6),
      createdAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 31),
      paceTargetMinutesPerMile: pace,
    );

    test('never renders a 60-second field', () {
      for (final v in _carryValues) {
        final out = activityWithPace(v).formattedPace!;
        expect(
          _secondsFieldOf(out),
          lessThan(60),
          reason: 'paceTargetMinutesPerMile=$v rendered "$out".',
        );
      }
    });

    test('7.99999 min/mi is 8:00/mi, not 7:60/mi', () {
      expect(activityWithPace(7.99999).formattedPace, '8:00/mi');
    });

    test('agrees with the shared formatter for ordinary values', () {
      expect(activityWithPace(8.5).formattedPace, '8:30/mi');
    });
  });

  group('ActivityCompletion.formattedPace', () {
    ActivityCompletion completionWithPace(double pace) => ActivityCompletion(
      id: 1,
      activityId: 1,
      userId: 'u1',
      completedAt: DateTime(2026, 7, 31, 7),
      averagePaceMinutesPerMile: pace,
    );

    test('never renders a 60-second field', () {
      for (final v in _carryValues) {
        final out = completionWithPace(v).formattedPace!;
        expect(
          _secondsFieldOf(out),
          lessThan(60),
          reason: 'averagePaceMinutesPerMile=$v rendered "$out".',
        );
      }
    });

    test('7.99999 min/mi is 8:00/mi, not 7:60/mi', () {
      expect(completionWithPace(7.99999).formattedPace, '8:00/mi');
    });
  });

  group('Event.formattedGoalPace', () {
    Event eventWithGoalPace(double pace) => Event(
      id: 'e1',
      userId: 'u1',
      eventType: ActivityType.running,
      eventName: 'Goal race',
      eventDate: DateTime(2026, 9, 1),
      goalPaceMinutesPerMile: pace,
      createdAt: DateTime(2026, 7, 31),
      updatedAt: DateTime(2026, 7, 31),
    );

    test('never renders a 60-second field', () {
      for (final v in _carryValues) {
        final out = eventWithGoalPace(v).formattedGoalPace!;
        expect(
          _secondsFieldOf(out),
          lessThan(60),
          reason: 'goalPaceMinutesPerMile=$v rendered "$out".',
        );
      }
    });

    test('6.99999 min/mi is 7:00/mi, not 6:60/mi', () {
      expect(eventWithGoalPace(6.99999).formattedGoalPace, '7:00/mi');
    });
  });

  group('RunMetrics', () {
    RunMetrics metrics({double durationH = 1.0, double? pace}) => RunMetrics(
      distanceMi: 10,
      distanceKm: 16.09,
      durationH: durationH,
      durationMin: durationH * 60,
      paceMinPerMile: pace,
      speedMph: 10,
      caloriesGrossKcal: 900,
      caloriesNetKcal: 800,
      met: 9,
    );

    test('formattedDuration never renders a 60-minute field', () {
      // 3.9999 h is 3 h 59.994 min — rounds to 60 min and must carry to 4:00.
      for (final v in _carryValues) {
        final out = metrics(durationH: v).formattedDuration;
        expect(
          _secondsFieldOf(out),
          lessThan(60),
          reason: 'durationH=$v rendered "$out".',
        );
      }
    });

    test('3.9999 h is 4:00, not 3:60', () {
      expect(metrics(durationH: 3.9999).formattedDuration, '4:00');
    });

    test('formattedPace never renders a 60-second field', () {
      for (final v in _carryValues) {
        final out = metrics(pace: v).formattedPace;
        expect(
          _secondsFieldOf(out),
          lessThan(60),
          reason: 'paceMinPerMile=$v rendered "$out".',
        );
      }
    });

    test('7.99999 min/mi is 8:00, not 7:60', () {
      expect(metrics(pace: 7.99999).formattedPace, '8:00');
    });

    test('null pace still reports N/A', () {
      expect(metrics().formattedPace, 'N/A');
    });
  });
}
