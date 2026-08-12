import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/data/syncable_repository.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../domain/integration.dart';

/// Repository for managing external training-platform integrations
/// (Final Surge, TrainingPeaks, Strava, Garmin).
///
/// Storage model:
/// - Drift is the source of truth on-device.
/// - Supabase mirrors the row so OAuth tokens survive Drift schema resyncs
///   and device reinstalls. All local mutations flag `needsUpload = true`;
///   [uploadDirtyRecords] pushes them, [syncFromRemote] hydrates a fresh DB.
class IntegrationsRepository with SyncableRepository {
  IntegrationsRepository({
    required AppDatabase database,
    required SupabaseClient supabase,
    required AppLogger logger,
    required SentryReporter sentry,
  }) : _db = database,
       _supabase = supabase,
       _logger = logger,
       _sentry = sentry;

  final AppDatabase _db;
  final SupabaseClient _supabase;
  final AppLogger _logger;
  final SentryReporter _sentry;
  static const _uuid = Uuid();

  // ==========================================================================
  // SyncableRepository
  // ==========================================================================

  @override
  String get repositoryKey => 'integrations';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing integrations from Supabase',
        context: 'INTEGRATIONS_REPOSITORY',
        data: {'userId': userId},
      );

      final response = await _supabase
          .from('integrations')
          .select('*')
          .eq('user_id', userId);

      final remoteRows = (response as List<dynamic>);

      // Skip overwrite for any locally-dirty rows so we never clobber tokens
      // that haven't been pushed yet.
      final dirtyIds = await _getDirtyIdsForUser(userId);

      var upserted = 0;
      await _db.batch((batch) {
        for (final row in remoteRows) {
          if (row is! Map) continue;
          final mapped = Map<String, dynamic>.from(row);
          final id = mapped['id']?.toString();
          if (id == null || id.isEmpty) continue;
          if (dirtyIds.contains(id)) continue;

          batch.insert(
            _db.integrationsTable,
            _supabaseJsonToCompanion(mapped),
            mode: InsertMode.insertOrReplace,
          );
          upserted++;
        }
      });

      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Integrations sync complete',
        context: 'INTEGRATIONS_REPOSITORY',
        data: {
          'userId': userId,
          'remoteCount': remoteRows.length,
          'upsertedCount': upserted,
          'preservedDirty': dirtyIds.length,
        },
      );

      return SyncResult.successful(upserted);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync integrations from Supabase',
        context: 'INTEGRATIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      _sentry.reportNetworkError(
        e,
        url: 'supabase:integrations:select',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  /// Whether `public.users` already has a row for [userId].
  ///
  /// Fails **closed**: if the check itself errors (offline, transient), we
  /// return false and defer the upload rather than attempting an upsert that
  /// would violate the FK. Deferring is free — the rows stay dirty and retry.
  Future<bool> _remoteUserExists(String userId) async {
    try {
      final row = await _supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return row != null;
    } catch (e) {
      _logger.warning(
        'Could not confirm remote user row; deferring integration upload',
        context: 'INTEGRATIONS_REPOSITORY',
        data: {'userId': userId, 'error': e.toString()},
      );
      return false;
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      final dirty =
          await (_db.select(_db.integrationsTable)..where(
                (t) => t.userId.equals(userId) & t.needsUpload.equals(true),
              ))
              .get();

      if (dirty.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Parent-row guard for integrations_user_id_fkey.
      //
      // During onboarding the user connects a training provider before the
      // profile has been written remotely, so this upsert lands before the
      // `users` row exists and Postgres rejects it with 23503 (Sentry
      // MEALVANA-ENDURANCE-3W — 339 occurrences, still live on 1.22.0+88).
      //
      // The sync graph already declares `integrations: ['users']`, but that
      // only guarantees the users repository is *asked* to sync first — it
      // does not guarantee a row was actually produced, which is exactly the
      // onboarding case. So check for the parent directly and, when it isn't
      // there yet, leave the rows dirty and defer. They upload on the next
      // sync once the profile lands, which is the offline-first contract.
      if (!await _remoteUserExists(userId)) {
        _logger.info(
          'Deferring integration upload: user row not yet remote',
          context: 'INTEGRATIONS_REPOSITORY',
          data: {'userId': userId, 'deferred': dirty.length},
        );
        return UploadResult.nothingToUpload();
      }

      _logger.info(
        'Uploading dirty integrations to Supabase',
        context: 'INTEGRATIONS_REPOSITORY',
        data: {'userId': userId, 'count': dirty.length},
      );

      final payload = dirty.map(_toSupabaseJson).toList(growable: false);

      // Upsert by primary key — onConflict: 'id' is always safe per the
      // PostgREST + partial-index rule documented in MEMORY.md.
      await _supabase.from('integrations').upsert(payload, onConflict: 'id');

      // Clear dirty flags for the rows we just pushed.
      final ids = dirty.map((r) => r.id).toSet();
      await _db.batch((batch) {
        for (final id in ids) {
          batch.update(
            _db.integrationsTable,
            const IntegrationsTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(id),
          );
        }
      });

      _logger.info(
        'Dirty integrations uploaded',
        context: 'INTEGRATIONS_REPOSITORY',
        data: {'userId': userId, 'count': ids.length},
      );

      return UploadResult.successful(ids.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty integrations',
        context: 'INTEGRATIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      _sentry.reportNetworkError(
        e,
        url: 'supabase:integrations:upsert',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      return UploadResult.failed(e.toString());
    }
  }

  Future<Set<String>> _getDirtyIdsForUser(String userId) async {
    final dirtyRows =
        await (_db.select(_db.integrationsTable)..where(
              (t) => t.userId.equals(userId) & t.needsUpload.equals(true),
            ))
            .get();
    return dirtyRows.map((r) => r.id).toSet();
  }

  // ==========================================================================
  // Public API
  // ==========================================================================

  /// Get a specific integration by user and provider
  Future<IntegrationModel?> getIntegration(
    String userId,
    String provider,
  ) async {
    final query = _db.select(_db.integrationsTable)
      ..where((t) => t.userId.equals(userId) & t.provider.equals(provider));

    final result = await query.getSingleOrNull();
    return result != null ? _toModel(result) : null;
  }

  /// Get all integrations for a user
  Future<List<IntegrationModel>> getIntegrationsForUser(String userId) async {
    final query = _db.select(_db.integrationsTable)
      ..where((t) => t.userId.equals(userId));

    final results = await query.get();
    return results.map(_toModel).toList();
  }

  /// Get all active integrations for a user
  Future<List<IntegrationModel>> getActiveIntegrationsForUser(
    String userId,
  ) async {
    final query = _db.select(_db.integrationsTable)
      ..where((t) => t.userId.equals(userId) & t.isActive.equals(true));

    final results = await query.get();
    return results.map(_toModel).toList();
  }

  /// Insert or update an integration (upsert by user_id + provider).
  ///
  /// Marks the row dirty and best-effort-pushes to Supabase immediately so
  /// freshly-issued OAuth tokens are backed up before anything else runs.
  Future<IntegrationModel> upsertIntegration(IntegrationModel model) async {
    final existing = await getIntegration(model.userId, model.provider);
    final now = DateTime.now();

    final IntegrationModel saved;
    if (existing != null) {
      saved = model.copyWith(
        id: existing.id,
        createdAt: existing.createdAt,
        updatedAt: now,
      );

      await (_db.update(_db.integrationsTable)
            ..where((t) => t.id.equals(existing.id!)))
          .write(_toCompanion(saved, dirty: true));
    } else {
      saved = model.copyWith(
        id: model.id ?? _uuid.v4(),
        createdAt: model.createdAt ?? now,
        updatedAt: now,
      );

      await _db
          .into(_db.integrationsTable)
          .insert(_toCompanion(saved, dirty: true));
    }

    await _pushToSupabase(saved);
    return saved;
  }

  /// Deactivate an integration (soft delete)
  Future<void> deactivateIntegration(String userId, String provider) async {
    await (_db.update(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .write(
          IntegrationsTableCompanion(
            isActive: const Value(false),
            needsUpload: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );

    await _pushUserProviderToSupabase(userId, provider);
  }

  /// Delete an integration permanently.
  ///
  /// Removes the row both locally and remotely so that, after a Drift wipe,
  /// the integration does not get hydrated back from Supabase.
  Future<void> deleteIntegration(String userId, String provider) async {
    await (_db.delete(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .go();

    try {
      await _supabase
          .from('integrations')
          .delete()
          .eq('user_id', userId)
          .eq('provider', provider);
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to delete integration from Supabase; local row already removed',
        context: 'INTEGRATIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId, 'provider': provider},
      );
      _sentry.reportNetworkError(
        e,
        url: 'supabase:integrations:delete',
        method: 'DELETE',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update sync status after a sync attempt
  Future<void> updateSyncStatus(
    String userId,
    String provider, {
    required String status,
    String? error,
  }) async {
    await (_db.update(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .write(
          IntegrationsTableCompanion(
            lastSyncAt: Value(DateTime.now()),
            lastSyncStatus: Value(status),
            lastSyncError: Value(error),
            needsUpload: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );

    await _pushUserProviderToSupabase(userId, provider);
  }

  /// Update access token (after refresh)
  Future<void> updateToken(
    String userId,
    String provider, {
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) async {
    await (_db.update(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .write(
          IntegrationsTableCompanion(
            accessToken: Value(accessToken),
            refreshToken: refreshToken != null
                ? Value(refreshToken)
                : const Value.absent(),
            tokenExpiresAt: expiresAt != null
                ? Value(expiresAt)
                : const Value.absent(),
            needsUpload: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );

    await _pushUserProviderToSupabase(userId, provider);
  }

  /// Update athlete zones JSON for an integration
  Future<void> updateAthleteZones(
    String userId,
    String provider, {
    required String zonesJson,
  }) async {
    await (_db.update(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .write(
          IntegrationsTableCompanion(
            athleteZonesJson: Value(zonesJson),
            needsUpload: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );

    await _pushUserProviderToSupabase(userId, provider);
  }

  /// Migrate integrations from one user ID to another.
  ///
  /// Used during onboarding when integrations are created before the final
  /// user profile exists. Updates user_id locally and flags for re-upload so
  /// Supabase reflects the final user.
  ///
  /// Returns the number of integrations migrated.
  Future<int> migrateIntegrationsToUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return 0;

    try {
      final result =
          await (_db.update(
            _db.integrationsTable,
          )..where((t) => t.userId.equals(fromUserId))).write(
            IntegrationsTableCompanion(
              userId: Value(toUserId),
              needsUpload: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // Best-effort push for the migrated rows so Supabase rebases under the
      // new user immediately. uploadDirtyRecords will retry anything missed.
      try {
        await uploadDirtyRecords(toUserId);
      } catch (_) {
        // swallow — dirty flag remains, will retry later
      }

      return result;
    } catch (e) {
      // Migration is best-effort; don't throw.
      return 0;
    }
  }

  /// Get all integrations (regardless of user).
  ///
  /// Used during onboarding to rebase orphan rows created before the user
  /// profile was finalized.
  Future<List<IntegrationModel>> getAllIntegrations() async {
    final results = await _db.select(_db.integrationsTable).get();
    return results.map(_toModel).toList();
  }

  // ==========================================================================
  // Supabase mirroring
  // ==========================================================================

  Future<void> _pushUserProviderToSupabase(
    String userId,
    String provider,
  ) async {
    final row = await getIntegration(userId, provider);
    if (row == null) return;
    await _pushToSupabase(row);
  }

  /// Best-effort upsert to Supabase. Failures keep the row dirty so the next
  /// `uploadDirtyRecords` pass picks it up — they are not surfaced to callers.
  Future<void> _pushToSupabase(IntegrationModel model) async {
    if (model.id == null) return;
    try {
      await _supabase
          .from('integrations')
          .upsert(_modelToSupabaseJson(model), onConflict: 'id');

      await (_db.update(_db.integrationsTable)
            ..where((t) => t.id.equals(model.id!)))
          .write(const IntegrationsTableCompanion(needsUpload: Value(false)));
    } catch (e, stackTrace) {
      _logger.warning(
        'Immediate integration upload failed; row stays dirty for retry',
        context: 'INTEGRATIONS_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': model.userId, 'provider': model.provider},
      );
      _sentry.reportNetworkError(
        e,
        url: 'supabase:integrations:upsert',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
    }
  }

  // ==========================================================================
  // Mappers
  // ==========================================================================

  IntegrationModel _toModel(Integration entity) {
    return IntegrationModel(
      id: entity.id,
      userId: entity.userId,
      provider: entity.provider,
      accessToken: entity.accessToken,
      refreshToken: entity.refreshToken,
      tokenExpiresAt: entity.tokenExpiresAt,
      providerAthleteId: entity.providerAthleteId,
      providerAthleteName: entity.providerAthleteName,
      providerAthleteEmail: entity.providerAthleteEmail,
      providerAthleteWeightKg: entity.providerAthleteWeightKg,
      providerAthleteBirthMonth: entity.providerAthleteBirthMonth,
      providerAthleteGender: entity.providerAthleteGender,
      providerAthleteBodyFatPct: entity.providerAthleteBodyFatPct,
      athleteZonesJson: entity.athleteZonesJson,
      isActive: entity.isActive,
      lastSyncAt: entity.lastSyncAt,
      lastSyncStatus: entity.lastSyncStatus,
      lastSyncError: entity.lastSyncError,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  IntegrationsTableCompanion _toCompanion(
    IntegrationModel model, {
    required bool dirty,
  }) {
    return IntegrationsTableCompanion(
      id: Value(model.id ?? _uuid.v4()),
      userId: Value(model.userId),
      provider: Value(model.provider),
      accessToken: Value(model.accessToken),
      refreshToken: Value(model.refreshToken),
      tokenExpiresAt: Value(model.tokenExpiresAt),
      providerAthleteId: Value(model.providerAthleteId),
      providerAthleteName: Value(model.providerAthleteName),
      providerAthleteEmail: Value(model.providerAthleteEmail),
      providerAthleteWeightKg: Value(model.providerAthleteWeightKg),
      providerAthleteBirthMonth: Value(model.providerAthleteBirthMonth),
      providerAthleteGender: Value(model.providerAthleteGender),
      providerAthleteBodyFatPct: Value(model.providerAthleteBodyFatPct),
      athleteZonesJson: Value(model.athleteZonesJson),
      isActive: Value(model.isActive),
      lastSyncAt: Value(model.lastSyncAt),
      lastSyncStatus: Value(model.lastSyncStatus),
      lastSyncError: Value(model.lastSyncError),
      needsUpload: Value(dirty),
      createdAt: Value(model.createdAt ?? DateTime.now()),
      updatedAt: Value(model.updatedAt ?? DateTime.now()),
    );
  }

  Map<String, dynamic> _toSupabaseJson(Integration entity) {
    return {
      'id': entity.id,
      'user_id': entity.userId,
      'provider': entity.provider,
      'access_token': entity.accessToken,
      'refresh_token': entity.refreshToken,
      'token_expires_at': entity.tokenExpiresAt?.toUtc().toIso8601String(),
      'provider_athlete_id': entity.providerAthleteId,
      'provider_athlete_name': entity.providerAthleteName,
      'provider_athlete_email': entity.providerAthleteEmail,
      'provider_athlete_weight_kg': entity.providerAthleteWeightKg,
      'provider_athlete_birth_month': entity.providerAthleteBirthMonth,
      'provider_athlete_gender': entity.providerAthleteGender,
      'provider_athlete_body_fat_pct': entity.providerAthleteBodyFatPct,
      'athlete_zones_json': _decodeZonesForJsonb(entity.athleteZonesJson),
      'is_active': entity.isActive,
      'last_sync_at': entity.lastSyncAt?.toUtc().toIso8601String(),
      'last_sync_status': entity.lastSyncStatus,
      'last_sync_error': entity.lastSyncError,
      'created_at': entity.createdAt.toUtc().toIso8601String(),
      'updated_at': entity.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _modelToSupabaseJson(IntegrationModel model) {
    final now = DateTime.now();
    return {
      'id': model.id,
      'user_id': model.userId,
      'provider': model.provider,
      'access_token': model.accessToken,
      'refresh_token': model.refreshToken,
      'token_expires_at': model.tokenExpiresAt?.toUtc().toIso8601String(),
      'provider_athlete_id': model.providerAthleteId,
      'provider_athlete_name': model.providerAthleteName,
      'provider_athlete_email': model.providerAthleteEmail,
      'provider_athlete_weight_kg': model.providerAthleteWeightKg,
      'provider_athlete_birth_month': model.providerAthleteBirthMonth,
      'provider_athlete_gender': model.providerAthleteGender,
      'provider_athlete_body_fat_pct': model.providerAthleteBodyFatPct,
      'athlete_zones_json': _decodeZonesForJsonb(model.athleteZonesJson),
      'is_active': model.isActive,
      'last_sync_at': model.lastSyncAt?.toUtc().toIso8601String(),
      'last_sync_status': model.lastSyncStatus,
      'last_sync_error': model.lastSyncError,
      'created_at': (model.createdAt ?? now).toUtc().toIso8601String(),
      'updated_at': (model.updatedAt ?? now).toUtc().toIso8601String(),
    };
  }

  /// Drift stores athlete zones as a JSON-encoded string; Supabase wants the
  /// decoded structure for its JSONB column. Pass nulls and malformed input
  /// through unchanged so we never block a token upload over a parse error.
  Object? _decodeZonesForJsonb(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  IntegrationsTableCompanion _supabaseJsonToCompanion(
    Map<String, dynamic> json,
  ) {
    DateTime? parseTime(Object? v) =>
        v == null ? null : DateTime.parse(v as String);

    final createdAt = parseTime(json['created_at']) ?? DateTime.now();
    final updatedAt = parseTime(json['updated_at']) ?? DateTime.now();

    return IntegrationsTableCompanion(
      id: Value(json['id'] as String),
      userId: Value(json['user_id'] as String),
      provider: Value(json['provider'] as String),
      accessToken: Value(json['access_token'] as String),
      refreshToken: Value(json['refresh_token'] as String?),
      tokenExpiresAt: Value(parseTime(json['token_expires_at'])),
      providerAthleteId: Value(json['provider_athlete_id'] as String),
      providerAthleteName: Value(json['provider_athlete_name'] as String?),
      providerAthleteEmail: Value(json['provider_athlete_email'] as String?),
      providerAthleteWeightKg: Value(
        (json['provider_athlete_weight_kg'] as num?)?.toDouble(),
      ),
      providerAthleteBirthMonth: Value(
        json['provider_athlete_birth_month'] as String?,
      ),
      providerAthleteGender: Value(json['provider_athlete_gender'] as String?),
      providerAthleteBodyFatPct: Value(
        (json['provider_athlete_body_fat_pct'] as num?)?.toDouble(),
      ),
      athleteZonesJson: Value(_zonesJsonAsString(json['athlete_zones_json'])),
      isActive: Value(json['is_active'] as bool? ?? true),
      lastSyncAt: Value(parseTime(json['last_sync_at'])),
      lastSyncStatus: Value(json['last_sync_status'] as String?),
      lastSyncError: Value(json['last_sync_error'] as String?),
      needsUpload: const Value(false), // came from server, so not dirty
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  /// Supabase returns JSONB as a parsed Map/List; Drift stores it as a string,
  /// so re-encode any structured payload back to JSON.
  String? _zonesJsonAsString(Object? raw) {
    if (raw == null) return null;
    if (raw is String) return raw;
    return jsonEncode(raw);
  }
}
