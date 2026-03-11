import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/auth/domain/user_preferences.dart' as domain;
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/coach_repository.dart';
import '../data/coach_messaging_repository.dart';
import '../domain/coach.dart';
import '../domain/coach_athlete_relationship.dart';
import '../domain/coach_message.dart';

part 'coach_service.g.dart';

@riverpod
CoachService coachService(Ref ref) {
  return CoachService(
    repository: ref.read(coachRepositoryProvider),
    messagingRepository: ref.read(coachMessagingRepositoryProvider),
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    supabase: Supabase.instance.client,
  );
}

/// Service for coach mode business logic
/// Handles orchestration between coach operations and user context
/// Note: Coach status is determined by approved record in coaches table (set by admin)
class CoachService {
  const CoachService({
    required CoachRepository repository,
    required CoachMessagingRepository messagingRepository,
    required AppDatabase database,
    required AppLogger logger,
    required SupabaseClient supabase,
  }) : _repository = repository,
       _messagingRepository = messagingRepository,
       _database = database,
       _logger = logger,
       _supabase = supabase;

  final CoachRepository _repository;
  final CoachMessagingRepository _messagingRepository;
  final AppDatabase _database;
  final AppLogger _logger;
  final SupabaseClient _supabase;

  /// Get the current authenticated user's ID from Supabase
  String? get _currentAuthUserId => _supabase.auth.currentUser?.id;

  /// Helper method to get current user profile with auth context
  Future<domain.UserProfile?> _getCurrentProfile() async {
    return await _database.userDao.getCurrentUserProfile(
      currentAuthUserId: _currentAuthUserId,
    );
  }

  // ============================================================================
  // COACH STATUS CHECKS
  // ============================================================================

