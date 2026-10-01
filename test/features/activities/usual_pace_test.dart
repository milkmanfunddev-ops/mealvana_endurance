// Usual pace per sport, from what the athlete has actually done
// (ruled 2026-09-30, Xuan — option (b), slowest quartile).
//
// The load-bearing test here is the long-run one: it is the whole reason the
// ruling chose a quartile over a median, and it is the failure that would
// otherwise be silent — a long workout estimated under 90 minutes gets no
// nudge, which looks exactly like the bug this feature exists to fix.
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/usual_pace.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

CompletedSample run(double miles, int minutes) =>
    (distanceMiles: miles, durationMinutes: minutes);

void main() {
  group('fallbacks (ruled)', () {
    test('each sport converts to the common currency', () {
      expect(UsualPaceEngine.fallbackMinutesPerMile(ActivityType.running), 10.0);
      // 15 mph
      expect(UsualPaceEngine.fallbackMinutesPerMile(ActivityType.cycling), 4.0);
      // 2:00 per 100 yd, and a mile is 17.6 of those
      expect(
        UsualPaceEngine.fallbackMinutesPerMile(ActivityType.swimming),
        closeTo(35.2, 0.001),
      );
    });

    test('unknown and mixed sports take the slowest fallback, not the fastest',
        () {
      // Over-estimating duration nudges someone who may not need it;
      // under-estimating drops the athlete the feature exists for.
      for (final s in [
        ActivityType.brick,
        ActivityType.triathlon,
        ActivityType.other,
        null,
      ]) {
        expect(UsualPaceEngine.fallbackMinutesPerMile(s), 10.0, reason: '$s');
      }
    });

    test('fewer than three samples is not history', () {
      final p = UsualPaceEngine.from(
        [run(3, 24), run(4, 32)],
        ActivityType.running,
      );
      expect(p.source, UsualPaceSource.fallback);
      expect(p.minutesPerMile, 10.0);
      expect(p.sampleCount, 2);
    });

    test('rows with a zero or missing side are not sessions', () {
      final p = UsualPaceEngine.from(
        [run(0, 30), run(5, 0), run(-1, 10)],
        ActivityType.running,
      );
      expect(p.source, UsualPaceSource.fallback);
      expect(p.sampleCount, 0);
    });
  });

  group('the slowest quartile, and why it is not the median', () {
    // A realistic week: three fast short sessions, one long slow one.
    final mixed = [
      run(3, 21), //  7:00/mi intervals
      run(4, 30), //  7:30/mi tempo
      run(5, 40), //  8:00/mi steady
      run(12, 126), // 10:30/mi long run
    ];

    test('the figure is slower than the median', () {
      final p = UsualPaceEngine.from(mixed, ActivityType.running);
      expect(p.source, UsualPaceSource.history);
      // median of 7.0/7.5/8.0/10.5 is 7.75; the quartile figure must exceed it
      expect(p.minutesPerMile, greaterThan(7.75));
    });

    test('a long run is NOT estimated under the LONG threshold', () {
      // THE POINT. At the median (7.75 min/mi) a 10-mile long run estimates to
      // 77 minutes and silently gets no nudge. At the quartile figure it clears
      // 90 and the athlete is nudged.
      final p = UsualPaceEngine.from(mixed, ActivityType.running);
      final tenMiler = p.durationFor(10).inMinutes;

      expect(10 * 7.75, lessThan(90), reason: 'median would have missed it');
      expect(tenMiler, greaterThanOrEqualTo(90),
          reason: 'the quartile figure must clear the 90-minute threshold');
    });

    test('a consistent athlete gets their own pace, near enough', () {
      final steady = [run(5, 45), run(6, 54), run(8, 72), run(10, 90)];
      final p = UsualPaceEngine.from(steady, ActivityType.running);
      expect(p.source, UsualPaceSource.history);
      expect(p.minutesPerMile, closeTo(9.0, 0.01));
    });

    test('history beats the fallback even when the athlete is slower than it',
        () {
      final slow = [run(3, 36), run(4, 50), run(5, 65)]; // 12-13 min/mi
      final p = UsualPaceEngine.from(slow, ActivityType.running);
      expect(p.source, UsualPaceSource.history);
      expect(p.minutesPerMile, greaterThan(10.0),
          reason: 'a slower athlete must not be sped up to the fallback');
    });

    test('provenance travels with the figure', () {
      final p = UsualPaceEngine.from(
        [run(5, 45), run(6, 54), run(8, 72)],
        ActivityType.running,
      );
      expect(p.fromHistory, isTrue);
      expect(p.sampleCount, 3);
      expect(
        UsualPaceEngine.from([], ActivityType.cycling).fromHistory,
        isFalse,
      );
    });
  });

  group('duration estimation', () {
    test('distance times pace, rounded to the second', () {
      const p = UsualPace(10.0, UsualPaceSource.fallback);
      expect(p.durationFor(14).inMinutes, 140);
      expect(p.durationFor(3.1).inSeconds, 1860);
    });

    test('a 40-mile ride at the ruled fallback is 2h40, not 6h40', () {
      // Guards the unit conversion: 15 mph, not 15 min/mile.
      final p = UsualPace(
        UsualPaceEngine.fallbackMinutesPerMile(ActivityType.cycling),
        UsualPaceSource.fallback,
      );
      expect(p.durationFor(40).inMinutes, 160);
    });

    test('a 1-mile swim at the ruled fallback is about 35 minutes', () {
      final p = UsualPace(
        UsualPaceEngine.fallbackMinutesPerMile(ActivityType.swimming),
        UsualPaceSource.fallback,
      );
      expect(p.durationFor(1).inMinutes, 35);
    });
  });
}
