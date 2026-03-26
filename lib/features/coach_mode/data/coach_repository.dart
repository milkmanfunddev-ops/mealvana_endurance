import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/data/syncable_repository.dart';
import '../domain/coach.dart';
import '../domain/coach_athlete_relationship.dart';
import '../domain/pairing_code_connection_result.dart';

part 'coach_repository.g.dart';

@riverpod
CoachRepository coachRepository(Ref ref) {
  final deps = ref.read(appExternalDepsProvider);
  return CoachRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    sentry: deps.sentry,
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

  // ============================================================================
  // SyncableRepository Implementation
  // ============================================================================

  @override
  String get repositoryKey => 'coaches';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

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
            .insertOnConflictUpdate(
              CoachesTableCompanion.insert(
                id: coachJson['id'] as String,
                userId: coachJson['user_id'] as String,
                firstName: coachJson['first_name'] as String,
                lastName: coachJson['last_name'] as String,
                email: coachJson['email'] as String,
                bio: Value(coachJson['bio'] as String?),
                applicationStatus: Value(
                  coachJson['application_status'] as String? ?? 'pending',
                ),
                reviewedBy: Value(coachJson['reviewed_by'] as String?),
                reviewedAt: Value(
                  coachJson['reviewed_at'] != null
                      ? DateTime.parse(coachJson['reviewed_at'] as String)
                      : null,
                ),
                rejectionReason: Value(
                  coachJson['rejection_reason'] as String?,
                ),
                createdAt: Value(
                  coachJson['created_at'] != null
                      ? DateTime.parse(coachJson['created_at'] as String)
                      : now,
                ),
                updatedAt: Value(
                  coachJson['updated_at'] != null
                      ? DateTime.parse(coachJson['updated_at'] as String)
                      : now,
                ),
              ),
            );

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
              requestedAt: Value(
                r['requested_at'] != null
                    ? DateTime.parse(r['requested_at'] as String)
                    : now,
              ),
              acceptedAt: Value(
                r['accepted_at'] != null
                    ? DateTime.parse(r['accepted_at'] as String)
                    : null,
              ),
              declinedAt: Value(
                r['declined_at'] != null
                    ? DateTime.parse(r['declined_at'] as String)
                    : null,
              ),
              archivedAt: Value(
                r['archived_at'] != null
                    ? DateTime.parse(r['archived_at'] as String)
                    : null,
              ),
              createdAt: Value(
                r['created_at'] != null
                    ? DateTime.parse(r['created_at'] as String)
                    : now,
              ),
              updatedAt: Value(
                r['updated_at'] != null
                    ? DateTime.parse(r['updated_at'] as String)
                    : now,
              ),
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
      final result =
          await (_database.select(_database.coachesTable)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.applicationStatus.equals('approved'),
              ))
              .getSingleOrNull();

      if (result == null) return null;

      // Get user profile for device ID
      final userProfile = await (_database.select(
        _database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();

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
          .map(
            (r) => CoachInfo(
              userId: r['user_id'] as String,
              deviceId: '', // Not needed for directory listing
              isCoach: true,
              displayName: r['first_name'] as String?,
            ),
          )
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
      final query =
          _database.select(_database.coachAthleteRelationshipsTable).join([
              leftOuterJoin(
                _database.userProfilesTable,
                _database.userProfilesTable.id.equalsExp(
                  _database.coachAthleteRelationshipsTable.athleteUserId,
                ),
              ),
            ])
            ..where(
              _database.coachAthleteRelationshipsTable.coachUserId.equals(
                coachUserId,
              ),
            )
            ..orderBy([
              OrderingTerm.desc(
                _database.coachAthleteRelationshipsTable.createdAt,
              ),
            ]);

      final results = await query.get();

      return results.map((row) {
        final relationship = row.readTable(
          _database.coachAthleteRelationshipsTable,
        );
        final athleteProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          athleteDisplayName: _getDisplayNameFromProfile(
            athleteProfile,
            relationship.athleteUserId,
          ),
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
      final query =
          _database.select(_database.coachAthleteRelationshipsTable).join([
              leftOuterJoin(
                _database.coachesTable,
                _database.coachesTable.userId.equalsExp(
                  _database.coachAthleteRelationshipsTable.coachUserId,
                ),
              ),
              leftOuterJoin(
                _database.userProfilesTable,
                _database.userProfilesTable.id.equalsExp(
                  _database.coachAthleteRelationshipsTable.coachUserId,
                ),
              ),
            ])
            ..where(
              _database.coachAthleteRelationshipsTable.athleteUserId.equals(
                athleteUserId,
              ),
            )
            ..orderBy([
              OrderingTerm.desc(
                _database.coachAthleteRelationshipsTable.createdAt,
              ),
            ]);

      final results = await query.get();

      return results.map((row) {
        final relationship = row.readTable(
          _database.coachAthleteRelationshipsTable,
        );
        final coachEntry = row.readTableOrNull(_database.coachesTable);
        final coachProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          coachDisplayName: _getCoachDisplayName(
            coachEntry,
            coachProfile,
            relationship.coachUserId,
          ),
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
      final query =
          _database.select(_database.coachAthleteRelationshipsTable).join([
              leftOuterJoin(
                _database.userProfilesTable,
                _database.userProfilesTable.id.equalsExp(
                  _database.coachAthleteRelationshipsTable.athleteUserId,
                ),
              ),
            ])
            ..where(
              _database.coachAthleteRelationshipsTable.coachUserId.equals(
                    coachUserId,
                  ) &
                  _database.coachAthleteRelationshipsTable.status.equals(
                    'active',
                  ),
            )
            ..orderBy([
              OrderingTerm.asc(
                _database.coachAthleteRelationshipsTable.createdAt,
              ),
            ]);

      final results = await query.get();

      return results.map((row) {
        final relationship = row.readTable(
          _database.coachAthleteRelationshipsTable,
        );
        final athleteProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          athleteDisplayName: _getDisplayNameFromProfile(
            athleteProfile,
            relationship.athleteUserId,
          ),
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
      final relationship =
          await (_database.select(_database.coachAthleteRelationshipsTable)
                ..where(
                  (r) =>
                      r.coachUserId.equals(coachUserId) &
                      r.athleteUserId.equals(athleteUserId) &
                      r.status.equals('active'),
                ))
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
      // Coach-initiated relationships are immediately active (no confirmation needed)
      final isCoachInitiated = requestedBy == 'coach';
      final status = isCoachInitiated ? 'active' : 'pending';
      try {
        await _supabase.from('coach_athlete_relationships').insert({
          'id': id,
          'coach_user_id': coachUserId,
          'athlete_user_id': athleteUserId,
          'status': status,
          'requested_by': requestedBy,
          'requested_at': now.toIso8601String(),
          if (isCoachInitiated) 'accepted_at': now.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'create', 'recordId': id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coach_athlete_relationships:create',
          method: 'INSERT',
          stackTrace: stackTrace,
        );
        throw StateError(
          'Failed to create coach-athlete relationship remotely',
        );
      }

      // Also save to local Drift database
      final companion = CoachAthleteRelationshipsTableCompanion.insert(
        id: id,
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        status: Value(status),
        requestedBy: requestedBy,
        requestedAt: Value(now),
        acceptedAt: Value(isCoachInitiated ? now : null),
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
        status: isCoachInitiated
            ? RelationshipStatus.active
            : RelationshipStatus.pending,
        requestedBy: requestedBy,
        requestedAt: now,
        acceptedAt: isCoachInitiated ? now : null,
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
    String relationshipId,
  ) async {
    try {
      final now = DateTime.now();

      // Update Supabase first (for cross-device sync)
      try {
        await _supabase
            .from('coach_athlete_relationships')
            .update({
              'status': 'active',
              'accepted_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', relationshipId);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'accept', 'recordId': relationshipId},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coach_athlete_relationships:accept',
          method: 'UPDATE',
          stackTrace: stackTrace,
        );
        throw StateError(
          'Failed to accept coach-athlete relationship remotely',
        );
      }

      // Update local Drift database
      await (_database.update(
        _database.coachAthleteRelationshipsTable,
      )..where((t) => t.id.equals(relationshipId))).write(
        CoachAthleteRelationshipsTableCompanion(
          status: const Value('active'),
          acceptedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final result = await (_database.select(
        _database.coachAthleteRelationshipsTable,
      )..where((t) => t.id.equals(relationshipId))).getSingle();

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
    String relationshipId,
  ) async {
    try {
      final now = DateTime.now();

      // Update Supabase first (for cross-device sync)
      try {
        await _supabase
            .from('coach_athlete_relationships')
            .update({
              'status': 'declined',
              'declined_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', relationshipId);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'decline', 'recordId': relationshipId},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coach_athlete_relationships:decline',
          method: 'UPDATE',
          stackTrace: stackTrace,
        );
        throw StateError(
          'Failed to decline coach-athlete relationship remotely',
        );
      }

      // Update local Drift database
      await (_database.update(
        _database.coachAthleteRelationshipsTable,
      )..where((t) => t.id.equals(relationshipId))).write(
        CoachAthleteRelationshipsTableCompanion(
          status: const Value('declined'),
          declinedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final result = await (_database.select(
        _database.coachAthleteRelationshipsTable,
      )..where((t) => t.id.equals(relationshipId))).getSingle();

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
    String relationshipId,
  ) async {
    try {
      final now = DateTime.now();

      // Update Supabase first (for cross-device sync)
      try {
        await _supabase
            .from('coach_athlete_relationships')
            .update({
              'status': 'archived',
              'archived_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .eq('id', relationshipId);
      } catch (e, stackTrace) {
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'archive', 'recordId': relationshipId},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coach_athlete_relationships:archive',
          method: 'UPDATE',
          stackTrace: stackTrace,
        );
        throw StateError(
          'Failed to archive coach-athlete relationship remotely',
        );
      }

      // Update local Drift database
      await (_database.update(
        _database.coachAthleteRelationshipsTable,
      )..where((t) => t.id.equals(relationshipId))).write(
        CoachAthleteRelationshipsTableCompanion(
          status: const Value('archived'),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      final result = await (_database.select(
        _database.coachAthleteRelationshipsTable,
      )..where((t) => t.id.equals(relationshipId))).getSingle();

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
                    record['status'] as String? ?? 'pending',
                  ),
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
    RealtimeChannel channel,
  ) async {
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
    CoachAthleteRelationship relationship,
  ) async {
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
    String userId,
  ) async {
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
          status: RelationshipStatus.fromString(
            r['status'] as String? ?? 'pending',
          ),
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
            .insertOnConflictUpdate(
              CoachesTableCompanion.insert(
                id: r['id'] as String,
                userId: r['user_id'] as String,
                firstName: r['first_name'] as String,
                lastName: r['last_name'] as String,
                email: r['email'] as String,
                bio: Value(r['bio'] as String?),
                applicationStatus: Value(
                  r['application_status'] as String? ?? 'pending',
                ),
                reviewedBy: Value(r['reviewed_by'] as String?),
                reviewedAt: Value(
                  r['reviewed_at'] != null
                      ? DateTime.parse(r['reviewed_at'] as String)
                      : null,
                ),
                rejectionReason: Value(r['rejection_reason'] as String?),
                createdAt: Value(
                  r['created_at'] != null
                      ? DateTime.parse(r['created_at'] as String)
                      : now,
                ),
                updatedAt: Value(
                  r['updated_at'] != null
                      ? DateTime.parse(r['updated_at'] as String)
                      : now,
                ),
              ),
            );
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
  Future<void> syncAthleteProfilesFromSupabase(
    List<String> athleteUserIds,
  ) async {
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

        // Update existing local user_profiles (only name fields)
        final rowsAffected =
            await (_database.update(
              _database.userProfilesTable,
            )..where((t) => t.id.equals(id))).write(
              UserProfilesTableCompanion(
                firstName: Value(r['first_name'] as String?),
                lastName: Value(r['last_name'] as String?),
                senderName: Value(r['sender_name'] as String?),
                updatedAt: Value(DateTime.now()),
              ),
            );

        // If profile doesn't exist locally, create a minimal one with name data
        // This is needed because the LEFT OUTER JOIN in getActiveRelationshipsForCoach
        // returns null when the profile row is missing, causing "Athlete XXXXX" fallback
        if (rowsAffected == 0) {
          await _database
              .into(_database.userProfilesTable)
              .insert(
                UserProfilesTableCompanion.insert(
                  id: id,
                  deviceId: id,
                  firstName: Value(r['first_name'] as String?),
                  lastName: Value(r['last_name'] as String?),
                  senderName: Value(r['sender_name'] as String?),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
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
  // COACH CREATE FOR ATHLETE (Activities, Events, Carb Loading)
  // ============================================================================

  /// Create an activity for an athlete directly in Supabase
  /// Also inserts into local Drift database for immediate display
  Future<String> createActivityForAthlete({
    required String athleteUserId,
    required String title,
    required String activityType,
    required DateTime scheduledDateTime,
    int? durationMinutes,
    double? distanceMiles,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final activityData = {
        'id': id,
        'user_id': athleteUserId,
        'title': title,
        'activity_type': activityType,
        'scheduled_date_time': scheduledDateTime.toIso8601String(),
        'duration_minutes': durationMinutes,
        'distance_miles': distanceMiles,
        'needs_upload': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Insert into Supabase first
      await _supabase.from('activities').insert(activityData);

      // Also insert into local Drift database for immediate display
      await _database
          .into(_database.activitiesTable)
          .insert(
            ActivitiesTableCompanion.insert(
              id: Value(id),
              userId: athleteUserId,
              title: title,
              activityType: activityType,
              scheduledDateTime: scheduledDateTime,
              durationMinutes: Value(durationMinutes),
              distanceMiles: Value(distanceMiles),
              needsUpload: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );

      _logger.info(
        'Created activity for athlete',
        context: 'COACH_REPOSITORY',
        data: {'activityId': id, 'athleteUserId': athleteUserId},
      );

      return id;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create activity for athlete',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create an event for an athlete directly in Supabase
  /// Also inserts into local Drift database for immediate display
  Future<String> createEventForAthlete({
    required String athleteUserId,
    required String eventName,
    required String eventType,
    required DateTime eventDate,
    String? eventSubtype,
    String? location,
    double? goalPaceMinutesPerMile,
    int? goalTimeMinutes,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final eventData = {
        'id': id,
        'user_id': athleteUserId,
        'event_name': eventName,
        'event_type': eventType,
        'event_subtype': eventSubtype,
        'event_date': eventDate.toIso8601String(),
        'location': location,
        'goal_pace_minutes_per_mile': goalPaceMinutesPerMile,
        'goal_time_minutes': goalTimeMinutes,
        'needs_upload': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Insert into Supabase first
      await _supabase.from('events').insert(eventData);

      // Also insert into local Drift database for immediate display
      await _database
          .into(_database.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              id: Value(id),
              userId: athleteUserId,
              eventType: eventType,
              eventSubtype: Value(eventSubtype),
              eventName: Value(eventName),
              eventDate: Value(eventDate),
              location: Value(location),
              goalPaceMinutesPerMile: Value(goalPaceMinutesPerMile),
              goalTimeMinutes: Value(goalTimeMinutes),
              needsUpload: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );

      _logger.info(
        'Created event for athlete',
        context: 'COACH_REPOSITORY',
        data: {'eventId': id, 'athleteUserId': athleteUserId},
      );

      return id;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create event for athlete',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // ATHLETE PROFILE UPDATE (Coach editing athlete's profile)
  // ============================================================================

  /// Update an athlete's profile in Supabase users table
  /// Only coaches with an active relationship can update athlete profiles
  Future<void> updateAthleteProfile({
    required String athleteUserId,
    String? firstName,
    String? lastName,
    DateTime? birthday,
    double? weightPounds,
    int? heightFeet,
    int? heightInches,
    bool? runsWithWaterBottle,
    String? gutTraining,
    String? gender,
    bool? giSensitivity,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (firstName != null) updates['first_name'] = firstName;
      if (lastName != null) updates['last_name'] = lastName;
      if (birthday != null) updates['birthday'] = birthday.toIso8601String();
      if (weightPounds != null) updates['weight_pounds'] = weightPounds;
      if (heightFeet != null) updates['height_feet'] = heightFeet;
      if (heightInches != null) updates['height_inches'] = heightInches;
      if (runsWithWaterBottle != null) {
        updates['runs_with_water_bottle'] = runsWithWaterBottle;
      }
      if (gutTraining != null) updates['gut_training_level'] = gutTraining;
      if (gender != null) updates['gender'] = gender;
      if (giSensitivity != null) updates['gi_sensitivity'] = giSensitivity;

      // Update in Supabase
      await _supabase.from('users').update(updates).eq('id', athleteUserId);

      // Also update local Drift database
      await (_database.update(
        _database.userProfilesTable,
      )..where((t) => t.id.equals(athleteUserId))).write(
        UserProfilesTableCompanion(
          firstName: firstName != null
              ? Value(firstName)
              : const Value.absent(),
          lastName: lastName != null ? Value(lastName) : const Value.absent(),
          birthday: birthday != null ? Value(birthday) : const Value.absent(),
          weightPounds: weightPounds != null
              ? Value(weightPounds)
              : const Value.absent(),
          heightFeet: heightFeet != null
              ? Value(heightFeet)
              : const Value.absent(),
          heightInches: heightInches != null
              ? Value(heightInches)
              : const Value.absent(),
          runsWithWaterBottle: runsWithWaterBottle != null
              ? Value(runsWithWaterBottle)
              : const Value.absent(),
          gutTrainingLevel: gutTraining != null
              ? Value(gutTraining)
              : const Value.absent(),
          gender: gender != null ? Value(gender) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      _logger.info(
        'Updated athlete profile',
        context: 'COACH_REPOSITORY',
        data: {
          'athleteUserId': athleteUserId,
          'updatedFields': updates.keys.toList(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update athlete profile',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'athleteUserId': athleteUserId},
      );
      rethrow;
    }
  }

  /// Update an athlete's nutrition target overrides in Supabase.
  /// Pass null to clear all overrides.
  Future<void> updateAthleteNutritionTargets({
    required String athleteUserId,
    required Map<String, dynamic>? overridesJson,
  }) async {
    try {
      await _supabase
          .from('users')
          .update({
            'nutrition_target_overrides': overridesJson,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', athleteUserId);

      // Also update local Drift database
      await (_database.update(
        _database.userProfilesTable,
      )..where((t) => t.id.equals(athleteUserId))).write(
        UserProfilesTableCompanion(
          nutritionTargetOverrides: Value(
            overridesJson != null
                ? Uri.encodeFull(overridesJson.toString())
                : null,
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );

      _logger.info(
        'Updated athlete nutrition targets',
        context: 'COACH_REPOSITORY',
        data: {
          'athleteUserId': athleteUserId,
          'hasOverrides': overridesJson != null,
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update athlete nutrition targets',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get a relationship by ID (works for both coach and athlete perspective)
  Future<CoachAthleteRelationship?> getRelationshipById(
    String relationshipId,
  ) async {
    try {
      // Join with coaches and user_profiles tables to get coach display name
      final query =
          _database.select(_database.coachAthleteRelationshipsTable).join([
            leftOuterJoin(
              _database.coachesTable,
              _database.coachesTable.userId.equalsExp(
                _database.coachAthleteRelationshipsTable.coachUserId,
              ),
            ),
            leftOuterJoin(
              _database.userProfilesTable,
              _database.userProfilesTable.id.equalsExp(
                _database.coachAthleteRelationshipsTable.coachUserId,
              ),
            ),
          ])..where(
            _database.coachAthleteRelationshipsTable.id.equals(relationshipId),
          );

      final results = await query.get();
      if (results.isEmpty) return null;

      final row = results.first;
      final relationship = row.readTable(
        _database.coachAthleteRelationshipsTable,
      );
      final coachEntry = row.readTableOrNull(_database.coachesTable);
      final coachProfile = row.readTableOrNull(_database.userProfilesTable);

      // Also try to get athlete display name
      final athleteProfile =
          await (_database.select(_database.userProfilesTable)
                ..where((t) => t.id.equals(relationship.athleteUserId)))
              .getSingleOrNull();

      return _mapToRelationshipDomain(
        relationship,
        coachDisplayName: _getCoachDisplayName(
          coachEntry,
          coachProfile,
          relationship.coachUserId,
        ),
        athleteDisplayName: _getDisplayNameFromProfile(
          athleteProfile,
          relationship.athleteUserId,
        ),
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
      final localResults = await _database
          .select(_database.userProfilesTable)
          .get();
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
      final result =
          await (_database.select(_database.coachesTable)..where(
                (t) =>
                    t.userId.equals(userId) &
                    t.applicationStatus.equals('approved'),
              ))
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
      final result = await (_database.select(
        _database.coachesTable,
      )..where((t) => t.userId.equals(userId))).getSingleOrNull();

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
      try {
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
        _logger.warning(
          'Immediate upload failed; record stays dirty for retry',
          context: 'COACH_REPOSITORY',
          error: e,
          stackTrace: stackTrace,
          data: {'operation': 'submit_application', 'recordId': id},
        );
        _sentry.reportNetworkError(
          e,
          url: 'supabase:coaches:submit_application',
          method: 'INSERT',
          stackTrace: stackTrace,
        );
        return false;
      }
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
  String? _getCoachDisplayName(
    CoachEntry? coachEntry,
    UserProfileEntry? profile,
    String userId,
  ) {
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
      final hasFirstName =
          profile.firstName != null && profile.firstName!.trim().isNotEmpty;
      final hasLastName =
          profile.lastName != null && profile.lastName!.trim().isNotEmpty;

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
    final hasFirstName =
        profile.firstName != null && profile.firstName!.trim().isNotEmpty;
    final hasLastName =
        profile.lastName != null && profile.lastName!.trim().isNotEmpty;

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

  // ─── Athlete Pairing Codes ────────────────────────────────────────

  /// Characters allowed in pairing codes (no confusing chars: 0/O, 1/I/L)
  static const _codeChars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Generate a 6-character alphanumeric pairing code for an athlete.
  /// Invalidates any existing active code for this user first.
  /// Returns the generated code string.
  Future<String> generatePairingCode(String userId) async {
    try {
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(hours: 24));
      final code = _generateRandomCode(6);
      final id = const Uuid().v4();

      // Expire any existing unused codes for this user
      await _supabase
          .from('athlete_pairing_codes')
          .update({'expires_at': now.toIso8601String()})
          .eq('user_id', userId)
          .isFilter('used_at', null);

      // Insert new code
      await _supabase.from('athlete_pairing_codes').insert({
        'id': id,
        'user_id': userId,
        'code': code,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });

      // Also save locally
      await _database
          .into(_database.athletePairingCodesTable)
          .insertOnConflictUpdate(
            AthletePairingCodesTableCompanion.insert(
              id: id,
              userId: userId,
              code: code,
              expiresAt: expiresAt,
              createdAt: Value(now),
            ),
          );

      _logger.info(
        'Generated pairing code for user',
        context: 'COACH_REPOSITORY',
        data: {
          'userId': userId,
          'code': code,
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      return code;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to generate pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Validate a pairing code entered by a coach.
  /// Returns the athlete's userId if the code is valid (not expired, not used).
  /// Returns null if invalid.
  Future<String?> validatePairingCode(String code) async {
    final validation = await _validatePairingCodeDetailed(code);
    return validation.athleteUserId;
  }

  /// Connect coach to athlete using a valid pairing code.
  /// Marks the code as used and creates an active relationship.
  /// Returns the created relationship or null on failure.
  Future<CoachAthleteRelationship?> connectViaCode({
    required String code,
    required String coachUserId,
  }) async {
    final result = await connectViaCodeDetailed(
      code: code,
      coachUserId: coachUserId,
    );
    return result.relationship;
  }

  /// Connect coach to athlete using a valid pairing code.
  /// Returns a detailed success/failure result for UI-level messaging.
  Future<PairingCodeConnectResult> connectViaCodeDetailed({
    required String code,
    required String coachUserId,
  }) async {
    try {
      final normalizedCode = code.trim().toUpperCase();

      if (!_isPairingCodeFormatValid(normalizedCode)) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.invalidCodeFormat,
        );
      }

      // Validate code first
      final validation = await _validatePairingCodeDetailed(normalizedCode);
      if (!validation.isValid) {
        return PairingCodeConnectResult.failure(
          validation.failureReason ?? PairingCodeConnectFailureReason.unknown,
        );
      }
      final athleteUserId = validation.athleteUserId!;

      // Prevent self-connection
      if (athleteUserId == coachUserId) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.selfConnectionNotAllowed,
        );
      }

      // Prevent duplicate relationship attempts before consuming the code.
      final existingRelationship = await _supabase
          .from('coach_athlete_relationships')
          .select('id')
          .eq('coach_user_id', coachUserId)
          .eq('athlete_user_id', athleteUserId)
          .maybeSingle();
      if (existingRelationship != null) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.relationshipAlreadyExists,
        );
      }

      // Mark code as used
      final now = DateTime.now().toUtc();
      final updatedRows = await _supabase
          .from('athlete_pairing_codes')
          .update({
            'used_by_coach_id': coachUserId,
            'used_at': now.toIso8601String(),
          })
          .eq('code', normalizedCode)
          .isFilter('used_at', null)
          .gte('expires_at', now.toIso8601String())
          .select('id');
      if ((updatedRows as List).isEmpty) {
        final latestValidation = await _validatePairingCodeDetailed(
          normalizedCode,
        );
        return PairingCodeConnectResult.failure(
          latestValidation.failureReason ??
              PairingCodeConnectFailureReason.unknown,
        );
      }

      // Create active relationship (coach-initiated = immediately active)
      final relationship = await createRelationship(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        requestedBy: 'coach',
      );

      _logger.info(
        'Connected via pairing code',
        context: 'COACH_REPOSITORY',
        data: {
          'code': normalizedCode,
          'coachUserId': coachUserId,
          'athleteUserId': athleteUserId,
        },
      );

      return PairingCodeConnectResult.success(relationship);
    } on PostgrestException catch (e, stackTrace) {
      final message = e.message.toLowerCase();
      final isDuplicate = e.code == '23505' || message.contains('duplicate');
      if (isDuplicate) {
        _logger.warning(
          'Coach-athlete relationship already exists during pairing connect',
          context: 'COACH_REPOSITORY',
          data: {'coachUserId': coachUserId, 'code': code, 'pgCode': e.code},
        );
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.relationshipAlreadyExists,
        );
      }

      _logger.error(
        'Postgrest error while connecting via pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'coachUserId': coachUserId, 'code': code, 'pgCode': e.code},
      );
      return PairingCodeConnectResult.failure(
        PairingCodeConnectFailureReason.unknown,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to connect via pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return PairingCodeConnectResult.failure(
        PairingCodeConnectFailureReason.unknown,
      );
    }
  }

  Future<_PairingCodeValidationResult> _validatePairingCodeDetailed(
    String code,
  ) async {
    try {
      final normalizedCode = code.trim().toUpperCase();
      if (!_isPairingCodeFormatValid(normalizedCode)) {
        return _PairingCodeValidationResult.invalid(
          PairingCodeConnectFailureReason.invalidCodeFormat,
        );
      }

      final response = await _supabase
          .from('athlete_pairing_codes')
          .select('user_id, expires_at, used_at')
          .eq('code', normalizedCode)
          .maybeSingle();

      if (response == null) {
        _logger.warning(
          'Pairing code not found',
          context: 'COACH_REPOSITORY',
          data: {'code': normalizedCode},
        );
        return _PairingCodeValidationResult.invalid(
          PairingCodeConnectFailureReason.codeNotFound,
        );
      }

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      final usedAt = response['used_at'];

      if (usedAt != null) {
        _logger.warning(
          'Pairing code already used',
          context: 'COACH_REPOSITORY',
          data: {'code': normalizedCode},
        );
        return _PairingCodeValidationResult.invalid(
          PairingCodeConnectFailureReason.codeAlreadyUsed,
        );
      }

      if (expiresAt.isBefore(DateTime.now().toUtc())) {
        _logger.warning(
          'Pairing code expired',
          context: 'COACH_REPOSITORY',
          data: {
            'code': normalizedCode,
            'expiresAt': expiresAt.toIso8601String(),
          },
        );
        return _PairingCodeValidationResult.invalid(
          PairingCodeConnectFailureReason.codeExpired,
        );
      }

      return _PairingCodeValidationResult.valid(response['user_id'] as String);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to validate pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'code': code},
      );
      return _PairingCodeValidationResult.invalid(
        PairingCodeConnectFailureReason.unknown,
      );
    }
  }

  bool _isPairingCodeFormatValid(String code) {
    return RegExp(r'^[A-Z0-9]{6}$').hasMatch(code);
  }

  /// Get the active (unexpired, unused) pairing code for a user, if any.
  Future<({String code, DateTime expiresAt})?> getActivePairingCode(
    String userId,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('athlete_pairing_codes')
          .select('code, expires_at')
          .eq('user_id', userId)
          .isFilter('used_at', null)
          .gte('expires_at', now.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return (
        code: response['code'] as String,
        expiresAt: DateTime.parse(response['expires_at'] as String),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get the athlete's connected coach info.
  /// Returns null if the athlete has no active coach connection.
  Future<({String coachUserId, String? coachName})?> getMyCoach(
    String athleteUserId,
  ) async {
    try {
      final response = await _supabase
          .from('coach_athlete_relationships')
          .select('coach_user_id')
          .eq('athlete_user_id', athleteUserId)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      final coachUserId = response['coach_user_id'] as String;

      // Look up coach name
      String? coachName;
      try {
        final coachRow = await _supabase
            .from('users')
            .select('first_name, last_name, sender_name')
            .eq('id', coachUserId)
            .maybeSingle();

        if (coachRow != null) {
          final first = coachRow['first_name'] as String?;
          final last = coachRow['last_name'] as String?;
          final sender = coachRow['sender_name'] as String?;
          coachName = [
            first,
            last,
          ].where((s) => s?.isNotEmpty ?? false).join(' ');
          if (coachName.isEmpty) coachName = sender;
        }
      } catch (_) {
        // Name lookup is best-effort
      }

      return (coachUserId: coachUserId, coachName: coachName);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get athlete coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Disconnect athlete from their coach.
  Future<bool> disconnectFromCoach({
    required String athleteUserId,
    required String coachUserId,
  }) async {
    try {
      await _supabase
          .from('coach_athlete_relationships')
          .update({
            'status': 'archived',
            'archived_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('athlete_user_id', athleteUserId)
          .eq('coach_user_id', coachUserId)
          .eq('status', 'active');

      // Also update local DB
      await (_database.update(_database.coachAthleteRelationshipsTable)..where(
            (t) =>
                t.athleteUserId.equals(athleteUserId) &
                t.coachUserId.equals(coachUserId) &
                t.status.equals('active'),
          ))
          .write(
            CoachAthleteRelationshipsTableCompanion(
              status: const Value('archived'),
              archivedAt: Value(DateTime.now().toUtc()),
            ),
          );

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to disconnect from coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ─── Coach Pairing Codes (Reversed Flow) ──────────────────────────

  /// Generate a 6-character pairing code for a coach.
  /// Invalidates any existing active code for this coach first.
  /// Returns the generated code string.
  Future<String> generateCoachPairingCode(String coachUserId) async {
    try {
      final now = DateTime.now().toUtc();
      final expiresAt = now.add(const Duration(hours: 24));
      final code = _generateRandomCode(6);
      final id = const Uuid().v4();

      // Expire any existing unused codes for this coach
      await _supabase
          .from('coach_pairing_codes')
          .update({'expires_at': now.toIso8601String()})
          .eq('coach_user_id', coachUserId)
          .isFilter('used_at', null);

      // Insert new code
      await _supabase.from('coach_pairing_codes').insert({
        'id': id,
        'coach_user_id': coachUserId,
        'code': code,
        'created_at': now.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
      });

      // Also save locally
      await _database
          .into(_database.coachPairingCodesTable)
          .insertOnConflictUpdate(
            CoachPairingCodesTableCompanion.insert(
              id: id,
              coachUserId: coachUserId,
              code: code,
              expiresAt: expiresAt,
              createdAt: Value(now),
            ),
          );

      _logger.info(
        'Generated coach pairing code',
        context: 'COACH_REPOSITORY',
        data: {
          'coachUserId': coachUserId,
          'code': code,
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      return code;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to generate coach pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the active (unexpired, unused) coach pairing code, if any.
  Future<({String code, DateTime expiresAt})?> getActiveCoachPairingCode(
    String coachUserId,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('coach_pairing_codes')
          .select('code, expires_at')
          .eq('coach_user_id', coachUserId)
          .isFilter('used_at', null)
          .gte('expires_at', now.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return (
        code: response['code'] as String,
        expiresAt: DateTime.parse(response['expires_at'] as String),
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get active coach pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Athlete connects to a coach using the coach's pairing code.
  /// Validates the code, marks it as used, and creates an active relationship.
  Future<PairingCodeConnectResult> connectViaCoachCode({
    required String code,
    required String athleteUserId,
  }) async {
    try {
      final normalizedCode = code.trim().toUpperCase();

      if (!_isPairingCodeFormatValid(normalizedCode)) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.invalidCodeFormat,
        );
      }

      // Look up the code
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('coach_pairing_codes')
          .select('coach_user_id, expires_at, used_at')
          .eq('code', normalizedCode)
          .maybeSingle();

      if (response == null) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.codeNotFound,
        );
      }

      if (response['used_at'] != null) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.codeAlreadyUsed,
        );
      }

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      if (expiresAt.isBefore(now)) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.codeExpired,
        );
      }

      final coachUserId = response['coach_user_id'] as String;

      // Prevent self-connection
      if (coachUserId == athleteUserId) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.selfConnectionNotAllowed,
        );
      }

      // Check for existing relationship
      final existingRelationship = await _supabase
          .from('coach_athlete_relationships')
          .select('id')
          .eq('coach_user_id', coachUserId)
          .eq('athlete_user_id', athleteUserId)
          .maybeSingle();
      if (existingRelationship != null) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.relationshipAlreadyExists,
        );
      }

      // Mark code as used
      final updatedRows = await _supabase
          .from('coach_pairing_codes')
          .update({
            'used_by_athlete_id': athleteUserId,
            'used_at': now.toIso8601String(),
          })
          .eq('code', normalizedCode)
          .isFilter('used_at', null)
          .gte('expires_at', now.toIso8601String())
          .select('id');

      if ((updatedRows as List).isEmpty) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.codeExpired,
        );
      }

      // Create active relationship (coach-initiated = immediately active)
      final relationship = await createRelationship(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        requestedBy: 'coach',
      );

      _logger.info(
        'Athlete connected via coach pairing code',
        context: 'COACH_REPOSITORY',
        data: {
          'code': normalizedCode,
          'coachUserId': coachUserId,
          'athleteUserId': athleteUserId,
        },
      );

      return PairingCodeConnectResult.success(relationship);
    } on PostgrestException catch (e, stackTrace) {
      final message = e.message.toLowerCase();
      final isDuplicate = e.code == '23505' || message.contains('duplicate');
      if (isDuplicate) {
        return PairingCodeConnectResult.failure(
          PairingCodeConnectFailureReason.relationshipAlreadyExists,
        );
      }

      _logger.error(
        'Postgrest error while connecting via coach pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return PairingCodeConnectResult.failure(
        PairingCodeConnectFailureReason.unknown,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to connect via coach pairing code',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return PairingCodeConnectResult.failure(
        PairingCodeConnectFailureReason.unknown,
      );
    }
  }

  /// Generate a random code of the given length
  String _generateRandomCode(int length) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _codeChars[random.nextInt(_codeChars.length)],
    ).join();
  }
}

class _PairingCodeValidationResult {
  const _PairingCodeValidationResult._({
    this.athleteUserId,
    this.failureReason,
  });

  final String? athleteUserId;
  final PairingCodeConnectFailureReason? failureReason;

  bool get isValid => athleteUserId != null;

  factory _PairingCodeValidationResult.valid(String athleteUserId) {
    return _PairingCodeValidationResult._(athleteUserId: athleteUserId);
  }

  factory _PairingCodeValidationResult.invalid(
    PairingCodeConnectFailureReason reason,
  ) {
    return _PairingCodeValidationResult._(failureReason: reason);
  }
}
