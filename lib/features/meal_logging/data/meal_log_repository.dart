import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/meal_log.dart';

part 'meal_log_repository.g.dart';

@riverpod
MealLogRepository mealLogRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return MealLogRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for meal log entries (`meal_logs` table).
///
/// Storage strategy:
/// - **Local-first writes**: every insert/update writes to Drift immediately,
///   sets `needs_upload = true`, and schedules a non-blocking remote upsert.
/// - **Soft delete**: `softDelete` sets `is_deleted = true` and re-dirties the
///   row so the tombstone propagates across devices via upsert-only sync.
/// - **Remote hydration**: [hydrateFromRemote] preserves locally-dirty rows
///   (dirty-preserve strategy) to avoid clobbering un-synced edits.
/// - **Upload**: [uploadDirtyRecords] upserts via `onConflict: 'id'` (primary
///   key — never column-based `onConflict` due to the PostgREST partial-index
///   gotcha documented in MEMORY.md).
///
/// **DateTime ↔ Supabase.** Drift stores [DateTime] columns as Unix timestamps
/// locally. [toSupabaseJson] converts to UTC ISO-8601 strings.
/// The `log_date` column is a TEXT `'yyyy-MM-dd'` in Drift (no conversion
/// needed) and a DATE in Supabase (Postgres accepts `'yyyy-MM-dd'` strings).
class MealLogRepository with SyncableRepository {
  MealLogRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SentryReporter sentry,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger,
       _sentry = sentry;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SentryReporter _sentry;

  static const _uuid = Uuid();

  /// Coalesces concurrent [syncFromRemote] callers into one round-trip.
  Future<SyncResult>? _inflightSync;

  // ========================================================================
  // SyncableRepository
  // ========================================================================

  @override
  String get repositoryKey => 'meal_logs';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    final inflight = _inflightSync;
    if (inflight != null) {
      _logger.debug(
        'syncFromRemote: coalescing into in-flight sync',
        context: 'MEAL_LOG_REPOSITORY',
        data: {'userId': userId},
      );
      return inflight;
    }
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
      _logger.info(
        'Syncing meal logs from Supabase',
        context: 'MEAL_LOG_REPOSITORY',
        data: {'userId': userId},
      );

