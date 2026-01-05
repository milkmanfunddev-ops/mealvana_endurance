import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/coach.dart';
import '../domain/coach_athlete_relationship.dart';
import '../domain/coach_feedback.dart' as domain;

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
/// Handles coaches, coach-athlete relationships, and feedback
class CoachRepository {
  const CoachRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  // ignore: unused_field - Will be used for Supabase sync in future
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  static const _uuid = Uuid();

  // ============================================================================
  // COACH PROFILE OPERATIONS
  // ============================================================================

  /// Get coach profile for a user
  Future<Coach?> getCoachByUserId(String userId) async {
    try {
      final result = await (_database.select(_database.coachesTable)
            ..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

      if (result == null) return null;
      return _mapToCoachDomain(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get coach by user ID',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get coach profile by device ID
  Future<Coach?> getCoachByDeviceId(String deviceId) async {
    try {
      final result = await (_database.select(_database.coachesTable)
            ..where((t) => t.deviceId.equals(deviceId)))
          .getSingleOrNull();

      if (result == null) return null;
      return _mapToCoachDomain(result);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get coach by device ID',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new coach profile
  Future<Coach> createCoach({
    required String userId,
    required String deviceId,
    required String coachName,
    String? bio,
    List<String>? certifications,
    List<String>? specializations,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final companion = CoachesTableCompanion.insert(
        id: id,
        userId: userId,
        deviceId: deviceId,
        coachName: coachName,
        bio: Value(bio),
        certifications: Value(_listToPostgresArray(certifications ?? [])),
        specializations: Value(_listToPostgresArray(specializations ?? [])),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _database.into(_database.coachesTable).insert(companion);

      _logger.info(
        'Created coach profile',
        context: 'COACH_REPOSITORY',
        data: {'coachId': id, 'userId': userId},
      );

      return Coach(
        id: id,
        userId: userId,
        deviceId: deviceId,
        coachName: coachName,
        bio: bio,
        certifications: certifications ?? [],
        specializations: specializations ?? [],
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update coach profile
  Future<Coach> updateCoach(Coach coach) async {
    try {
      final updatedAt = DateTime.now();

      await (_database.update(_database.coachesTable)
            ..where((t) => t.id.equals(coach.id)))
          .write(CoachesTableCompanion(
        coachName: Value(coach.coachName),
        bio: Value(coach.bio),
        certifications: Value(_listToPostgresArray(coach.certifications)),
        specializations: Value(_listToPostgresArray(coach.specializations)),
        businessName: Value(coach.businessName),
        websiteUrl: Value(coach.websiteUrl),
        email: Value(coach.email),
        phone: Value(coach.phone),
        isActive: Value(coach.isActive),
        maxAthletes: Value(coach.maxAthletes),
        autoAcceptRequests: Value(coach.autoAcceptRequests),
        updatedAt: Value(updatedAt),
      ));

      _logger.info(
        'Updated coach profile',
        context: 'COACH_REPOSITORY',
        data: {'coachId': coach.id},
      );

      return coach.copyWith(updatedAt: updatedAt);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update coach',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all active coaches for directory browsing
  Future<List<Coach>> getActiveCoaches() async {
    try {
      final results = await (_database.select(_database.coachesTable)
            ..where((t) => t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.coachName)]))
          .get();

      return results.map(_mapToCoachDomain).toList();
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

  /// Get all relationships for a coach
  Future<List<CoachAthleteRelationship>> getRelationshipsForCoach(
    String coachId,
  ) async {
    try {
      final results = await (_database
              .select(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.coachId.equals(coachId))
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
    String coachId,
  ) async {
    try {
      final results = await (_database
              .select(_database.coachAthleteRelationshipsTable)
            ..where((t) =>
                t.coachId.equals(coachId) & t.status.equals('active'))
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
    required String coachId,
    required String athleteUserId,
    required String athleteDeviceId,
    required String requestedBy,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final companion = CoachAthleteRelationshipsTableCompanion.insert(
        id: id,
        coachId: coachId,
        athleteUserId: athleteUserId,
        athleteDeviceId: athleteDeviceId,
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
        data: {'relationshipId': id, 'coachId': coachId, 'athleteUserId': athleteUserId},
      );

      return CoachAthleteRelationship(
        id: id,
        coachId: coachId,
        athleteUserId: athleteUserId,
        athleteDeviceId: athleteDeviceId,
        status: RelationshipStatus.pending,
        permissionLevel: PermissionLevel.viewOnly,
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
  Future<CoachAthleteRelationship> acceptRelationship(String relationshipId) async {
    try {
      final now = DateTime.now();

      await (_database.update(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.id.equals(relationshipId)))
          .write(CoachAthleteRelationshipsTableCompanion(
        status: const Value('active'),
        acceptedAt: Value(now),
        updatedAt: Value(now),
      ));

      final result = await (_database.select(_database.coachAthleteRelationshipsTable)
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
  Future<CoachAthleteRelationship> declineRelationship(String relationshipId) async {
    try {
      final now = DateTime.now();

      await (_database.update(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.id.equals(relationshipId)))
          .write(CoachAthleteRelationshipsTableCompanion(
        status: const Value('declined'),
        declinedAt: Value(now),
        updatedAt: Value(now),
      ));

      final result = await (_database.select(_database.coachAthleteRelationshipsTable)
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
  Future<CoachAthleteRelationship> archiveRelationship(String relationshipId) async {
    try {
      final now = DateTime.now();

      await (_database.update(_database.coachAthleteRelationshipsTable)
            ..where((t) => t.id.equals(relationshipId)))
          .write(CoachAthleteRelationshipsTableCompanion(
        status: const Value('archived'),
        archivedAt: Value(now),
        updatedAt: Value(now),
      ));

      final result = await (_database.select(_database.coachAthleteRelationshipsTable)
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
  // FEEDBACK OPERATIONS
  // ============================================================================

  /// Get feedback for a relationship
  Future<List<domain.CoachFeedback>> getFeedbackForRelationship(
    String relationshipId,
  ) async {
    try {
      final results = await (_database.select(_database.coachFeedbackTable)
            ..where((t) => t.relationshipId.equals(relationshipId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

      return results.map(_mapToFeedbackDomain).toList();
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to get feedback for relationship',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create new feedback
  Future<domain.CoachFeedback> createFeedback({
    required String relationshipId,
    required String coachId,
    required String athleteUserId,
    required String feedbackText,
    domain.FeedbackType feedbackType = domain.FeedbackType.general,
    String? activityId,
    String? nutritionPlanId,
    bool isVisibleToAthlete = true,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      final companion = CoachFeedbackTableCompanion.insert(
        id: id,
        relationshipId: relationshipId,
        coachId: coachId,
        athleteUserId: athleteUserId,
        feedbackText: feedbackText,
        feedbackType: Value(feedbackType.name),
        activityId: Value(activityId),
        nutritionPlanId: Value(nutritionPlanId),
        isVisibleToAthlete: Value(isVisibleToAthlete),
        createdAt: Value(now),
        updatedAt: Value(now),
      );

      await _database.into(_database.coachFeedbackTable).insert(companion);

      _logger.info(
        'Created coach feedback',
        context: 'COACH_REPOSITORY',
        data: {'feedbackId': id, 'relationshipId': relationshipId},
      );

      return domain.CoachFeedback(
        id: id,
        relationshipId: relationshipId,
        coachId: coachId,
        athleteUserId: athleteUserId,
        feedbackText: feedbackText,
        feedbackType: feedbackType,
        activityId: activityId,
        nutritionPlanId: nutritionPlanId,
        isVisibleToAthlete: isVisibleToAthlete,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to create feedback',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update feedback
  Future<domain.CoachFeedback> updateFeedback(domain.CoachFeedback feedback) async {
    try {
      final updatedAt = DateTime.now();

      await (_database.update(_database.coachFeedbackTable)
            ..where((t) => t.id.equals(feedback.id)))
          .write(CoachFeedbackTableCompanion(
        feedbackText: Value(feedback.feedbackText),
        feedbackType: Value(feedback.feedbackType.name),
        isVisibleToAthlete: Value(feedback.isVisibleToAthlete),
        updatedAt: Value(updatedAt),
      ));

      _logger.info(
        'Updated coach feedback',
        context: 'COACH_REPOSITORY',
        data: {'feedbackId': feedback.id},
      );

      return feedback.copyWith(updatedAt: updatedAt);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to update feedback',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete feedback
  Future<void> deleteFeedback(String feedbackId) async {
    try {
      await (_database.delete(_database.coachFeedbackTable)
            ..where((t) => t.id.equals(feedbackId)))
          .go();

      _logger.info(
        'Deleted coach feedback',
        context: 'COACH_REPOSITORY',
        data: {'feedbackId': feedbackId},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete feedback',
        context: 'COACH_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Convert PostgreSQL array format to list
  List<String> _postgresArrayToList(String? arrayString) {
    if (arrayString == null || arrayString.isEmpty || arrayString == '{}') {
      return [];
    }
    // Remove braces and split by comma
    final inner = arrayString.substring(1, arrayString.length - 1);
    if (inner.isEmpty) return [];
    return inner.split(',').map((s) => s.trim()).toList();
  }

  /// Convert list to PostgreSQL array format
  String _listToPostgresArray(List<String> list) {
    if (list.isEmpty) return '{}';
    return '{${list.join(',')}}';
  }

  /// Map Drift CoachEntry to domain Coach
  Coach _mapToCoachDomain(CoachEntry entry) {
    return Coach(
      id: entry.id,
      userId: entry.userId,
      deviceId: entry.deviceId,
      coachName: entry.coachName,
      bio: entry.bio,
      certifications: _postgresArrayToList(entry.certifications),
      specializations: _postgresArrayToList(entry.specializations),
      businessName: entry.businessName,
      websiteUrl: entry.websiteUrl,
      email: entry.email,
      phone: entry.phone,
      isActive: entry.isActive,
      isVerified: entry.isVerified,
      maxAthletes: entry.maxAthletes,
      autoAcceptRequests: entry.autoAcceptRequests,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Map Drift CoachAthleteRelationshipEntry to domain
  CoachAthleteRelationship _mapToRelationshipDomain(
    CoachAthleteRelationshipEntry entry,
  ) {
    CustomPermissions permissions = const CustomPermissions();
    if (entry.customPermissions.isNotEmpty) {
      try {
        permissions = CustomPermissions.fromJson(
          jsonDecode(entry.customPermissions) as Map<String, dynamic>,
        );
      } catch (_) {
        // Use default permissions if JSON parsing fails
      }
    }

    return CoachAthleteRelationship(
      id: entry.id,
      coachId: entry.coachId,
      athleteUserId: entry.athleteUserId,
      athleteDeviceId: entry.athleteDeviceId,
      status: RelationshipStatus.fromString(entry.status),
      permissionLevel: PermissionLevel.fromString(entry.permissionLevel),
      customPermissions: permissions,
      requestedBy: entry.requestedBy,
      requestedAt: entry.requestedAt,
      acceptedAt: entry.acceptedAt,
      declinedAt: entry.declinedAt,
      archivedAt: entry.archivedAt,
      coachNotes: entry.coachNotes,
      athleteNotes: entry.athleteNotes,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Map Drift CoachFeedbackEntry to domain
  domain.CoachFeedback _mapToFeedbackDomain(CoachFeedbackEntry entry) {
    return domain.CoachFeedback(
      id: entry.id,
      relationshipId: entry.relationshipId,
      coachId: entry.coachId,
      athleteUserId: entry.athleteUserId,
      activityId: entry.activityId,
      nutritionPlanId: entry.nutritionPlanId,
      feedbackText: entry.feedbackText,
      feedbackType: domain.FeedbackType.fromString(entry.feedbackType),
      isVisibleToAthlete: entry.isVisibleToAthlete,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }
}
