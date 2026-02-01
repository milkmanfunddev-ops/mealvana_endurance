import 'package:flutter/foundation.dart';

import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/integrations_repository.dart';
import '../data/training_peaks_api_client.dart';
import '../domain/athlete_zones.dart';
import '../domain/integration.dart';
import '../domain/sync_change_result.dart';
import 'change_detection_service.dart';
import 'training_peaks_transformer.dart';

/// Service for syncing workouts and events from TrainingPeaks
///
/// CRITICAL DIFFERENCES FROM FINAL SURGE:
/// - Token refresh before API calls (tokens expire in 1 hour!)
/// - Event sync support (unique to TrainingPeaks)
/// - Different API response format (array vs wrapped object)
/// - Max date range is 45 days (vs 14 for Final Surge)
///
/// MANUAL SYNC ONLY (MVP decision):
/// - User clicks "Sync Now" button
/// - Initial sync during onboarding
/// - No automatic background checking
///
/// Sync behavior:
/// - Only imports NEW workouts (doesn't update existing)
/// - Deleted workouts in TrainingPeaks remain in Mealvana
/// - User can manually delete unwanted activities
class TrainingPeaksSyncService {
  TrainingPeaksSyncService({
    required TrainingPeaksApiClient apiClient,
    required IntegrationsRepository integrationsRepository,
    required ActivitiesRepository activitiesRepository,
    required TrainingPeaksTransformer transformer,
    required ChangeDetectionService changeDetectionService,
  })  : _apiClient = apiClient,
        _integrationsRepository = integrationsRepository,
        _activitiesRepository = activitiesRepository,
        _transformer = transformer,
        _changeDetectionService = changeDetectionService;

  final TrainingPeaksApiClient _apiClient;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final TrainingPeaksTransformer _transformer;
  final ChangeDetectionService _changeDetectionService;

  /// Buffer time before token expiration to trigger proactive refresh (5 min)
  static const _tokenExpirationBuffer = Duration(minutes: 5);

  /// How often to re-fetch athlete zones (24 hours)
  static const _zonesStalenessThreshold = Duration(hours: 24);

  /// Sync upcoming workouts from TrainingPeaks with change detection
  ///
  /// [userId] - The user to sync workouts for
  /// [numDays] - How many days ahead to fetch (default: 14, max: 45)
  ///
  /// Returns a [TrainingPeaksSyncResult] with sync statistics.
  Future<TrainingPeaksSyncResult> syncWorkouts(
    String userId, {
    int numDays = 14,
  }) async {
    // 1. First check if integration exists and is active
    var integration = await _integrationsRepository.getIntegration(userId, 'training_peaks');
    if (integration == null || !integration.isActive) {
      return TrainingPeaksSyncResult.notConnected();
    }

    // 2. Ensure we have a valid token (refreshes if needed)
    // IMPORTANT: Use the integration object directly to avoid race conditions
    // during onboarding when the DB write may not be fully committed yet
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksSyncResult.tokenExpired();
    }

    final accessToken = integration.accessToken;

    if (kDebugMode) {
      print('🔄 Starting TrainingPeaks workout sync for user $userId');
    }

