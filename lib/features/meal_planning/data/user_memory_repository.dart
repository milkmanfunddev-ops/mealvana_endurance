import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/memory_kind.dart';
import '../domain/user_memory.dart';
import '../domain/vana_setting.dart';

part 'user_memory_repository.g.dart';

@riverpod
UserMemoryRepository userMemoryRepository(Ref ref) {
  final deps = ref.watch(appExternalDepsProvider);
  return UserMemoryRepository(
    database: ref.watch(appDatabaseProvider),
    logger: deps.logger,
    remote: SupabaseUserMemoryRemote(deps.supabaseClient),
  );
}

/// Remote half of [UserMemoryRepository] (interface for tests).
abstract class UserMemoryRemote {
  /// Non-deleted rows for [userId], every column but `embedding`.
  Future<List<Map<String, dynamic>>> fetchMemories(String userId);

  /// `upsert(rows, onConflict: 'id')`.
  Future<void> upsertMemories(List<Map<String, dynamic>> rows);

  /// The id of the live `kind = 'setting'` row for [key], if the server has
  /// one — used so a replayed setting reuses that row instead of tripping
  /// the partial unique index `user_memories_setting_key`.
  Future<String?> findSettingId(String userId, String key);
}

class SupabaseUserMemoryRemote implements UserMemoryRemote {
  const SupabaseUserMemoryRemote(this._supabase);

  final SupabaseClient _supabase;

  static const _columns =
      'id, user_id, kind, key, fact, value, confidence, source, created_at, '
      'last_confirmed_at, expires_at, is_deleted';

