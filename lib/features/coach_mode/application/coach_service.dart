import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/coach_repository.dart';
import '../domain/coach.dart';
import '../domain/coach_athlete_relationship.dart';
import '../domain/coach_message.dart';

part 'coach_service.g.dart';

@riverpod
CoachService coachService(Ref ref) {
  return CoachService(
    repository: ref.read(coachRepositoryProvider),
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Service for coach mode business logic
/// Handles orchestration between coach operations and user context
/// Note: Coach status is determined by is_coach flag on users table (set by admin)
class CoachService {
  const CoachService({
    required CoachRepository repository,
    required AppDatabase database,
    required AppLogger logger,
  })  : _repository = repository,
        _database = database,
        _logger = logger;

  final CoachRepository _repository;
  final AppDatabase _database;
  final AppLogger _logger;

  // ============================================================================
  // COACH STATUS CHECKS
  // ============================================================================

  /// Check if the current user is a coach
  Future<bool> isCurrentUserCoach() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) return false;
      return profile.isCoach;
    } catch (e) {
      _logger.warning(
        'Failed to check coach status',
        context: 'COACH_SERVICE',
        data: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Get the current user's coach info (if they are a coach)
  Future<CoachInfo?> getCurrentCoachInfo() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null || !profile.isCoach) return null;

      return CoachInfo(
        userId: profile.id,
        deviceId: profile.deviceId,
        isCoach: profile.isCoach,
        displayName: profile.senderName,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get current coach info',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ============================================================================
  // ATHLETE MANAGEMENT (Coach perspective)
  // ============================================================================

  /// Get all athletes for the current coach
  Future<List<CoachAthleteRelationship>> getMyAthletes() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null || !profile.isCoach) return [];

      return await _repository.getActiveRelationshipsForCoach(profile.id);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get athletes',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get pending athlete requests for the current coach
  Future<List<CoachAthleteRelationship>> getPendingAthleteRequests() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null || !profile.isCoach) return [];

      final all = await _repository.getRelationshipsForCoach(profile.id);
      return all
          .where((r) => r.status == RelationshipStatus.pending)
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get pending requests',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Invite an athlete to connect with the coach using their athlete code
  /// Athlete code format: ATH-XXXXXXXX (e.g., ATH-FE36370A)
  /// Returns the relationship if successful, null if athlete not found or user is not a coach
  Future<CoachAthleteRelationship?> inviteAthleteByCode({
    required String athleteCode,
  }) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null || !profile.isCoach) {
        _logger.warning(
          'Cannot invite athlete: user is not a coach',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      // Look up the athlete by their code
      final athleteUserId = await _repository.findUserIdByAthleteCode(athleteCode);
      if (athleteUserId == null) {
        _logger.warning(
          'Athlete not found by code',
          context: 'COACH_SERVICE',
          data: {'athleteCode': athleteCode},
        );
        return null;
      }

      // Prevent inviting yourself
      if (athleteUserId == profile.id) {
        _logger.warning(
          'Cannot invite yourself as an athlete',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _repository.createRelationship(
        coachUserId: profile.id,
        athleteUserId: athleteUserId,
        requestedBy: 'coach',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to invite athlete by code',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Invite an athlete to connect with the coach (legacy - uses full user ID)
  Future<CoachAthleteRelationship?> inviteAthlete({
    required String athleteUserId,
  }) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null || !profile.isCoach) {
        _logger.warning(
          'Cannot invite athlete: user is not a coach',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _repository.createRelationship(
        coachUserId: profile.id,
        athleteUserId: athleteUserId,
        requestedBy: 'coach',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to invite athlete',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Accept an athlete's request to connect
  Future<CoachAthleteRelationship?> acceptAthleteRequest(
    String relationshipId,
  ) async {
    try {
      return await _repository.acceptRelationship(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to accept athlete request',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Decline an athlete's request to connect
  Future<CoachAthleteRelationship?> declineAthleteRequest(
    String relationshipId,
  ) async {
    try {
      return await _repository.declineRelationship(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to decline athlete request',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Archive a relationship with an athlete
  Future<CoachAthleteRelationship?> archiveAthlete(
    String relationshipId,
  ) async {
    try {
      return await _repository.archiveRelationship(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to archive athlete',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // COACH MANAGEMENT (Athlete perspective)
  // ============================================================================

  /// Get all coaches for the current athlete
  Future<List<CoachAthleteRelationship>> getMyCoaches() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) return [];

      final all = await _repository.getRelationshipsForAthlete(profile.id);
      return all
          .where((r) => r.status == RelationshipStatus.active)
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get coaches',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get pending coach requests for the current athlete
  Future<List<CoachAthleteRelationship>> getPendingCoachRequests() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) return [];

      final all = await _repository.getRelationshipsForAthlete(profile.id);
      return all
          .where((r) =>
              r.status == RelationshipStatus.pending &&
              r.requestedBy == 'coach')
          .toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get pending coach requests',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Accept a coach's request to connect
  Future<CoachAthleteRelationship?> acceptCoachRequest(
    String relationshipId,
  ) async {
    try {
      return await _repository.acceptRelationship(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to accept coach request',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Decline a coach's request to connect
  Future<CoachAthleteRelationship?> declineCoachRequest(
    String relationshipId,
  ) async {
    try {
      return await _repository.declineRelationship(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to decline coach request',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // MESSAGING (Bidirectional)
  // ============================================================================

  /// Get conversation messages between coach and athlete
  Future<List<CoachMessage>> getConversation({
    required String coachUserId,
    required String athleteUserId,
    int? limit,
  }) async {
    try {
      return await _repository.getMessagesForConversation(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        limit: limit,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get conversation',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get comments/messages for a nutrition plan
  Future<List<CoachMessage>> getNutritionPlanComments(
    String nutritionPlanId,
  ) async {
    try {
      return await _repository.getMessagesForNutritionPlan(nutritionPlanId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get nutrition plan comments',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get comments/messages for an activity
  Future<List<CoachMessage>> getActivityComments(String activityId) async {
    try {
      return await _repository.getMessagesForActivity(activityId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get activity comments',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get unread message count for current user
  Future<int> getUnreadMessageCount() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) return 0;

      return await _repository.getUnreadMessageCount(profile.id);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get unread message count',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  /// Send a message in a conversation
  Future<CoachMessage?> sendMessage({
    required String coachUserId,
    required String athleteUserId,
    required String messageText,
    String? nutritionPlanId,
    String? activityId,
  }) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot send message: no user profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _repository.sendMessage(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: profile.id,
        messageText: messageText,
        nutritionPlanId: nutritionPlanId,
        activityId: activityId,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to send message',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark messages as read in a conversation
  Future<void> markConversationAsRead({
    required String coachUserId,
    required String athleteUserId,
  }) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) return;

      await _repository.markMessagesAsRead(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        readerUserId: profile.id,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to mark conversation as read',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Delete a message (current user must be the sender)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete message',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // COACH DIRECTORY (Athlete browsing coaches)
  // ============================================================================

  /// Get all available/active coaches for browsing
  Future<List<CoachInfo>> getAvailableCoaches() async {
    try {
      return await _repository.getActiveCoaches();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get available coaches',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Request to connect with a coach (athlete initiates)
  Future<bool> requestCoachConnection(String coachUserId) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot request coach: no user profile',
          context: 'COACH_SERVICE',
        );
        return false;
      }

      await _repository.createRelationship(
        coachUserId: coachUserId,
        athleteUserId: profile.id,
        requestedBy: 'athlete',
      );

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to request coach connection',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ============================================================================
  // COACH APPLICATION SUBMISSION
  // ============================================================================

  /// Submit a coach application for the current user
  /// Returns true if successful, false otherwise
  Future<bool> submitCoachApplication({
    required String firstName,
    required String lastName,
    required String email,
    String? bio,
  }) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot submit coach application: no user profile',
          context: 'COACH_SERVICE',
        );
        return false;
      }

      return await _repository.submitCoachApplication(
        userId: profile.id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        bio: bio,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to submit coach application',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ============================================================================
  // IS_COACH SYNC (for admin-approved coach status)
  // ============================================================================

  /// Sync is_coach status from Supabase to local database
  /// Call this on app startup to pick up any admin approvals
  Future<bool> syncIsCoachStatus() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) return false;

      // Fetch latest status from Supabase
      final isCoach = await _repository.fetchIsCoachFromSupabase(profile.id);
      if (isCoach == null) return false;

      // If status changed, update local database
      if (isCoach != profile.isCoach) {
        await _repository.updateLocalUserIsCoach(profile.id, isCoach);
        _logger.info(
          'Synced is_coach status from Supabase',
          context: 'COACH_SERVICE',
          data: {'userId': profile.id, 'isCoach': isCoach},
        );
        return true; // Status was updated
      }

      return false; // No change
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync is_coach status',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