    // 3. Fetch athlete zones if stale (non-blocking - failure doesn't stop sync)
    AthleteZones? athleteZones;
    try {
      athleteZones = await _fetchZonesIfStale(integration);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Zone fetch failed (non-blocking): $e');
      }
    }

    try {
      // 4. Fetch workouts from TrainingPeaks API
      final workoutsJson = await _apiClient.getUpcomingWorkouts(
        accessToken,
        days: numDays,
        includeDescription: true,
      );

      if (kDebugMode) {
        print('   Fetched ${workoutsJson.length} workouts from TrainingPeaks');
      }

      // 3. Transform remote workouts to Activity objects
      final remoteActivities = <Activity>[];
      int filteredCount = 0;

      for (final workoutJson in workoutsJson) {
        // Transform (returns null for unsupported workout types)
        final result = _transformer.transform(workoutJson, userId, zones: athleteZones);

        if (result == null) {
          filteredCount++;
          continue;
        }

        remoteActivities.add(result.activity);
      }

      if (kDebugMode) {
        print('   Transformed ${remoteActivities.length} workouts (filtered $filteredCount)');
      }

      // 4. Get existing activities synced from TrainingPeaks
      final localActivities = await _activitiesRepository.getActivitiesByUserAndProvider(
        userId,
        'training_peaks',
      );

      if (kDebugMode) {
        print('   Found ${localActivities.length} local TrainingPeaks activities');
      }

      // 5. Detect changes using ChangeDetectionService
      final changeResult = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: remoteActivities,
        provider: 'training_peaks',
      );

      if (kDebugMode) {
        print('   Change detection: ${changeResult.toString()}');
      }

      // 6. Apply changes to local database
      final insertedActivities = <Activity>[];
      final updatedActivities = <Activity>[];
      final deletedActivityIds = <String>[];

      // Insert NEW activities
      for (final activity in changeResult.newActivities) {
        await _activitiesRepository.insertActivity(activity);
        insertedActivities.add(activity);

        if (kDebugMode) {
          print('   ✓ Inserted: ${activity.title}');
        }
      }

      // Update CHANGED activities
      for (final change in changeResult.updatedActivities) {
        // Merge remote data with local activity ID
        final updatedActivity = change.updatedActivity.copyWith(
          id: change.activityId,
          needsNutritionRefresh: change.scheduleChanged,
        );

        await _activitiesRepository.updateActivityFromProvider(updatedActivity);
        updatedActivities.add(updatedActivity);

        if (kDebugMode) {
          print('   ↻ Updated: ${updatedActivity.title} (needsRefresh: ${change.scheduleChanged})');
        }
      }

      // Soft-delete REMOVED activities
      for (final activityId in changeResult.deletedActivityIds) {
        await _activitiesRepository.softDeleteFromProvider(activityId);
        deletedActivityIds.add(activityId);

        if (kDebugMode) {
          print('   🗑️ Soft-deleted: $activityId');
        }
      }

      // 7. Update sync status
      await _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'success',
      );

      if (kDebugMode) {
        print('✅ Workout sync complete: '
            '${insertedActivities.length} new, '
            '${updatedActivities.length} updated, '
            '${deletedActivityIds.length} deleted, '
            '${changeResult.unchangedCount} unchanged, '
            '$filteredCount filtered');
      }

      return TrainingPeaksSyncResult(
        success: true,
        newWorkouts: insertedActivities.length,
        updated: updatedActivities.length,
        deleted: deletedActivityIds.length,
        unchanged: changeResult.unchangedCount,
        filtered: filteredCount,
        activities: insertedActivities,
        changeResult: changeResult,
      );
    } on TrainingPeaksTokenExpiredException {
      // Token expired during request - this shouldn't happen if OAuth service works
      await _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'error',
        error: 'Token expired. Please reconnect.',
      );
      return TrainingPeaksSyncResult.tokenExpired();
    } catch (e) {
      // Update sync status with error
      await _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'error',
        error: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Workout sync failed: $e');
      }

      return TrainingPeaksSyncResult.error(e.toString());
    }
  }

  /// Sync workouts for a specific date range with change detection
  ///
  /// Max range is 45 days (TrainingPeaks API limitation).
  Future<TrainingPeaksSyncResult> syncWorkoutsByDateRange(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Validate date range (max 45 days)
    final daysDiff = endDate.difference(startDate).inDays;
    if (daysDiff > 45) {
      return TrainingPeaksSyncResult.error(
        'Date range exceeds 45 days limit. Got $daysDiff days.',
      );
    }

    // First check if integration exists and is active
    var integration = await _integrationsRepository.getIntegration(userId, 'training_peaks');
    if (integration == null || !integration.isActive) {
      return TrainingPeaksSyncResult.notConnected();
    }

    // Ensure we have a valid token (refreshes if needed)
    // Use the integration object directly to avoid race conditions
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksSyncResult.tokenExpired();
    }

    final accessToken = integration.accessToken;

    // Fetch athlete zones if stale (non-blocking)
    AthleteZones? athleteZones;
    try {
      athleteZones = await _fetchZonesIfStale(integration);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Zone fetch failed (non-blocking): $e');
      }
    }

    try {
      // Fetch workouts from TrainingPeaks API
      final workoutsJson = await _apiClient.getWorkouts(
        accessToken,
        startDate: startDate,
        endDate: endDate,
        includeDescription: true,
      );

      // Transform remote workouts to Activity objects
      final remoteActivities = <Activity>[];
      int filteredCount = 0;

      for (final workoutJson in workoutsJson) {
        final result = _transformer.transform(workoutJson, userId, zones: athleteZones);

        if (result == null) {
          filteredCount++;
          continue;
        }

        remoteActivities.add(result.activity);
      }

      // Get existing activities synced from TrainingPeaks
      final localActivities = await _activitiesRepository.getActivitiesByUserAndProvider(
        userId,
        'training_peaks',
      );

      // Detect changes
      final changeResult = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: remoteActivities,
        provider: 'training_peaks',
      );

      // Apply changes
      final insertedActivities = <Activity>[];
      final updatedActivities = <Activity>[];
      final deletedActivityIds = <String>[];

      // Insert NEW activities
      for (final activity in changeResult.newActivities) {
        await _activitiesRepository.insertActivity(activity);
        insertedActivities.add(activity);
      }

      // Update CHANGED activities
      for (final change in changeResult.updatedActivities) {
        final updatedActivity = change.updatedActivity.copyWith(
          id: change.activityId,
          needsNutritionRefresh: change.scheduleChanged,
        );

        await _activitiesRepository.updateActivityFromProvider(updatedActivity);
        updatedActivities.add(updatedActivity);
      }

      // Soft-delete REMOVED activities
      for (final activityId in changeResult.deletedActivityIds) {
        await _activitiesRepository.softDeleteFromProvider(activityId);
        deletedActivityIds.add(activityId);
      }

      // Update sync status
      await _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'success',
      );

      return TrainingPeaksSyncResult(
        success: true,
        newWorkouts: insertedActivities.length,
        updated: updatedActivities.length,
        deleted: deletedActivityIds.length,
        unchanged: changeResult.unchangedCount,
        filtered: filteredCount,
        activities: insertedActivities,
        changeResult: changeResult,
      );
    } on TrainingPeaksTokenExpiredException {
      await _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'error',
        error: 'Token expired. Please reconnect.',
      );
      return TrainingPeaksSyncResult.tokenExpired();
    } catch (e) {
      await _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: 'error',
        error: e.toString(),
      );
      return TrainingPeaksSyncResult.error(e.toString());
    }
  }

  /// Sync all upcoming events from TrainingPeaks (UNIQUE FEATURE!)
  ///
  /// This is a major differentiator from Final Surge - we can auto-import
  /// races for nutrition planning and carb-loading.
  ///
  /// [days] - Number of days ahead to search (default: 90 = ~3 months)
  ///
  /// Returns all events found within the date range.
  Future<TrainingPeaksEventSyncResult> syncEvents(
    String userId, {
    int days = 90,
  }) async {
    // First check if integration exists and is active
    var integration = await _integrationsRepository.getIntegration(userId, 'training_peaks');
    if (integration == null || !integration.isActive) {
      return TrainingPeaksEventSyncResult.notConnected();
    }

    // Ensure we have a valid token (refreshes if needed)
    // Use the integration object directly to avoid race conditions
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksEventSyncResult.tokenExpired();
    }

    final accessToken = integration.accessToken;

    if (kDebugMode) {
      print('🔄 Fetching all events from TrainingPeaks ($days day range)...');
    }

    try {
      final eventsJson = await _apiClient.getEventsInRange(
        accessToken,
        days: days,
      );

      if (eventsJson.isEmpty) {
        if (kDebugMode) {
          print('   No upcoming events found');
        }
        return TrainingPeaksEventSyncResult.noEvents();
      }

      // Transform all events
      final events = <TrainingPeaksEventResult>[];
      for (final eventJson in eventsJson) {
        final event = _transformer.transformEvent(eventJson);
        if (event != null) {
          events.add(event);
          if (kDebugMode) {
            print('✅ Found event: ${event.eventName}');
            print('   Type: ${event.eventType}');
            print('   Date: ${event.eventDate}');
          }
        }
      }

      if (kDebugMode) {
        print('✅ Total events found: ${events.length}');
      }

      return TrainingPeaksEventSyncResult(
        success: true,
        events: events,
      );
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksEventSyncResult.tokenExpired();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Event sync failed: $e');
      }
      return TrainingPeaksEventSyncResult.error(e.toString());
    }
  }

  /// Sync only the next upcoming event (faster, single API call)
  ///
  /// Use this for quick checks. For full sync, use [syncEvents].
  Future<TrainingPeaksEventSyncResult> syncNextEvent(String userId) async {
    // First check if integration exists and is active
    var integration = await _integrationsRepository.getIntegration(userId, 'training_peaks');
    if (integration == null || !integration.isActive) {
      return TrainingPeaksEventSyncResult.notConnected();
    }

    // Ensure we have a valid token (refreshes if needed)
    // Use the integration object directly to avoid race conditions
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksEventSyncResult.tokenExpired();
    }

    final accessToken = integration.accessToken;

    if (kDebugMode) {
      print('🔄 Fetching next event from TrainingPeaks...');
    }

    try {
      final eventJson = await _apiClient.getNextEvent(accessToken);

      if (eventJson == null) {
        if (kDebugMode) {
          print('   No upcoming events found');
        }
        return TrainingPeaksEventSyncResult.noEvents();
      }

      final event = _transformer.transformEvent(eventJson);
      if (event == null) {
        return TrainingPeaksEventSyncResult.noEvents();
      }

      if (kDebugMode) {
        print('✅ Found event: ${event.eventName}');
        print('   Type: ${event.eventType}');
        print('   Date: ${event.eventDate}');
        if (event.goalDistanceMiles != null) {
          print('   Distance: ${event.goalDistanceMiles} miles');
        }
      }

      return TrainingPeaksEventSyncResult(
        success: true,
        events: [event],
      );
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksEventSyncResult.tokenExpired();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Event sync failed: $e');
      }
      return TrainingPeaksEventSyncResult.error(e.toString());
    }
  }

  /// Full sync: workouts + all events
  ///
  /// Use this for initial onboarding sync.
  /// [eventDays] - How many days ahead to search for events (default: 90 = ~3 months)
  Future<TrainingPeaksFullSyncResult> syncAll(
    String userId, {
    int workoutDays = 14,
    int eventDays = 90,
  }) async {
    if (kDebugMode) {
      print('🔄 Starting full TrainingPeaks sync...');
    }

    // Sync workouts
    final workoutResult = await syncWorkouts(userId, numDays: workoutDays);

    // Sync all events (don't fail if this fails - events are optional)
    TrainingPeaksEventSyncResult? eventResult;
    try {
      eventResult = await syncEvents(userId, days: eventDays);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Event sync failed, continuing: $e');
      }
    }

    return TrainingPeaksFullSyncResult(
      workoutResult: workoutResult,
      eventResult: eventResult,
    );
  }

  /// Fetch athlete zones from Training Peaks if stale (>24h)
  ///
  /// Returns cached zones from the integration record if fresh,
  /// otherwise fetches from API and persists. Returns null if fetch fails
  /// or no zones are available.
  Future<AthleteZones?> _fetchZonesIfStale(IntegrationModel integration) async {
    // Check if we already have zones and they're fresh
    if (integration.athleteZonesJson != null) {
      final existingZones = AthleteZones.fromJsonString(integration.athleteZonesJson);
      if (existingZones != null) {
        // Consider zones fresh if integration was updated within threshold
        if (integration.updatedAt != null) {
          final age = DateTime.now().difference(integration.updatedAt!);
          if (age < _zonesStalenessThreshold) {
            if (kDebugMode) {
              print('   ✅ Athlete zones are fresh (${age.inHours}h old)');
            }
            return existingZones;
          }
        }
      }
    }

    if (kDebugMode) {
      print('   🔄 Fetching athlete zones from Training Peaks...');
    }

    final zonesJson = await _apiClient.getAthleteZones(integration.accessToken);
    final zones = AthleteZones.fromTrainingPeaksResponse(zonesJson);
    final serialized = zones.toJsonString();

    // Persist zones to integration record
    await _integrationsRepository.updateAthleteZones(
      integration.userId,
      'training_peaks',
      zonesJson: serialized,
    );

    if (kDebugMode) {
      print('   ✅ Athlete zones fetched and stored: $zones');
    }

    return zones;
  }

  /// Ensure the token is valid, refreshing if needed
  ///
  /// IMPORTANT: This method works with the integration object directly,
  /// avoiding race conditions during onboarding when the DB write may not
  /// be fully committed yet. This mirrors the FinalSurgeSyncService pattern.
  Future<IntegrationModel> _ensureValidToken(IntegrationModel integration) async {
    // Check if token is about to expire
    if (integration.tokenExpiresAt != null) {
      final expiresAt = integration.tokenExpiresAt!;
      final now = DateTime.now();
      final bufferTime = now.add(_tokenExpirationBuffer);

      if (expiresAt.isBefore(bufferTime)) {
        if (kDebugMode) {
          print('⚠️ TrainingPeaks token expires soon, proactively refreshing...');
        }
        return _refreshToken(integration);
      }
    }
    return integration;
  }

  /// Refresh the access token and update the stored integration
  Future<IntegrationModel> _refreshToken(IntegrationModel integration) async {
    if (integration.refreshToken == null) {
      if (kDebugMode) {
        print('❌ No refresh token available. User must re-authenticate.');
      }
      throw const TrainingPeaksTokenExpiredException();
    }

    if (kDebugMode) {
      print('🔄 Refreshing TrainingPeaks token...');
    }

    try {
      final tokenResponse = await _apiClient.refreshToken(integration.refreshToken!);

      // Update the integration with new tokens
      final updatedIntegration = IntegrationModel(
        userId: integration.userId,
        provider: integration.provider,
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken ?? integration.refreshToken,
        tokenExpiresAt: tokenResponse.expiresAt,
        providerAthleteId: integration.providerAthleteId,
        providerAthleteName: integration.providerAthleteName,
        providerAthleteEmail: integration.providerAthleteEmail,
        providerAthleteWeightKg: integration.providerAthleteWeightKg,
        providerAthleteBirthMonth: integration.providerAthleteBirthMonth,
        providerAthleteGender: integration.providerAthleteGender,
        athleteZonesJson: integration.athleteZonesJson,
        isActive: true,
        lastSyncStatus: integration.lastSyncStatus,
        lastSyncAt: integration.lastSyncAt,
        lastSyncError: integration.lastSyncError,
        createdAt: integration.createdAt,
        updatedAt: DateTime.now(),
      );

      await _integrationsRepository.upsertIntegration(updatedIntegration);

      if (kDebugMode) {
        print('✅ TrainingPeaks token refreshed and saved');
      }

      return updatedIntegration;
    } on TrainingPeaksApiException catch (e) {
      if (kDebugMode) {
        print('❌ Token refresh failed: ${e.toString()}');
      }
      throw const TrainingPeaksTokenExpiredException();
    }
  }
}

