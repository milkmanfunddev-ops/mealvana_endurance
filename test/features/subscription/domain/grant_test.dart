/// A Grant's source, read from its length, and its days left (mp-558).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/subscription/domain/grant.dart';

void main() {
  group('GrantSource.fromLength', () {
    test('thirty days is the Legacy grace month', () {
      expect(
        GrantSource.fromLength(const Duration(days: 30)),
        GrantSource.legacyGrace,
      );
      // The grant call's own timing moves the ends by seconds.
      expect(
        GrantSource.fromLength(const Duration(days: 30, seconds: 3)),
        GrantSource.legacyGrace,
      );
      expect(
        GrantSource.fromLength(const Duration(days: 29, hours: 13)),
        GrantSource.legacyGrace,
      );
    });

    test('any other length is a Code', () {
      for (final days in [1, 7, 28, 32, 90, 365]) {
        expect(
          GrantSource.fromLength(Duration(days: days)),
          GrantSource.code,
          reason: '$days days',
        );
      }
    });
  });

  test('a Grant with a date missing counts as a Code', () {
    expect(
      Grant.fromDates(endsAt: DateTime.utc(2026, 10, 31)).source,
      GrantSource.code,
    );
  });

  group('daysLeftAt', () {
    final grace = Grant.fromDates(
      startedAt: DateTime.utc(2026, 10, 1, 10),
      endsAt: DateTime.utc(2026, 10, 31, 10),
    );

    test('counts calendar days to the day it ends', () {
      expect(grace.daysLeftAt(DateTime.utc(2026, 10, 19, 12)), 12);
      expect(grace.daysLeftAt(DateTime.utc(2026, 10, 30, 12)), 1);
    });

    test('is 0 on the last day and never negative', () {
      expect(grace.daysLeftAt(DateTime.utc(2026, 10, 31, 9)), 0);
      expect(grace.daysLeftAt(DateTime.utc(2026, 11, 5)), 0);
    });

    test('is null for a Grant with no end', () {
      expect(
        const Grant(source: GrantSource.code).daysLeftAt(DateTime.utc(2026)),
        isNull,
      );
    });
  });
}
