import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/domain/session_input_resolver.dart';

/// Regression suite for the duration ladder.
///
/// **This file used to test a copy of the logic.** It declared its own
/// `estimateDurationMinutes` and `mapSportForActivity` in the test file —
/// "the function under test is private and tightly coupled to Drift row
/// reads, so we extract the pure arithmetic here" — which meant it imported
/// no production code and would have stayed green if the real derivation had
/// been deleted outright. It could not, and did not, notice a SECOND consumer
/// (the macro dashboard) shipping without the ladder at all
/// (`ops/data/bug-reports/2026-08-22-dashboard-prices-distance-sessions-at-flat-60min.md`).
///
/// It now exercises [SessionInputResolver] — the real, shared implementation.
/// Cases below are preserved verbatim from the copy so the original 2026-06-15
/// coverage is not lost in the move.
int estimateDurationMinutes({
  required int? durationMinutes,
  required String activityType,
  double? distanceMiles,
  double? paceTargetMinutesPerMile,
  double? cyclingSpeedMph,
  int? swimmingPacePer100mSeconds,
}) =>
    SessionInputResolver.durationMinutes(
      activityType: activityType,
      explicitMinutes: durationMinutes,
      distanceMiles: distanceMiles,
      paceTargetMinutesPerMile: paceTargetMinutesPerMile,
      cyclingSpeedMph: cyclingSpeedMph,
      swimmingPacePer100mSeconds: swimmingPacePer100mSeconds,
    );

String mapSportForActivity(String activityType) =>
    SessionInputResolver.engineSport(activityType);

void main() {
  group('estimateDurationMinutes – regression for calorie bug', () {
    test('14-mile run at 10:00/mi pace should estimate 140 min, not 60', () {
      final duration = estimateDurationMinutes(
        durationMinutes: null,
        activityType: 'running',
        distanceMiles: 14.0,
        paceTargetMinutesPerMile: 10.0,
      );
      expect(duration, 140);
    });

    test('8-mile run at 8:00/mi pace should estimate 64 min', () {
      final duration = estimateDurationMinutes(
        durationMinutes: null,
        activityType: 'running',
        distanceMiles: 8.0,
        paceTargetMinutesPerMile: 8.0,
      );
      expect(duration, 64);
    });

    test(
      '14-mile run should always produce higher calorie duration than 8-mile run at same pace',
      () {
        final longRun = estimateDurationMinutes(
          durationMinutes: null,
          activityType: 'running',
          distanceMiles: 14.0,
          paceTargetMinutesPerMile: 10.0,
        );
        final shortRun = estimateDurationMinutes(
          durationMinutes: null,
          activityType: 'running',
          distanceMiles: 8.0,
          paceTargetMinutesPerMile: 10.0,
        );
        expect(longRun, greaterThan(shortRun));
      },
    );

    test('explicit duration_minutes is used when present', () {
      final duration = estimateDurationMinutes(
        durationMinutes: 45,
        activityType: 'running',
        distanceMiles: 14.0,
        paceTargetMinutesPerMile: 10.0,
      );
      expect(duration, 45);
    });

    test('falls back to 60 when no distance/pace available', () {
      final duration = estimateDurationMinutes(
        durationMinutes: null,
        activityType: 'running',
        distanceMiles: null,
        paceTargetMinutesPerMile: null,
      );
      expect(duration, 60);
    });

    test('cycling: estimates from distance and speed', () {
      final duration = estimateDurationMinutes(
        durationMinutes: null,
        activityType: 'cycling',
        distanceMiles: 30.0,
        cyclingSpeedMph: 18.0,
      );
      // 30 / 18 * 60 = 100 min
      expect(duration, 100);
    });

    test('swimming: estimates from distance and pace per 100m', () {
      final duration = estimateDurationMinutes(
        durationMinutes: null,
        activityType: 'swimming',
        distanceMiles: 1.0,
        swimmingPacePer100mSeconds: 120,
      );
      // 1 mile = 1609.34m → 16.0934 × 100m segments
      // 16.0934 × 120s = 1931.2s → 32.19 min → rounds to 32
      expect(duration, 32);
    });

    test('duration_minutes of 0 triggers estimation (same as null)', () {
      final duration = estimateDurationMinutes(
        durationMinutes: 0,
        activityType: 'running',
        distanceMiles: 10.0,
        paceTargetMinutesPerMile: 9.0,
      );
      expect(duration, 90);
    });

    test('other activity with no duration defaults to 30 min, not 60', () {
      final duration = estimateDurationMinutes(
        durationMinutes: null,
        activityType: 'other',
      );
      expect(duration, 30);
    });

    test('other activity with explicit duration uses that duration', () {
      final duration = estimateDurationMinutes(
        durationMinutes: 20,
        activityType: 'other',
      );
      expect(duration, 20);
    });
  });

  group('mapSportForActivity – regression for 766-cal overcount bug', () {
    test('other activity maps to strength, not running', () {
      expect(mapSportForActivity('other'), 'strength');
    });

    test('running activity maps to running', () {
      expect(mapSportForActivity('running'), 'running');
    });

    test('cycling activity maps to cycling', () {
      expect(mapSportForActivity('cycling'), 'cycling');
    });

    test('swimming activity maps to swimming', () {
      expect(mapSportForActivity('swimming'), 'swimming');
    });

    test('unknown activity type still defaults to running', () {
      expect(mapSportForActivity('some_unknown_type'), 'running');
    });
  });
}
