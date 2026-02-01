import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../domain/integration.dart';

/// Repository for managing external integrations (Final Surge, etc.)
///
/// Handles CRUD operations for the integrations table using Drift.
class IntegrationsRepository {
  IntegrationsRepository({
    required AppDatabase database,
  }) : _db = database;

  final AppDatabase _db;
  static const _uuid = Uuid();

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

  /// Insert or update an integration (upsert by user_id + provider)
  Future<IntegrationModel> upsertIntegration(IntegrationModel model) async {
    final existing = await getIntegration(model.userId, model.provider);

    if (existing != null) {
      // Update existing
      final updated = model.copyWith(
        id: existing.id,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );

      await (_db.update(_db.integrationsTable)
            ..where((t) => t.id.equals(existing.id!)))
          .write(_toCompanion(updated));

      return updated;
    } else {
      // Insert new
      final newModel = model.copyWith(
        id: model.id ?? _uuid.v4(),
        createdAt: model.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.into(_db.integrationsTable).insert(_toCompanion(newModel));

      return newModel;
    }
  }

  /// Deactivate an integration (soft delete)
  Future<void> deactivateIntegration(String userId, String provider) async {
    await (_db.update(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .write(IntegrationsTableCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Delete an integration permanently
  Future<void> deleteIntegration(String userId, String provider) async {
    await (_db.delete(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .go();
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
        .write(IntegrationsTableCompanion(
      lastSyncAt: Value(DateTime.now()),
      lastSyncStatus: Value(status),
      lastSyncError: Value(error),
      updatedAt: Value(DateTime.now()),
    ));
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
        .write(IntegrationsTableCompanion(
      accessToken: Value(accessToken),
      refreshToken: refreshToken != null ? Value(refreshToken) : const Value.absent(),
      tokenExpiresAt: expiresAt != null ? Value(expiresAt) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Update athlete zones JSON for an integration
  Future<void> updateAthleteZones(
    String userId,
    String provider, {
    required String zonesJson,
  }) async {
    await (_db.update(_db.integrationsTable)
          ..where((t) => t.userId.equals(userId) & t.provider.equals(provider)))
        .write(IntegrationsTableCompanion(
      athleteZonesJson: Value(zonesJson),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Convert Drift entity to domain model
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
      athleteZonesJson: entity.athleteZonesJson,
      isActive: entity.isActive,
      lastSyncAt: entity.lastSyncAt,
      lastSyncStatus: entity.lastSyncStatus,
      lastSyncError: entity.lastSyncError,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert domain model to Drift companion for inserts/updates
  IntegrationsTableCompanion _toCompanion(IntegrationModel model) {
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
      athleteZonesJson: Value(model.athleteZonesJson),
      isActive: Value(model.isActive),
      lastSyncAt: Value(model.lastSyncAt),
      lastSyncStatus: Value(model.lastSyncStatus),
      lastSyncError: Value(model.lastSyncError),
      createdAt: Value(model.createdAt ?? DateTime.now()),
      updatedAt: Value(model.updatedAt ?? DateTime.now()),
    );
  }

  /// Migrate integrations from one user ID to another
  ///
  /// Used during onboarding when integrations are created before the final
  /// user profile is created. This updates the user_id on all integrations
  /// that belong to the old user so they are associated with the new user.
  ///
  /// Returns the number of integrations migrated.
  Future<int> migrateIntegrationsToUser({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) return 0;

    try {
      final result = await (_db.update(_db.integrationsTable)
            ..where((t) => t.userId.equals(fromUserId)))
          .write(IntegrationsTableCompanion(
        userId: Value(toUserId),
        updatedAt: Value(DateTime.now()),
      ));

      return result;
    } catch (e) {
      // Log but don't throw - migration is best-effort
      return 0;
    }
  }

  /// Get all integrations (regardless of user)
  ///
  /// Used to find any integrations that were created during onboarding
  /// before the user profile was finalized.
  Future<List<IntegrationModel>> getAllIntegrations() async {
    final results = await _db.select(_db.integrationsTable).get();
    return results.map(_toModel).toList();
  }
}
