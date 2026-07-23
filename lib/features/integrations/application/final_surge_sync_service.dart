import 'package:flutter/foundation.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';

import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import 'synced_workout_analytics.dart';
import '../data/final_surge_api_client.dart';
import '../data/integrations_repository.dart';
import '../domain/integration.dart';
import '../domain/sync_change_result.dart';
import 'change_detection_service.dart';
import 'final_surge_transformer.dart';

/// Service for syncing workouts from Final Surge
///
/// MANUAL SYNC ONLY (MVP decision):
/// - User clicks "Sync Now" button
/// - Initial sync during onboarding
/// - No automatic background checking
///
/// Token refresh behavior:
/// - Proactively refreshes tokens within 5 minutes of expiration
/// - Automatically retries on 401 with refreshed token
/// - Marks integration as needing re-auth if refresh fails
///
/// Sync behavior (UPDATED with change detection):
/// - NEW workouts: Inserted with synced_from_provider metadata
/// - UPDATED workouts: Updated with schedule change detection
///   - Significant schedule changes → needsNutritionRefresh = true
///   - Minor changes → update only
/// - DELETED workouts: Soft-deleted with providerDeletedAt timestamp
class FinalSurgeSyncService {
  FinalSurgeSyncService({
    required FinalSurgeApiClient apiClient,
    required IntegrationsRepository integrationsRepository,
    required ActivitiesRepository activitiesRepository,
    required FinalSurgeTransformer transformer,
    required ChangeDetectionService changeDetectionService,
    AnalyticsTracker? analytics,
  }) : _analytics = analytics,
       _apiClient = apiClient,
       _integrationsRepository = integrationsRepository,
       _activitiesRepository = activitiesRepository,
       _transformer = transformer,
       _changeDetectionService = changeDetectionService;

  final FinalSurgeApiClient _apiClient;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final FinalSurgeTransformer _transformer;
  final ChangeDetectionService _changeDetectionService;
  final AnalyticsTracker? _analytics;

  void _trackSyncedWorkoutPlanned(Activity activity) =>
      trackSyncedWorkoutPlanned(_analytics, activity, provider: 'final_surge');

  /// Buffer time before token expiration to trigger proactive refresh (5 min)
  static const _tokenExpirationBuffer = Duration(minutes: 5);

