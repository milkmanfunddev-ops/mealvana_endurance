/// `public.daily_macro_targets.created_at` goes out in UTC (develop-2026-10
/// ticket 22, 01-004). The cached row keeps epoch milliseconds that read
/// back as local time; its ISO string used to carry no offset, so Postgres
/// stored the wall clock as UTC (five hours early in CDT).
///
/// Seam: a Drift epoch row written the way the cache writes it, read back
/// through the real [DailyMacroTargetsRepository], and saved through its
/// remote path against an in-memory PostgREST ([FakePostgrest]) that records
/// the upsert.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../../helpers/fakes/fake_postgrest.dart';
import '../../../helpers/fakes/recording_report.dart';

void main() {
  const userId = '8b2c3d4e-5f6a-4b7c-9d8e-0f1a2b3c4d5e';
  final targetDate = DateTime(2026, 10, 7);
  // 2026-10-07 11:11:03.123 UTC, as epoch milliseconds in the row.
  final createdAtUtc = DateTime.utc(2026, 10, 7, 11, 11, 3, 123);

  test('a cached row read back and saved remotely sends created_at and '
      'updated_at as the same instant, ending in Z', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final server = FakePostgrest();
    final repository = DailyMacroTargetsRepository(
      database: database,
      supabase: server.client,
      report: RecordingReport(),
    );

    await database.customStatement(
      '''INSERT INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr,
          session_kcal, mode, algorithm_version, needs_upload, created_at,
          updated_at)
         VALUES (?, ?, ?, 300, 110, 70, 2400, 1400, 400, 'prospective',
                 'v6.1.0', 0, ?, ?)''',
      [
        'row-22',
        userId,
        targetDate.millisecondsSinceEpoch,
        createdAtUtc.millisecondsSinceEpoch,
        createdAtUtc.millisecondsSinceEpoch,
      ],
    );

    final cached = await repository.getCachedForDate(userId, targetDate);
    expect(cached, isNotNull);
    expect(cached!.createdAt.isUtc, isFalse, reason: 'epoch reads back local');

    await repository.saveToRemote(cached);

    final write = server.writes.singleWhere(
      (w) => w.table == 'daily_macro_targets',
    );
    final body =
        ((write.body is List ? (write.body as List).single : write.body) as Map)
            .cast<String, dynamic>();
    for (final key in ['created_at', 'updated_at']) {
      final sent = body[key] as String;
      expect(sent, endsWith('Z'), reason: '$key carries its offset');
      expect(DateTime.parse(sent).isAtSameMomentAs(createdAtUtc), isTrue);
    }
  });

  test('the week save sends UTC too', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final server = FakePostgrest();
    final repository = DailyMacroTargetsRepository(
      database: database,
      supabase: server.client,
      report: RecordingReport(),
    );
    await database.customStatement(
      '''INSERT INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr,
          session_kcal, mode, algorithm_version, needs_upload, created_at,
          updated_at)
         VALUES (?, ?, ?, 300, 110, 70, 2400, 1400, 400, 'prospective',
                 'v6.1.0', 0, ?, ?)''',
      [
        'row-22b',
        userId,
        targetDate.millisecondsSinceEpoch,
        createdAtUtc.millisecondsSinceEpoch,
        createdAtUtc.millisecondsSinceEpoch,
      ],
    );
    final cached = (await repository.getCachedForDate(userId, targetDate))!;

    await repository.saveAllToRemote([cached]);

    final body = server.writes.single.body as List;
    expect((body.single as Map)['created_at'], endsWith('Z'));
  });
}
