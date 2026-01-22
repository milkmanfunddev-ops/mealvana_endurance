import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/data/syncable_repository.dart';
import '../domain/coach.dart';
import '../domain/coach_athlete_relationship.dart';
import '../domain/coach_message.dart';

part 'coach_repository.g.dart';

@riverpod
CoachRepository coachRepository(Ref ref) {
  return CoachRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Repository for managing coach mode data following FOA pattern
/// Implements SyncableRepository for new sync architecture
/// Handles coach-athlete relationships and bidirectional messaging
/// Note: Coach status is determined by approved record in coaches table (set by admin)
class CoachRepository with SyncableRepository {
  const CoachRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  static const _uuid = Uuid();

  // ============================================================================
  // SyncableRepository Implementation
  // ============================================================================

  @override
  String get repositoryKey => 'coaches';

  @override
  List<String> get dependencies => ['users'];

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing coach data from Supabase',
        context: 'COACH_REPOSITORY',
        data: {'userId': userId},
      );

      int totalSynced = 0;

      // 1. Sync coach record if user is a coach
      final coachResponse = await _supabase
          .from('coaches')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (coachResponse != null) {
        final coachJson = coachResponse;
        final now = DateTime.now();

        // Upsert coach record to local Drift database
        await _database
            .into(_database.coachesTable)
            .insertOnConflictUpdate(CoachesTableCompanion.insert(
              id: coachJson['id'] as String,
              userId: coachJson['user_id'] as String,
              firstName: coachJson['first_name'] as String,
              lastName: coachJson['last_name'] as String,
              email: coachJson['email'] as String,
              bio: Value(coachJson['bio'] as String?),
              applicationStatus: Value(coachJson['application_status'] as String? ?? 'pending'),
              reviewedBy: Value(coachJson['reviewed_by'] as String?),
              reviewedAt: Value(coachJson['reviewed_at'] != null
                  ? DateTime.parse(coachJson['reviewed_at'] as String)
                  : null),
              rejectionReason: Value(coachJson['rejection_reason'] as String?),
              createdAt: Value(coachJson['created_at'] != null
                  ? DateTime.parse(coachJson['created_at'] as String)
                  : now),
              updatedAt: Value(coachJson['updated_at'] != null
                  ? DateTime.parse(coachJson['updated_at'] as String)
                  : now),
            ));

        totalSynced++;
      }

      // 2. Sync coach_athlete_relationships where user is coach OR athlete
      final relationshipsResponse = await _supabase
          .from('coach_athlete_relationships')
          .select('*')
          .or('coach_user_id.eq.$userId,athlete_user_id.eq.$userId')
          .order('created_at', ascending: false);

      final relationships = relationshipsResponse as List<dynamic>;

      if (relationships.isNotEmpty) {
        // Batch insert relationships
        await _database.batch((batch) {
          for (final relJson in relationships) {
            final r = relJson as Map<String, dynamic>;
            final now = DateTime.now();

            final companion = CoachAthleteRelationshipsTableCompanion.insert(
              id: r['id'] as String,
              coachUserId: r['coach_user_id'] as String,
              athleteUserId: r['athlete_user_id'] as String,
              status: Value(r['status'] as String? ?? 'pending'),
              requestedBy: r['requested_by'] as String,
              requestedAt: Value(r['requested_at'] != null
                  ? DateTime.parse(r['requested_at'] as String)
                  : now),
              acceptedAt: Value(r['accepted_at'] != null
                  ? DateTime.parse(r['accepted_at'] as String)
                  : null),
              declinedAt: Value(r['declined_at'] != null
                  ? DateTime.parse(r['declined_at'] as String)
                  : null),
              archivedAt: Value(r['archived_at'] != null
                  ? DateTime.parse(r['archived_at'] as String)
                  : null),
              createdAt: Value(r['created_at'] != null
                  ? DateTime.parse(r['created_at'] as String)
                  : now),
              updatedAt: Value(r['updated_at'] != null
                  ? DateTime.parse(r['updated_at'] as String)
                  : now),
            );

            batch.insert(
              _database.coachAthleteRelationshipsTable,
              companion,
              mode: InsertMode.insertOrReplace,
            );
          }
        });

        totalSynced += relationships.length;
      }

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Successfully synced coach data',
        context: 'COACH_REPOSITORY',
        data: {
          'userId': userId,
          'coachRecord': coachResponse != null ? 1 : 0,
          'relationships': relationships.length,
          'total': totalSynced,
        },
      );

      return SyncResult.successful(totalSynced);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync coach data from Supabase',
        context: 'COACH_REPOSITORY',
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
        'Uploading dirty coach records to Supabase',
        context: 'COACH_REPOSITORY',
        data: {'userId': userId},
      );

      // NOTE: CoachRepository tables (coaches, coach_athlete_relationships) do not have
      // needs_upload columns like other repositories. The existing methods already
      // write directly to both Drift AND Supabase (see createRelationship, acceptRelationship, etc.).
      // This is a dual-write pattern for cross-device realtime sync.
      //
      // For this sync architecture implementation, uploadDirtyRecords is a no-op
      // because there are no dirty records to upload - all changes are already synced
      // to Supabase immediately when they occur.

      _logger.debug(
        'CoachRepository uses dual-write pattern - no dirty records to upload',
        context: 'COACH_REPOSITORY',
        data: {'userId': userId},
      );

      return UploadResult.nothingToUpload();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty coach records',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ============================================================================
  // COACH INFO OPERATIONS (from coaches table)
  // ============================================================================

  /// Get coach info for a user (from coaches table)
  /// Returns null if user is not an approved coach
  Future<CoachInfo?> getCoachInfoByUserId(String userId) async {
    try {
      // Check the local coaches table for an approved record
      final result = await (_database.select(_database.coachesTable)
            ..where((t) => t.userId.equals(userId) & t.applicationStatus.equals('approved')))
          .getSingleOrNull();

      if (result == null) return null;

      // Get user profile for device ID
      final userProfile = await (_database.select(_database.userProfilesTable)
            ..where((t) => t.id.equals(userId)))
          .getSingleOrNull();

      return CoachInfo(
        userId: result.userId,
        deviceId: userProfile?.deviceId ?? '',
        isCoach: true, // If we have an approved record, they're a coach
        displayName: '${result.firstName} ${result.lastName}'.trim(),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get coach info by user ID',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all approved coaches from the coaches table (for coach directory)
  Future<List<CoachInfo>> getActiveCoaches() async {
    try {
      // Query Supabase coaches table for approved coaches
      final response = await _supabase
          .from('coaches')
          .select('user_id, first_name, last_name, email, bio')
          .eq('application_status', 'approved')
          .order('created_at', ascending: true);

      final List<dynamic> results = response as List<dynamic>;

      return results
          .map((r) => CoachInfo(
                userId: r['user_id'] as String,
                deviceId: '', // Not needed for directory listing
                isCoach: true,
                displayName: r['first_name'] as String?,
              ))
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active coaches',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // RELATIONSHIP OPERATIONS
  // ============================================================================

  /// Get all relationships for a coach (user with is_coach=true)
  /// Joins with user_profiles to get athlete display names
  Future<List<CoachAthleteRelationship>> getRelationshipsForCoach(
    String coachUserId,
  ) async {
    try {
      // Join with user_profiles to get athlete display name
      final query = _database.select(_database.coachAthleteRelationshipsTable).join([
        leftOuterJoin(
          _database.userProfilesTable,
          _database.userProfilesTable.id.equalsExp(_database.coachAthleteRelationshipsTable.athleteUserId),
        ),
      ])
        ..where(_database.coachAthleteRelationshipsTable.coachUserId.equals(coachUserId))
        ..orderBy([OrderingTerm.desc(_database.coachAthleteRelationshipsTable.createdAt)]);

      final results = await query.get();

      return results.map((row) {
        final relationship = row.readTable(_database.coachAthleteRelationshipsTable);
        final athleteProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          athleteDisplayName: _getDisplayNameFromProfile(athleteProfile, relationship.athleteUserId),
        );
      }).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get relationships for coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all relationships for an athlete with coach display names
  Future<List<CoachAthleteRelationship>> getRelationshipsForAthlete(
    String athleteUserId,
  ) async {
    try {
      // Join with both coaches and user_profiles tables to get coach display name
      // Priority: coaches table (has first_name/last_name) > user_profiles (has sender_name)
      final query = _database.select(_database.coachAthleteRelationshipsTable).join([
        leftOuterJoin(
          _database.coachesTable,
          _database.coachesTable.userId.equalsExp(_database.coachAthleteRelationshipsTable.coachUserId),
        ),
        leftOuterJoin(
          _database.userProfilesTable,
          _database.userProfilesTable.id.equalsExp(_database.coachAthleteRelationshipsTable.coachUserId),
        ),
      ])
        ..where(_database.coachAthleteRelationshipsTable.athleteUserId.equals(athleteUserId))
        ..orderBy([OrderingTerm.desc(_database.coachAthleteRelationshipsTable.createdAt)]);

      final results = await query.get();

      return results.map((row) {
        final relationship = row.readTable(_database.coachAthleteRelationshipsTable);
        final coachEntry = row.readTableOrNull(_database.coachesTable);
        final coachProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          coachDisplayName: _getCoachDisplayName(coachEntry, coachProfile, relationship.coachUserId),
        );
      }).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get relationships for athlete',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get active relationships for a coach
  /// Joins with user_profiles to get athlete display names
  Future<List<CoachAthleteRelationship>> getActiveRelationshipsForCoach(
    String coachUserId,
  ) async {
    try {
      // Join with user_profiles to get athlete display name
      final query = _database.select(_database.coachAthleteRelationshipsTable).join([
        leftOuterJoin(
          _database.userProfilesTable,
          _database.userProfilesTable.id.equalsExp(_database.coachAthleteRelationshipsTable.athleteUserId),
        ),
      ])
        ..where(_database.coachAthleteRelationshipsTable.coachUserId.equals(coachUserId) &
                _database.coachAthleteRelationshipsTable.status.equals('active'))
        ..orderBy([OrderingTerm.asc(_database.coachAthleteRelationshipsTable.createdAt)]);

      final results = await query.get();

      return results.map((row) {
        final relationship = row.readTable(_database.coachAthleteRelationshipsTable);
        final athleteProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          athleteDisplayName: _getDisplayNameFromProfile(athleteProfile, relationship.athleteUserId),
        );
      }).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active relationships for coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if there is an active coach-athlete relationship
  /// Used to validate if a coach can create/edit activities for an athlete
  /// Returns true if coach has active relationship with athlete, false otherwise
  Future<bool> isActiveCoachAthleteRelationship({
    required String coachUserId,
    required String athleteUserId,
  }) async {
    try {
      final relationship = await (_database
              .select(_database.coachAthleteRelationshipsTable)
            ..where((r) =>
                r.coachUserId.equals(coachUserId) &
                r.athleteUserId.equals(athleteUserId) &
                r.status.equals('active')))
          .getSingleOrNull();

      return relationship != null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check coach-athlete relationship',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Create a new coach-athlete relationship request
  /// Writes to both local Drift database AND Supabase for cross-device sync
  Future<CoachAthleteRelationship> createRelationship({
    required String coachUserId,
    required String athleteUserId,
    required String requestedBy,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      // Insert into Supabase first (for cross-device sync)
      await _supabase.from('coach_athlete_relationships').insert({
        'id': id,
        'coach_user_id': coachUserId,
        'athlete_user_id': athleteUserId,
        'status': 'pending',
        'requested_by': requestedBy,
        'requested_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Also save to local Drift database
      final companion = CoachAthleteRelationshipsTableCompanion.insert(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        requestedBy: requestedBy,
        requestedAt: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _database
          .into(_database.coachAthleteRelationshipsTable)
          .insert(companion);

      return CoachAthleteRelationship(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        status: RelationshipStatus.pending,
        requestedBy: requestedBy,
        requestedAt: now,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create relationship',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Accept a relationship request
  /// Updates both local Drift database AND Supabase for cross-device sync
  Future<CoachAthleteRelationship> acceptRelationship(
      String relationshipId) async {
    try {
      final now = DateTime.now();

      // Update Supabase first (for cross-device sync)
      await _supabase
          .from('coach_athlete_relationships')
          .update({
            'status': 'active',
            'accepted_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', relationshipId);

      // Update local Drift database
      await (_database.update(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.id.equals(relationshipId)))
          .write(CoachAthleteRelationshipsTableCompanion(
        status: const Value('active'),
        acceptedAt: Value(now),
        updatedAt: Value(now),
      ));

      final result =
          await (_database.select(_database.coachAthleteRelationshipsTable)
                ..where((t) => t.id.equals(relationshipId)))
              .getSingle();

      return _mapToRelationshipDomain(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to accept relationship',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Decline a relationship request
  /// Updates both local Drift database AND Supabase for cross-device sync
  Future<CoachAthleteRelationship> declineRelationship(
      String relationshipId) async {
    try {
      final now = DateTime.now();

      // Update Supabase first (for cross-device sync)
      await _supabase
          .from('coach_athlete_relationships')
          .update({
            'status': 'declined',
            'declined_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', relationshipId);

      // Update local Drift database
      await (_database.update(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.id.equals(relationshipId)))
          .write(CoachAthleteRelationshipsTableCompanion(
        status: const Value('declined'),
        declinedAt: Value(now),
        updatedAt: Value(now),
      ));

      final result =
          await (_database.select(_database.coachAthleteRelationshipsTable)
                ..where((t) => t.id.equals(relationshipId)))
              .getSingle();

      return _mapToRelationshipDomain(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to decline relationship',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Archive a relationship
  /// Updates both local Drift database AND Supabase for cross-device sync
  Future<CoachAthleteRelationship> archiveRelationship(
      String relationshipId) async {
    try {
      final now = DateTime.now();

      // Update Supabase first (for cross-device sync)
      await _supabase
          .from('coach_athlete_relationships')
          .update({
            'status': 'archived',
            'archived_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('id', relationshipId);

      // Update local Drift database
      await (_database.update(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.id.equals(relationshipId)))
          .write(CoachAthleteRelationshipsTableCompanion(
        status: const Value('archived'),
        archivedAt: Value(now),
        updatedAt: Value(now),
      ));

      final result =
          await (_database.select(_database.coachAthleteRelationshipsTable)
                ..where((t) => t.id.equals(relationshipId)))
              .getSingle();

      return _mapToRelationshipDomain(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to archive relationship',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Subscribe to relationship changes for a user (coach or athlete)
  /// Returns a RealtimeChannel that should be unsubscribed when done
  RealtimeChannel subscribeToRelationshipChanges({
    required String userId,
    required void Function(CoachAthleteRelationship) onRelationshipChanged,
  }) {
    final channelName = 'relationships:$userId';

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'coach_athlete_relationships',
          callback: (payload) async {
            try {
              final record = payload.newRecord.isNotEmpty
                  ? payload.newRecord
                  : payload.oldRecord;

              // Check if this relationship involves our user
              final coachUserId = record['coach_user_id'] as String?;
              final athleteUserId = record['athlete_user_id'] as String?;

              if (coachUserId != userId && athleteUserId != userId) return;

              // For inserts and updates, sync to local DB and notify
              if (payload.eventType != PostgresChangeEvent.delete) {
                final now = DateTime.now();
                final relationship = CoachAthleteRelationship(
                  id: record['id'] as String,
                  coachUserId: record['coach_user_id'] as String,
                  athleteUserId: record['athlete_user_id'] as String,
                  status: RelationshipStatus.fromString(
                      record['status'] as String? ?? 'pending'),
                  requestedBy: record['requested_by'] as String,
                  requestedAt: record['requested_at'] != null
                      ? DateTime.parse(record['requested_at'] as String)
                      : now,
                  acceptedAt: record['accepted_at'] != null
                      ? DateTime.parse(record['accepted_at'] as String)
                      : null,
                  declinedAt: record['declined_at'] != null
                      ? DateTime.parse(record['declined_at'] as String)
                      : null,
                  archivedAt: record['archived_at'] != null
                      ? DateTime.parse(record['archived_at'] as String)
                      : null,
                  createdAt: record['created_at'] != null
                      ? DateTime.parse(record['created_at'] as String)
                      : now,
                  updatedAt: record['updated_at'] != null
                      ? DateTime.parse(record['updated_at'] as String)
                      : now,
                );

                // Sync to local database
                await _syncRelationshipToLocal(relationship);

                onRelationshipChanged(relationship);
              }
            } catch (e, stackTrace) {
              _logger.error(
                'Failed to process realtime relationship change',
                context: 'COACH_REPOSITORY',
                error: e,
                stackTrace: stackTrace,
              );
            }
          },
        )
        .subscribe();

    return channel;
  }

  /// Unsubscribe from relationship changes
  Future<void> unsubscribeFromRelationshipChanges(
      RealtimeChannel channel) async {
    try {
      await channel.unsubscribe();
      await _supabase.removeChannel(channel);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to unsubscribe from relationship changes',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Sync a relationship from Supabase to local Drift database
  Future<void> _syncRelationshipToLocal(
      CoachAthleteRelationship relationship) async {
    try {
      final companion = CoachAthleteRelationshipsTableCompanion(
        id: Value(relationship.id),
        coachUserId: Value(relationship.coachUserId),
        athleteUserId: Value(relationship.athleteUserId),
        status: Value(relationship.status.name),
        requestedBy: Value(relationship.requestedBy),
        requestedAt: Value(relationship.requestedAt),
        acceptedAt: Value(relationship.acceptedAt),
        declinedAt: Value(relationship.declinedAt),
        archivedAt: Value(relationship.archivedAt),
        createdAt: Value(relationship.createdAt),
        updatedAt: Value(relationship.updatedAt),
      );

      await _database
          .into(_database.coachAthleteRelationshipsTable)
          .insertOnConflictUpdate(companion);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync relationship to local DB',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Fetch all relationships for a user from Supabase and sync to local DB
  /// Call this on dashboard load to ensure local DB is up-to-date
  Future<List<CoachAthleteRelationship>> syncRelationshipsFromSupabase(
      String userId) async {
    try {
      // Fetch relationships where user is coach OR athlete
      final response = await _supabase
          .from('coach_athlete_relationships')
          .select()
          .or('coach_user_id.eq.$userId,athlete_user_id.eq.$userId')
          .order('created_at', ascending: false);

      final List<dynamic> results = response as List<dynamic>;
      final relationships = <CoachAthleteRelationship>[];

      final now = DateTime.now();
      for (final r in results) {
        final relationship = CoachAthleteRelationship(
          id: r['id'] as String,
          coachUserId: r['coach_user_id'] as String,
          athleteUserId: r['athlete_user_id'] as String,
          status:
              RelationshipStatus.fromString(r['status'] as String? ?? 'pending'),
          requestedBy: r['requested_by'] as String,
          requestedAt: r['requested_at'] != null
              ? DateTime.parse(r['requested_at'] as String)
              : now,
          acceptedAt: r['accepted_at'] != null
              ? DateTime.parse(r['accepted_at'] as String)
              : null,
          declinedAt: r['declined_at'] != null
              ? DateTime.parse(r['declined_at'] as String)
              : null,
          archivedAt: r['archived_at'] != null
              ? DateTime.parse(r['archived_at'] as String)
              : null,
          createdAt: r['created_at'] != null
              ? DateTime.parse(r['created_at'] as String)
              : now,
          updatedAt: r['updated_at'] != null
              ? DateTime.parse(r['updated_at'] as String)
              : now,
        );

        // Sync to local database
        await _syncRelationshipToLocal(relationship);
        relationships.add(relationship);
      }

      return relationships;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync relationships from Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Return empty list on error - local cache may still have data
      return [];
    }
  }

  /// Sync coach records from Supabase to local database
  /// This should be called when loading My Coaches screen to ensure we have coach names
  Future<void> syncCoachesFromSupabase(List<String> coachUserIds) async {
    if (coachUserIds.isEmpty) return;

    try {
      // Fetch coach records from Supabase for the given user IDs
      final response = await _supabase
          .from('coaches')
          .select('*')
          .inFilter('user_id', coachUserIds)
          .eq('application_status', 'approved');

      final List<dynamic> results = response as List<dynamic>;

      for (final r in results) {
        final now = DateTime.now();

        // Upsert into local coaches table
        await _database
            .into(_database.coachesTable)
            .insertOnConflictUpdate(CoachesTableCompanion.insert(
              id: r['id'] as String,
              userId: r['user_id'] as String,
              firstName: r['first_name'] as String,
              lastName: r['last_name'] as String,
              email: r['email'] as String,
              bio: Value(r['bio'] as String?),
              applicationStatus: Value(r['application_status'] as String? ?? 'pending'),
              reviewedBy: Value(r['reviewed_by'] as String?),
              reviewedAt: Value(r['reviewed_at'] != null
                  ? DateTime.parse(r['reviewed_at'] as String)
                  : null),
              rejectionReason: Value(r['rejection_reason'] as String?),
              createdAt: Value(r['created_at'] != null
                  ? DateTime.parse(r['created_at'] as String)
                  : now),
              updatedAt: Value(r['updated_at'] != null
                  ? DateTime.parse(r['updated_at'] as String)
                  : now),
            ));
      }

      _logger.info(
        'Synced ${results.length} coach records from Supabase',
        context: 'COACH_REPOSITORY',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync coaches from Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// Sync athlete profiles from Supabase to local database
  /// This should be called when loading the Coach Dashboard to ensure we have athlete names
  Future<void> syncAthleteProfilesFromSupabase(List<String> athleteUserIds) async {
    if (athleteUserIds.isEmpty) return;

    try {
      // Fetch athlete profiles from Supabase users table
      final response = await _supabase
          .from('users')
          .select('id, first_name, last_name, sender_name')
          .inFilter('id', athleteUserIds);

      final List<dynamic> results = response as List<dynamic>;

      for (final r in results) {
        final id = r['id'] as String?;
        if (id == null) continue;

        // Upsert into local user_profiles table (only name fields)
        final companion = UserProfilesTableCompanion(
          id: Value(id),
          firstName: Value(r['first_name'] as String?),
          lastName: Value(r['last_name'] as String?),
          senderName: Value(r['sender_name'] as String?),
          updatedAt: Value(DateTime.now()),
        );

        await _database
            .into(_database.userProfilesTable)
            .insertOnConflictUpdate(companion);
      }

      _logger.info(
        'Synced ${results.length} athlete profiles from Supabase',
        context: 'COACH_REPOSITORY',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync athlete profiles from Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - this is not critical for app functionality
    }
  }

  // ============================================================================
  // MESSAGE OPERATIONS (bidirectional messaging)
  // ============================================================================

  /// Get ONLY general chat messages (excludes activity and nutrition plan comments)
  /// Used for the dedicated chat screen
  /// Queries Supabase directly for real-time accuracy (historical messages)
  Future<List<CoachMessage>> getGeneralChatMessages({
    required String coachUserId,
    required String athleteUserId,
    int? limit,
  }) async {
    try {
      // Query Supabase directly to get all historical messages
      var query = _supabase
          .from('coach_messages')
          .select('*')
          .eq('coach_user_id', coachUserId)
          .eq('athlete_user_id', athleteUserId)
          .isFilter('activity_id', null)
          .isFilter('nutrition_plan_id', null)
          .order('created_at', ascending: true); // Oldest first for chat display

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      final List<dynamic> data = response as List<dynamic>;

      final messages = data.map((json) {
        final m = json as Map<String, dynamic>;
        return CoachMessage(
          id: m['id'] as String,
          coachUserId: m['coach_user_id'] as String,
          athleteUserId: m['athlete_user_id'] as String,
          senderUserId: m['sender_user_id'] as String,
          messageText: m['message_text'] as String,
          activityId: m['activity_id'] as String?,
          nutritionPlanId: m['nutrition_plan_id'] as String?,
          isRead: m['is_read'] as bool? ?? false,
          createdAt: DateTime.parse(m['created_at'] as String),
          updatedAt: DateTime.parse(m['updated_at'] as String),
        );
      }).toList();

      // Also cache to local Drift for offline access
      for (final message in messages) {
        final companion = CoachMessagesTableCompanion.insert(
          id: message.id,
          coachUserId: message.coachUserId,
          athleteUserId: message.athleteUserId,
          senderUserId: message.senderUserId,
          messageText: message.messageText,
          nutritionPlanId: Value(message.nutritionPlanId),
          activityId: Value(message.activityId),
          isRead: Value(message.isRead),
          createdAt: Value(message.createdAt),
          updatedAt: Value(message.updatedAt),
        );

        await _database
            .into(_database.coachMessagesTable)
            .insert(companion, mode: InsertMode.insertOrReplace);
      }

      return messages;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get general chat messages from Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Subscribe to new messages for a conversation using Supabase Realtime
  /// Returns a RealtimeChannel that should be unsubscribed when done
  RealtimeChannel subscribeToConversation({
    required String coachUserId,
    required String athleteUserId,
    required void Function(CoachMessage) onNewMessage,
  }) {
    final channelName = 'chat:$coachUserId:$athleteUserId';

    _logger.info(
      'Setting up realtime subscription for conversation',
      context: 'COACH_REPOSITORY',
      data: {
        'channelName': channelName,
        'coachUserId': coachUserId,
        'athleteUserId': athleteUserId,
      },
    );

    final channel = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'coach_messages',
          // REMOVED FILTER: Let all messages through, filter in callback
          // This ensures we don't miss messages due to overly restrictive filters
          callback: (payload) {
            _logger.info(
              'Realtime event received',
              context: 'COACH_REPOSITORY',
              data: {
                'eventType': payload.eventType.toString(),
                'table': payload.table,
                'newRecord': payload.newRecord,
              },
            );

            try {
              final newRecord = payload.newRecord;

              // Check if this message is for our conversation
              final messageCoachUserId = newRecord['coach_user_id'] as String?;
              final messageAthleteUserId = newRecord['athlete_user_id'] as String?;

              if (messageCoachUserId != coachUserId || messageAthleteUserId != athleteUserId) {
                _logger.info(
                  'Message not for our conversation, skipping',
                  context: 'COACH_REPOSITORY',
                  data: {
                    'expected_coach_user_id': coachUserId,
                    'expected_athlete_user_id': athleteUserId,
                    'received_coach_user_id': messageCoachUserId,
                    'received_athlete_user_id': messageAthleteUserId,
                  },
                );
                return;
              }

              final message = CoachMessage(
                id: newRecord['id'] as String,
                coachUserId: newRecord['coach_user_id'] as String,
                athleteUserId: newRecord['athlete_user_id'] as String,
                senderUserId: newRecord['sender_user_id'] as String,
                messageText: newRecord['message_text'] as String,
                nutritionPlanId: newRecord['nutrition_plan_id'] as String?,
                activityId: newRecord['activity_id'] as String?,
                isRead: newRecord['is_read'] as bool? ?? false,
                createdAt: DateTime.parse(newRecord['created_at'] as String),
                updatedAt: DateTime.parse(newRecord['updated_at'] as String),
              );

              // Only notify for general messages (not activity/plan comments)
              if (message.isGeneralMessage) {
                _logger.info(
                  'Calling onNewMessage callback',
                  context: 'COACH_REPOSITORY',
                  data: {'messageId': message.id},
                );
                onNewMessage(message);
              } else {
                _logger.info(
                  'Message is not a general message, skipping',
                  context: 'COACH_REPOSITORY',
                  data: {
                    'messageId': message.id,
                    'isActivityComment': message.isActivityComment,
                    'isNutritionPlanComment': message.isNutritionPlanComment,
                  },
                );
              }
            } catch (e, stackTrace) {
              _logger.error(
                'Failed to parse realtime message',
                context: 'COACH_REPOSITORY',
                error: e,
                stackTrace: stackTrace,
              );
            }
          },
        )
        .subscribe();

    _logger.info(
      'Realtime subscription created and subscribed',
      context: 'COACH_REPOSITORY',
      data: {
        'channelName': channelName,
      },
    );

    return channel;
  }

  /// Unsubscribe from a conversation channel
  Future<void> unsubscribeFromConversation(RealtimeChannel channel) async {
    try {
      await channel.unsubscribe();
      await _supabase.removeChannel(channel);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to unsubscribe from conversation',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send a chat message to Supabase (for realtime sync)
  /// Also saves to local Drift database
  Future<CoachMessage> sendChatMessageToSupabase({
    required String coachUserId,
    required String athleteUserId,
    required String senderUserId,
    required String messageText,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();

      // Insert into Supabase first (this triggers realtime for other party)
      await _supabase.from('coach_messages').insert({
        'id': id,
        'coach_user_id': coachUserId,
        'athlete_user_id': athleteUserId,
        'sender_user_id': senderUserId,
        'message_text': messageText,
        'is_read': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        // activity_id and nutrition_plan_id are NULL for general chat
      });

      // Also save to local Drift database
      final companion = CoachMessagesTableCompanion.insert(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        isRead: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      await _database.into(_database.coachMessagesTable).insert(companion);

      return CoachMessage(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        isRead: false,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to send chat message to Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a relationship by ID (works for both coach and athlete perspective)
  Future<CoachAthleteRelationship?> getRelationshipById(
      String relationshipId) async {
    try {
      // Join with coaches and user_profiles tables to get coach display name
      final query = _database
          .select(_database.coachAthleteRelationshipsTable)
          .join([
        leftOuterJoin(
          _database.coachesTable,
          _database.coachesTable.userId.equalsExp(
              _database.coachAthleteRelationshipsTable.coachUserId),
        ),
        leftOuterJoin(
          _database.userProfilesTable,
          _database.userProfilesTable.id.equalsExp(
              _database.coachAthleteRelationshipsTable.coachUserId),
        ),
      ])
        ..where(
            _database.coachAthleteRelationshipsTable.id.equals(relationshipId));

      final results = await query.get();
      if (results.isEmpty) return null;

      final row = results.first;
      final relationship =
          row.readTable(_database.coachAthleteRelationshipsTable);
      final coachEntry = row.readTableOrNull(_database.coachesTable);
      final coachProfile = row.readTableOrNull(_database.userProfilesTable);

      // Also try to get athlete display name
      final athleteProfile = await (_database.select(_database.userProfilesTable)
            ..where((t) => t.id.equals(relationship.athleteUserId)))
          .getSingleOrNull();

      return _mapToRelationshipDomain(
        relationship,
        coachDisplayName: _getCoachDisplayName(coachEntry, coachProfile, relationship.coachUserId),
        athleteDisplayName: _getDisplayNameFromProfile(athleteProfile, relationship.athleteUserId),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get relationship by ID',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get messages for a coach-athlete conversation
  Future<List<CoachMessage>> getMessagesForConversation({
    required String coachUserId,
    required String athleteUserId,
    int? limit,
  }) async {
    try {
      var query = _database.select(_database.coachMessagesTable)
        ..where((t) =>
            t.coachUserId.equals(coachUserId) &
            t.athleteUserId.equals(athleteUserId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      if (limit != null) {
        query = query..limit(limit);
      }

      final results = await query.get();
      return results.map(_mapToMessageDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get messages for conversation',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get messages/comments for a nutrition plan
  Future<List<CoachMessage>> getMessagesForNutritionPlan(
      String nutritionPlanId) async {
    try {
      final results = await (_database.select(_database.coachMessagesTable)
            ..where((t) => t.nutritionPlanId.equals(nutritionPlanId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      return results.map(_mapToMessageDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get messages for nutrition plan',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get messages/comments for an activity
  Future<List<CoachMessage>> getMessagesForActivity(String activityId) async {
    try {
      final results = await (_database.select(_database.coachMessagesTable)
            ..where((t) => t.activityId.equals(activityId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      return results.map(_mapToMessageDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get messages for activity',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      // User can be either coach or athlete in the conversation
      // Count messages where they are the recipient (not the sender) and unread
      final results = await (_database.select(_database.coachMessagesTable)
            ..where((t) =>
                (t.coachUserId.equals(userId) | t.athleteUserId.equals(userId)) &
                t.senderUserId.isNotValue(userId) &
                t.isRead.equals(false)))
          .get();

      return results.length;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get unread message count',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Send a message in a coach-athlete conversation
  /// Writes to both Supabase (for cross-device sync) AND local Drift database
  Future<CoachMessage> sendMessage({
    required String coachUserId,
    required String athleteUserId,
    required String senderUserId,
    required String messageText,
    String? nutritionPlanId,
    String? activityId,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().toUtc();

      // Insert into Supabase first (for cross-device sync and realtime)
      await _supabase.from('coach_messages').insert({
        'id': id,
        'coach_user_id': coachUserId,
        'athlete_user_id': athleteUserId,
        'sender_user_id': senderUserId,
        'message_text': messageText,
        'nutrition_plan_id': nutritionPlanId,
        'activity_id': activityId,
        'is_read': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // Also save to local Drift database
      final companion = CoachMessagesTableCompanion.insert(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        nutritionPlanId: Value(nutritionPlanId),
        activityId: Value(activityId),
        isRead: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _database.into(_database.coachMessagesTable).insert(companion);

      return CoachMessage(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: senderUserId,
        messageText: messageText,
        nutritionPlanId: nutritionPlanId,
        activityId: activityId,
        isRead: false,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to send message',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead({
    required String coachUserId,
    required String athleteUserId,
    required String readerUserId,
  }) async {
    try {
      // Mark all messages in this conversation as read where:
      // - The reader is not the sender (they're the recipient)
      await (_database.update(_database.coachMessagesTable)
            ..where((t) =>
                t.coachUserId.equals(coachUserId) &
                t.athleteUserId.equals(athleteUserId) &
                t.senderUserId.isNotValue(readerUserId) &
                t.isRead.equals(false)))
          .write(CoachMessagesTableCompanion(
        isRead: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark messages as read',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete a message (only sender can delete)
  Future<void> deleteMessage(String messageId) async {
    try {
      await (_database.delete(_database.coachMessagesTable)
            ..where((t) => t.id.equals(messageId)))
          .go();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete message',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // USER PROFILE OPERATIONS (for coach mode)
  // ============================================================================

  /// Look up a user ID by their athlete code
  /// Athlete code format: ATH-XXXXXXXX (first 8 chars of UUID, uppercase, no hyphens)
  /// Returns the full user ID if found, null otherwise
  Future<String?> findUserIdByAthleteCode(String athleteCode) async {
    try {
      // Validate and extract the code
      final code = athleteCode.toUpperCase().trim();
      if (!code.startsWith('ATH-') || code.length != 12) {
        _logger.warning(
          'Invalid athlete code format',
          context: 'COACH_REPOSITORY',
          data: {'code': code},
        );
        return null;
      }

      final codePrefix = code.substring(4); // Remove 'ATH-' prefix

      // First try locally from Drift
      final localResults = await _database.select(_database.userProfilesTable).get();
      for (final user in localResults) {
        final cleanId = user.id.replaceAll('-', '').toUpperCase();
        if (cleanId.startsWith(codePrefix)) {
          return user.id;
        }
      }

      // If not found locally, try Supabase
      // Use ilike to match the beginning of the ID
      final response = await _supabase.from('users').select('id');

      for (final row in response) {
        final userId = row['id'] as String?;
        if (userId != null) {
          final cleanId = userId.replaceAll('-', '').toUpperCase();
          if (cleanId.startsWith(codePrefix)) {
            return userId;
          }
        }
      }

      _logger.warning(
        'User not found by athlete code',
        context: 'COACH_REPOSITORY',
        data: {'code': code},
      );
      return null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to find user by athlete code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ============================================================================
  // COACH STATUS OPERATIONS (using coaches table)
  // ============================================================================

  /// Check if a user is an approved coach by querying the local coaches table
  /// This is the primary method to determine coach status
  Future<bool> isUserApprovedCoach(String userId) async {
    try {
      final result = await (_database.select(_database.coachesTable)
            ..where((t) => t.userId.equals(userId) & t.applicationStatus.equals('approved')))
          .getSingleOrNull();

      return result != null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check if user is approved coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Get the coach record for a user from local database (if they are a coach)
  Future<Coach?> getCoachRecordForUser(String userId) async {
    try {
      final result = await (_database.select(_database.coachesTable)
            ..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

      if (result == null) return null;

      return Coach(
        id: result.id,
        userId: result.userId,
        firstName: result.firstName,
        lastName: result.lastName,
        email: result.email,
        bio: result.bio,
        status: result.applicationStatus,
        reviewedBy: result.reviewedBy,
        reviewedAt: result.reviewedAt,
        rejectionReason: result.rejectionReason,
        createdAt: result.createdAt,
        updatedAt: result.updatedAt,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get coach record for user',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Fetch the latest coach status from Supabase coaches table for a user
  /// Returns true if user has an approved coach record, false otherwise
  Future<bool?> fetchIsCoachFromSupabase(String userId) async {
    try {
      // Check the coaches table for an approved record
      final response = await _supabase
          .from('coaches')
          .select('application_status')
          .eq('user_id', userId)
          .eq('application_status', 'approved')
          .maybeSingle();

      // User is a coach if they have an approved record
      return response != null;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch coach status from Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ============================================================================
  // COACH APPLICATION OPERATIONS
  // ============================================================================

  /// Submit a coach application
  /// Creates a new entry in the coaches table with pending status
  Future<bool> submitCoachApplication({
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    String? bio,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      // Insert into Supabase coaches table
      await _supabase.from('coaches').insert({
        'id': id,
        'user_id': userId,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'bio': bio,
        'application_status': 'pending',
        'submitted_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to submit coach application',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get coach display name, prioritizing coaches table over user_profiles
  /// Priority: coaches table (first_name + last_name) > user_profiles (firstName/lastName/senderName) > userId fallback
  String? _getCoachDisplayName(CoachEntry? coachEntry, UserProfileEntry? profile, String userId) {
    // Priority 1: Try coaches table first (where coaches submit their application)
    if (coachEntry != null) {
      final firstName = coachEntry.firstName.trim();
      final lastName = coachEntry.lastName.trim();

      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }

      if (firstName.isNotEmpty) {
        return firstName;
      }

      if (lastName.isNotEmpty) {
        return lastName;
      }
    }

    // Priority 2: Fall back to user_profiles table
    if (profile != null) {
      final hasFirstName = profile.firstName != null && profile.firstName!.trim().isNotEmpty;
      final hasLastName = profile.lastName != null && profile.lastName!.trim().isNotEmpty;

      if (hasFirstName && hasLastName) {
        return '${profile.firstName!.trim()} ${profile.lastName!.trim()}';
      }

      if (hasFirstName) {
        return profile.firstName!.trim();
      }

      if (hasLastName) {
        return profile.lastName!.trim();
      }

      // Try sender_name field (legacy)
      if (profile.senderName != null && profile.senderName!.trim().isNotEmpty) {
        return profile.senderName!.trim();
      }
    }

    // Fallback: Shortened user ID (remove hyphens for cleaner display)
    return 'Coach ${userId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
  }

  /// Get display name from a user profile entry
  /// Priority: firstName + lastName > firstName only > lastName only > senderName > userId fallback
  String? _getDisplayNameFromProfile(UserProfileEntry? profile, String userId) {
    if (profile == null) {
      // Fallback to shortened user ID
      return 'Athlete ${userId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
    }

    // Priority 1: Full name (first + last)
    final hasFirstName = profile.firstName != null && profile.firstName!.trim().isNotEmpty;
    final hasLastName = profile.lastName != null && profile.lastName!.trim().isNotEmpty;

    if (hasFirstName && hasLastName) {
      return '${profile.firstName!.trim()} ${profile.lastName!.trim()}';
    }

    // Priority 2: First name only
    if (hasFirstName) {
      return profile.firstName!.trim();
    }

    // Priority 3: Last name only
    if (hasLastName) {
      return profile.lastName!.trim();
    }

    // Priority 4: Sender name (legacy field)
    if (profile.senderName != null && profile.senderName!.trim().isNotEmpty) {
      return profile.senderName!.trim();
    }

    // Fallback: Shortened user ID (remove hyphens for cleaner display)
    return 'Athlete ${userId.replaceAll('-', '').substring(0, 8).toUpperCase()}';
  }

  /// Map Drift CoachAthleteRelationshipEntry to domain
  CoachAthleteRelationship _mapToRelationshipDomain(
    CoachAthleteRelationshipEntry entry, {
    String? coachDisplayName,
    String? athleteDisplayName,
  }) {
    return CoachAthleteRelationship(
      id: entry.id,
      coachUserId: entry.coachUserId,
      athleteUserId: entry.athleteUserId,
      status: RelationshipStatus.fromString(entry.status),
      requestedBy: entry.requestedBy,
      requestedAt: entry.requestedAt,
      acceptedAt: entry.acceptedAt,
      declinedAt: entry.declinedAt,
      archivedAt: entry.archivedAt,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      coachDisplayName: coachDisplayName,
      athleteDisplayName: athleteDisplayName,
    );
  }

  /// Map Drift CoachMessageEntry to domain
  CoachMessage _mapToMessageDomain(CoachMessageEntry entry) {
    return CoachMessage(
      id: entry.id,
      coachUserId: entry.coachUserId,
      athleteUserId: entry.athleteUserId,
      senderUserId: entry.senderUserId,
      messageText: entry.messageText,
      nutritionPlanId: entry.nutritionPlanId,
      activityId: entry.activityId,
      isRead: entry.isRead,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }
}
