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

  /// Get all users with is_coach=true (for coach directory)
  Future<List<CoachInfo>> getActiveCoaches() async {
    try {
      final results = await (_database.select(_database.userProfilesTable)
            ..where((t) => t.isCoach.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

      return results
          .map((r) => CoachInfo(
                userId: r.id,
                deviceId: r.deviceId,
                isCoach: r.isCoach,
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

  /// Get all relationships for an athlete
  Future<List<CoachAthleteRelationship>> getRelationshipsForAthlete(
    String athleteUserId,
  ) async {
    try {
      final results = await (_database
              .select(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.athleteUserId.equals(athleteUserId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      return results.map(_mapToRelationshipDomain).toList();
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

  /// Fetch the latest is_coach status from Supabase for a user
  /// Returns true if user is a coach, false otherwise
  Future<bool?> fetchIsCoachFromSupabase(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('is_coach')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return response['is_coach'] as bool? ?? false;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to fetch is_coach from Supabase',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Map Drift CoachAthleteRelationshipEntry to domain
  CoachAthleteRelationship _mapToRelationshipDomain(
    CoachAthleteRelationshipEntry entry,
  ) {
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
