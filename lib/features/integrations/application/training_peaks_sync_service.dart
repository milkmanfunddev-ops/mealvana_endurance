import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../shared/services/analytics/analytics_tracker.dart';
import 'synced_workout_analytics.dart';
import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/integrations_repository.dart';
import '../data/provider_raw_payloads_repository.dart';
import '../data/training_peaks_api_client.dart';
import '../domain/athlete_zones.dart';
import '../domain/integration.dart';
import '../domain/integration_exceptions.dart';
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
    AnalyticsTracker? analytics,
    ProviderRawPayloadsRepository? rawPayloadsRepository,
  }) : _apiClient = apiClient,
       _integrationsRepository = integrationsRepository,
       _activitiesRepository = activitiesRepository,
       _transformer = transformer,
       _changeDetectionService = changeDetectionService,
       _analytics = analytics,
       _rawPayloadsRepository = rawPayloadsRepository;

  final TrainingPeaksApiClient _apiClient;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final TrainingPeaksTransformer _transformer;
  final ChangeDetectionService _changeDetectionService;
  final AnalyticsTracker? _analytics;
  final ProviderRawPayloadsRepository? _rawPayloadsRepository;

  /// Raw-payload capture (real-payload-corpus@v1, lifecycle.md L-7): offers
  /// the whole fetched list to `provider_raw_payloads`, non-blocking — the
  /// repository dedups by (Id, LastModifiedDate) and never throws.
  void _captureRawPayloads(
    String userId,
    List<Map<String, dynamic>> workoutsJson,
  ) {
    final repo = _rawPayloadsRepository;
    if (repo == null || workoutsJson.isEmpty) return;
    unawaited(
      repo.uploadRawPayloads(
        userId: userId,
        provider: 'training_peaks',
        payloads: workoutsJson,
        idOf: (w) => w['Id']?.toString(),
        lastModifiedOf: (w) => w['LastModifiedDate']?.toString(),
      ),
    );
  }

  void _trackSyncedWorkoutPlanned(Activity activity) =>
      trackSyncedWorkoutPlanned(
        _analytics,
        activity,
        provider: 'training_peaks',
      );

  /// Buffer time before token expiration to trigger proactive refresh (5 min)
  static const _tokenExpirationBuffer = Duration(minutes: 5);

  /// How often to re-fetch athlete zones (24 hours)
  static const _zonesStalenessThreshold = Duration(hours: 24);

  /// How often to re-fetch TP body metrics (same 24 h clock as zones —
  /// data-integrations@v1, Q-INT26 shortlist item 4)
  static const _metricsStalenessThreshold = Duration(hours: 24);

  /// How far back the metrics range read looks (daily body metrics)
  static const _metricsWindowDays = 7;

  /// Max upcoming workout range (TrainingPeaks API limit)
  static const _maxWorkoutDays = 45;

  /// Sync upcoming workouts from TrainingPeaks with change detection
  ///
  /// [userId] - The user to sync workouts for
  /// [numDays] - How many days ahead to fetch (default: 45, max: 45)
  ///
  /// Returns a [TrainingPeaksSyncResult] with sync statistics.
  Future<TrainingPeaksSyncResult> syncWorkouts(
    String userId, {
    int numDays = 45,
  }) async {
    // 1. First check if integration exists and is active
    var integration = await _integrationsRepository.getIntegration(
      userId,
      'training_peaks',
    );
    if (integration == null || !integration.isActive) {
      return TrainingPeaksSyncResult.notConnected();
    }

    // 2. Ensure we have a valid token (refreshes if needed)
    // IMPORTANT: Use the integration object directly to avoid race conditions
    // during onboarding when the DB write may not be fully committed yet
    final stored = integration;
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksSyncResult.tokenExpired();
    } on TrainingPeaksApiException catch (e) {
      await _recordRefreshFailed(userId, e);
      return TrainingPeaksSyncResult.error(e.toString());
    }
    final freshToken = !identical(integration, stored);

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

    // 3b. Fetch body metrics if stale (non-blocking; A1: attempt-and-observe,
    // never gated on the IsPremium snapshot — a 401/403 lands here harmlessly)
    try {
      await _fetchMetricsIfStale(integration);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Metrics fetch failed (non-blocking): $e');
      }
    }

    try {
      final effectiveDays = numDays < 1
          ? 1
          : (numDays > _maxWorkoutDays ? _maxWorkoutDays : numDays);

      // 4. Fetch workouts from TrainingPeaks API
      final workoutsJson = await _callWithToken(
        integration,
        freshToken: freshToken,
        (token) => _apiClient.getUpcomingWorkouts(
          token,
          days: effectiveDays,
          includeDescription: true,
        ),
      );

      if (kDebugMode) {
        print('   Fetched ${workoutsJson.length} workouts from TrainingPeaks');
      }

      _captureRawPayloads(userId, workoutsJson);

      // 3. Transform remote workouts to Activity objects
      final remoteActivities = <Activity>[];
      // M-1.3: provider ids whose payload carries completion evidence — a
      // keyed completion pierces a tombstone; a plan re-import never does.
      final completionSignalIds = <String>{};
      int filteredCount = 0;

      for (final workoutJson in workoutsJson) {
        // Transform (returns null for unsupported workout types)
        final result = _transformer.transform(
          workoutJson,
          userId,
          zones: athleteZones,
        );

        if (result == null) {
          filteredCount++;
          continue;
        }

        remoteActivities.add(result.activity);
        if (result.providerReportsCompletion) {
          completionSignalIds.add(result.providerWorkoutId);
        }
      }

      if (kDebugMode) {
        print(
          '   Transformed ${remoteActivities.length} workouts (filtered $filteredCount)',
        );
      }

      final dedupedRemoteActivities = _dedupeRemoteActivities(remoteActivities);
      final remoteDuplicateCount =
          remoteActivities.length - dedupedRemoteActivities.length;
      if (remoteDuplicateCount > 0) {
        filteredCount += remoteDuplicateCount;
        if (kDebugMode) {
          print(
            '   ⚠️ Removed $remoteDuplicateCount duplicate TrainingPeaks workouts from payload',
          );
        }
      }

      // 4. Clean any existing local duplicates from prior buggy syncs.
      final localDuplicatesRemoved = await _activitiesRepository
          .cleanupDuplicateProviderActivities(
            userId: userId,
            provider: 'training_peaks',
          );
      if (localDuplicatesRemoved > 0 && kDebugMode) {
        print(
          '   🧹 Removed $localDuplicatesRemoved duplicate local TrainingPeaks activities',
        );
      }

      // 5. Get existing activities synced from TrainingPeaks
      final localActivities = await _activitiesRepository
          .getActivitiesByUserAndProvider(userId, 'training_peaks');

      if (kDebugMode) {
        print(
          '   Found ${localActivities.length} local TrainingPeaks activities',
        );
      }

      // 5. Detect changes using ChangeDetectionService
      final changeResult = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: dedupedRemoteActivities,
        provider: 'training_peaks',
        completionSignalIds: completionSignalIds,
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
        _trackSyncedWorkoutPlanned(activity);

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
          print(
            '   ↻ Updated: ${updatedActivity.title} (needsRefresh: ${change.scheduleChanged})',
          );
        }
      }

      // M-1.3: keyed completion signals revive their tombstones.
      for (final revive in changeResult.revivedActivities) {
        await _activitiesRepository.reviveTombstoneFromProvider(
          revive.activityId,
          revive.updatedActivity,
        );
        if (kDebugMode) {
          print(
            '   ⚡ Revived tombstone ${revive.activityId} from completion signal',
          );
        }
      }

      // Q-INT2: hidden-by-disconnect rows matched by this re-sync unhide.
      for (final unhide in changeResult.unhiddenActivities) {
        await _activitiesRepository.unhideAndUpdateFromProvider(
          unhide.activityId,
          unhide.updatedActivity,
        );
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
        print(
          '✅ Workout sync complete: '
          '${insertedActivities.length} new, '
          '${updatedActivities.length} updated, '
          '${deletedActivityIds.length} deleted, '
          '${changeResult.unchangedCount} unchanged, '
          '$filteredCount filtered',
        );
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
      // TP refused the token; _callWithToken or _refreshToken has already
      // marked the connection requires_reauth.
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
    var integration = await _integrationsRepository.getIntegration(
      userId,
      'training_peaks',
    );
    if (integration == null || !integration.isActive) {
      return TrainingPeaksSyncResult.notConnected();
    }

    // Ensure we have a valid token (refreshes if needed)
    // Use the integration object directly to avoid race conditions
    final stored = integration;
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksSyncResult.tokenExpired();
    } on TrainingPeaksApiException catch (e) {
      await _recordRefreshFailed(userId, e);
      return TrainingPeaksSyncResult.error(e.toString());
    }
    final freshToken = !identical(integration, stored);

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
      final workoutsJson = await _callWithToken(
        integration,
        freshToken: freshToken,
        (token) => _apiClient.getWorkouts(
          token,
          startDate: startDate,
          endDate: endDate,
          includeDescription: true,
        ),
      );

      _captureRawPayloads(userId, workoutsJson);

      // Transform remote workouts to Activity objects
      final remoteActivities = <Activity>[];
      // M-1.3: completion-carrying provider ids (see syncWorkouts).
      final completionSignalIds = <String>{};
      int filteredCount = 0;

      for (final workoutJson in workoutsJson) {
        final result = _transformer.transform(
          workoutJson,
          userId,
          zones: athleteZones,
        );

        if (result == null) {
          filteredCount++;
          continue;
        }

        remoteActivities.add(result.activity);
        if (result.providerReportsCompletion) {
          completionSignalIds.add(result.providerWorkoutId);
        }
      }

      final dedupedRemoteActivities = _dedupeRemoteActivities(remoteActivities);
      final remoteDuplicateCount =
          remoteActivities.length - dedupedRemoteActivities.length;
      if (remoteDuplicateCount > 0) {
        filteredCount += remoteDuplicateCount;
      }

      // Clean any existing local duplicates from prior buggy syncs.
      await _activitiesRepository.cleanupDuplicateProviderActivities(
        userId: userId,
        provider: 'training_peaks',
      );

      // Get existing activities synced from TrainingPeaks
      final localActivities = await _activitiesRepository
          .getActivitiesByUserAndProvider(userId, 'training_peaks');

      // Detect changes
      final changeResult = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: dedupedRemoteActivities,
        provider: 'training_peaks',
        completionSignalIds: completionSignalIds,
      );

      // M-1.3: keyed completion signals revive their tombstones.
      for (final revive in changeResult.revivedActivities) {
        await _activitiesRepository.reviveTombstoneFromProvider(
          revive.activityId,
          revive.updatedActivity,
        );
      }

      for (final unhide in changeResult.unhiddenActivities) {
        await _activitiesRepository.unhideAndUpdateFromProvider(
          unhide.activityId,
          unhide.updatedActivity,
        );
      }

      // Apply changes
      final insertedActivities = <Activity>[];
      final updatedActivities = <Activity>[];
      final deletedActivityIds = <String>[];

      // Insert NEW activities
      for (final activity in changeResult.newActivities) {
        await _activitiesRepository.insertActivity(activity);
        insertedActivities.add(activity);
        _trackSyncedWorkoutPlanned(activity);
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
      // Already marked requires_reauth (see syncWorkouts).
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
    var integration = await _integrationsRepository.getIntegration(
      userId,
      'training_peaks',
    );
    if (integration == null || !integration.isActive) {
      return TrainingPeaksEventSyncResult.notConnected();
    }

    // Ensure we have a valid token (refreshes if needed)
    // Use the integration object directly to avoid race conditions
    final stored = integration;
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksEventSyncResult.tokenExpired();
    } on TrainingPeaksApiException catch (e) {
      await _recordRefreshFailed(userId, e);
      return TrainingPeaksEventSyncResult.error(e.toString());
    }
    final freshToken = !identical(integration, stored);

    if (kDebugMode) {
      print('🔄 Fetching all events from TrainingPeaks ($days day range)...');
    }

    try {
      final eventsJson = await _callWithToken(
        integration,
        freshToken: freshToken,
        (token) => _apiClient.getEventsInRange(token, days: days),
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

      return TrainingPeaksEventSyncResult(success: true, events: events);
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
    var integration = await _integrationsRepository.getIntegration(
      userId,
      'training_peaks',
    );
    if (integration == null || !integration.isActive) {
      return TrainingPeaksEventSyncResult.notConnected();
    }

    // Ensure we have a valid token (refreshes if needed)
    // Use the integration object directly to avoid race conditions
    final stored = integration;
    try {
      integration = await _ensureValidToken(integration);
    } on TrainingPeaksTokenExpiredException {
      return TrainingPeaksEventSyncResult.tokenExpired();
    } on TrainingPeaksApiException catch (e) {
      await _recordRefreshFailed(userId, e);
      return TrainingPeaksEventSyncResult.error(e.toString());
    }
    final freshToken = !identical(integration, stored);

    if (kDebugMode) {
      print('🔄 Fetching next event from TrainingPeaks...');
    }

    try {
      final eventJson = await _callWithToken(
        integration,
        freshToken: freshToken,
        _apiClient.getNextEvent,
      );

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

      return TrainingPeaksEventSyncResult(success: true, events: [event]);
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
    int workoutDays = 45,
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
      final existingZones = AthleteZones.fromJsonString(
        integration.athleteZonesJson,
      );
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

  /// Fetch TP body metrics if stale (data-integrations@v1, Q-INT26 item 4).
  ///
  /// A1 (ruled 2026-09-20): NOT gated on the stored IsPremium flag — the
  /// flag is a connect-time snapshot proven false-negative on
  /// premium-featured trials, so with the old gate this fetch had never run
  /// for any athlete. The fetch simply attempts; a 401/403 (range reads are
  /// premium/scope-gated at TP's end) lands in the caller's non-blocking
  /// catch, which is the graceful handling. The cache carries its own
  /// `fetchedAt` marker inside `athlete_metrics_json` because
  /// `integration.updatedAt` is shared with the zones write and would read
  /// as always-fresh right after a zones fetch. The newest metric carrying
  /// `WeightInKilograms` also refreshes `provider_athlete_weight_kg` —
  /// ongoing TP weight without Garmin.
  Future<void> _fetchMetricsIfStale(IntegrationModel integration) async {
    final cached = integration.athleteMetricsJson;
    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final fetchedAt = DateTime.tryParse(
          decoded['fetchedAt'] as String? ?? '',
        );
        if (fetchedAt != null &&
            DateTime.now().difference(fetchedAt) < _metricsStalenessThreshold) {
          if (kDebugMode) {
            print('   ✅ Athlete metrics are fresh');
          }
          return;
        }
      } catch (_) {
        // Malformed cache — fall through and refetch.
      }
    }

    final now = DateTime.now();
    final metrics = await _apiClient.getAthleteMetrics(
      integration.accessToken,
      startDate: now.subtract(const Duration(days: _metricsWindowDays)),
      endDate: now,
    );

    // Newest metric that carries a weight refreshes the profile mirror.
    double? weightKg;
    DateTime? weightSeenAt;
    for (final metric in metrics) {
      final w = (metric['WeightInKilograms'] as num?)?.toDouble();
      if (w == null) continue;
      final at =
          DateTime.tryParse(metric['DateTime'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (weightSeenAt == null || at.isAfter(weightSeenAt)) {
        weightSeenAt = at;
        weightKg = w;
      }
    }

    await _integrationsRepository.updateAthleteMetrics(
      integration.userId,
      'training_peaks',
      metricsJson: jsonEncode({
        'fetchedAt': now.toIso8601String(),
        'metrics': metrics,
      }),
      weightKg: weightKg,
    );

    if (kDebugMode) {
      print(
        '   ✅ Athlete metrics fetched (${metrics.length} days'
        '${weightKg != null ? ', weight ${weightKg.toStringAsFixed(1)} kg' : ''})',
      );
    }
  }

  /// Ensure the token is valid, refreshing if needed
  ///
  /// IMPORTANT: This method works with the integration object directly,
  /// avoiding race conditions during onboarding when the DB write may not
  /// be fully committed yet. This mirrors the FinalSurgeSyncService pattern.
  Future<IntegrationModel> _ensureValidToken(
    IntegrationModel integration,
  ) async {
    // Check if token is about to expire
    if (integration.tokenExpiresAt != null) {
      final expiresAt = integration.tokenExpiresAt!;
      final now = DateTime.now();
      final bufferTime = now.add(_tokenExpirationBuffer);

      if (expiresAt.isBefore(bufferTime)) {
        if (kDebugMode) {
          print(
            '⚠️ TrainingPeaks token expires soon, proactively refreshing...',
          );
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
      await _markNeedsReconnect(integration.userId);
      throw const TrainingPeaksTokenExpiredException();
    }

    if (kDebugMode) {
      print('🔄 Refreshing TrainingPeaks token...');
    }

    try {
      final tokenResponse = await _apiClient.refreshToken(
        integration.refreshToken!,
      );

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
      // Ticket 64 (Finding 21-004): TP refusing the refresh token is final —
      // record it on the row so the connection shows as needing a sign-in
      // again. A transient failure (outage, rate limit) stays an ordinary
      // error: the next sync may well succeed.
      if (!isRefreshRefusedForGood(e.statusCode)) rethrow;
      await _markNeedsReconnect(integration.userId);
      throw const TrainingPeaksTokenExpiredException();
    }
  }

  /// Ticket 76 (Finding 64-001): runs a TP data call with the connection's
  /// access token. A 401 on a token this sync has not refreshed gets one
  /// refresh and one retry; a 401 on a fresh token means TP refuses the
  /// connection, so it is marked as needing reconnection and
  /// [TrainingPeaksTokenExpiredException] is thrown. Other failures pass
  /// through unchanged and stay ordinary errors.
  Future<T> _callWithToken<T>(
    IntegrationModel integration,
    Future<T> Function(String accessToken) call, {
    required bool freshToken,
  }) async {
    try {
      return await call(integration.accessToken);
    } on TokenExpiredException {
      if (freshToken) {
        await _markNeedsReconnect(integration.userId);
        throw const TrainingPeaksTokenExpiredException();
      }
    }
    final refreshed = await _refreshToken(integration);
    return _callWithToken(refreshed, call, freshToken: true);
  }

  /// A refresh that failed without TP refusing it (outage, rate limit, no
  /// network): an ordinary error the next sync may clear.
  Future<void> _recordRefreshFailed(
    String userId,
    TrainingPeaksApiException e,
  ) => _integrationsRepository.updateSyncStatus(
    userId,
    'training_peaks',
    status: 'error',
    error: e.toString(),
  );

  Future<void> _markNeedsReconnect(String userId) =>
      _integrationsRepository.updateSyncStatus(
        userId,
        'training_peaks',
        status: requiresReauthStatus,
        error: 'Token refresh refused. Please reconnect.',
      );

  /// Dedupe remote workouts so sync remains idempotent even when provider APIs
  /// return repeated records in a single payload.
  List<Activity> _dedupeRemoteActivities(List<Activity> activities) {
    final deduped = <Activity>[];
    final seenKeys = <String>{};

    for (final activity in activities) {
      final providerId = activity.providerWorkoutId?.trim();
      final key = (providerId != null && providerId.isNotEmpty)
          ? 'id:$providerId'
          : 'fp:${activity.activityType.name}|${activity.title.trim().toLowerCase()}|'
                '${activity.scheduledDateTime.toUtc().toIso8601String()}|'
                '${activity.durationMinutes ?? -1}|${activity.distanceMiles?.toStringAsFixed(3) ?? 'na'}';

      if (seenKeys.add(key)) {
        deduped.add(activity);
      }
    }

    return deduped;
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
    return TrainingPeaksSyncResult(success: false, error: message);
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
  int get totalProcessed =>
      newWorkouts + updated + deleted + unchanged + filtered;

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
    return const TrainingPeaksEventSyncResult(success: true, events: []);
  }

  factory TrainingPeaksEventSyncResult.error(String message) {
    return TrainingPeaksEventSyncResult(success: false, error: message);
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