/// Result of a workout sync operation with change detection
class TrainingPeaksSyncResult {
  const TrainingPeaksSyncResult({
    required this.success,
    this.error,
    this.newWorkouts = 0,
    this.updated = 0,
    this.deleted = 0,
    this.unchanged = 0,
    this.filtered = 0,
    this.activities = const [],
    this.tokenExpired = false,
    this.changeResult,
  });

  /// Create a "not connected" result
  factory TrainingPeaksSyncResult.notConnected() {
    return const TrainingPeaksSyncResult(
      success: false,
      error: 'TrainingPeaks is not connected',
    );
  }

  /// Create a "token expired" result
  factory TrainingPeaksSyncResult.tokenExpired() {
    return const TrainingPeaksSyncResult(
      success: false,
      error: 'Token expired. Please reconnect.',
      tokenExpired: true,
    );
  }

  /// Create an error result
  factory TrainingPeaksSyncResult.error(String message) {
    return TrainingPeaksSyncResult(
      success: false,
      error: message,
    );
  }

  final bool success;
  final String? error;
  final int newWorkouts;
  final int updated;
  final int deleted;
  final int unchanged;
  final int filtered;
  final List<Activity> activities;
  final bool tokenExpired;
  final SyncChangeResult? changeResult;

  /// Whether any new workouts were imported
  bool get hasNewWorkouts => newWorkouts > 0;

