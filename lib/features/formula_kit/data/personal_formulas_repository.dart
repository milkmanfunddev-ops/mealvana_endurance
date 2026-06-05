import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/formula_phase.dart';
import '../domain/personal_formula.dart';

part 'personal_formulas_repository.g.dart';

@riverpod
PersonalFormulasRepository personalFormulasRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return PersonalFormulasRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for Formula Kit personal formulas (user-forked Before/During
/// formulas saved via "Make this mine").
///
/// Storage strategy matches `formula_pins`: local-first writes with
/// `needs_upload`/`local_updated_at` dirty tracking, then a non-blocking
/// upload to Supabase. The remote upsert preserves locally-dirty rows so
/// concurrent edits aren't clobbered.
///
/// **Soft delete.** [deleteFormula] sets `is_deleted = true` rather than
/// removing the row, so deletions propagate across devices via the upsert-only
/// sync handler. All read paths filter `WHERE NOT is_deleted`.
class PersonalFormulasRepository with SyncableRepository {
  PersonalFormulasRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required SentryReporter sentry,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _sentry = sentry;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final SentryReporter _sentry;

  static const _ctx = 'PERSONAL_FORMULAS_REPOSITORY';

  /// SharedPreferences key for the "we've confirmed remote has zero formulas"
  /// sentinel. Mirrors the `formula_pins` pattern: with zero active local rows
  /// an empty cache is ambiguous (never-synced vs genuinely-empty), so we force
  /// a sync until a successful sync confirms the remote is also empty.
  static const _confirmedEmptyPrefsKey = 'personal_formulas_confirmed_empty';

  /// In-flight [syncFromRemote] future, used to coalesce concurrent callers.
  Future<SyncResult>? _inflightSync;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'personal_formulas';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<bool> isStale() async {
    final activeLocal = await (_database.select(_database.personalFormulasTable)
          ..where((tbl) => tbl.isDeleted.equals(false)))
        .get();
    if (activeLocal.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final confirmedEmpty = prefs.getBool(_confirmedEmptyPrefsKey) ?? false;
      if (confirmedEmpty) {
        return super.isStale();
      }
      _logger.info(
        'Forcing sync - no active local personal formulas and remote not yet '
        'confirmed empty',
        context: _ctx,
      );
      return true;
    }
    return super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    final inflight = _inflightSync;
    if (inflight != null) {
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
        'Syncing personal formulas from Supabase',
        context: _ctx,
        data: {'userId': userId},
      );

      // Fetch ALL rows (including tombstones) so deletes propagate.
      final response = await _supabase
          .from('personal_formulas')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final remoteRows = response as List<dynamic>;
      final syncedCount = await upsertRemotePreservingDirty(remoteRows);

      await setLastSyncTime(DateTime.now());
      await _refreshConfirmedEmptySentinel();

      _logger.info(
        'Successfully synced personal formulas from Supabase',
        context: _ctx,
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync personal formulas from Supabase',
        context: _ctx,
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  Future<void> _refreshConfirmedEmptySentinel() async {
    final activeCount =
        (await (_database.select(_database.personalFormulasTable)
                  ..where((tbl) => tbl.isDeleted.equals(false)))
                .get())
            .length;
    final prefs = await SharedPreferences.getInstance();
    if (activeCount == 0) {
      await prefs.setBool(_confirmedEmptyPrefsKey, true);
    } else {
      await prefs.remove(_confirmedEmptyPrefsKey);
    }
  }

  Future<void> _clearConfirmedEmptySentinel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_confirmedEmptyPrefsKey);
  }

  /// Apply a batch of remote rows to Drift, skipping any local row flagged
  /// `needs_upload = true` (dirty-preserve). Tombstones are applied like any
  /// other row; read paths filter them via `WHERE NOT is_deleted`.
  @visibleForTesting
  Future<int> upsertRemotePreservingDirty(List<dynamic> remoteRows) async {
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
    final dirtyRows = await (_database.select(_database.personalFormulasTable)
          ..where(
            (tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true),
          ))
        .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue;
        batch.insert(
          _database.personalFormulasTable,
          PersonalFormula.companionFromSupabaseJson(entry.value),
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote overwrite for dirty local personal formulas',
        context: _ctx,
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }

    return upsertedCount;
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      final dirtyRecords =
          await (_database.select(_database.personalFormulasTable)
                ..where(
                  (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
                ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      final formulas = dirtyRecords
          .map(PersonalFormula.fromDriftEntry)
          .whereType<PersonalFormula>()
          .toList();

      if (formulas.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      await _supabase.from('personal_formulas').upsert(
            formulas.map((f) => f.toSupabaseJson()).toList(),
            onConflict: 'id',
          );

      await _database.batch((batch) {
        for (final f in formulas) {
          batch.update(
            _database.personalFormulasTable,
            const PersonalFormulasTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(f.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty personal formulas',
        context: _ctx,
        data: {'count': formulas.length},
      );

      return UploadResult.successful(formulas.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty personal formulas',
        context: _ctx,
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

  /// Return all active (non-deleted) personal formulas for [userId], newest
  /// first, optionally filtered to a single [phase].
  Future<List<PersonalFormula>> getForUser(
    String userId, {
    FormulaPhase? phase,
  }) async {
    final query = _database.select(_database.personalFormulasTable)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.isDeleted.equals(false));

    if (phase != null) {
      query.where((tbl) => tbl.phase.equals(phase.analyticsValue));
    }

    query.orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

    final entries = await query.get();
    return entries
        .map(PersonalFormula.fromDriftEntry)
        .whereType<PersonalFormula>()
        .toList();
  }

  // ========================================================================
  // Mutation Methods
  // ========================================================================

  /// Persist a personal formula locally (with `needs_upload = true`) and kick
  /// off a non-blocking remote upsert. Used by both create and update — the
  /// caller owns the [formula] id (create generates a fresh one; update reuses
  /// the existing id).
  Future<PersonalFormula> save(PersonalFormula formula) async {
    final now = DateTime.now();
    final toWrite = formula.copyWith(
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await _database
        .into(_database.personalFormulasTable)
        .insertOnConflictUpdate(toWrite.toDriftCompanion());

    await _clearConfirmedEmptySentinel();

    _logger.info(
      'Saved personal formula',
      context: _ctx,
      data: {
        'id': toWrite.id,
        'phase': toWrite.phase.analyticsValue,
        'componentCount': toWrite.components.length,
      },
    );

    _scheduleImmediateUpload(toWrite, label: 'save');
    return toWrite;
  }

  /// Soft-delete a personal formula by id (sets `is_deleted = true`). No-op if
  /// no active row exists.
  Future<void> deleteFormula({
    required String userId,
    required String id,
  }) async {
    final row = await (_database.select(_database.personalFormulasTable)
          ..where((tbl) =>
              tbl.id.equals(id) &
              tbl.userId.equals(userId) &
              tbl.isDeleted.equals(false))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return;

    final formula = PersonalFormula.fromDriftEntry(row);
    if (formula == null) return;

    final now = DateTime.now();
    final tombstone = formula.copyWith(
      isDeleted: true,
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await (_database.update(_database.personalFormulasTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      PersonalFormulasTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.info(
      'Deleted personal formula',
      context: _ctx,
      data: {'id': id},
    );

    _scheduleImmediateUpload(tombstone, label: 'delete');
  }

  // ========================================================================
  // Private Helpers
  // ========================================================================

  void _scheduleImmediateUpload(PersonalFormula formula,
      {required String label}) {
    unawaited(() async {
      try {
        await _supabase
            .from('personal_formulas')
            .upsert(formula.toSupabaseJson(), onConflict: 'id');
        await _clearDirtyFlag(formula.id);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate $label upload failed; formula stays dirty for retry',
          context: _ctx,
          error: e,
          stackTrace: stackTrace,
          data: {'id': formula.id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:personal_formulas:$label',
          method: 'UPSERT',
          stackTrace: stackTrace,
        );
      }
    }());
  }

  Future<void> _clearDirtyFlag(String id) async {
    await (_database.update(_database.personalFormulasTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(const PersonalFormulasTableCompanion(needsUpload: Value(false)));
  }
}
