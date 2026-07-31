import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/log_date_time.dart';

void main() {
  group('eatenAtForLogDate', () {
    test('seeds the logDate calendar day, not today', () {
      // The regression: logging onto a back-dated day used to stamp eatenAt
      // with today's date, sinking the entry below every activity on the day
      // being viewed.
      final result = eatenAtForLogDate(
        '2026-07-19',
        now: DateTime(2026, 7, 20, 15, 42),
      );

      expect(result, DateTime(2026, 7, 19, 15, 42));
    });

    test('carries the current clock time and zeroes seconds', () {
      final result = eatenAtForLogDate(
        '2026-07-19',
        now: DateTime(2026, 7, 20, 6, 5, 33, 777),
      );

      expect(result.hour, 6);
      expect(result.minute, 5);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });

    test('is a no-op on the date component when logDate is today', () {
      final now = DateTime(2026, 7, 20, 11, 15);
      final result = eatenAtForLogDate('2026-07-20', now: now);

      expect(result, DateTime(2026, 7, 20, 11, 15));
    });

    test('handles a future logDate symmetrically', () {
      final result = eatenAtForLogDate(
        '2026-07-21',
        now: DateTime(2026, 7, 20, 9, 30),
      );

      expect(result, DateTime(2026, 7, 21, 9, 30));
    });

    test('falls back to now on a malformed logDate instead of throwing', () {
      // logDate arrives as router `extra` on deep-linkable screens, so a bad
      // value must not blow up the screen.
      final now = DateTime(2026, 7, 20, 15, 42);

      for (final bad in ['', 'not-a-date', 'garbage', '19-07-2026']) {
        expect(
          () => eatenAtForLogDate(bad, now: now),
          returnsNormally,
          reason: 'logDate "$bad" should not throw',
        );
        expect(eatenAtForLogDate(bad, now: now), now);
      }
    });

    test('out-of-range components parse rather than fall back', () {
      // Documents real DateTime.tryParse behavior: '2026-13-45' is accepted
      // and normalized (rolls into 2027) rather than rejected. Garbage in,
      // garbage out — but never a throw, which is what this helper guarantees.
      expect(
        () => eatenAtForLogDate('2026-13-45', now: DateTime(2026, 7, 20, 15)),
        returnsNormally,
      );
    });
  });
}
