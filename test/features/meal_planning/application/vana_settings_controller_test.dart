/// "What Vana knows": the flat Memory list and its delete, through the real
/// notifier — a local tombstone first, with upload tracking, then the server.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_settings_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/container.dart';
import '../helpers/fakes.dart';

const _user = 'user-1';
final _now = DateTime.utc(2026, 9, 1, 12);

Map<String, dynamic> _row({
  required String id,
  String kind = 'preference',
  String? key,
  required String fact,
  Object? value,
  String source = 'conversation',
  DateTime? confirmedAt,
}) => {
  'id': id,
  'user_id': _user,
  'kind': kind,
  'key': key,
  'fact': fact,
  'value': value,
  'confidence': 0.9,
  'source': source,
  'created_at': _now.toIso8601String(),
  'last_confirmed_at': (confirmedAt ?? _now).toIso8601String(),
  'expires_at': null,
  'is_deleted': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingUserMemoryRemote remote;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    remote = RecordingUserMemoryRemote();
  });
  tearDown(() => db.close());

  ProviderContainer container() => testContainer([
    ...baseOverrides(userId: _user),
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWithValue(db),
    userMemoryRepositoryProvider.overrideWithValue(
      UserMemoryRepository(database: db, logger: FakeLogger(), remote: remote),
    ),
  ]);

  test('the list is flat and newest first, with settings in it', () async {
    remote.memories = [
      _row(
        id: 'mem-old',
        fact: 'Hates cilantro',
        confirmedAt: DateTime.utc(2026, 9, 1),
      ),
      _row(
        id: 'mem-new',
        fact: 'Wednesdays are chaos',
        confirmedAt: DateTime.utc(2026, 9, 8),
      ),
      _row(
        id: 'mem-setting',
        kind: 'setting',
        key: 'batch_cooking',
        fact: 'Cooks in batches (cook once, eat across the week)',
        value: true,
        source: 'settings',
        confirmedAt: DateTime.utc(2026, 9, 5),
      ),
      _row(
        id: 'mem-episode',
        kind: 'episode',
        key: 'conv-1',
        fact: 'Planned three dinners.',
        confirmedAt: DateTime.utc(2026, 9, 9),
      ),
    ];
    final c = container();
    await c.read(userMemoryRepositoryProvider).syncFromRemote(_user);
    c.listen(vanaSettingsControllerProvider, (_, __) {});

    final state = await c.read(vanaSettingsControllerProvider.future);
    expect(state.memories.map((m) => m.id), [
      'mem-new',
      'mem-setting',
      'mem-old',
    ]);
  });

  test(
    'delete tombstones locally with upload tracking, then reaches the server',
    () async {
      remote.memories = [_row(id: 'mem-1', fact: 'Hates cilantro')];
      final c = container();
      await c.read(userMemoryRepositoryProvider).syncFromRemote(_user);
      // Hold the subscription — the controller is autoDispose, and a bare read
      // would tear it down between assertions.
      c.listen(vanaSettingsControllerProvider, (_, __) {});
      await c.read(vanaSettingsControllerProvider.future);

      await c
          .read(vanaSettingsControllerProvider.notifier)
          .deleteMemory('mem-1');

      await settle();

      final after = c.read(vanaSettingsControllerProvider);
      expect(
        after.error,
        isNull,
        reason: '${after.error}\n${after.stackTrace}',
      );
      // Gone from the state the screen renders.
      expect(after.value!.memories, isEmpty);

      // And gone locally, as a tombstone flagged for upload — not a hard delete.
      final rows = await db.select(db.userMemoriesTable).get();
      expect(rows.single.id, 'mem-1');
      expect(rows.single.isDeleted, isTrue);

      expect(remote.upserts.single.single['id'], 'mem-1');
      expect(remote.upserts.single.single['is_deleted'], isTrue);
    },
  );

  test('an empty file leaves an empty list, not an error', () async {
    final c = container();
    c.listen(vanaSettingsControllerProvider, (_, __) {});
    final state = await c.read(vanaSettingsControllerProvider.future);
    expect(state.memories, isEmpty);
    expect(c.read(vanaSettingsControllerProvider).hasError, isFalse);
  });
}
