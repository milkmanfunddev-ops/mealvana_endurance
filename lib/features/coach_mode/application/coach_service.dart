import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../data/coach_repository.dart';
import '../domain/coach.dart';
import '../domain/coach_athlete_relationship.dart';
import '../domain/coach_feedback.dart' as domain;

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

  /// Get the current user's coach profile (if they are a coach)
  Future<Coach?> getCurrentCoachProfile() async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null || !profile.isCoach) return null;

      return await _repository.getCoachByUserId(profile.id);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get current coach profile',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // ============================================================================
  // COACH PROFILE MANAGEMENT
  // ============================================================================

  /// Create a new coach profile for the current user
  /// Requires that the user has is_coach = true in their profile
  Future<Coach?> createCoachProfile({
    required String coachName,
    String? bio,
    List<String>? certifications,
    List<String>? specializations,
  }) async {
    try {
      final profile = await _database.getCurrentUserProfile();
      if (profile == null) {
        _logger.warning(
          'Cannot create coach profile: no user profile found',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      if (!profile.isCoach) {
        _logger.warning(
          'User is not authorized to be a coach',
          context: 'COACH_SERVICE',
          data: {'userId': profile.id},
        );
        return null;
      }

      // Check if coach profile already exists
      final existing = await _repository.getCoachByUserId(profile.id);
      if (existing != null) {
        _logger.info(
          'Coach profile already exists',
          context: 'COACH_SERVICE',
          data: {'coachId': existing.id},
        );
        return existing;
      }

      return await _repository.createCoach(
        userId: profile.id,
        deviceId: profile.deviceId,
        coachName: coachName,
        bio: bio,
        certifications: certifications,
        specializations: specializations,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create coach profile',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update the current user's coach profile
  Future<Coach?> updateCoachProfile(Coach coach) async {
    try {
      return await _repository.updateCoach(coach);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update coach profile',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // ATHLETE MANAGEMENT (Coach perspective)
  // ============================================================================

  /// Get all athletes for the current coach
  Future<List<CoachAthleteRelationship>> getMyAthletes() async {
    try {
      final coach = await getCurrentCoachProfile();
      if (coach == null) return [];

      return await _repository.getActiveRelationshipsForCoach(coach.id);
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
      final coach = await getCurrentCoachProfile();
      if (coach == null) return [];

      final all = await _repository.getRelationshipsForCoach(coach.id);
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

  /// Invite an athlete to connect with the coach
  Future<CoachAthleteRelationship?> inviteAthlete({
    required String athleteUserId,
    required String athleteDeviceId,
  }) async {
    try {
      final coach = await getCurrentCoachProfile();
      if (coach == null) {
        _logger.warning(
          'Cannot invite athlete: no coach profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _repository.createRelationship(
        coachId: coach.id,
        athleteUserId: athleteUserId,
        athleteDeviceId: athleteDeviceId,
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
  // FEEDBACK MANAGEMENT
  // ============================================================================

  /// Get feedback for a specific relationship
  Future<List<domain.CoachFeedback>> getFeedbackForRelationship(
    String relationshipId,
  ) async {
    try {
      return await _repository.getFeedbackForRelationship(relationshipId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get feedback',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Add feedback for an athlete
  Future<domain.CoachFeedback?> addFeedback({
    required String relationshipId,
    required String athleteUserId,
    required String feedbackText,
    domain.FeedbackType feedbackType = domain.FeedbackType.general,
    String? activityId,
    String? nutritionPlanId,
    bool isVisibleToAthlete = true,
  }) async {
    try {
      final coach = await getCurrentCoachProfile();
      if (coach == null) {
        _logger.warning(
          'Cannot add feedback: no coach profile',
          context: 'COACH_SERVICE',
        );
        return null;
      }

      return await _repository.createFeedback(
        relationshipId: relationshipId,
        coachId: coach.id,
        athleteUserId: athleteUserId,
        feedbackText: feedbackText,
        feedbackType: feedbackType,
        activityId: activityId,
        nutritionPlanId: nutritionPlanId,
        isVisibleToAthlete: isVisibleToAthlete,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to add feedback',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update feedback
  Future<domain.CoachFeedback?> updateFeedback(
    domain.CoachFeedback feedback,
  ) async {
    try {
      return await _repository.updateFeedback(feedback);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update feedback',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete feedback
  Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _repository.deleteFeedback(feedbackId);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete feedback',
        context: 'COACH_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
