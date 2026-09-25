// Ticket 54 (testing-wave; Finding 27-002): editing or deleting a meal log
// keeps the server's created time.
//
// The upsert sent the phone's `created_at`, and the local copy holds whole
// seconds (Drift), so every edit or delete rewrote the server's value
// (20:43:41.451694 became 20:43:41). An upsert that can land on a row the
// server already holds must not carry `created_at`; only an
// insert-if-missing (`ON CONFLICT DO NOTHING`) may, so a row the server never
// saw still gets the phone's created time.
//
// The row is fed as the `meal_logs` SELECT answered on dev in 27-002 and
// applied through the real remote-apply path into a real in-memory Drift;
// only the wire ([MealLogRepository.sendUpsert]) is recorded instead of sent.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _serverCreatedAt = '2026-09-24T20:43:41.451694+00:00';

/// Row 1ce8b3b7 as dev answered it in 27-002, before the edit.
Map<String, dynamic> _serverRow() => {
  'id': '1ce8b3b7-5b0e-4a51-9d0c-7f2f1b0d2a11',
  'user_id': _user,
  'log_date': '2026-09-24',
  'slot': null,
  'name': 'W15-27 edit',
  'source': 'manual',
  'items': const <Map<String, dynamic>>[],
  'calories': 300,
  'carbs_g': 40,
  'protein_g': 10,
  'fat_g': 8,
  'sodium_mg': 0,
  'photo_path': null,
  'recipe_id': null,
  'saved_meal_id': null,
  'plan_meal_id': null,
  'notes': null,
  'eaten_at': '2026-09-24T20:43:00+00:00',
  'created_at': _serverCreatedAt,
  'updated_at': '2026-09-24T20:43:41.452317+00:00',
  'is_deleted': false,
};

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _Upsert {
  _Upsert(this.rows, {required this.ignoreDuplicates});
  final List<Map<String, dynamic>> rows;
  final bool ignoreDuplicates;
}

/// The real repository; the wire records what it would send.
class _RecordingRepository extends MealLogRepository {
  _RecordingRepository({required super.database})
    : super(
        supabase: _MockSupabaseClient(),
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  final sent = <_Upsert>[];

  /// Upserts that overwrite a row the server may already hold.
  Iterable<Map<String, dynamic>> get overwrites =>
      sent.where((u) => !u.ignoreDuplicates).expand((u) => u.rows);

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    sent.add(_Upsert(rows, ignoreDuplicates: ignoreDuplicates));
  }
}

/// The immediate uploads are fire-and-forget; let them run.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late AppDatabase db;
  late _RecordingRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(database: db);
    await repo.applyRemoteRows([_serverRow()]);
  });

  tearDown(() async {
    await _settle();
    await db.close();
  });

  Future<MealLog> localCopy() async => (await repo.getRecentLogs(_user)).single;

  test('the update payload carries no created_at', () {
    final log = MealLog.fromSupabaseJson(_serverRow())!;

    expect(log.toSupabaseJson(), contains('created_at'));
    expect(log.toSupabaseUpdateJson(), isNot(contains('created_at')));
    expect(
      log.toSupabaseUpdateJson(),
      log.toSupabaseJson()..remove('created_at'),
      reason: 'everything else goes up as before',
    );
  });

  test('an edit never overwrites the server\'s created_at', () async {
    final local = await localCopy();
    expect(
      local.createdAt.microsecond,
      0,
      reason:
          'the local copy holds whole seconds; sending it cuts the fraction',
    );

    await repo.updateLog(local.copyWith(name: 'W15-27 edited'));
    await _settle();

    expect(repo.overwrites, isNotEmpty);
    for (final row in repo.overwrites) {
      expect(row, isNot(contains('created_at')));
      expect(row['name'], 'W15-27 edited');
    }
  });

  test('a delete never overwrites the server\'s created_at', () async {
    await repo.softDeleteLog(id: _serverRow()['id'] as String, userId: _user);
    await _settle();

    expect(repo.overwrites, isNotEmpty);
    for (final row in repo.overwrites) {
      expect(row, isNot(contains('created_at')));
      expect(row['is_deleted'], isTrue);
    }
  });

  test('a restore never overwrites the server\'s created_at', () async {
    final id = _serverRow()['id'] as String;
    await repo.softDeleteLog(id: id, userId: _user);
    await _settle();
    repo.sent.clear();

    await repo.restoreLog(id: id, userId: _user);
    await _settle();

    expect(repo.overwrites, isNotEmpty);
    for (final row in repo.overwrites) {
      expect(row, isNot(contains('created_at')));
    }
  });

  test('a retried upload never overwrites the server\'s created_at, and a row '
      'the server never saw is still inserted with the phone\'s', () async {
    final local = await localCopy();
    await repo.updateLog(local.copyWith(name: 'W15-27 edited'));
    await repo.insertLog(
      MealLog(
        id: '',
        userId: _user,
        logDate: '2026-09-24',
        name: 'Logged offline',
        source: MealLogSource.manual,
        components: const [],
        createdAt: DateTime.utc(2026, 9, 24, 21, 5, 7),
        updatedAt: DateTime.utc(2026, 9, 24, 21, 5, 7),
      ),
    );
    await _settle();
    repo.sent.clear();

    // Both rows are still dirty (their immediate uploads were only recorded,
    // never acknowledged, as when the phone was offline) — mark them so.
    await db.customStatement('UPDATE meal_logs SET needs_upload = 1');

    final result = await repo.uploadDirtyRecords(_user);
    expect(result.success, isTrue);

    expect(repo.overwrites, hasLength(2));
    for (final row in repo.overwrites) {
      expect(row, isNot(contains('created_at')));
    }
    final inserted = repo.sent
        .where((u) => u.ignoreDuplicates)
        .expand((u) => u.rows)
        .firstWhere((r) => r['name'] == 'Logged offline');
    expect(inserted['created_at'], '2026-09-24T21:05:07.000Z');
  });

  test('a new log goes up with the phone\'s created_at', () async {
    await repo.insertLog(
      MealLog(
        id: '',
        userId: _user,
        logDate: '2026-09-24',
        name: 'Fresh',
        source: MealLogSource.manual,
        components: const [],
        createdAt: DateTime.utc(2026, 9, 24, 21, 0, 0, 123),
        updatedAt: DateTime.utc(2026, 9, 24, 21, 0, 0, 123),
      ),
    );
    await _settle();

    final rows = repo.sent.expand((u) => u.rows).toList();
    expect(rows.single['created_at'], '2026-09-24T21:00:00.123Z');
  });
}
