import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/macro_cache_invalidation.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Proves the payoff of scoped invalidation against a real (in-memory) database:
/// editing an activity drops the days whose inputs moved and LEAVES THE REST OF
/// THE USER'S CACHE INTACT.
///
/// The old behaviour was `DELETE FROM daily_macro_targets WHERE user_id = ?` —
/// every cached day, all history, gone on any single workout edit. Each survivor
/// below is one edge-function round trip the user no longer pays, and one date
/// that still works offline.
void main() {
  _versionGateTests();
  late AppDatabase database;
  late DailyMacroTargetsRepository repository;

  const userId = 'user-1';
  const otherUserId = 'user-2';

  /// Insert a cached macro row for [date] directly, so the test doesn't depend
  /// on the calculation pipeline.
  Future<void> seedCachedDay(String uid, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    await database.customStatement(
      '''INSERT OR REPLACE INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr,
          session_kcal, neat_kcal, tef_kcal, mode, ea, ea_status,
          algorithm_version, needs_upload, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        '$uid-${day.millisecondsSinceEpoch}',
        uid,
        day.millisecondsSinceEpoch,
        300.0,
        150.0,
        70.0,
        2600.0,
        1600.0,
        600.0,
        300.0,
        100.0,
        'performance',
        40.0,
        null,
        'v5.0.0',
        0,
        0,
        0,
      ],
    );
  }

  Future<Set<DateTime>> cachedDaysFor(String uid) async {
    final rows = await database
        .customSelect(
          'SELECT target_date FROM daily_macro_targets WHERE user_id = ?',
          variables: [Variable.withString(uid)],
        )
        .get();
    return rows
        .map(
          (r) =>
              DateTime.fromMillisecondsSinceEpoch(r.read<int>('target_date')),
        )
        .toSet();
  }

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DailyMacroTargetsRepository(
      database: database,
      supabase: MockSupabaseClient(),
    );
  });

  tearDown(() async => database.close());

  test('invalidateDates deletes only the given days', () async {
    final jul13 = DateTime(2026, 7, 13);
    final jul15 = DateTime(2026, 7, 15);
    final jul20 = DateTime(2026, 7, 20);

    for (final d in [jul13, jul15, jul20]) {
      await seedCachedDay(userId, d);
    }

    await repository.invalidateDates(userId, [jul13, jul15]);

    expect(
      await cachedDaysFor(userId),
      equals({jul20}),
      reason: 'only the requested days should be dropped',
    );
  });

  test('an empty set is a no-op — it must not wipe the cache', () async {
    await seedCachedDay(userId, DateTime(2026, 7, 15));

    await repository.invalidateDates(userId, const []);

    expect(await cachedDaysFor(userId), hasLength(1));
  });

  test('it never touches another user\'s cache', () async {
    final jul15 = DateTime(2026, 7, 15);
    await seedCachedDay(userId, jul15);
    await seedCachedDay(otherUserId, jul15);

    await repository.invalidateDates(userId, [jul15]);

    expect(await cachedDaysFor(userId), isEmpty);
    expect(await cachedDaysFor(otherUserId), equals({jul15}));
  });

  test('the time of day on the passed date is irrelevant', () async {
    final jul15 = DateTime(2026, 7, 15);
    await seedCachedDay(userId, jul15);

    // Pass a mid-afternoon timestamp; the row is keyed at midnight.
    await repository.invalidateDates(userId, [DateTime(2026, 7, 15, 16, 20)]);

    expect(await cachedDaysFor(userId), isEmpty);
  });

  test(
    'a large day-set (multi-year import) deletes correctly across chunks',
    () async {
      // NB: this does NOT demonstrate a parameter-limit overflow — the sqlite3 we
      // bundle allows 32766 variables, so 1500 would pass unchunked too. What it
      // pins is that the CHUNKING ITSELF is correct: every requested day is
      // deleted across chunk boundaries, and nothing outside the set is.
      final manyDays = [
        for (var i = 0; i < 1500; i++)
          DateTime(2024, 1, 1).add(Duration(days: i)),
      ];
      for (final d in manyDays) {
        await seedCachedDay(userId, d);
      }
      // One day deliberately outside the set, to prove it isn't a blanket wipe.
      final survivor = DateTime(2029, 5, 5);
      await seedCachedDay(userId, survivor);

      await repository.invalidateDates(userId, manyDays);

      expect(
        await cachedDaysFor(userId),
        equals({survivor}),
        reason: 'all 1500 requested days gone; the untouched day remains',
      );
    },
  );

  test('editing one workout drops only its week — months of cache survive '
      '(previously ALL of this was deleted)', () async {
    // A user with macros cached across three separate months.
    final march = [for (var d = 2; d <= 6; d++) DateTime(2026, 3, d)];
    final june = [for (var d = 8; d <= 12; d++) DateTime(2026, 6, d)];
    // The week of the edit: Mon Jul 13 .. Sun Jul 19.
    final julyWeek = [for (var d = 13; d <= 19; d++) DateTime(2026, 7, d)];
    // A later week that must be untouched.
    final julyNextWeek = [for (var d = 20; d <= 24; d++) DateTime(2026, 7, d)];

    for (final d in [...march, ...june, ...julyWeek, ...julyNextWeek]) {
      await seedCachedDay(userId, d);
    }
    final totalSeeded =
        march.length + june.length + julyWeek.length + julyNextWeek.length;
    expect(await cachedDaysFor(userId), hasLength(totalSeeded));

    // The user deletes a workout on Wednesday 2026-07-15.
    final stale = daysAffectedByActivityOn(DateTime(2026, 7, 15));
    await repository.invalidateDates(userId, stale);

    final survivors = await cachedDaysFor(userId);

    // The edited week is gone...
    for (final d in julyWeek) {
      expect(survivors, isNot(contains(d)), reason: '$d is in the edited week');
    }
    // ...and absolutely everything else survived.
    for (final d in [...march, ...june, ...julyNextWeek]) {
      expect(survivors, contains(d), reason: '$d must NOT have been wiped');
    }
    expect(
      survivors,
      hasLength(march.length + june.length + julyNextWeek.length),
    );
  });
}

// ---------------------------------------------------------------------------
// Algorithm-version gate (Phase C of daily-macros-dashboard@v3, 2026-08-19):
// a cached day is stale only when its engine version is OLDER than this
// build's floor — never when it is newer. An equality gate coupled the engine
// deploy to the app release (deploy v6 first → every v5-pinned install
// discards → recalcs → discards forever, the 2026-08-14 flicker). With the
// floor, a newer engine can ship ahead of the client; raising the floor later
// invalidates the leftover old rows exactly once.
// ---------------------------------------------------------------------------
void _versionGateTests() {
  group('algorithm-version gate — older-than floor, never equality', () {
    test('rows at or above the floor are served; older rows are stale', () {
      expect(
        DailyMacroTargetsRepository.isStaleAlgorithmVersion('v6.0.0'),
        isFalse,
      );
      expect(
        DailyMacroTargetsRepository.isStaleAlgorithmVersion('v6.1.0'),
        isFalse,
        reason: 'newer than the floor is accepted as-is',
      );
      expect(
        DailyMacroTargetsRepository.isStaleAlgorithmVersion('v7.0.0'),
        isFalse,
      );
      expect(
        DailyMacroTargetsRepository.isStaleAlgorithmVersion('v5.0.0'),
        isTrue,
        reason: 'older → recalculated once',
      );
      expect(
        DailyMacroTargetsRepository.isStaleAlgorithmVersion('v5.9.9'),
        isTrue,
      );
      expect(
        DailyMacroTargetsRepository.isStaleAlgorithmVersion('garbage'),
        isTrue,
        reason: 'unparsable → treated as older',
      );
    });
  });
}