  /// Whether any changes were detected (new/updated/deleted)
  bool get hasChanges => (newWorkouts + updated + deleted) > 0;

  /// Total workouts processed (new + updated + deleted + unchanged + filtered)
  int get totalProcessed => newWorkouts + updated + deleted + unchanged + filtered;

  /// Human-readable summary
  String get summary {
    if (!success) {
      if (tokenExpired) {
        return 'Token expired. Please reconnect.';
      }
      return error ?? 'Sync failed';
    }
    if (!hasChanges && unchanged == 0) {
      return 'No workouts found';
    }
    if (!hasChanges) {
      return 'All $unchanged workouts up to date';
    }

    final parts = <String>[];
    if (newWorkouts > 0) {
      parts.add('$newWorkouts new');
    }
    if (updated > 0) {
      parts.add('$updated updated');
    }
    if (deleted > 0) {
      parts.add('$deleted removed');
    }

    return '${parts.join(', ')} workout${(newWorkouts + updated + deleted) == 1 ? '' : 's'}';
  }

  @override
  String toString() {
    return 'TrainingPeaksSyncResult('
        'success: $success, '
        'new: $newWorkouts, '
        'updated: $updated, '
        'deleted: $deleted, '
        'unchanged: $unchanged, '
        'filtered: $filtered'
        ')';
  }
}

