import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// Repository for Formula Kit personal formulas (user-authored fueling
/// recipes).
///
/// Storage strategy matches `formula_pins`: local-first writes with
/// `needs_upload` / `local_updated_at` dirty tracking, then a non-blocking
/// upload to Supabase. The remote upsert preserves locally-dirty rows so
/// concurrent edits aren't clobbered.
///
/// **Soft delete.** [delete] sets `is_deleted = true` rather than removing the
/// row, so deletes propagate across devices via the upsert-only sync and any
/// `formula_pins` referencing the formula can be reconciled. All read paths
/// filter `WHERE NOT is_deleted`. See `docs/database/apply_all.sql` §4.
class PersonalFormulasRepository with SyncableRepository {
  PersonalFormulasRepository({
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

  /// SharedPreferences sentinel mirroring `formula_pins`: once a sync confirms
  /// the remote has zero active formulas, [isStale] falls through to
  /// time-based staleness instead of forcing a fetch on every empty-cache
  /// read. Cleared on any local write, rewritten by every successful sync.
  static const _confirmedEmptyPrefsKey = 'personal_formulas_confirmed_empty';

  /// Coalesces concurrent [syncFromRemote] callers into one round-trip.
  Future<SyncResult>? _inflightSync;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'personal_formulas';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  /// Force a sync when there are no active local formulas **and** we haven't
  /// already confirmed the remote is empty — an empty cache is ambiguous on
  /// first read ("never synced" vs "genuinely none"). Mirrors
  /// `FormulaPinsRepository.isStale`.
  @override
  Future<bool> isStale() async {
    final activeLocal = await (_database.select(
      _database.personalFormulasTable,
    )..where((tbl) => tbl.isDeleted.equals(false))).get();
    if (activeLocal.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final confirmedEmpty = prefs.getBool(_confirmedEmptyPrefsKey) ?? false;
      if (confirmedEmpty) {
        return super.isStale();
      }
      _logger.info(
        'Forcing sync - no active local personal formulas and remote not yet '
        'confirmed empty',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
      );
      return true;
    }
    return super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    final inflight = _inflightSync;
    if (inflight != null) {
      _logger.debug(
        'syncFromRemote: coalescing into in-flight sync',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
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
        'Syncing personal formulas from Supabase',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        data: {'userId': userId},
      );

      // Fetch ALL rows (including tombstones) so deletes propagate.
      final response = await _supabase
          .from('personal_formulas')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final remoteFormulas = response as List<dynamic>;
      final syncedCount = await upsertRemoteFormulasPreservingDirty(
        remoteFormulas,
      );

      await setLastSyncTime(DateTime.now());
      await _refreshConfirmedEmptySentinel();

      _logger.info(
        'Successfully synced personal formulas from Supabase',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync personal formulas from Supabase',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  Future<void> _refreshConfirmedEmptySentinel() async {
    final activeCount = (await (_database.select(
      _database.personalFormulasTable,
    )..where((tbl) => tbl.isDeleted.equals(false))).get()).length;
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

  /// Applies a batch of remote rows to Drift, skipping any local row flagged
  /// `needs_upload = true` (dirty-preserve). Tombstones (`is_deleted = true`)
  /// are applied like any other row; read paths filter them out.
  ///
  /// Exposed via `@visibleForTesting` because the project's repository tests
  /// punt on full Supabase mocking — see `formula_pins_repository.dart`.
  @visibleForTesting
  Future<int> upsertRemoteFormulasPreservingDirty(
    List<dynamic> remoteFormulas,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};

    for (final item in remoteFormulas) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) return 0;

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows =
        await (_database.select(_database.personalFormulasTable)..where(
              (tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true),
            ))
            .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    var skippedUnparseable = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue;

        final formula = PersonalFormula.fromSupabaseJson(entry.value);
        if (formula == null) {
          // Unknown provenance/phase wire value (forward-compat) — skip.
          skippedUnparseable++;
          continue;
        }
        batch.insert(
          _database.personalFormulasTable,
          formula
              .copyWith(needsUpload: false, localUpdatedAt: DateTime.now())
              .toDriftCompanion(),
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote formula overwrite for dirty local rows',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        data: {
          'skippedCount': dirtyIds.length,
          'totalRemote': remoteById.length,
        },
      );
    }
    if (skippedUnparseable > 0) {
      _logger.warning(
        'Skipped remote formulas with unknown provenance/phase',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        data: {'skippedCount': skippedUnparseable},
      );
    }

    return upsertedCount;
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      _logger.info(
        'Uploading dirty personal formulas to Supabase',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        data: {'userId': userId},
      );

      final dirtyRecords =
          await (_database.select(_database.personalFormulasTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      final decoded = _decodeEntries(dirtyRecords);
      if (decoded.isEmpty) {
        // Every dirty row had unrecognized provenance/phase — leave dirty so a
        // newer binary can retry.
        return UploadResult.nothingToUpload();
      }

      final payload = decoded.map((f) => f.toSupabaseJson()).toList();

      await _supabase
          .from('personal_formulas')
          .upsert(payload, onConflict: 'id');

      await _database.batch((batch) {
        for (final f in decoded) {
          batch.update(
            _database.personalFormulasTable,
            const PersonalFormulasTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(f.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty personal formulas',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
        data: {'count': decoded.length},
      );

      return UploadResult.successful(decoded.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty personal formulas',
        context: 'PERSONAL_FORMULAS_REPOSITORY',
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

  /// Active (non-deleted) formulas for [userId], newest first, optionally
  /// filtered to a single [phase]. Backs the "Your formulas" listing.
  Future<List<PersonalFormula>> getFormulasForUser(
    String userId, {
    FormulaPhase? phase,
  }) async {
    final query = _database.select(_database.personalFormulasTable)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.isDeleted.equals(false));

    if (phase != null) {
      query.where((tbl) => tbl.phase.equals(phase.wireValue));
    }
    query.orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

    final entries = await query.get();
    return _decodeEntries(entries);
  }

  /// Single active formula by id, or `null` if missing/deleted/unparseable.
  Future<PersonalFormula?> getById(String id) async {
    final row =
        await (_database.select(_database.personalFormulasTable)
              ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(false))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return PersonalFormula.fromDriftEntry(row);
  }

  /// Count of active formulas for [userId], optionally per [phase]. Distinct
  /// from the legacy `personal_templates` saved-plan quota.
  Future<int> getActiveCount(String userId, {FormulaPhase? phase}) async {
    final query = _database.select(_database.personalFormulasTable)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.isDeleted.equals(false));
    if (phase != null) {
      query.where((tbl) => tbl.phase.equals(phase.wireValue));
    }
    return (await query.get()).length;
  }

  // ========================================================================
  // Mutation Methods
  // ========================================================================

  /// Persist a new formula offline-first. Assigns an id if [formula.id] is
  /// empty, stamps timestamps + dirty flag, writes to Drift, and schedules a
  /// non-blocking remote upsert.
  Future<PersonalFormula> create(PersonalFormula formula) async {
    final now = DateTime.now();
    final toSave = formula.copyWith(
      id: formula.id.isEmpty ? _uuid.v4() : formula.id,
      createdAt: formula.createdAt,
      updatedAt: now,
      isDeleted: false,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await _database
        .into(_database.personalFormulasTable)
        .insert(toSave.toDriftCompanion(), mode: InsertMode.insertOrReplace);

    await _clearConfirmedEmptySentinel();

    _logger.info(
      'Created personal formula',
      context: 'PERSONAL_FORMULAS_REPOSITORY',
      data: {'formulaId': toSave.id, 'phase': toSave.phase.wireValue},
    );

    _scheduleImmediateUpload(toSave, label: 'create');
    return toSave;
  }

  /// Overwrite an existing formula (full replace), bumping `updated_at` and
  /// re-dirtying for sync.
  Future<PersonalFormula> update(PersonalFormula formula) async {
    final now = DateTime.now();
    final toSave = formula.copyWith(
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await (_database.update(_database.personalFormulasTable)
          ..where((tbl) => tbl.id.equals(toSave.id)))
        .write(toSave.toDriftCompanion());

    _logger.info(
      'Updated personal formula',
      context: 'PERSONAL_FORMULAS_REPOSITORY',
      data: {'formulaId': toSave.id},
    );

    _scheduleImmediateUpload(toSave, label: 'update');
    return toSave;
  }

  /// Soft-delete a formula by id. No-op if no active row exists.
  Future<void> delete({required String id, required String userId}) async {
    final existing = await getById(id);
    if (existing == null) return;

    final now = DateTime.now();
    final tombstone = existing.copyWith(
      isDeleted: true,
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await (_database.update(
      _database.personalFormulasTable,
    )..where((tbl) => tbl.id.equals(id))).write(
      PersonalFormulasTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.info(
      'Soft-deleted personal formula',
      context: 'PERSONAL_FORMULAS_REPOSITORY',
      data: {'formulaId': id},
    );

    _scheduleImmediateUpload(tombstone, label: 'delete');
  }

  /// Persist a coach insight to the formula's row without a full formula
  /// rewrite. Marks the row dirty so the next sync uploads it to Supabase.
  Future<void> persistInsight({
    required String formulaId,
    required String insightText,
    required String marker,
  }) async {
    await (_database.update(
      _database.personalFormulasTable,
    )..where((tbl) => tbl.id.equals(formulaId))).write(
      PersonalFormulasTableCompanion(
        coachInsightText: Value(insightText),
        coachInsightMarker: Value(marker),
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ========================================================================
  // Private Helpers
  // ========================================================================

  void _scheduleImmediateUpload(
    PersonalFormula formula, {
    required String label,
  }) {
    unawaited(() async {
      try {
        await _supabase
            .from('personal_formulas')
            .upsert(formula.toSupabaseJson(), onConflict: 'id');
        await _clearDirtyFlag(formula.id);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate $label upload failed; formula stays dirty for retry',
          context: 'PERSONAL_FORMULAS_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'formulaId': formula.id},
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

  Future<void> _clearDirtyFlag(String formulaId) async {
    await (_database.update(_database.personalFormulasTable)
          ..where((tbl) => tbl.id.equals(formulaId)))
        .write(const PersonalFormulasTableCompanion(needsUpload: Value(false)));
  }

  /// Decode Drift rows, skipping (and logging) any with unknown
  /// provenance/phase wire values (forward-compat).
  List<PersonalFormula> _decodeEntries(Iterable<PersonalFormulaEntry> entries) {
    final result = <PersonalFormula>[];
    for (final entry in entries) {
      final formula = PersonalFormula.fromDriftEntry(entry);
      if (formula == null) {
        _logUnknownFormula(entry);
        continue;
      }
      result.add(formula);
    }
    return result;
  }

  void _logUnknownFormula(PersonalFormulaEntry entry) {
    _logger.warning(
      'Skipping personal formula with unknown provenance/phase',
      context: 'PERSONAL_FORMULAS_REPOSITORY',
      data: {
        'formula_id': entry.id,
        'provenance': entry.provenance,
        'phase': entry.phase,
      },
    );
    unawaited(
      _sentry.captureMessage(
        'Skipped personal formula with unknown provenance/phase',
        level: SentryLevel.warning,
        tags: {
          'formula_id': entry.id,
          'provenance': entry.provenance,
          'phase': entry.phase,
        },
      ),
    );
  }
}