  /// Sync upcoming workouts from Final Surge
  ///
  /// [userId] - The user to sync workouts for
  /// [numDays] - How many days ahead to fetch (default: 14, max: 14)
  /// [numWorkouts] - Maximum workouts per request (default: 21, max: 21)
  ///
  /// Returns a [SyncResult] with sync statistics.
  ///
  /// Automatically handles token refresh when tokens expire.
  Future<SyncResult> syncWorkouts(
    String userId, {
    int numDays = 14,
    int numWorkouts = 21,
  }) async {
    // 1. Check if user has an active Final Surge integration
    final integrationRecord = await _integrationsRepository.getIntegration(
      userId,
      'final_surge',
    );

    if (integrationRecord == null || !integrationRecord.isActive) {
      return SyncResult.notConnected();
    }

    var integration = integrationRecord;

    if (kDebugMode) {
      print('🔄 Starting Final Surge sync for user $userId');
    }

    try {
      // 2. Proactively refresh token if it's about to expire
      integration = await _ensureValidToken(integration);

      // 3. Fetch workouts from Final Surge API (two 7-day chunks for 14-day window)
      Future<FinalSurgeWorkoutsResponse> fetchUpcomingChunk(int days) async {
        try {
          return await _apiClient.getUpcomingWorkouts(
            integration.accessToken,
            numDays: days,
            numWorkouts: numWorkouts,
          );
        } on TokenExpiredException {
          // Token expired during request - refresh and retry once
          if (kDebugMode) {
            print('⚠️ Token expired during request, refreshing...');
          }
          integration = await _refreshToken(integration);
          return await _apiClient.getUpcomingWorkouts(
            integration.accessToken,
            numDays: days,
            numWorkouts: numWorkouts,
          );
        }
      }

      Future<FinalSurgeWorkoutsResponse> fetchDateRangeChunk({
        required DateTime startDate,
        required DateTime endDate,
      }) async {
        try {
          return await _apiClient.getWorkoutsByDateRange(
            integration.accessToken,
            startDate: startDate,
            endDate: endDate,
          );
        } on TokenExpiredException {
          if (kDebugMode) {
            print('⚠️ Token expired during request, refreshing...');
          }
          integration = await _refreshToken(integration);
          return await _apiClient.getWorkoutsByDateRange(
            integration.accessToken,
            startDate: startDate,
            endDate: endDate,
          );
        }
      }

      final effectiveDays = numDays < 1 ? 1 : (numDays > 14 ? 14 : numDays);
      final firstChunkDays = effectiveDays > 7 ? 7 : effectiveDays;

      final workouts = <Map<String, dynamic>>[];
      final firstResponse = await fetchUpcomingChunk(firstChunkDays);
      if (firstResponse.hasError) {
        throw FinalSurgeApiException(
          firstResponse.errorMessage ?? 'Failed to fetch workouts',
        );
      }
      workouts.addAll(firstResponse.workouts);

      if (effectiveDays > 7) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final startDate = today.add(const Duration(days: 7));
        final endDate = today.add(Duration(days: effectiveDays - 1));

        try {
          final secondResponse = await fetchDateRangeChunk(
            startDate: startDate,
            endDate: endDate,
          );
          if (secondResponse.hasError) {
            throw FinalSurgeApiException(
              secondResponse.errorMessage ?? 'Failed to fetch workouts',
            );
          }
          workouts.addAll(secondResponse.workouts);
        } on IntegrationApiException catch (e) {
          // Some Final Surge tenants return 404 for /API/v1/Workouts.
          // Fall back to UpcomingWorkouts for the full window instead of failing the sync.
          if (e.statusCode != 404) rethrow;

          if (kDebugMode) {
            print(
              '⚠️ Date-range endpoint unavailable (404), falling back to UpcomingWorkouts for $effectiveDays days',
            );
          }

          final fallbackResponse = await fetchUpcomingChunk(effectiveDays);
          if (fallbackResponse.hasError) {
            throw FinalSurgeApiException(
              fallbackResponse.errorMessage ?? 'Failed to fetch workouts',
            );
          }
          workouts.addAll(fallbackResponse.workouts);
        }
      }

      // Dedupe by provider workout ID to avoid duplicates across chunks
      final seenIds = <String>{};
      final dedupedWorkouts = <Map<String, dynamic>>[];
      for (final workout in workouts) {
        final workoutId = _transformer.extractWorkoutId(workout);
        if (seenIds.add(workoutId)) {
          dedupedWorkouts.add(workout);
        }
      }

      if (kDebugMode) {
        print('   Fetched ${dedupedWorkouts.length} workouts from Final Surge');
      }

      // 4. Transform workouts to Activity objects
      // For workouts with structured data, fetch and pass it to the transformer
      final remoteActivities = <Activity>[];
      final raceCandidates = <FinalSurgeRaceCandidate>[];
      int filteredCount = 0;

      for (final workoutJson in dedupedWorkouts) {
        // Fetch structured workout data if available
        Map<String, dynamic>? structuredData;
        if (workoutJson['HasStructuredWorkout'] == true) {
          try {
            final urls =
                workoutJson['StructuredWorkoutURLs'] as Map<String, dynamic>?;
            final jsonFsV1Url = urls?['json_fs_v1'] as String?;
            if (jsonFsV1Url != null && jsonFsV1Url.isNotEmpty) {
              structuredData = await _apiClient.getStructuredWorkout(
                integration.accessToken,
                jsonFsV1Url,
              );
              if (kDebugMode) {
                print(
                  '   📋 Fetched structured workout for ${workoutJson['WorkoutTitle']}',
                );
              }
            }
          } catch (e) {
            // Don't block sync if structured workout fetch fails
            if (kDebugMode) {
              print('   ⚠️ Failed to fetch structured workout: $e');
            }
          }
        }

        // Transform (returns null for unsupported workout types)
        final result = _transformer.transform(
          workoutJson,
          userId,
          structuredData: structuredData,
        );

        if (result == null) {
          filteredCount++;
          continue;
        }

        remoteActivities.add(result.activity);
        final candidate = _buildRaceCandidate(workoutJson, result.activity);
        if (candidate != null) {
          raceCandidates.add(candidate);
        }
      }

      if (kDebugMode) {
        print(
          '   Transformed ${remoteActivities.length} workouts (filtered: $filteredCount)',
        );
      }

      final dedupedRemoteActivities = _dedupeRemoteActivities(remoteActivities);
      final remoteDuplicateCount =
          remoteActivities.length - dedupedRemoteActivities.length;
      if (remoteDuplicateCount > 0) {
        filteredCount += remoteDuplicateCount;
        if (kDebugMode) {
          print(
            '   ⚠️ Removed $remoteDuplicateCount duplicate Final Surge workouts from payload',
          );
        }
      }

      // Clean any existing local duplicates from prior buggy syncs.
      final localDuplicatesRemoved = await _activitiesRepository
          .cleanupDuplicateProviderActivities(
            userId: userId,
            provider: 'final_surge',
          );
      if (localDuplicatesRemoved > 0 && kDebugMode) {
        print(
          '   🧹 Removed $localDuplicatesRemoved duplicate local Final Surge activities',
        );
      }

      // 5. Get existing activities from this provider for change detection
      final localActivities = await _activitiesRepository
          .getActivitiesByUserAndProvider(userId, 'final_surge');

      if (kDebugMode) {
        print(
          '   Found ${localActivities.length} existing Final Surge activities',
        );
      }

      // 6. Detect changes between local and remote
      final changes = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: dedupedRemoteActivities,
        provider: 'final_surge',
      );

