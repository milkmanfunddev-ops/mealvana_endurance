import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
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
/// Handles coach-athlete relationships and bidirectional messaging
/// Note: Coach status is determined by is_coach flag on users table (set by admin)
class CoachRepository {
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
  // COACH INFO OPERATIONS (from users table)
  // ============================================================================

  /// Get coach info for a user (basic info from users table)
  Future<CoachInfo?> getCoachInfoByUserId(String userId) async {
    try {
      final result = await (_database.select(_database.userProfilesTable)
            ..where((t) => t.id.equals(userId) & t.isCoach.equals(true)))
          .getSingleOrNull();

      if (result == null) return null;
      return CoachInfo(
        userId: result.id,
        deviceId: result.deviceId,
        isCoach: result.isCoach,
        displayName: result.senderName,
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
          .eq('status', 'approved')
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
  Future<List<CoachAthleteRelationship>> getRelationshipsForCoach(
    String coachUserId,
  ) async {
    try {
      final results = await (_database
              .select(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.coachUserId.equals(coachUserId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      return results.map(_mapToRelationshipDomain).toList();
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
      // Join with user_profiles to get coach display name (sender_name field)
      final query = _database.select(_database.coachAthleteRelationshipsTable).join([
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
        final coachProfile = row.readTableOrNull(_database.userProfilesTable);

        return _mapToRelationshipDomain(
          relationship,
          coachDisplayName: coachProfile?.senderName,
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
  Future<List<CoachAthleteRelationship>> getActiveRelationshipsForCoach(
    String coachUserId,
  ) async {
    try {
      final results = await (_database
              .select(_database.coachAthleteRelationshipsTable)
            ..where((t) =>
                t.coachUserId.equals(coachUserId) & t.status.equals('active'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      return results.map(_mapToRelationshipDomain).toList();
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

  /// Create a new coach-athlete relationship request
  Future<CoachAthleteRelationship> createRelationship({
    required String coachUserId,
    required String athleteUserId,
    required String requestedBy,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

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

      _logger.info(
        'Created coach-athlete relationship',
        context: 'COACH_REPOSITORY',
        data: {
          'relationshipId': id,
          'coachUserId': coachUserId,
          'athleteUserId': athleteUserId
        },
      );

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
  Future<CoachAthleteRelationship> acceptRelationship(
      String relationshipId) async {
    try {
      final now = DateTime.now();

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

      _logger.info(
        'Accepted relationship',
        context: 'COACH_REPOSITORY',
        data: {'relationshipId': relationshipId},
      );

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
  Future<CoachAthleteRelationship> declineRelationship(
      String relationshipId) async {
    try {
      final now = DateTime.now();

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

      _logger.info(
        'Declined relationship',
        context: 'COACH_REPOSITORY',
        data: {'relationshipId': relationshipId},
      );

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
  Future<CoachAthleteRelationship> archiveRelationship(
      String relationshipId) async {
    try {
      final now = DateTime.now();

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

      _logger.info(
        'Archived relationship',
        context: 'COACH_REPOSITORY',
        data: {'relationshipId': relationshipId},
      );

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

  // ============================================================================
  // MESSAGE OPERATIONS (bidirectional messaging)
  // ============================================================================

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
      final now = DateTime.now();

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

      _logger.info(
        'Sent coach message',
        context: 'COACH_REPOSITORY',
        data: {
          'messageId': id,
          'coachUserId': coachUserId,
          'athleteUserId': athleteUserId,
          'senderUserId': senderUserId,
        },
      );

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

      _logger.info(
        'Marked messages as read',
        context: 'COACH_REPOSITORY',
        data: {
          'coachUserId': coachUserId,
          'athleteUserId': athleteUserId,
          'readerUserId': readerUserId,
        },
      );
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

      _logger.info(
        'Deleted coach message',
        context: 'COACH_REPOSITORY',
        data: {'messageId': messageId},
      );
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
          _logger.info(
            'Found user by athlete code (local)',
            context: 'COACH_REPOSITORY',
            data: {'code': code, 'userId': user.id},
          );
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
            _logger.info(
              'Found user by athlete code (Supabase)',
              context: 'COACH_REPOSITORY',
              data: {'code': code, 'userId': userId},
            );
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

  /// Update local user profile to set is_coach flag
  /// Used when syncing is_coach status from Supabase
  Future<void> updateLocalUserIsCoach(String userId, bool isCoach) async {
    try {
      await (_database.update(_database.userProfilesTable)
            ..where((t) => t.id.equals(userId)))
          .write(UserProfilesTableCompanion(
        isCoach: Value(isCoach),
        updatedAt: Value(DateTime.now()),
      ));

      _logger.info(
        'Updated local user is_coach flag',
        context: 'COACH_REPOSITORY',
        data: {'userId': userId, 'isCoach': isCoach},
      );
    } catch (e) {
      _logger.warning(
        'Failed to update local is_coach flag (non-critical)',
        context: 'COACH_REPOSITORY',
        data: {'error': e.toString()},
      );
    }
  }

  // ============================================================================
  // IS_COACH SYNC OPERATIONS
  // ============================================================================

  /// Fetch the latest coach status from Supabase coaches table for a user
  /// Returns true if user has an approved coach record, false otherwise
  Future<bool?> fetchIsCoachFromSupabase(String userId) async {
    try {
      // Check the coaches table for an approved record
      final response = await _supabase
          .from('coaches')
          .select('status')
          .eq('user_id', userId)
          .eq('status', 'approved')
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

      _logger.info(
        'Submitted coach application',
        context: 'COACH_REPOSITORY',
        data: {
          'applicationId': id,
          'userId': userId,
          'email': email,
        },
      );

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
