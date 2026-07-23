import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/formula_pin.dart';

part 'formula_pins_repository.g.dart';

@riverpod
FormulaPinsRepository formulaPinsRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return FormulaPinsRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
  );
}

/// Repository for Formula Kit pins (user-declared algorithm signals).
///
/// Storage strategy matches `personal_templates`: local-first writes with
/// `needs_upload`/`local_updated_at` dirty tracking, then non-blocking
/// upload to Supabase. The remote upsert preserves locally-dirty rows so
/// concurrent edits aren't clobbered.
///
/// **Soft delete.** `unpin()` sets `is_deleted = true` rather than deleting
/// the row. The unique index on `(user_id, template_id, template_kind)` is
/// partial (`WHERE NOT is_deleted`), so re-pinning a soft-deleted template
/// inserts a new active row (with new id); the tombstone stays for sync.
/// All read paths filter `WHERE NOT is_deleted`. See migration
/// `20260520120000_formula_pins.sql`.
class FormulaPinsRepository with SyncableRepository {
  FormulaPinsRepository({
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

  /// SharedPreferences key for the "we've confirmed remote has zero pins"
  /// sentinel. When set, [isStale] falls through to time-based staleness even
  /// when the local active-pin cache is empty. Cleared on any local pin
  /// write, and rewritten by every successful [syncFromRemote].
  static const _confirmedEmptyPrefsKey = 'formula_pins_confirmed_empty';

  /// In-flight [syncFromRemote] future, used to coalesce concurrent callers.
  /// `FormulaLibraryController` and `FormulaPinController` both call this on
  /// `build()` and Riverpod has no guaranteed ordering — without this the two
  /// would race a duplicate Supabase round-trip + double `setLastSyncTime`
  /// write. Cleared in the `finally` of the originating call so retries are
  /// possible after failure.
  Future<SyncResult>? _inflightSync;

  static const _uuid = Uuid();

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'formula_pins';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  /// Force a sync when there are no active local pins **and** we haven't
  /// already confirmed that the remote is empty.
  ///
  /// Unlike the read-only catalog mirrors (pre/during/post templates), an
  /// empty `formula_pins` cache is ambiguous on first read — it can mean
  /// "never synced" OR "this user genuinely has no pins". We err toward
  /// correctness on first contact: with zero active local pins we force a
  /// sync so a pin created on another device shows up promptly (the #32
  /// cross-device gap, where a sibling controller's recent-but-empty sync
  /// timestamp suppressed the fetch).
  ///
  /// Once a sync has confirmed the remote also has zero pins, the
  /// [_confirmedEmptyPrefsKey] sentinel is set and subsequent [isStale]
  /// calls fall through to standard time-based staleness — otherwise a
  /// genuinely pin-less user would fire one Supabase round-trip per
  /// controller rebuild forever. The sentinel is cleared on any local pin
  /// write and rewritten by every successful sync.
  @override
  Future<bool> isStale() async {
    final activeLocal = await (_database.select(
      _database.formulaPinsTable,
    )..where((tbl) => tbl.isDeleted.equals(false))).get();
    if (activeLocal.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final confirmedEmpty = prefs.getBool(_confirmedEmptyPrefsKey) ?? false;
      if (confirmedEmpty) {
        return super.isStale();
      }
      _logger.info(
        'Forcing sync - no active local formula pins and remote not yet confirmed empty',
        context: 'FORMULA_PINS_REPOSITORY',
      );
      return true;
    }
    return super.isStale();
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    // Coalesce concurrent callers (FormulaLibraryController and
    // FormulaPinController both call this on build).
    final inflight = _inflightSync;
    if (inflight != null) {
      _logger.debug(
        'syncFromRemote: coalescing into in-flight sync',
        context: 'FORMULA_PINS_REPOSITORY',
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
        'Syncing formula pins from Supabase',
        context: 'FORMULA_PINS_REPOSITORY',
        data: {'userId': userId},
      );

      // Fetch ALL rows (including tombstones) so unpin events propagate.
      final response = await _supabase
          .from('formula_pins')
          .select('*')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final remotePins = response as List<dynamic>;
      final syncedCount = await upsertRemotePinsPreservingDirty(remotePins);

      await setLastSyncTime(DateTime.now());
      await _refreshConfirmedEmptySentinel();

      _logger.info(
        'Successfully synced formula pins from Supabase',
        context: 'FORMULA_PINS_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync formula pins from Supabase',
        context: 'FORMULA_PINS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  /// Set the confirmed-empty sentinel iff there are zero active local pins
  /// after a successful sync; clear it otherwise. Run after every sync so
  /// the sentinel tracks the latest remote-side truth.
  Future<void> _refreshConfirmedEmptySentinel() async {
    final activeCount = (await (_database.select(
      _database.formulaPinsTable,
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

  /// Applies a batch of remote pin rows to Drift, skipping any local row
  /// flagged `needs_upload = true` (dirty-preserve). Tombstones (rows with
  /// `is_deleted = true`) are applied like any other row; read paths filter
  /// them out via `WHERE NOT is_deleted`.
  ///
  /// Exposed via `@visibleForTesting` because the project's repository tests
  /// punt on full Supabase mocking — see `test/new_sync/coach_repository_sync_test.dart`.
  /// This lets the dirty-preserve + tombstone-propagation invariants be locked
  /// down without a SupabaseQueryBuilder mock stack.
  @visibleForTesting
  Future<int> upsertRemotePinsPreservingDirty(List<dynamic> remotePins) async {
    final remoteById = <String, Map<String, dynamic>>{};

    for (final item in remotePins) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) return 0;

    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows =
        await (_database.select(_database.formulaPinsTable)..where(
              (tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true),
            ))
            .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue;

        final companion = _mapSupabaseJsonToCompanion(entry.value);
        batch.insert(
          _database.formulaPinsTable,
          companion,
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    if (dirtyIds.isNotEmpty) {
      _logger.warning(
        'Skipped remote pin overwrite for dirty local rows',
        context: 'FORMULA_PINS_REPOSITORY',
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
      _logger.info(
        'Uploading dirty formula pins to Supabase',
        context: 'FORMULA_PINS_REPOSITORY',
        data: {'userId': userId},
      );

      final dirtyRecords =
          await (_database.select(_database.formulaPinsTable)..where(
                (t) => t.needsUpload.equals(true) & t.userId.equals(userId),
              ))
              .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.debug(
        'Found dirty formula pins to upload',
        context: 'FORMULA_PINS_REPOSITORY',
        data: {'count': dirtyRecords.length},
      );

      final decodedPins = _decodePinEntries(dirtyRecords);

      if (decodedPins.isEmpty) {
        // Every dirty row had an unrecognized template_kind (forward-compat
        // skip). Nothing safe to upload; leave dirty flags set so a newer
        // binary can retry.
        return UploadResult.nothingToUpload();
      }

      final pinsToUpload = decodedPins
          .map((pin) => pin.toSupabaseJson())
          .toList();

      await _supabase
          .from('formula_pins')
          .upsert(pinsToUpload, onConflict: 'id');

      // Clear dirty flags only for rows we actually uploaded. Rows skipped
      // due to unknown template_kind keep their dirty flag so a newer binary
      // can retry.
      await _database.batch((batch) {
        for (final pin in decodedPins) {
          batch.update(
            _database.formulaPinsTable,
            const FormulaPinsTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(pin.id),
          );
        }
      });

      _logger.info(
        'Successfully uploaded dirty formula pins',
        context: 'FORMULA_PINS_REPOSITORY',
        data: {'count': decodedPins.length},
      );

      return UploadResult.successful(decodedPins.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty formula pins',
        context: 'FORMULA_PINS_REPOSITORY',
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

  /// Return all active (non-deleted) pins for [userId], optionally filtered
  /// to a single [kind]. Used by the algorithm + UI badge lookups.
  Future<List<FormulaPin>> getActivePinsForUser(
    String userId, {
    TemplateKind? kind,
  }) async {
    final query = _database.select(_database.formulaPinsTable)
      ..where((tbl) => tbl.userId.equals(userId) & tbl.isDeleted.equals(false));

    if (kind != null) {
      query.where((tbl) => tbl.templateKind.equals(kind.wireValue));
    }

    query.orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

    final entries = await query.get();
    return _decodePinEntries(entries);
  }

  /// Whether an active pin exists for the given user + template + kind.
  Future<bool> isPinned({
    required String userId,
    required String templateId,
    required TemplateKind kind,
  }) async {
    final row =
        await (_database.select(_database.formulaPinsTable)
              ..where(
                (tbl) =>
                    tbl.userId.equals(userId) &
                    tbl.templateId.equals(templateId) &
                    tbl.templateKind.equals(kind.wireValue) &
                    tbl.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Return the active pin row (if any) for the given user + template + kind.
  Future<FormulaPin?> findActivePin({
    required String userId,
    required String templateId,
    required TemplateKind kind,
  }) async {
    final row =
        await (_database.select(_database.formulaPinsTable)
              ..where(
                (tbl) =>
                    tbl.userId.equals(userId) &
                    tbl.templateId.equals(templateId) &
                    tbl.templateKind.equals(kind.wireValue) &
                    tbl.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    final pin = FormulaPin.fromDriftEntry(row);
    if (pin == null) {
      // The query filtered on `kind.wireValue`, so the row's wire value
      // must equal a known enum value — reaching here would mean DB
      // corruption or an unexpected schema drift. Log + skip.
      _logUnknownTemplateKind(row);
    }
    return pin;
  }

  // ========================================================================
  // Mutation Methods
  // ========================================================================

  /// Pin a template for [userId]. If an active pin already exists for the
  /// (user, template, kind) tuple, returns it unchanged (idempotent).
  ///
  /// Writes locally with `needs_upload = true` and attempts a non-blocking
  /// remote upsert. If the upload fails, the pin stays dirty for the next
  /// sync pass.
  Future<FormulaPin> pin({
    required String userId,
    required String templateId,
    required TemplateKind kind,
  }) async {
    final existing = await findActivePin(
      userId: userId,
      templateId: templateId,
      kind: kind,
    );
    if (existing != null) return existing;

    final now = DateTime.now();
    final pin = FormulaPin(
      id: _uuid.v4(),
      userId: userId,
      templateId: templateId,
      templateKind: kind,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await _database
        .into(_database.formulaPinsTable)
        .insert(pin.toDriftCompanion());

    // Local-active count just became non-zero — invalidate the
    // confirmed-empty sentinel so isStale() doesn't gate behind it.
    await _clearConfirmedEmptySentinel();

    _logger.info(
      'Pinned formula',
      context: 'FORMULA_PINS_REPOSITORY',
      data: {'pinId': pin.id, 'templateId': templateId, 'kind': kind.wireValue},
    );

    _scheduleImmediateUpload(pin, label: 'pin');

    return pin;
  }

  /// Unpin a template by setting `is_deleted = true` on the active row(s).
  /// No-op if no active pin exists.
  Future<void> unpin({
    required String userId,
    required String templateId,
    required TemplateKind kind,
  }) async {
    final active = await findActivePin(
      userId: userId,
      templateId: templateId,
      kind: kind,
    );
    if (active == null) return;

    final now = DateTime.now();
    final tombstone = active.copyWith(
      isDeleted: true,
      updatedAt: now,
      needsUpload: true,
      localUpdatedAt: now,
    );

    await (_database.update(
      _database.formulaPinsTable,
    )..where((tbl) => tbl.id.equals(active.id))).write(
      FormulaPinsTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
        needsUpload: const Value(true),
        localUpdatedAt: Value(now),
      ),
    );

    _logger.info(
      'Unpinned formula',
      context: 'FORMULA_PINS_REPOSITORY',
      data: {
        'pinId': active.id,
        'templateId': templateId,
        'kind': kind.wireValue,
      },
    );

    _scheduleImmediateUpload(tombstone, label: 'unpin');
  }

  // ========================================================================
  // Private Helpers
  // ========================================================================

  void _scheduleImmediateUpload(FormulaPin pin, {required String label}) {
    unawaited(() async {
      try {
        await _supabase
            .from('formula_pins')
            .upsert(pin.toSupabaseJson(), onConflict: 'id');
        await _clearDirtyFlag(pin.id);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate $label upload failed; pin stays dirty for retry',
          context: 'FORMULA_PINS_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'pinId': pin.id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:formula_pins:$label',
          method: 'UPSERT',
          stackTrace: stackTrace,
        );
      }
    }());
  }

  Future<void> _clearDirtyFlag(String pinId) async {
    await (_database.update(_database.formulaPinsTable)
          ..where((tbl) => tbl.id.equals(pinId)))
        .write(const FormulaPinsTableCompanion(needsUpload: Value(false)));
  }

  FormulaPinsTableCompanion _mapSupabaseJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    return FormulaPinsTableCompanion.insert(
      id: Value(json['id'] as String),
      userId: json['user_id'] as String,
      templateId: json['template_id'] as String,
      templateKind: json['template_kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isDeleted: Value(json['is_deleted'] as bool? ?? false),
      needsUpload: const Value(false),
      localUpdatedAt: Value(DateTime.now()),
    );
  }

  /// Decode a batch of Drift rows into [FormulaPin]s, skipping (and logging)
  /// any rows whose `template_kind` doesn't match this binary's
  /// [TemplateKind] enum. This is the forward-compat path: a newer client
  /// may have written a wire value (e.g. `post_system` from PR 3) that this
  /// binary doesn't recognize. Skipping is safer than crashing.
  List<FormulaPin> _decodePinEntries(Iterable<FormulaPinEntry> entries) {
    final result = <FormulaPin>[];
    for (final entry in entries) {
      final pin = FormulaPin.fromDriftEntry(entry);
      if (pin == null) {
        _logUnknownTemplateKind(entry);
        continue;
      }
      result.add(pin);
    }
    return result;
  }

  void _logUnknownTemplateKind(FormulaPinEntry entry) {
    _logger.warning(
      'Skipping formula pin with unknown template_kind',
      context: 'FORMULA_PINS_REPOSITORY',
      data: {'pin_id': entry.id, 'template_kind': entry.templateKind},
    );
    unawaited(
      _sentry.captureMessage(
        'Skipped formula pin with unknown template_kind',
        level: SentryLevel.warning,
        tags: {'pin_id': entry.id, 'template_kind': entry.templateKind},
      ),
    );
  }
}