/// Result of an event sync operation
class TrainingPeaksEventSyncResult {
  const TrainingPeaksEventSyncResult({
    required this.success,
    this.events = const [],
    this.error,
    this.tokenExpired = false,
  });

  factory TrainingPeaksEventSyncResult.notConnected() {
    return const TrainingPeaksEventSyncResult(
      success: false,
      error: 'TrainingPeaks is not connected',
    );
  }

  factory TrainingPeaksEventSyncResult.tokenExpired() {
    return const TrainingPeaksEventSyncResult(
      success: false,
      error: 'Token expired. Please reconnect.',
      tokenExpired: true,
    );
  }

  factory TrainingPeaksEventSyncResult.noEvents() {
    return const TrainingPeaksEventSyncResult(
      success: true,
      events: [],
    );
  }

  factory TrainingPeaksEventSyncResult.error(String message) {
    return TrainingPeaksEventSyncResult(
      success: false,
      error: message,
    );
  }

  final bool success;
  final List<TrainingPeaksEventResult> events;
  final String? error;
  final bool tokenExpired;

  bool get hasEvent => events.isNotEmpty;
}

/// Result of a full sync (workouts + events)
class TrainingPeaksFullSyncResult {
  const TrainingPeaksFullSyncResult({
    required this.workoutResult,
    this.eventResult,
  });

  final TrainingPeaksSyncResult workoutResult;
  final TrainingPeaksEventSyncResult? eventResult;

  bool get success => workoutResult.success;
  bool get hasNewWorkouts => workoutResult.hasNewWorkouts;
  bool get hasEvents => eventResult?.hasEvent ?? false;
  int get eventCount => eventResult?.events.length ?? 0;

  String get summary {
    final parts = <String>[];
    parts.add(workoutResult.summary);
    if (eventResult?.hasEvent ?? false) {
      final count = eventResult!.events.length;
      if (count == 1) {
        parts.add('Found event: ${eventResult!.events.first.eventName}');
      } else {
        parts.add('Found $count events');
      }
    }
    return parts.join('. ');
  }
}
