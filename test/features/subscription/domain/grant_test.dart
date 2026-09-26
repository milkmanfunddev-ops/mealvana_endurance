/// A Grant's source, from the server's record (mp-615) or else its length,
/// and its days left (mp-558).
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

  group('GrantSource.fromServer', () {
    test('maps each pro_grants source', () {
      expect(GrantSource.fromServer('grace'), GrantSource.legacyGrace);
      expect(GrantSource.fromServer('code'), GrantSource.code);
      expect(GrantSource.fromServer('coach'), GrantSource.coach);
    });

    test('an unknown or missing name is no source', () {
      expect(GrantSource.fromServer('partner'), isNull);
      expect(GrantSource.fromServer(null), isNull);
    });
  });

  group('GrantRecord', () {
    GrantRecord rec(GrantSource? source, DateTime at, int days) =>
        GrantRecord(source: source, grantedAt: at, proDays: days);

    final graceEnd = DateTime.utc(2026, 10, 31, 10);

    test('fromRow reads a PostgREST row; a broken row is null', () {
      final r = GrantRecord.fromRow({
        'source': 'coach',
        'pro_days': 30,
        'granted_at': '2026-10-01T10:00:02.5+00:00',
      })!;
      expect(r.source, GrantSource.coach);
      expect(r.grantedAt, DateTime.utc(2026, 10, 1, 10, 0, 2, 500));
      expect(r.endsAt, DateTime.utc(2026, 10, 31, 10, 0, 2, 500));
      expect(
        GrantRecord.fromRow({'source': 'code', 'granted_at': 'x'}),
        isNull,
      );
    });

    test("sourceFor picks the row whose end is the running Grant's", () {
      final records = [
        rec(GrantSource.code, DateTime.utc(2026, 6, 1), 365),
        rec(GrantSource.coach, DateTime.utc(2026, 10, 1, 10, 0, 3), 30),
      ];
      expect(GrantRecord.sourceFor(records, graceEnd), GrantSource.coach);
    });

    test('sourceFor: rows ending elsewhere say nothing', () {
      final records = [rec(GrantSource.coach, DateTime.utc(2026, 5, 1), 30)];
      expect(GrantRecord.sourceFor(records, graceEnd), isNull);
      expect(GrantRecord.sourceFor(const [], graceEnd), isNull);
    });

    test('sourceFor: the newest matching row wins; unknown sources skip', () {
      final records = [
        rec(GrantSource.legacyGrace, DateTime.utc(2026, 10, 1, 9), 30),
        rec(null, DateTime.utc(2026, 10, 1, 11), 30),
        rec(GrantSource.coach, DateTime.utc(2026, 10, 1, 10), 30),
      ];
      expect(GrantRecord.sourceFor(records, graceEnd), GrantSource.coach);
    });

    test('sourceFor with no end to match: the newest row', () {
      final records = [
        rec(GrantSource.legacyGrace, DateTime.utc(2026, 10, 1), 30),
        rec(GrantSource.code, DateTime.utc(2026, 10, 3), 365),
      ];
      expect(GrantRecord.sourceFor(records, null), GrantSource.code);
    });
  });

  test('withSource replaces the guess; no record keeps it', () {
    final guessed = Grant.fromDates(
      startedAt: DateTime.utc(2026, 10, 1, 10),
      endsAt: DateTime.utc(2026, 10, 31, 10),
    );
    expect(guessed.source, GrantSource.legacyGrace);
    expect(guessed.withSource(GrantSource.coach).source, GrantSource.coach);
    expect(guessed.withSource(GrantSource.coach).endsAt, guessed.endsAt);
    expect(guessed.withSource(null), guessed);
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