  /// Check if the current user is a coach
  /// Checks the coaches table for an approved record
  Future<bool> isCurrentUserCoach() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return false;
      return await _repository.isUserApprovedCoach(profile.id);
    } catch (e) {
      _logger.warning(
        'Failed to check coach status',
        context: 'COACH_SERVICE',
        data: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Get the current user's coach record (if they are an approved coach)
  Future<Coach?> getCurrentCoachRecord() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return null;

      return await _repository.getCoachRecordForUser(profile.id);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get current coach record',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get the current user's coach info (simplified view for UI)
  /// Used by coach dashboard and other UI components
  Future<CoachInfo?> getCurrentCoachInfo() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return null;

      return await _repository.getCoachInfoByUserId(profile.id);
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
      final profile = await _getCurrentProfile();
      if (profile == null) return [];

      // Check coaches table for approved status
      final isCoach = await _repository.isUserApprovedCoach(profile.id);
      if (!isCoach) return [];

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
      final profile = await _getCurrentProfile();
      if (profile == null) return [];

      // Check coaches table for approved status
      final isCoach = await _repository.isUserApprovedCoach(profile.id);
      if (!isCoach) return [];

      final all = await _repository.getRelationshipsForCoach(profile.id);
      return all.where((r) => r.status == RelationshipStatus.pending).toList();
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

  /// Search users to add as athletes by name/email.
  Future<List<AthleteSearchResult>> searchAthletesByNameOrEmail(
    String query, {
    int limit = 20,
  }) async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return [];

      // Check coaches table for approved status
      final isCoach = await _repository.isUserApprovedCoach(profile.id);
      if (!isCoach) return [];

      return await _repository.searchAthletesByNameOrEmail(
        query: query,
        currentUserId: profile.id,
        limit: limit,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to search athletes by name/email',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
        data: {'query': query},
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
      final profile = await _getCurrentProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot invite athlete: no user profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      // Check coaches table for approved status
      final isCoach = await _repository.isUserApprovedCoach(profile.id);
      if (!isCoach) {
        _logger.warning(
          'Cannot invite athlete: user is not a coach',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      // Look up the athlete by their code
      final athleteUserId = await _repository.findUserIdByAthleteCode(
        athleteCode,
      );
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
      final profile = await _getCurrentProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot invite athlete: no user profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      // Check coaches table for approved status
      final isCoach = await _repository.isUserApprovedCoach(profile.id);
      if (!isCoach) {
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
  // COACH CREATE FOR ATHLETE (Activities, Events)
  // ============================================================================

  /// Create an activity for an athlete
  Future<String> createActivityForAthlete({
    required String athleteUserId,
    required String title,
    required String activityType,
    required DateTime scheduledDateTime,
    int? durationMinutes,
    double? distanceMiles,
  }) async {
    try {
      return await _repository.createActivityForAthlete(
        athleteUserId: athleteUserId,
        title: title,
        activityType: activityType,
        scheduledDateTime: scheduledDateTime,
        durationMinutes: durationMinutes,
        distanceMiles: distanceMiles,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create activity for athlete',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create an event for an athlete
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
      return await _repository.createEventForAthlete(
        athleteUserId: athleteUserId,
        eventName: eventName,
        eventType: eventType,
        eventDate: eventDate,
        eventSubtype: eventSubtype,
        location: location,
        goalPaceMinutesPerMile: goalPaceMinutesPerMile,
        goalTimeMinutes: goalTimeMinutes,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create event for athlete',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // ATHLETE PROFILE MANAGEMENT (Coach perspective)
  // ============================================================================

  /// Update an athlete's profile (coach can set name, biometrics, etc.)
  /// Requires active coach-athlete relationship
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
      await _repository.updateAthleteProfile(
        athleteUserId: athleteUserId,
        firstName: firstName,
        lastName: lastName,
        birthday: birthday,
        weightPounds: weightPounds,
        heightFeet: heightFeet,
        heightInches: heightInches,
        runsWithWaterBottle: runsWithWaterBottle,
        gutTraining: gutTraining,
        gender: gender,
        giSensitivity: giSensitivity,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update athlete profile',
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
      final profile = await _getCurrentProfile();
      if (profile == null) return [];

      final all = await _repository.getRelationshipsForAthlete(profile.id);
      return all.where((r) => r.status == RelationshipStatus.active).toList();
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
      final profile = await _getCurrentProfile();
      if (profile == null) return [];

      final all = await _repository.getRelationshipsForAthlete(profile.id);
      return all
          .where(
            (r) =>
                r.status == RelationshipStatus.pending &&
                r.requestedBy == 'coach',
          )
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
      return await _messagingRepository.getMessagesForConversation(
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
      return await _messagingRepository.getMessagesForNutritionPlan(nutritionPlanId);
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
      return await _messagingRepository.getMessagesForActivity(activityId);
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
      final profile = await _getCurrentProfile();
      if (profile == null) return 0;

      return await _messagingRepository.getUnreadMessageCount(profile.id);
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
      final profile = await _getCurrentProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot send message: no user profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _messagingRepository.sendMessage(
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
      final profile = await _getCurrentProfile();
      if (profile == null) return;

      await _messagingRepository.markMessagesAsRead(
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
      await _messagingRepository.deleteMessage(messageId);
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
  // CHAT (General messaging - no activity/plan context)
  // ============================================================================

  /// Get general chat messages (excludes activity and nutrition plan comments)
  /// Used for the dedicated chat screen
  Future<List<CoachMessage>> getGeneralChatMessages({
    required String coachUserId,
    required String athleteUserId,
    int? limit,
  }) async {
    try {
      return await _messagingRepository.getGeneralChatMessages(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        limit: limit,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get general chat messages',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Subscribe to new messages in a conversation using Supabase Realtime
  /// Returns a RealtimeChannel that should be unsubscribed when done
  RealtimeChannel subscribeToConversation({
    required String coachUserId,
    required String athleteUserId,
    required void Function(CoachMessage) onNewMessage,
  }) {
    return _messagingRepository.subscribeToConversation(
      coachUserId: coachUserId,
      athleteUserId: athleteUserId,
      onNewMessage: onNewMessage,
    );
  }

  /// Unsubscribe from a conversation channel
  Future<void> unsubscribeFromConversation(RealtimeChannel channel) async {
    await _messagingRepository.unsubscribeFromConversation(channel);
  }

  /// Send a general chat message (not linked to activity or nutrition plan)
  /// Used by the dedicated chat screen
  Future<CoachMessage?> sendChatMessage({
    required String coachUserId,
    required String athleteUserId,
    required String messageText,
  }) async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot send chat message: no user profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _messagingRepository.sendChatMessageToSupabase(
        coachUserId: coachUserId,
        athleteUserId: athleteUserId,
        senderUserId: profile.id,
        messageText: messageText,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to send chat message',
        context: 'COACH_SERVICE',
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
      return await _repository.getRelationshipById(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get relationship by ID',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get the current user's ID
  Future<String?> getCurrentUserId() async {
    final profile = await _getCurrentProfile();
    return profile?.id;
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
      final profile = await _getCurrentProfile();
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
      final profile = await _getCurrentProfile();
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
  // RELATIONSHIP SYNC & REALTIME
  // ============================================================================

  /// Sync all relationships from Supabase to local database
  /// Call this when loading the dashboard to ensure we have latest data
  Future<List<CoachAthleteRelationship>> syncRelationshipsFromSupabase() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return [];

      return await _repository.syncRelationshipsFromSupabase(profile.id);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync relationships from Supabase',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Sync coach data for athlete's coaches
  /// This ensures we have the coach names (first_name, last_name) in local DB
  Future<void> syncMyCoachesData() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return;

      // Get all relationships where user is athlete
      final relationships = await _repository.getRelationshipsForAthlete(
        profile.id,
      );

      // Extract unique coach user IDs
      final coachUserIds = relationships
          .map((r) => r.coachUserId)
          .toSet()
          .toList();

      if (coachUserIds.isEmpty) return;

      // Sync coach data from Supabase
      await _repository.syncCoachesFromSupabase(coachUserIds);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync my coaches data',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// Sync athlete profiles for the current coach's athletes
  /// This ensures we have athlete names (first_name, last_name) in local DB for the dashboard
  Future<void> syncMyAthletesProfiles() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return;

      // Check if user is a coach first
      final isCoach = await _repository.isUserApprovedCoach(profile.id);
      if (!isCoach) return;

      // Get all relationships where user is coach
      final relationships = await _repository.getRelationshipsForCoach(
        profile.id,
      );

      // Extract unique athlete user IDs
      final athleteUserIds = relationships
          .map((r) => r.athleteUserId)
          .toSet()
          .toList();

      if (athleteUserIds.isEmpty) return;

      // Sync athlete profiles from Supabase
      await _repository.syncAthleteProfilesFromSupabase(athleteUserIds);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync my athletes profiles',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - this is not critical for app functionality
    }
  }

  /// Subscribe to relationship changes using Supabase Realtime
  /// Returns a RealtimeChannel that should be unsubscribed when done
  Future<RealtimeChannel?> subscribeToRelationshipChanges({
    required void Function(CoachAthleteRelationship) onRelationshipChanged,
  }) async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return null;

      return _repository.subscribeToRelationshipChanges(
        userId: profile.id,
        onRelationshipChanged: onRelationshipChanged,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to subscribe to relationship changes',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Unsubscribe from relationship changes
  Future<void> unsubscribeFromRelationshipChanges(
    RealtimeChannel channel,
  ) async {
    await _repository.unsubscribeFromRelationshipChanges(channel);
  }

  // ============================================================================
  // COACH RECORD SYNC
  // ============================================================================

  /// Check if the current user has an approved coach record
  /// This is used by the data sync service to determine coach status
  /// Note: Coach record is synced during sync-all-data, so this is for manual checks
  Future<bool> checkCoachStatusFromSupabase() async {
    try {
      final profile = await _getCurrentProfile();
      if (profile == null) return false;

      // Fetch latest status from Supabase coaches table
      return await _repository.fetchIsCoachFromSupabase(profile.id) ?? false;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to check coach status from Supabase',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
