import 'dart:async';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../shared/database/database_provider.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../activities/domain/activity.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../events/domain/event.dart';
import '../../../carb_loading/domain/carb_loading_plan_simple.dart';
import '../../application/coach_service.dart';
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
  final List<Activity> activities;
  final List<CoachMessage> messages;
  final bool isLoading;
  final String? error;

  const AthleteDetailState({
    required this.relationship,
    this.athleteProfile,
    this.events = const [],
    this.carbLoadingPlans = const [],
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
      final db = ref.read(appDatabaseProvider);

      // Load athlete profile by user ID
      final athleteProfile = await db.getUserProfileById(relationship.athleteUserId);

      // Debug logging
      print('🔍 DEBUG: Loading athlete ${relationship.athleteUserId}');
      print('🔍 DEBUG: Profile found: ${athleteProfile != null}');
      if (athleteProfile != null) {
        print('🔍 DEBUG: First name: ${athleteProfile.firstName}');
        print('🔍 DEBUG: Last name: ${athleteProfile.lastName}');
        print('🔍 DEBUG: Display name: ${athleteProfile.displayName}');
      }

      // Load athlete events using Drift select syntax
      final eventEntries = await (db.select(db.eventsTable)
            ..where((t) => t.userId.equals(relationship.athleteUserId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
      final events = eventEntries.map((e) => _mapEventEntry(e)).toList();

      // Load athlete activities using Drift select syntax
      final activityEntries = await (db.select(db.activitiesTable)
            ..where((t) => t.userId.equals(relationship.athleteUserId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.scheduledDateTime)]))
          .get();
      final activities = activityEntries.map((a) => _mapActivityEntry(a)).toList();

      // Load athlete carb loading plans using Drift select syntax
      // NOTE: Carb loading plans currently disabled due to schema mismatch.
      // Database table (carb_loading_plans) schema doesn't match domain model (CarbLoadingPlan).
      // Table has: totalDays, startDate, endDate, dailyCarbTargetGrams
      // Domain expects: raceDate, raceDistance, trainingVolume, dailyCarbTargetG, daySelections
      // This requires schema migration or repository layer transformation.
      final carbLoadingPlans = <CarbLoadingPlan>[];

      return AthleteDetailState(
        relationship: relationship,
        athleteProfile: athleteProfile,
        messages: messages,
        events: events,
        activities: activities,
        carbLoadingPlans: carbLoadingPlans,
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
        state = AsyncData(currentState.copyWith(
          messages: updatedMessages,
          isLoading: false,
        ));
      } else {
        state = AsyncData(currentState.copyWith(
          isLoading: false,
          error: 'Failed to send message',
        ));
      }
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to send message: ${e.toString()}',
      ));
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

      state = AsyncData(currentState.copyWith(
        messages: updatedMessages,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoading: false,
        error: 'Failed to delete message: ${e.toString()}',
      ));
    }
  }

  /// Refresh athlete data from server
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
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

  /// Clear error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}