      // Fetch ALL rows (including tombstones) so deletes propagate.
      final response = await _supabase
          .from('meal_logs')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final remoteRows = response as List<dynamic>;
      final syncedCount = await _upsertRemotePreservingDirty(remoteRows);

      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Successfully synced meal logs from Supabase',
        context: 'MEAL_LOG_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync meal logs from Supabase',
        context: 'MEAL_LOG_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty meal logs to Supabase',
        context: 'MEAL_LOG_REPOSITORY',
        data: {'userId': userId},
      );

      final dirtyEntries =
          await (_database.select(_database.mealLogsTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      if (dirtyEntries.isEmpty) return UploadResult.nothingToUpload();

      final logs = _decodeEntries(dirtyEntries);

      // A dirty row may be new to the server or an edit of a row it holds;
      // [_sendChanged] keeps the server's created time either way.
      await _sendChanged(logs);

      await _database.batch((batch) {
        for (final log in logs) {
          batch.update(
            _database.mealLogsTable,
            const MealLogsTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(log.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty meal logs',
        context: 'MEAL_LOG_REPOSITORY',
        data: {'count': logs.length},
      );

      return UploadResult.successful(logs.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty meal logs',
        context: 'MEAL_LOG_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // Query Methods
  // ========================================================================

  /// Returns the count of non-deleted meal logs for [userId] with a
  /// [createdAt] on or after [since].
  ///
  /// Used by [aiCoachHasBaselineProvider] to decide whether to show the
  /// baseline-logging tutorial copy on the Mealvana AI coach banner.
  Future<int> countLogsSince(String userId, DateTime since) async {
    final result =
        await (_database.select(_database.mealLogsTable)..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.isDeleted.equals(false) &
                  t.createdAt.isBiggerOrEqualValue(since),
            ))
            .get();
    return result.length;
  }

  /// Watch the distinct `log_date` values carrying at least one non-deleted
  /// meal log for [userId] in the inclusive range [startDate]..[endDate]
  /// (both `'yyyy-MM-dd'`; ISO dates compare lexicographically).
  ///
  /// The per-day fueling-log rollup of the home-shell calendar sheet's tint
  /// channel (calendar-sheet.md Q2, binary v1): presence only — ANY meal-log
  /// row counts as the athlete's, whatever its [MealLog.source]. Day
  /// boundary is `log_date` itself, the app's existing daily-macros day
  /// definition (a local calendar date, never a timestamp range).
  Stream<Set<String>> watchLogDatesInRange(
    String userId,
    String startDate,
    String endDate,
  ) {
    final query = _database.selectOnly(_database.mealLogsTable, distinct: true)
      ..addColumns([_database.mealLogsTable.logDate])
      ..where(
        _database.mealLogsTable.userId.equals(userId) &
            _database.mealLogsTable.isDeleted.equals(false) &
            _database.mealLogsTable.logDate.isBetweenValues(startDate, endDate),
      );

    return query.watch().map(
      (rows) => rows
          .map((r) => r.read(_database.mealLogsTable.logDate))
          .whereType<String>()
          .toSet(),
    );
  }

  /// Watch non-deleted logs for a calendar day, ordered by [eatenAt] then
  /// [createdAt] (most-recent first within a slot).
  ///
  /// [logDate] must be formatted as `'yyyy-MM-dd'`.
  Stream<List<MealLog>> watchLogsForDate(String userId, String logDate) {
    final query = _database.select(_database.mealLogsTable)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.logDate.equals(logDate) &
            t.isDeleted.equals(false),
      )
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.eatenAt,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);

    return query.watch().map(
      (entries) =>
          entries.map(MealLog.fromDriftEntry).whereType<MealLog>().toList(),
    );
  }

  /// Most recent non-deleted logs for [userId], newest first, up to [limit]
  /// rows. Deduplicated by lowercase name so the "Recent" section shows unique
  /// meal types rather than duplicating the same meal logged many times.
  ///
  /// Deduplication is performed in Dart (not SQL) for portability.
  Future<List<MealLog>> getRecentLogs(String userId, {int limit = 25}) async =>
      _dedupeRecent(await _recentQuery(userId, limit).get(), limit);

  /// [getRecentLogs] as a Drift stream: re-emits on every local write to
  /// `meal_logs`, so a meal just logged moves to the top at once
  /// (testing-wave 26-005).
  Stream<List<MealLog>> watchRecentLogs(String userId, {int limit = 25}) =>
      _recentQuery(
        userId,
        limit,
      ).watch().map((entries) => _dedupeRecent(entries, limit));

  SimpleSelectStatement<$MealLogsTableTable, MealLogEntry> _recentQuery(
    String userId,
    int limit,
  ) => _database.select(_database.mealLogsTable)
    ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ..limit(limit * 3); // over-fetch to survive deduplication

  List<MealLog> _dedupeRecent(List<MealLogEntry> entries, int limit) {
    final seen = <String>{};
    final result = <MealLog>[];

    for (final entry in entries) {
      final log = MealLog.fromDriftEntry(entry);
      if (log == null) continue;
      final key = log.name.toLowerCase().trim();
      if (seen.add(key)) {
        result.add(log);
        if (result.length >= limit) break;
      }
    }

    return result;
  }

  // ========================================================================
  // Mutation Methods
  // ========================================================================

  /// Insert a new meal log entry (offline-first).
  ///
  /// Assigns a UUID if [log.id] is empty, stamps dirty-tracking columns,
  /// writes to Drift, and schedules a non-blocking remote upsert.
  Future<MealLog> insertLog(MealLog log) async {
    final now = DateTime.now();
    final toSave = log.copyWith(
      id: log.id.isEmpty ? _uuid.v4() : log.id,
      createdAt: log.createdAt,
      updatedAt: now,
      isDeleted: false,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await _database
        .into(_database.mealLogsTable)
        .insert(toSave.toDriftCompanion(), mode: InsertMode.insertOrReplace);

    _logger.info(
      'Inserted meal log',
      context: 'MEAL_LOG_REPOSITORY',
      data: {
        'logId': toSave.id,
        'slot': toSave.slot?.wireValue,
        'source': toSave.source.wireValue,
      },
    );

    _scheduleImmediateUpload(toSave, label: 'insert', isNew: true);
    return toSave;
  }

  /// Bulk-insert meal logs in a single Drift batch (offline-first) — the
  /// multi-log primitive.
  ///
  /// Assigns a UUID to any empty [MealLog.id], stamps dirty-tracking columns,
  /// writes every row in one transaction, then schedules ONE non-blocking bulk
  /// remote upsert (not N per-row uploads). Per-row semantics match
  /// [insertLog]. Returns the persisted logs (with generated ids/timestamps).
  Future<List<MealLog>> insertLogs(List<MealLog> logs) async {
    if (logs.isEmpty) return const <MealLog>[];
    final now = DateTime.now();
    final toSave = logs
        .map(
          (log) => log.copyWith(
            id: log.id.isEmpty ? _uuid.v4() : log.id,
            createdAt: log.createdAt,
            updatedAt: now,
            isDeleted: false,
            needsUpload: true,
            localUpdatedAt: now,
          ),
        )
        .toList(growable: false);

    await _database.batch((batch) {
      batch.insertAll(
        _database.mealLogsTable,
        toSave.map((l) => l.toDriftCompanion()).toList(growable: false),
        mode: InsertMode.insertOrReplace,
      );
    });

    _logger.info(
      'Bulk-inserted meal logs',
      context: 'MEAL_LOG_REPOSITORY',
      data: {'count': toSave.length},
    );

    _scheduleImmediateBulkUpload(toSave);
    return toSave;
  }

  /// Overwrite an existing log entry (full replace), re-dirtying for sync.
  Future<MealLog> updateLog(MealLog log) async {
    final now = DateTime.now();
    final toSave = log.copyWith(
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await (_database.update(
      _database.mealLogsTable,
    )..where((t) => t.id.equals(toSave.id))).write(toSave.toDriftCompanion());

    _logger.info(
      'Updated meal log',
      context: 'MEAL_LOG_REPOSITORY',
      data: {'logId': toSave.id},
    );

    _scheduleImmediateUpload(toSave, label: 'update');
    return toSave;
  }

  /// Restore a previously soft-deleted log entry.
  ///
  /// Clears [isDeleted], re-dirties for sync, and schedules an immediate upload
  /// so the un-delete propagates across devices.  No-op if no row exists.
  Future<void> restoreLog({required String id, required String userId}) async {
    final row =
        await (_database.select(_database.mealLogsTable)
              ..where((t) => t.id.equals(id) & t.userId.equals(userId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return;

    final log = MealLog.fromDriftEntry(row);
    if (log == null) return;

    final now = DateTime.now();
    await (_database.update(
      _database.mealLogsTable,
    )..where((t) => t.id.equals(id))).write(
      MealLogsTableCompanion(
        isDeleted: const Value(false),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.info(
      'Restored meal log',
      context: 'MEAL_LOG_REPOSITORY',
      data: {'logId': id},
    );

    final restored = log.copyWith(
      isDeleted: false,
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );
    _scheduleImmediateUpload(restored, label: 'restore');
  }

  /// Soft-delete a log entry by id. No-op if no active row exists.
  Future<void> softDeleteLog({
    required String id,
    required String userId,
  }) async {
    final row =
        await (_database.select(_database.mealLogsTable)
              ..where((t) => t.id.equals(id) & t.isDeleted.equals(false))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return;

    final log = MealLog.fromDriftEntry(row);
    if (log == null) return;

    final now = DateTime.now();
    await (_database.update(
      _database.mealLogsTable,
    )..where((t) => t.id.equals(id))).write(
      MealLogsTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.info(
      'Soft-deleted meal log',
      context: 'MEAL_LOG_REPOSITORY',
      data: {'logId': id},
    );

    final tombstone = log.copyWith(
      isDeleted: true,
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );
    _scheduleImmediateUpload(tombstone, label: 'delete');
  }

  // ========================================================================
  // Remote Hydration
  // ========================================================================

  /// Apply a batch of remote rows to Drift, skipping any local row flagged
  /// `needs_upload = true` (dirty-preserve). Tombstones are applied like any
  /// other row; read paths filter them out.
  ///
  /// [since] is reserved for future incremental-sync support; currently all
  /// rows for the user are fetched in [syncFromRemote].
  @visibleForTesting
  Future<int> hydrateFromRemote(String userId, {DateTime? since}) async {
    final response = await _supabase
        .from('meal_logs')
        .select('*')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    final remoteRows = response as List<dynamic>;
    return _upsertRemotePreservingDirty(remoteRows);
  }

  /// The write half of [syncFromRemote] on its own: server-shaped rows in,
  /// Drift rows out, dirty local rows kept. Lets a seam test feed the rows
  /// a `meal_logs` SELECT answers with, without a Supabase client.
  @visibleForTesting
  Future<int> applyRemoteRows(List<dynamic> remoteRows) =>
      _upsertRemotePreservingDirty(remoteRows);

  // ========================================================================
  // Private Helpers
  // ========================================================================

  Future<int> _upsertRemotePreservingDirty(List<dynamic> remoteRows) async {
    final remoteById = <String, Map<String, dynamic>>{};
    for (final item in remoteRows) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) return 0;

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows = await (_database.select(
      _database.mealLogsTable,
    )..where((t) => t.id.isIn(remoteIds) & t.needsUpload.equals(true))).get();
    final dirtyIds = dirtyRows.map((r) => r.id).toSet();

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote meal log overwrite for dirty local rows',
        context: 'MEAL_LOG_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue;

        final log = MealLog.fromSupabaseJson(entry.value);
        if (log == null) continue;

        batch.insert(
          _database.mealLogsTable,
          log
              .copyWith(needsUpload: false, localUpdatedAt: DateTime.now())
              .toDriftCompanion(),
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    return upsertedCount;
  }

  void _scheduleImmediateUpload(
    MealLog log, {
    required String label,
    bool isNew = false,
  }) {
    unawaited(() async {
      try {
        // A new row carries a fresh id, so the plain upsert is an insert and
        // sends the phone's created time; an update, delete or restore may
        // land on a row the server holds and must keep the server's.
        if (isNew) {
          await sendUpsert([log.toSupabaseJson()]);
        } else {
          await _sendChanged([log]);
        }
        await _clearDirtyFlag(log.id);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate $label upload failed; log stays dirty for retry',
          context: 'MEAL_LOG_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'logId': log.id},
        );
        unawaited(
          _sentry.reportNetworkError(
            e,
            url: 'supabase:meal_logs:$label',
            method: 'UPSERT',
            stackTrace: stackTrace,
          ),
        );
      }
    }());
  }

  /// Fire-and-forget bulk upsert for [insertLogs] — one round-trip for the
  /// whole batch instead of N per-row uploads. Rows stay dirty on failure so
  /// the normal sync path retries them.
  void _scheduleImmediateBulkUpload(List<MealLog> logs) {
    if (logs.isEmpty) return;
    unawaited(() async {
      try {
        await sendUpsert(
          logs.map((l) => l.toSupabaseJson()).toList(growable: false),
        );
        await _clearDirtyFlags(logs.map((l) => l.id).toList(growable: false));
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate bulk insert upload failed; logs stay dirty for retry',
          context: 'MEAL_LOG_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'count': logs.length},
        );
        unawaited(
          _sentry.reportNetworkError(
            e,
            url: 'supabase:meal_logs:insert-bulk',
            method: 'UPSERT',
            stackTrace: stackTrace,
          ),
        );
      }
    }());
  }

  /// Upload [logs] that may already exist on the server without touching
  /// their server `created_at` (testing-wave 27-002).
  ///
  /// Two round trips: first an insert-if-missing with the full row, so a row
  /// the server never saw (logged offline, then edited) is created with the
  /// phone's created time; then the overwrite, which carries no `created_at`,
  /// so a row the server holds keeps the value it first wrote. The local copy
  /// holds whole seconds, so sending it back would cut the server's fraction.
  Future<void> _sendChanged(List<MealLog> logs) async {
    if (logs.isEmpty) return;
    await sendUpsert(
      logs.map((l) => l.toSupabaseJson()).toList(growable: false),
      ignoreDuplicates: true,
    );
    await sendUpsert(
      logs.map((l) => l.toSupabaseUpdateJson()).toList(growable: false),
    );
  }

  /// The one place a `meal_logs` upsert crosses the wire.
  ///
  /// CRITICAL: always `onConflict: 'id'` (primary key). Never a column-based
  /// `onConflict` — see the PostgREST partial-index gotcha in MEMORY.md.
  /// [ignoreDuplicates] makes it an insert-if-missing (`ON CONFLICT DO
  /// NOTHING`): rows the server already holds are left untouched.
  ///
  /// Overridable so a test can read the payload without a Supabase client.
  @protected
  @visibleForTesting
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    await _supabase
        .from('meal_logs')
        .upsert(rows, onConflict: 'id', ignoreDuplicates: ignoreDuplicates);
  }

  Future<void> _clearDirtyFlag(String logId) async {
    await (_database.update(_database.mealLogsTable)
          ..where((t) => t.id.equals(logId)))
        .write(const MealLogsTableCompanion(needsUpload: Value(false)));
  }

  Future<void> _clearDirtyFlags(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_database.update(_database.mealLogsTable)
          ..where((t) => t.id.isIn(ids)))
        .write(const MealLogsTableCompanion(needsUpload: Value(false)));
  }

  /// Decode Drift rows, skipping (and logging) any with unknown slot/source
  /// wire values.
  List<MealLog> _decodeEntries(Iterable<MealLogEntry> entries) {
    final result = <MealLog>[];
    for (final entry in entries) {
      final log = MealLog.fromDriftEntry(entry);
      if (log == null) {
        _logger.warning(
          'Skipping meal log with unknown slot or source',
          context: 'MEAL_LOG_REPOSITORY',
          data: {
            'log_id': entry.id,
            'slot': entry.slot,
            'source': entry.source,
          },
        );
        continue;
      }
      result.add(log);
    }
    return result;
  }
}
