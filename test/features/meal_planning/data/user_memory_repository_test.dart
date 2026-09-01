/// UserMemoryRepository: settings + facts, local-first, upsert replay.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/memory_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_setting.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

const _user = 'user-1';
final _now = DateTime.utc(2026, 9, 1, 12);

Map<String, dynamic> _row({
  required String id,
  String kind = 'preference',
  String? key,
  String fact = 'Likes oats',
  Object? value,
}) => {
  'id': id,
  'user_id': _user,
  'kind': kind,
  'key': key,
  'fact': fact,
  'value': value,
  'confidence': 0.9,
  'source': 'conversation',
  'created_at': _now.toIso8601String(),
  'last_confirmed_at': _now.toIso8601String(),
  'expires_at': null,
  'is_deleted': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingUserMemoryRemote remote;
  late UserMemoryRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    remote = RecordingUserMemoryRemote();
    repo = UserMemoryRepository(
      database: db,
      logger: FakeLogger(),
      remote: remote,
    );
  });

  tearDown(() => db.close());

  test('getSetting is null until set; setSetting is local-first', () async {
    expect(await repo.getSetting(_user, VanaSetting.batchCooking), isNull);

    final memory = await repo.setSetting(
      _user,
      VanaSetting.batchCooking,
      false,
    );
    expect(memory.kind, MemoryKind.setting);
    expect(memory.key, 'batch_cooking');
    expect(memory.value, isFalse);
    expect(
      memory.fact,
      UserMemoryRepository.settingFact(VanaSetting.batchCooking, false),
    );
    expect(await repo.getSetting(_user, VanaSetting.batchCooking), isFalse);

    // Setting it again reuses the same row (one live row per key).
    await repo.setSetting(_user, VanaSetting.batchCooking, true);
    final rows = await db.select(db.userMemoriesTable).get();
    expect(rows, hasLength(1));
    expect(rows.single.needsUpload, isTrue);
    expect(await repo.getSetting(_user, VanaSetting.batchCooking), isTrue);
  });

  test(
    'uploadDirtyRecords upserts the row (onConflict id semantics) and clears the flag',
    () async {
      await repo.setSetting(_user, VanaSetting.showMacros, true);

      final result = await repo.uploadDirtyRecords(_user);
      expect(result.success, isTrue, reason: result.error);
      expect(result.count, 1);
      final payload = remote.upserts.single.single;
      expect(payload['kind'], 'setting');
      expect(payload['key'], 'show_macros');
      expect(payload['value'], isTrue);
      expect(payload['is_deleted'], isFalse);
      final rows = await db.select(db.userMemoriesTable).get();
      expect(rows.single.needsUpload, isFalse);
    },
  );

  test(
    'a setting already on the server under another id is remapped, not duplicated',
    () async {
      remote.settingIds['batch_cooking'] = 'server-id';
      await repo.setSetting(_user, VanaSetting.batchCooking, false);

      final result = await repo.uploadDirtyRecords(_user);
      expect(result.success, isTrue);
      expect(remote.upserts.single.single['id'], 'server-id');
      final rows = await db.select(db.userMemoriesTable).get();
      expect(rows.single.id, 'server-id');
      expect(rows.single.needsUpload, isFalse);
    },
  );

  test('deleteMemory tombstones locally and replays is_deleted', () async {
    remote.memories = [_row(id: 'mem-1')];
    await repo.syncFromRemote(_user);
    expect((await repo.watchMemories(_user).first).map((m) => m.id), ['mem-1']);

    await repo.deleteMemory('mem-1');
    expect(await repo.watchMemories(_user).first, isEmpty);

    await repo.uploadDirtyRecords(_user);
    expect(remote.upserts.single.single['is_deleted'], isTrue);
  });

  test(
    'syncFromRemote merges with dirty-preserve and prunes deleted rows',
    () async {
      remote.memories = [
        _row(id: 'mem-1'),
        _row(id: 'mem-2', fact: 'Runs at 6am'),
      ];
      await repo.syncFromRemote(_user);
      await repo.deleteMemory('mem-2'); // dirty tombstone

      remote.memories = [_row(id: 'mem-2', fact: 'Runs at 6am')]; // mem-1 gone
      final result = await repo.syncFromRemote(_user);
      expect(result.success, isTrue);

      final rows = await db.select(db.userMemoriesTable).get();
      expect(rows.map((r) => r.id), ['mem-2']);
      expect(
        rows.single.isDeleted,
        isTrue,
        reason: 'dirty tombstone preserved',
      );
    },
  );

  test('applyServerMemory stores a memory_saved part as clean', () async {
    const memory = UserMemory(
      id: 'mem-9',
      kind: MemoryKind.constraint,
      fact: 'No shellfish',
      confidence: 1,
      lastConfirmedAt: '2026-09-01T12:00:00.000Z',
    );
    await repo.applyServerMemory(memory, userId: _user);
    final rows = await db.select(db.userMemoriesTable).get();
    expect(rows.single.fact, 'No shellfish');
    expect(rows.single.needsUpload, isFalse);
  });

  test('watchSettings reports both keys with null for unset', () async {
    await repo.setSetting(_user, VanaSetting.showMacros, true);
    final settings = await repo.watchSettings(_user).first;
    expect(settings[VanaSetting.showMacros], isTrue);
    expect(settings[VanaSetting.batchCooking], isNull);
  });
}