  @override
  Future<List<Map<String, dynamic>>> fetchMemories(String userId) async {
    final rows = await _supabase
        .from('user_memories')
        .select(_columns)
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('last_confirmed_at', ascending: false);
    return [
      for (final row in rows as List<dynamic>)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  @override
  Future<void> upsertMemories(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    // CRITICAL: onConflict 'id' only — (user_id, key) is a partial index.
    await _supabase.from('user_memories').upsert(rows, onConflict: 'id');
  }

  @override
  Future<String?> findSettingId(String userId, String key) async {
    final row = await _supabase
        .from('user_memories')
        .select('id')
        .eq('user_id', userId)
        .eq('kind', MemoryKind.setting.wire)
        .eq('key', key)
        .eq('is_deleted', false)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }
}

/// Repository for `user_memories` — "What Vana knows" plus the two boolean
/// settings (`batch_cooking`, `show_macros`) stored as `kind = 'setting'`
/// rows.
///
/// Local-first: [setSetting] and [deleteMemory] write Drift with
/// `needs_upload` and are replayed by [uploadDirtyRecords] as an upsert
/// `onConflict: 'id'`. Facts are written server-side by the model
/// (`rememberFact`) and arrive through [syncFromRemote] or, mid-chat, via
/// [applyServerMemory] from a `memory_saved` part. Embeddings never leave
/// the server.
class UserMemoryRepository with SyncableRepository {
  UserMemoryRepository({
    required AppDatabase database,
    required AppLogger logger,
    required UserMemoryRemote remote,
  }) : _database = database,
       _logger = logger,
       _remote = remote;

  final AppDatabase _database;
  final AppLogger _logger;
  final UserMemoryRemote _remote;

  static const _context = 'USER_MEMORY_REPOSITORY';
  static const _uuid = Uuid();

  Future<SyncResult>? _inflightSync;

  // ========================================================================
  // SyncableRepository
  // ========================================================================

  @override
  String get repositoryKey => 'user_memories';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    final inflight = _inflightSync;
    if (inflight != null) return inflight;
    final future = _syncFromRemoteImpl(userId);
    _inflightSync = future;
    try {
      return await future;
    } finally {
      _inflightSync = null;
    }
  }

  Future<SyncResult> _syncFromRemoteImpl(String userId) async {
    try {
      final rows = await _remote.fetchMemories(userId);
      final count = await _database.transaction(() async {
        final dirty =
            await (_database.select(_database.userMemoriesTable)..where(
                  (t) => t.userId.equals(userId) & t.needsUpload.equals(true),
                ))
                .get();
        final dirtyIds = dirty.map((r) => r.id).toSet();
        final remoteIds = <String>{};
        var upserted = 0;
        for (final row in rows) {
          final companion = _companionFromRow(row);
          if (companion == null) continue;
          remoteIds.add(companion.id.value);
          if (dirtyIds.contains(companion.id.value)) continue;
          await _database
              .into(_database.userMemoriesTable)
              .insert(companion, mode: InsertMode.insertOrReplace);
          upserted++;
        }
        // Rows the server no longer lists were deleted elsewhere.
        await (_database.delete(_database.userMemoriesTable)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.id.isIn(remoteIds).not() &
                  t.needsUpload.equals(true).not(),
            ))
            .go();
        return upserted;
      });
      await setLastSyncTime(DateTime.now());
      _logger.info(
        'Synced user memories',
        context: _context,
        data: {'userId': userId, 'count': count},
      );
      return SyncResult.successful(count);
    } catch (e, st) {
      _logger.error(
        'Failed to sync user memories',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      final dirty =
          await (_database.select(_database.userMemoriesTable)..where(
                (t) => t.userId.equals(userId) & t.needsUpload.equals(true),
              ))
              .get();
      if (dirty.isEmpty) return UploadResult.nothingToUpload();

      final payload = <Map<String, dynamic>>[];
      final idRemap = <String, String>{}; // local id → server id
      for (final row in dirty) {
        var id = row.id;
        // A live setting written offline may already exist server-side under
        // another id (set from another device / the chat). Reuse that row so
        // the upsert does not collide with the partial unique index.
        if (row.kind == MemoryKind.setting.wire &&
            row.key != null &&
            !row.isDeleted) {
          final serverId = await _remote.findSettingId(userId, row.key!);
          if (serverId != null && serverId != row.id) {
            idRemap[row.id] = serverId;
            id = serverId;
          }
        }
        payload.add(_toSupabaseJson(row, id: id));
      }

      await _remote.upsertMemories(payload);

      await _database.transaction(() async {
        for (final row in dirty) {
          final serverId = idRemap[row.id];
          if (serverId != null) {
            await (_database.delete(
              _database.userMemoriesTable,
            )..where((t) => t.id.equals(row.id))).go();
            await _database
                .into(_database.userMemoriesTable)
                .insert(
                  row
                      .copyWith(id: serverId, needsUpload: const Value(false))
                      .toCompanion(false),
                  mode: InsertMode.insertOrReplace,
                );
          } else {
            await (_database.update(
              _database.userMemoriesTable,
            )..where((t) => t.id.equals(row.id))).write(
              const UserMemoriesTableCompanion(needsUpload: Value(false)),
            );
          }
        }
      });

      _logger.info(
        'Uploaded dirty user memories',
        context: _context,
        data: {'count': payload.length, 'remapped': idRemap.length},
      );
      return UploadResult.successful(payload.length);
    } catch (e, st) {
      _logger.error(
        'Failed to upload dirty user memories',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Queries
  // ========================================================================

  /// Live memories for [userId], most recently confirmed first. Settings
  /// rows are excluded unless [includeSettings].
  Stream<List<UserMemory>> watchMemories(
    String userId, {
    bool includeSettings = false,
  }) {
    final query = _database.select(_database.userMemoriesTable)
      ..where((t) {
        final base = t.userId.equals(userId) & t.isDeleted.equals(false);
        return includeSettings
            ? base
            : base & t.kind.equals(MemoryKind.setting.wire).not();
      })
      ..orderBy([(t) => OrderingTerm.desc(t.lastConfirmedAt)]);
    return query.watch().map(
      (rows) => rows.map(_fromEntry).toList(growable: false),
    );
  }

  /// The boolean value of [setting], or null when never set (the server
  /// defaults `batch_cooking` to true, `show_macros` to true).
  Future<bool?> getSetting(String userId, VanaSetting setting) async {
    final row = await _liveSetting(userId, setting.wire);
    if (row == null) return null;
    final value = _decodeValue(row.value);
    return value is bool ? value : null;
  }

  /// Both settings as a stream (re-emits on change).
  Stream<Map<VanaSetting, bool?>> watchSettings(String userId) {
    final query = _database.select(_database.userMemoriesTable)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.isDeleted.equals(false) &
            t.kind.equals(MemoryKind.setting.wire),
      );
    return query.watch().map((rows) {
      final out = <VanaSetting, bool?>{
        for (final s in VanaSetting.values) s: null,
      };
      for (final row in rows) {
        final setting = VanaSetting.fromWire(row.key);
        if (setting == null) continue;
        final value = _decodeValue(row.value);
        if (value is bool) out[setting] = value;
      }
      return out;
    });
  }

  // ========================================================================
  // Local-first writes
  // ========================================================================

  /// Write a boolean setting locally (one live row per key) and mark it for
  /// upload. Returns the resulting memory.
  Future<UserMemory> setSetting(
    String userId,
    VanaSetting setting,
    bool value,
  ) async {
    final now = DateTime.now();
    final existing = await _liveSetting(userId, setting.wire);
    final id = existing?.id ?? _uuid.v4();
    final companion = UserMemoriesTableCompanion.insert(
      id: Value(id),
      userId: userId,
      kind: MemoryKind.setting.wire,
      key: Value(setting.wire),
      fact: settingFact(setting, value),
      value: Value(jsonEncode(value)),
      confidence: const Value(1),
      source: const Value('settings'),
      createdAt: existing?.createdAt ?? now,
      lastConfirmedAt: now,
      isDeleted: const Value(false),
      needsUpload: const Value(true),
      localUpdatedAt: Value(now),
    );
    await _database
        .into(_database.userMemoriesTable)
        .insert(companion, mode: InsertMode.insertOrReplace);
    _logger.info(
      'Set Vana setting',
      context: _context,
      data: {'key': setting.wire, 'value': value},
    );
    final row = await (_database.select(
      _database.userMemoriesTable,
    )..where((t) => t.id.equals(id))).getSingle();
    return _fromEntry(row);
  }

  /// Soft-delete a memory locally (tombstone replayed as `is_deleted`).
  Future<void> deleteMemory(String id) async {
    final now = DateTime.now();
    await (_database.update(
      _database.userMemoriesTable,
    )..where((t) => t.id.equals(id))).write(
      UserMemoriesTableCompanion(
        isDeleted: const Value(true),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );
  }

  /// Write a server-authored memory (a `memory_saved` part or the
  /// `set_setting` action's result) into Drift as clean.
  Future<void> applyServerMemory(
    UserMemory memory, {
    required String userId,
  }) async {
    final now = DateTime.now();
    final existing = await (_database.select(
      _database.userMemoriesTable,
    )..where((t) => t.id.equals(memory.id))).getSingleOrNull();
    await _database.transaction(() async {
      if (memory.kind == MemoryKind.setting && memory.key != null) {
        // One live row per setting key locally too.
        await (_database.delete(_database.userMemoriesTable)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.kind.equals(MemoryKind.setting.wire) &
                  t.key.equals(memory.key!) &
                  t.id.equals(memory.id).not(),
            ))
            .go();
      }
      await _database
          .into(_database.userMemoriesTable)
          .insert(
            UserMemoriesTableCompanion.insert(
              id: Value(memory.id),
              userId: userId,
              kind: memory.kind.wire,
              key: Value(memory.key),
              fact: memory.fact,
              value: Value(
                memory.value == null ? null : jsonEncode(memory.value),
              ),
              confidence: Value(memory.confidence),
              source: Value(
                memory.source ?? existing?.source ?? 'conversation',
              ),
              createdAt: existing?.createdAt ?? now,
              lastConfirmedAt: DateTime.tryParse(memory.lastConfirmedAt) ?? now,
              isDeleted: const Value(false),
              needsUpload: const Value(false),
              localUpdatedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });
  }

  // ========================================================================
  // Mapping
  // ========================================================================

  /// The `fact` text the server writes for a setting (`memory.ts
  /// setSetting`), kept identical so a local-first write reads the same in
  /// "What Vana knows".
  static String settingFact(VanaSetting setting, bool value) =>
      switch (setting) {
        VanaSetting.batchCooking =>
          value
              ? 'Cooks in batches (cook once, eat across the week)'
              : 'Cooks most nights — no batch cooking',
        VanaSetting.showMacros =>
          value
              ? 'Wants macro numbers shown by default'
              : 'Keeps macro numbers behind a tap',
      };

  Future<UserMemoryEntry?> _liveSetting(String userId, String key) =>
      (_database.select(_database.userMemoriesTable)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.kind.equals(MemoryKind.setting.wire) &
                  t.key.equals(key) &
                  t.isDeleted.equals(false),
            )
            ..limit(1))
          .getSingleOrNull();

  static UserMemory _fromEntry(UserMemoryEntry e) => UserMemory(
    id: e.id,
    kind: MemoryKind.fromWire(e.kind) ?? MemoryKind.preference,
    key: e.key,
    fact: e.fact,
    value: _decodeValue(e.value),
    confidence: e.confidence,
    lastConfirmedAt: e.lastConfirmedAt.toUtc().toIso8601String(),
    source: e.source,
  );

  static Map<String, dynamic> _toSupabaseJson(
    UserMemoryEntry e, {
    required String id,
  }) => {
    'id': id,
    'user_id': e.userId,
    'kind': e.kind,
    'key': e.key,
    'fact': e.fact,
    'value': _decodeValue(e.value),
    'confidence': e.confidence,
    'source': e.source,
    'created_at': e.createdAt.toUtc().toIso8601String(),
    'last_confirmed_at': e.lastConfirmedAt.toUtc().toIso8601String(),
    'expires_at': e.expiresAt?.toUtc().toIso8601String(),
    'is_deleted': e.isDeleted,
  };

  static UserMemoriesTableCompanion? _companionFromRow(
    Map<String, dynamic> row,
  ) {
    final id = row['id']?.toString();
    final userId = row['user_id']?.toString();
    final kind = row['kind']?.toString();
    if (id == null || userId == null || kind == null) return null;
    final now = DateTime.now();
    return UserMemoriesTableCompanion.insert(
      id: Value(id),
      userId: userId,
      kind: kind,
      key: Value(row['key'] as String?),
      fact: row['fact']?.toString() ?? '',
      value: Value(row['value'] == null ? null : jsonEncode(row['value'])),
      confidence: Value((row['confidence'] as num?)?.toDouble() ?? 0.8),
      source: Value(row['source']?.toString() ?? 'conversation'),
      createdAt: _parseTs(row['created_at']) ?? now,
      lastConfirmedAt: _parseTs(row['last_confirmed_at']) ?? now,
      expiresAt: Value(_parseTs(row['expires_at'])),
      isDeleted: Value(row['is_deleted'] == true),
      needsUpload: const Value(false),
      localUpdatedAt: Value(now),
    );
  }

  static Object? _decodeValue(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  static DateTime? _parseTs(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
