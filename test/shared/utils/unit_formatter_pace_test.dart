import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';

/// Regression cover for the M:SS carry bug.
///
/// A 25 mi ride in 100 min stores `pace_minutes_per_mile: 3.9999502907988265`.
/// Taking `floor()` for the minutes and rounding `(value - minutes) * 60`
/// separately rendered that as "3:60" — the seconds field overflowed instead of
/// carrying into the minute. Seen live on the activity detail header.
void main() {
  group('formatMinutesAsMinSec', () {
    test('carries into the next minute instead of rendering :60', () {
      expect(UnitFormatter.formatMinutesAsMinSec(3.9999502907988265), '4:00');
    });

    test('carries for any value that rounds up to a whole minute', () {
      expect(UnitFormatter.formatMinutesAsMinSec(8.99999), '9:00');
      expect(UnitFormatter.formatMinutesAsMinSec(5.999999), '6:00');
    });

    test('zero-pads seconds', () {
      expect(UnitFormatter.formatMinutesAsMinSec(9.05), '9:03');
      expect(UnitFormatter.formatMinutesAsMinSec(7.5), '7:30');
    });

    test('leaves exact values alone', () {
      expect(UnitFormatter.formatMinutesAsMinSec(9.0), '9:00');
      expect(UnitFormatter.formatMinutesAsMinSec(0.0), '0:00');
    });

    test('never emits a seconds field of 60 across a fine sweep', () {
      // Walk a range of paces at sub-second granularity; any ":60" here means
      // the minute/second halves have disagreed again.
      for (var i = 0; i < 20000; i++) {
        final minutes = 3.0 + i * 0.0001;
        expect(
          UnitFormatter.formatMinutesAsMinSec(minutes),
          isNot(contains(':60')),
          reason: 'minutes=$minutes rendered a :60 seconds field',
        );
      }
    });
  });

  group('formatPace', () {
    test('carries in the per-mile branch', () {
      expect(
        UnitFormatter.formatPace(3.9999502907988265, unit: PaceUnit.minPerMile),
        '4:00 /mi',
      );
    });

    test('carries in the per-km branch', () {
      // 6.4374 min/mi * 0.621371 = 3.99997... min/km — rounds up to 4:00.
      expect(
        UnitFormatter.formatPace(6.4374, unit: PaceUnit.minPerKm),
        '4:00 /km',
      );
    });
  });
}