      if (kDebugMode) {
        print('   Changes detected: $changes');
      }

      // 7. Apply changes
      // NEW: Insert new activities
      for (final activity in changes.newActivities) {
        await _activitiesRepository.insertActivity(activity);
        _trackSyncedWorkoutPlanned(activity);
        if (kDebugMode) {
          print('   ✓ Inserted: ${activity.title}');
        }
      }

      // UPDATED: Update existing activities (using copyWith to preserve all fields)
      for (final change in changes.updatedActivities) {
        final updatedActivity = change.updatedActivity.copyWith(
          id: change.activityId,
          needsNutritionRefresh: change.scheduleChanged,
          lastSyncedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _activitiesRepository.updateActivityFromProvider(updatedActivity);

        if (kDebugMode) {
          print(
            '   ✓ Updated: ${updatedActivity.title} (scheduleChanged: ${change.scheduleChanged})',
          );
        }
      }

      // DELETED: Soft-delete activities removed from provider
      for (final activityId in changes.deletedActivityIds) {
        await _activitiesRepository.softDeleteFromProvider(activityId);
        if (kDebugMode) {
          print('   ✓ Soft-deleted: $activityId');
        }
      }

      final raceCandidatesWithIds = _attachActivityIdsToRaceCandidates(
        raceCandidates: raceCandidates,
        localActivities: localActivities,
        changeResult: changes,
      );

      // 8. Update sync status
      await _integrationsRepository.updateSyncStatus(
        userId,
        'final_surge',
        status: 'success',
      );

      if (kDebugMode) {
        print(
          '✅ Sync complete: ${changes.newActivities.length} new, '
          '${changes.updatedActivities.length} updated, '
          '${changes.deletedActivityIds.length} deleted, '
          '$filteredCount filtered',
        );
      }

      return SyncResult(
        success: true,
        newWorkouts: changes.newActivities.length,
        updated: changes.updatedActivities.length,
        deleted: changes.deletedActivityIds.length,
        skipped: changes.unchangedCount,
        filtered: filteredCount,
        activities: changes.newActivities,
        raceCandidates: raceCandidatesWithIds,
      );
    } on TokenRefreshException catch (e) {
      // Token refresh failed - user must re-authenticate
      if (e.requiresReauth) {
        await _integrationsRepository.updateSyncStatus(
          userId,
          'final_surge',
          status: 'requires_reauth',
          error: 'Please reconnect your Final Surge account',
        );
        return SyncResult.requiresReauth();
      }
      return SyncResult.error(e.message);
    } on NetworkException catch (e) {
      // Network issues - don't update status, user can retry
      if (kDebugMode) {
        print('❌ Sync failed (network): $e');
      }
      return SyncResult.networkError(e.message);
    } catch (e) {
      // Update sync status with error
      await _integrationsRepository.updateSyncStatus(
        userId,
        'final_surge',
        status: 'error',
        error: e.toString(),
      );

      if (kDebugMode) {
        print('❌ Sync failed: $e');
      }

      return SyncResult.error(e.toString());
    }
  }

  /// Ensure the token is valid, refreshing if needed
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
          print('⚠️ Token expires soon, proactively refreshing...');
        }
        return _refreshToken(integration);
      }
    }
    return integration;
  }

  /// Refresh the access token and update the stored integration
  Future<IntegrationModel> _refreshToken(IntegrationModel integration) async {
    if (integration.refreshToken == null) {
      throw TokenRefreshException(
        'No refresh token available',
        requiresReauth: true,
      );
    }

    final tokenResponse = await _apiClient.refreshAccessToken(
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
      print('✅ Token refreshed and saved');
    }

    return updatedIntegration;
  }

  /// Sync workouts for a specific date range
  ///
  /// Useful for syncing past workouts or a longer range.
  /// Automatically handles token refresh when tokens expire.
  Future<SyncResult> syncWorkoutsByDateRange(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final integrationRecord = await _integrationsRepository.getIntegration(
      userId,
      'final_surge',
    );

    if (integrationRecord == null || !integrationRecord.isActive) {
      return SyncResult.notConnected();
    }

    var integration = integrationRecord;

    try {
      // Proactively refresh token if needed
      integration = await _ensureValidToken(integration);

      FinalSurgeWorkoutsResponse response;
      try {
        response = await _apiClient.getWorkoutsByDateRange(
          integration.accessToken,
          startDate: startDate,
          endDate: endDate,
        );
      } on TokenExpiredException {
        // Token expired during request - refresh and retry once
        integration = await _refreshToken(integration);
        response = await _apiClient.getWorkoutsByDateRange(
          integration.accessToken,
          startDate: startDate,
          endDate: endDate,
        );
      }

      if (response.hasError) {
        throw FinalSurgeApiException(
          response.errorMessage ?? 'Failed to fetch workouts',
        );
      }

      // Transform workouts to Activity objects (with structured data if available)
      final remoteActivities = <Activity>[];
      final raceCandidates = <FinalSurgeRaceCandidate>[];
      int filteredCount = 0;

      for (final workoutJson in response.workouts) {
        // Fetch structured workout data if available
        Map<String, dynamic>? structuredData;
        if (workoutJson['HasStructuredWorkout'] == true) {
          try {
            final urls =
                workoutJson['StructuredWorkoutURLs'] as Map<String, dynamic>?;
            final jsonFsV1Url = urls?['json_fs_v1'] as String?;
            if (jsonFsV1Url != null && jsonFsV1Url.isNotEmpty) {
              structuredData = await _apiClient.getStructuredWorkout(
                integration.accessToken,
                jsonFsV1Url,
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print('   ⚠️ Failed to fetch structured workout: $e');
            }
          }
        }

        final result = _transformer.transform(
          workoutJson,
          userId,
          structuredData: structuredData,
        );

        if (result == null) {
          filteredCount++;
          continue;
        }

        remoteActivities.add(result.activity);
        final candidate = _buildRaceCandidate(workoutJson, result.activity);
        if (candidate != null) {
          raceCandidates.add(candidate);
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
        provider: 'final_surge',
      );

      // Get existing activities from this provider for change detection
      final localActivities = await _activitiesRepository
          .getActivitiesByUserAndProvider(userId, 'final_surge');

      // Detect changes between local and remote
      final changes = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: dedupedRemoteActivities,
        provider: 'final_surge',
      );

      // Apply changes
      // NEW: Insert new activities
      for (final activity in changes.newActivities) {
        await _activitiesRepository.insertActivity(activity);
        _trackSyncedWorkoutPlanned(activity);
      }

      // UPDATED: Update existing activities (using copyWith to preserve all fields)
      for (final change in changes.updatedActivities) {
        final updatedActivity = change.updatedActivity.copyWith(
          id: change.activityId,
          needsNutritionRefresh: change.scheduleChanged,
          lastSyncedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _activitiesRepository.updateActivityFromProvider(updatedActivity);
      }

      // DELETED: Soft-delete activities removed from provider
      for (final activityId in changes.deletedActivityIds) {
        await _activitiesRepository.softDeleteFromProvider(activityId);
      }

      final raceCandidatesWithIds = _attachActivityIdsToRaceCandidates(
        raceCandidates: raceCandidates,
        localActivities: localActivities,
        changeResult: changes,
      );

      await _integrationsRepository.updateSyncStatus(
        userId,
        'final_surge',
        status: 'success',
      );

      return SyncResult(
        success: true,
        newWorkouts: changes.newActivities.length,
        updated: changes.updatedActivities.length,
        deleted: changes.deletedActivityIds.length,
        skipped: changes.unchangedCount,
        filtered: filteredCount,
        activities: changes.newActivities,
        raceCandidates: raceCandidatesWithIds,
      );
    } on TokenRefreshException catch (e) {
      if (e.requiresReauth) {
        await _integrationsRepository.updateSyncStatus(
          userId,
          'final_surge',
          status: 'requires_reauth',
          error: 'Please reconnect your Final Surge account',
        );
        return SyncResult.requiresReauth();
      }
      return SyncResult.error(e.message);
    } on NetworkException catch (e) {
      return SyncResult.networkError(e.message);
    } catch (e) {
      await _integrationsRepository.updateSyncStatus(
        userId,
        'final_surge',
        status: 'error',
        error: e.toString(),
      );

      return SyncResult.error(e.toString());
    }
  }

  FinalSurgeRaceCandidate? _buildRaceCandidate(
    Map<String, dynamic> workoutJson,
    Activity activity,
  ) {
    final isRace = workoutJson['WorkoutRace'] == true;
    if (!isRace) return null;

    final providerWorkoutId = activity.providerWorkoutId;
    if (providerWorkoutId == null || providerWorkoutId.isEmpty) {
      return null;
    }

    final rawTitle = workoutJson['WorkoutTitle'] as String?;
    final rawSubtype = workoutJson['WorkoutSubTypeName'] as String?;
    final rawTypeName = workoutJson['WorkoutTypeName'] as String?;
    final nameCandidates = [rawTitle, rawSubtype, rawTypeName]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);

    final eventName = nameCandidates.isNotEmpty ? nameCandidates.first : 'Race';

    return FinalSurgeRaceCandidate(
      providerWorkoutId: providerWorkoutId,
      activityId: activity.id,
      eventName: eventName,
      eventType: activity.activityType,
      scheduledAt: activity.scheduledDateTime,
      goalTimeMinutes: activity.durationMinutes,
      goalPaceMinutesPerMile: activity.paceTargetMinutesPerMile,
    );
  }

  List<FinalSurgeRaceCandidate> _attachActivityIdsToRaceCandidates({
    required List<FinalSurgeRaceCandidate> raceCandidates,
    required List<Activity> localActivities,
    required SyncChangeResult changeResult,
  }) {
    if (raceCandidates.isEmpty) {
      return const [];
    }

    final activityIdByProvider = <String, String>{};

    for (final activity in changeResult.newActivities) {
      final providerId = activity.providerWorkoutId;
      if (providerId != null && providerId.isNotEmpty) {
        activityIdByProvider[providerId] = activity.id;
      }
    }

    for (final change in changeResult.updatedActivities) {
      final providerId = change.updatedActivity.providerWorkoutId;
      if (providerId != null && providerId.isNotEmpty) {
        activityIdByProvider[providerId] = change.activityId;
      }
    }

    for (final activity in localActivities) {
      final providerId = activity.providerWorkoutId;
      if (providerId != null &&
          providerId.isNotEmpty &&
          !activityIdByProvider.containsKey(providerId)) {
        activityIdByProvider[providerId] = activity.id;
      }
    }

    final results = <FinalSurgeRaceCandidate>[];
    for (final candidate in raceCandidates) {
      final providerId = candidate.providerWorkoutId;
      final activityId = activityIdByProvider[providerId];
      if (activityId == null) continue;
      results.add(candidate.copyWith(activityId: activityId));
    }

    return results;
  }

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

class FinalSurgeRaceCandidate {
  const FinalSurgeRaceCandidate({
    required this.providerWorkoutId,
    this.activityId,
    required this.eventName,
    required this.eventType,
    required this.scheduledAt,
    this.goalTimeMinutes,
    this.goalPaceMinutesPerMile,
  });

  final String providerWorkoutId;
  final String? activityId;
  final String eventName;
  final ActivityType eventType;
  final DateTime scheduledAt;
  final int? goalTimeMinutes;
  final double? goalPaceMinutesPerMile;

  FinalSurgeRaceCandidate copyWith({String? activityId}) {
    return FinalSurgeRaceCandidate(
      providerWorkoutId: providerWorkoutId,
      activityId: activityId ?? this.activityId,
      eventName: eventName,
      eventType: eventType,
      scheduledAt: scheduledAt,
      goalTimeMinutes: goalTimeMinutes,
      goalPaceMinutesPerMile: goalPaceMinutesPerMile,
    );
  }
}

/// Result of a sync operation
class SyncResult {
  const SyncResult({
    required this.success,
    this.error,
    this.errorType = SyncErrorType.none,
    this.newWorkouts = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.filtered = 0,
    this.activities = const [],
    this.raceCandidates = const [],
  });

  /// Create a "not connected" result
  factory SyncResult.notConnected() {
    return const SyncResult(
      success: false,
      error: 'Final Surge is not connected',
      errorType: SyncErrorType.notConnected,
    );
  }

  /// Create an error result
  factory SyncResult.error(String message) {
    return SyncResult(
      success: false,
      error: message,
      errorType: SyncErrorType.apiError,
    );
  }

  /// Create a "requires re-authentication" result
  ///
  /// This indicates the user's tokens have expired and they need
  /// to reconnect their Final Surge account.
  factory SyncResult.requiresReauth() {
    return const SyncResult(
      success: false,
      error: 'Please reconnect your Final Surge account',
      errorType: SyncErrorType.requiresReauth,
    );
  }

  /// Create a network error result
  ///
  /// Network errors are transient and the user can retry.
  factory SyncResult.networkError(String message) {
    return SyncResult(
      success: false,
      error: message,
      errorType: SyncErrorType.network,
    );
  }

  final bool success;
  final String? error;
  final SyncErrorType errorType;
  final int newWorkouts;
  final int updated;
  final int deleted;
  final int skipped;
  final int filtered;
  final List<Activity> activities;
  final List<FinalSurgeRaceCandidate> raceCandidates;

  /// Whether any new workouts were imported
  bool get hasNewWorkouts => newWorkouts > 0;

  /// Whether any changes were detected (new/updated/deleted)
  bool get hasChanges => (newWorkouts + updated + deleted) > 0;

  /// Total workouts processed (new + skipped + filtered)
  int get totalProcessed => newWorkouts + skipped + filtered;

  /// Whether the user needs to reconnect their account
  bool get needsReauth => errorType == SyncErrorType.requiresReauth;

  /// Whether this is a transient network error (can retry)
  bool get isNetworkError => errorType == SyncErrorType.network;

  /// Human-readable summary
  String get summary {
    if (!success) {
      if (needsReauth) {
        return 'Please reconnect your Final Surge account';
      }
      if (isNetworkError) {
        return 'No internet connection. Please try again.';
      }
      return error ?? 'Sync failed';
    }
    if (newWorkouts == 0 && skipped == 0) {
      return 'No workouts found';
    }
    if (newWorkouts == 0) {
      return 'All $skipped workouts already synced';
    }
    return '$newWorkouts new workout${newWorkouts == 1 ? '' : 's'} synced';
  }

  @override
  String toString() {
    return 'SyncResult(success: $success, new: $newWorkouts, updated: $updated, deleted: $deleted, '
        'skipped: $skipped, filtered: $filtered, errorType: $errorType)';
  }
}

/// Types of sync errors for appropriate UI handling
enum SyncErrorType {
  /// No error
  none,

  /// User's Final Surge account is not connected
  notConnected,

  /// Token expired and refresh failed - user must reconnect
  requiresReauth,

  /// Network connectivity issue - user can retry
  network,

  /// API or server error
  apiError,
}
