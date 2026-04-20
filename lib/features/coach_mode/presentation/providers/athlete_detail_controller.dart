import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../activities/domain/activity.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../events/domain/event.dart';
import '../../../carb_loading/domain/carb_loading_plan_simple.dart';
import '../../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../carb_loading/application/carb_loading_service.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../application/coach_service.dart';
import '../../data/coach_repository.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../../domain/coach_message.dart';
import 'athlete_data_sync_provider.dart';

part 'athlete_detail_controller.g.dart';

/// State for viewing an athlete's details (coach perspective)
class AthleteDetailState {
  final CoachAthleteRelationship relationship;
  final UserProfile? athleteProfile;
  final List<Event> events;
  final List<CarbLoadingPlan> carbLoadingPlans;
  final List<db.CarbLoadingDay> carbLoadingDays;
  final List<Activity> activities;
  final List<CoachMessage> messages;
  final bool isLoading;
  final String? error;

  const AthleteDetailState({
    required this.relationship,
    this.athleteProfile,
    this.events = const [],
    this.carbLoadingPlans = const [],
    this.carbLoadingDays = const [],
    this.activities = const [],
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AthleteDetailState copyWith({
    CoachAthleteRelationship? relationship,
    UserProfile? athleteProfile,
    List<Event>? events,
    List<CarbLoadingPlan>? carbLoadingPlans,
    List<db.CarbLoadingDay>? carbLoadingDays,
    List<Activity>? activities,
    List<CoachMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return AthleteDetailState(
      relationship: relationship ?? this.relationship,
      athleteProfile: athleteProfile ?? this.athleteProfile,
      events: events ?? this.events,
      carbLoadingPlans: carbLoadingPlans ?? this.carbLoadingPlans,
      carbLoadingDays: carbLoadingDays ?? this.carbLoadingDays,
      activities: activities ?? this.activities,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

@riverpod
class AthleteDetailController extends _$AthleteDetailController {
  CoachService get _coachService => ref.read(coachServiceProvider);

  @override
  FutureOr<AthleteDetailState> build(String relationshipId) async {
    // First, get the relationship to find the athlete user ID
    final relationships = await _coachService.getMyAthletes();
    final relationship = relationships.firstWhere(
      (r) => r.id == relationshipId,
      orElse: () => _createPlaceholderRelationship(relationshipId),
    );

    // Automatically sync athlete data from Supabase on initial load
    // This ensures fresh data when coach views athlete details
    if (relationship.athleteUserId.isNotEmpty) {
      await ref.read(
        athleteDataSyncProvider(
          relationshipId,
          relationship.athleteUserId,
        ).future,
      );
    }

    // Now load from local database (which has fresh synced data)
    return _loadAthleteDetails(relationshipId);
  }

  Future<AthleteDetailState> _loadAthleteDetails(String relationshipId) async {
    try {
      // Get all relationships for this coach to find the specific one
      final relationships = await _coachService.getMyAthletes();
      final relationship = relationships.firstWhere(
        (r) => r.id == relationshipId,
        orElse: () => _createPlaceholderRelationship(relationshipId),
      );

      // Get conversation messages with this athlete
      final messages = await _coachService.getConversation(
        coachUserId: relationship.coachUserId,
        athleteUserId: relationship.athleteUserId,
      );

      // Fetch athlete's data from local database
      final database = ref.read(appDatabaseProvider);

      // Load athlete profile by user ID
      final athleteProfile = await database.userDao.getUserProfileById(
        relationship.athleteUserId,
      );

      // Load athlete events using Drift select syntax
      final eventEntries =
          await (database.select(database.eventsTable)
                ..where((t) => t.userId.equals(relationship.athleteUserId))
                ..orderBy([(t) => OrderingTerm.asc(t.eventDate)]))
              .get();
      final events = eventEntries.map((e) => _mapEventEntry(e)).toList();

      // Load athlete activities using Drift select syntax
      final activityEntries =
          await (database.select(database.activitiesTable)
                ..where(
                  (t) =>
                      t.userId.equals(relationship.athleteUserId) &
                      t.deletedAt.isNull() &
                      t.providerDeletedAt.isNull(),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.scheduledDateTime)]))
              .get();
      final activities = activityEntries
          .map((a) => _mapActivityEntry(a))
          .toList();

      // Load athlete carb loading plans using Drift select syntax
      // Note: Database schema differs from domain model, so we map available fields
      final carbLoadingPlanEntries =
          await (database.select(database.carbLoadingPlansTable)
                ..where((t) => t.userId.equals(relationship.athleteUserId))
                ..orderBy([(t) => OrderingTerm.desc(t.generatedAt)]))
              .get();
      final carbLoadingPlans = carbLoadingPlanEntries
          .map((e) => _mapCarbLoadingPlanEntry(e))
          .toList();

      // Load athlete carb loading days by joining through plans (days table has no user_id column).
      final carbLoadingDayRows =
          await (database.select(database.carbLoadingDaysTable).join([
                  innerJoin(
                    database.carbLoadingPlansTable,
                    database.carbLoadingPlansTable.id.equalsExp(
                      database.carbLoadingDaysTable.carbLoadingPlanId,
                    ),
                  ),
                ])
                ..where(
                  database.carbLoadingPlansTable.userId.equals(
                    relationship.athleteUserId,
                  ),
                )
                ..orderBy([
                  OrderingTerm.asc(database.carbLoadingDaysTable.planDate),
                  OrderingTerm.asc(database.carbLoadingDaysTable.dayNumber),
                ]))
              .get();
      final carbLoadingDays = carbLoadingDayRows
          .map((row) => row.readTable(database.carbLoadingDaysTable))
          .toList();

      return AthleteDetailState(
        relationship: relationship,
        athleteProfile: athleteProfile,
        messages: messages,
        events: events,
        activities: activities,
        carbLoadingPlans: carbLoadingPlans,
        carbLoadingDays: carbLoadingDays,
      );
    } catch (e) {
      return AthleteDetailState(
        relationship: _createPlaceholderRelationship(relationshipId),
        error: 'Failed to load athlete details: ${e.toString()}',
      );
    }
  }

  /// Map event entry from database to domain model
  Event _mapEventEntry(dynamic entry) {
    return Event(
      id: entry.id,
      userId: entry.userId,
      activityId: entry.activityId,
      eventType: _parseActivityType(entry.eventType),
      eventSubtype: entry.eventSubtype,
      eventName: entry.eventName,
      location: entry.location,
      registrationUrl: entry.registrationUrl,
      eventDate: entry.eventDate,
      startTime: entry.startTime,
      goalTimeMinutes: entry.goalTimeMinutes,
      goalPaceMinutesPerMile: entry.goalPaceMinutesPerMile,
      predictedFinishTimeMinutes: entry.predictedFinishTimeMinutes,
      hasCarbLoading: entry.hasCarbLoading ?? false,
      carbLoadingDays: entry.carbLoadingDays,
      carbLoadingStartDate: entry.carbLoadingStartDate,
      bibNumber: entry.bibNumber,
      waveStartTime: entry.waveStartTime,
      packetPickupInfo: entry.packetPickupInfo,
      actualFinishTimeMinutes: entry.actualFinishTimeMinutes,
      finalPlacement: entry.finalPlacement,
      ageGroupPlacement: entry.ageGroupPlacement,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Map activity entry from database to domain model
  Activity _mapActivityEntry(dynamic entry) {
    return Activity(
      id: entry.id,
      userId: entry.userId,
      title: entry.title,
      activityType: _parseActivityType(entry.activityType),
      scheduledDateTime: entry.scheduledDateTime,
      durationMinutes: entry.durationMinutes,
      distanceMiles: entry.distanceMiles,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Parse activity type from database string
  ActivityType _parseActivityType(String? type) {
    return ActivityType.values.firstWhere(
      (e) => e.dbValue == type || e.name == type,
      orElse: () => ActivityType.running,
    );
  }

  CoachAthleteRelationship _createPlaceholderRelationship(String id) {
    return CoachAthleteRelationship(
      id: id,
      coachUserId: '',
      athleteUserId: '',
      requestedBy: 'coach',
      requestedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Map carb loading plan from database entry to domain model
  /// Since database schema differs, we map available fields with sensible defaults
  CarbLoadingPlan _mapCarbLoadingPlanEntry(dynamic entry) {
    // Database has: totalDays, startDate, endDate, dailyCarbTargetGrams
    // Domain expects: raceDate, raceDistance, trainingVolume, dailyCarbTargetG, etc.
    // We use endDate as raceDate and provide defaults for unmapped fields
    final dailyCarbTargetG = entry.dailyCarbTargetGrams;
    final dailyServingsTarget = (dailyCarbTargetG / 50).round();

    return CarbLoadingPlan(
      id: entry.id,
      userId: entry.userId,
      raceDate: entry.endDate, // Use endDate as race date
      raceDistance: RaceDistance.marathon, // Default since not stored in DB
      trainingVolume: TrainingVolume.moderate, // Default since not stored in DB
      dailyCarbTargetG: dailyCarbTargetG,
      dailyServingsTarget: dailyServingsTarget,
      bodyWeightKg: 70.0, // Default since not stored in this table
      carbsPerKgTarget: 8.0, // Standard carb loading target
      daySelections: {
        -2: DayFoodSelections.empty(),
        -1: DayFoodSelections.empty(),
        0: DayFoodSelections.empty(),
      },
      createdAt: entry.generatedAt,
      updatedAt: entry.localUpdatedAt,
      isActive: entry.completedAt == null, // Active if not completed
    );
  }

  /// Send a message to this athlete
  Future<void> sendMessage({
    required String messageText,
    String? activityId,
    String? nutritionPlanId,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      final newMessage = await _coachService.sendMessage(
        coachUserId: currentState.relationship.coachUserId,
        athleteUserId: currentState.relationship.athleteUserId,
        messageText: messageText,
        activityId: activityId,
        nutritionPlanId: nutritionPlanId,
      );

      if (newMessage != null) {
        final updatedMessages = [newMessage, ...currentState.messages];
        state = AsyncData(
          currentState.copyWith(messages: updatedMessages, isLoading: false),
        );
      } else {
        state = AsyncData(
          currentState.copyWith(
            isLoading: false,
            error: 'Failed to send message',
          ),
        );
      }
    } catch (e) {
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to send message: ${e.toString()}',
        ),
      );
    }
  }

  /// Delete a message (only if you sent it)
  Future<void> deleteMessage(String messageId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    try {
      await _coachService.deleteMessage(messageId);

      final updatedMessages = currentState.messages
          .where((m) => m.id != messageId)
          .toList();

      state = AsyncData(
        currentState.copyWith(messages: updatedMessages, isLoading: false),
      );
    } catch (e) {
      state = AsyncData(
        currentState.copyWith(
          isLoading: false,
          error: 'Failed to delete message: ${e.toString()}',
        ),
      );
    }
  }

  /// Refresh athlete data from server
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) {
      // No state yet — trigger full rebuild via invalidation
      ref.invalidateSelf();
      return;
    }

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // Invalidate the cached sync provider to force a fresh sync
      ref.invalidate(
        athleteDataSyncProvider(
          currentState.relationship.id,
          currentState.relationship.athleteUserId,
        ),
      );

      // Trigger on-demand sync for this athlete from Supabase
      await ref.read(
        athleteDataSyncProvider(
          currentState.relationship.id,
          currentState.relationship.athleteUserId,
        ).future,
      );

      // Reload data from local database (now fresh)
      return await _loadAthleteDetails(currentState.relationship.id);
    });
  }

  /// Save nutrition target overrides for athlete
  Future<void> saveNutritionTargets(NutritionTargetOverrides overrides) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      final repo = ref.read(coachRepositoryProvider);

      // Apply guardrails
      final clamped = NutritionTargetGuardrails.clampAll(overrides);

      // Write to Supabase
      await repo.updateAthleteNutritionTargets(
        athleteUserId: currentState.relationship.athleteUserId,
        overridesJson: clamped.hasAnyOverride ? clamped.toJson() : null,
      );

      // Update local state with the new overrides
      final updatedProfile = currentState.athleteProfile?.copyWith(
        nutritionTargetOverrides: clamped.hasAnyOverride ? clamped : null,
      );

      return currentState.copyWith(athleteProfile: updatedProfile);
    });
  }

  /// Create carb loading plan for athlete
  Future<void> createCarbLoadingPlan({
    String? eventId,
    required int protocolDays,
    required DateTime raceDate,
    required double bodyWeightPounds,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      final coachUserId = await ref.read(userIdProvider.future);
      final service = ref.read(carbLoadingServiceProvider);

      await service.createCarbLoadingPlan(
        deviceId: coachUserId,
        userId: coachUserId,
        forUserId: currentState.relationship.athleteUserId,
        eventId: eventId,
        protocolDays: protocolDays,
        raceDate: raceDate,
        bodyWeightPounds: bodyWeightPounds,
      );

      // Reload to pick up the new plan
      return await _loadAthleteDetails(currentState.relationship.id);
    });
  }

  /// Delete carb loading plan for athlete
  Future<void> deleteCarbLoadingPlan({required String eventId}) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      final coachUserId = await ref.read(userIdProvider.future);
      final service = ref.read(carbLoadingServiceProvider);

      await service.deleteCarbLoadingPlan(
        deviceId: coachUserId,
        eventId: eventId,
        currentUserId: coachUserId,
        planOwnerId: currentState.relationship.athleteUserId,
      );

      // Reload to reflect the deleted plan
      return await _loadAthleteDetails(currentState.relationship.id);
    });
  }

  /// Clear error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
