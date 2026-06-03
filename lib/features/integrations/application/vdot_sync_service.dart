import 'package:flutter/foundation.dart';

import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/integrations_repository.dart';
import '../data/vdot_api_client.dart';
import '../domain/integration.dart';
import '../domain/integration_exceptions.dart';
import 'change_detection_service.dart';
import 'vdot_transformer.dart';

/// Syncs planned/completed workouts from V.O2 (VDOT) into the local
/// activities table.
///
/// Mirrors the FinalSurge / TrainingPeaks sync pattern — both manual and
/// automatic paths are supported:
/// - Manual: user taps "Sync Now" → ConnectTrainingController.importVdotWorkouts
/// - Manual: initial sync at the end of OAuth in onboarding
/// - Automatic: IntegrationSyncCoordinator triggers a sync when the
///   activities screen loads or the user pulls to refresh, subject to a
///   4-hour staleness window (same mechanism as FinalSurge and TrainingPeaks)
///
/// Token refresh:
/// - Proactively refreshes within 5 minutes of expiration
/// - Retries once on a 401 with a fresh token
/// - Marks integration as `requires_reauth` if refresh fails
class VdotSyncService {
  VdotSyncService({
    required VdotApiClient apiClient,
    required IntegrationsRepository integrationsRepository,
    required ActivitiesRepository activitiesRepository,
    required VdotTransformer transformer,
    required ChangeDetectionService changeDetectionService,
  })  : _apiClient = apiClient,
        _integrationsRepository = integrationsRepository,
        _activitiesRepository = activitiesRepository,
        _transformer = transformer,
        _changeDetectionService = changeDetectionService;

  final VdotApiClient _apiClient;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final VdotTransformer _transformer;
  final ChangeDetectionService _changeDetectionService;

  static const _provider = 'vdot';
  static const _tokenExpirationBuffer = Duration(minutes: 5);
  static const _vdotMaxRangeDays = 60;

  /// Sync workouts from `today - lookbackDays` through `today + lookaheadDays`.
  ///
  /// Defaults to a 14-day lookback and 45-day lookahead (matching the
  /// TrainingPeaks window). VDOT's date-range endpoint caps at 60 days, so
  /// the window is automatically chunked into 60-day requests if needed.
  Future<VdotSyncResult> syncWorkouts(
    String userId, {
    int lookbackDays = 14,
    int lookaheadDays = 45,
  }) async {
    final integrationRecord =
        await _integrationsRepository.getIntegration(userId, _provider);
    if (integrationRecord == null || !integrationRecord.isActive) {
      return VdotSyncResult.notConnected();
    }
    var integration = integrationRecord;

    if (kDebugMode) {
      print('🔄 [vdot] Starting sync for user $userId');
    }

    try {
      integration = await _ensureValidToken(integration);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final fromDate = today.subtract(Duration(days: lookbackDays));
      final toDate = today.add(Duration(days: lookaheadDays));

      final rawWorkouts = await _fetchRangeChunked(
        integration: integration,
        from: fromDate,
        to: toDate,
        onTokenRefresh: (refreshed) => integration = refreshed,
      );

      // Dedupe by eventId across chunks.
      final seen = <String>{};
      final deduped = <Map<String, dynamic>>[];
      for (final w in rawWorkouts) {
        final id = _transformer.extractWorkoutId(w);
        if (id.isEmpty) continue;
        if (seen.add(id)) deduped.add(w);
      }

      if (kDebugMode) {
        print('   [vdot] Fetched ${deduped.length} workouts');
      }

      final remoteActivities = <Activity>[];
      var filteredCount = 0;
      for (final workout in deduped) {
        final result = _transformer.transform(workout, userId);
        if (result == null) {
          filteredCount++;
          continue;
        }
        remoteActivities.add(result.activity);
      }

      // Clean any duplicates left behind by previous buggy syncs.
      await _activitiesRepository.cleanupDuplicateProviderActivities(
        userId: userId,
        provider: _provider,
      );

      final localActivities = await _activitiesRepository
          .getActivitiesByUserAndProvider(userId, _provider);

      final changes = _changeDetectionService.detectChanges(
        localActivities: localActivities,
        remoteWorkouts: remoteActivities,
        provider: _provider,
      );

      for (final activity in changes.newActivities) {
        await _activitiesRepository.insertActivity(activity);
      }
      for (final change in changes.updatedActivities) {
        final updated = change.updatedActivity.copyWith(
          id: change.activityId,
          needsNutritionRefresh: change.scheduleChanged,
          lastSyncedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _activitiesRepository.updateActivityFromProvider(updated);
      }
      for (final id in changes.deletedActivityIds) {
        await _activitiesRepository.softDeleteFromProvider(id);
      }

      await _integrationsRepository.updateSyncStatus(
        userId,
        _provider,
        status: 'success',
      );

      if (kDebugMode) {
        print(
          '✅ [vdot] Sync complete — '
          'new: ${changes.newActivities.length}, '
          'updated: ${changes.updatedActivities.length}, '
          'deleted: ${changes.deletedActivityIds.length}, '
          'filtered: $filteredCount',
        );
      }

      return VdotSyncResult(
        success: true,
        newWorkouts: changes.newActivities.length,
        updated: changes.updatedActivities.length,
        deleted: changes.deletedActivityIds.length,
        skipped: changes.unchangedCount,
        filtered: filteredCount,
        activities: changes.newActivities,
      );
    } on TokenRefreshException catch (e) {
      if (e.requiresReauth) {
        await _integrationsRepository.updateSyncStatus(
          userId,
          _provider,
          status: 'requires_reauth',
          error: 'Please reconnect your V.O2 account',
        );
        return VdotSyncResult.requiresReauth();
      }
      return VdotSyncResult.error(e.message);
    } on NetworkException catch (e) {
      return VdotSyncResult.networkError(e.message);
    } catch (e) {
      await _integrationsRepository.updateSyncStatus(
        userId,
        _provider,
        status: 'error',
        error: e.toString(),
      );
      if (kDebugMode) {
        print('❌ [vdot] Sync failed: $e');
      }
      return VdotSyncResult.error(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchRangeChunked({
    required IntegrationModel integration,
    required DateTime from,
    required DateTime to,
    required void Function(IntegrationModel refreshed) onTokenRefresh,
  }) async {
    final results = <Map<String, dynamic>>[];
    var chunkStart = from;
    var workingIntegration = integration;
    while (!chunkStart.isAfter(to)) {
      final chunkEnd = chunkStart.add(const Duration(days: _vdotMaxRangeDays - 1));
      final effectiveEnd = chunkEnd.isAfter(to) ? to : chunkEnd;
      try {
        final response = await _apiClient.getWorkoutsByDateRange(
          workingIntegration.accessToken,
          fromDate: chunkStart,
          toDate: effectiveEnd,
        );
        results.addAll(response);
      } on TokenExpiredException {
        if (kDebugMode) {
          print('⚠️ [vdot] Access token expired mid-sync, refreshing…');
        }
        workingIntegration = await _refreshToken(workingIntegration);
        onTokenRefresh(workingIntegration);
        final response = await _apiClient.getWorkoutsByDateRange(
          workingIntegration.accessToken,
          fromDate: chunkStart,
          toDate: effectiveEnd,
        );
        results.addAll(response);
      }
      chunkStart = effectiveEnd.add(const Duration(days: 1));
    }
    return results;
  }

  Future<IntegrationModel> _ensureValidToken(
    IntegrationModel integration,
  ) async {
    final expiresAt = integration.tokenExpiresAt;
    if (expiresAt == null) return integration;
    final bufferTime = DateTime.now().add(_tokenExpirationBuffer);
    if (expiresAt.isBefore(bufferTime)) {
      if (kDebugMode) {
        print('⚠️ [vdot] Token expires soon, proactively refreshing…');
      }
      return _refreshToken(integration);
    }
    return integration;
  }

  Future<IntegrationModel> _refreshToken(IntegrationModel integration) async {
    if (integration.refreshToken == null) {
      throw const TokenRefreshException(
        'No refresh token available',
        provider: _provider,
        requiresReauth: true,
      );
    }
    final tokenResponse = await _apiClient.refreshAccessToken(
      integration.refreshToken!,
      expiredAccessToken: integration.accessToken,
    );
    final updated = IntegrationModel(
      userId: integration.userId,
      provider: integration.provider,
      accessToken: tokenResponse.accessToken,
      refreshToken: tokenResponse.refreshToken ?? integration.refreshToken,
      tokenExpiresAt: tokenResponse.expiresAt,
      providerAthleteId: integration.providerAthleteId,
      providerAthleteName: integration.providerAthleteName,
      providerAthleteEmail: integration.providerAthleteEmail,
      isActive: true,
      lastSyncStatus: integration.lastSyncStatus,
      lastSyncAt: integration.lastSyncAt,
      lastSyncError: integration.lastSyncError,
      createdAt: integration.createdAt,
      updatedAt: DateTime.now(),
    );
    await _integrationsRepository.upsertIntegration(updated);
    return updated;
  }
}

/// Result returned to controllers/UI.
class VdotSyncResult {
  const VdotSyncResult({
    required this.success,
    this.error,
    this.errorType = VdotSyncErrorType.none,
    this.newWorkouts = 0,
    this.updated = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.filtered = 0,
    this.activities = const [],
  });

  factory VdotSyncResult.notConnected() {
    return const VdotSyncResult(
      success: false,
      error: 'V.O2 is not connected',
      errorType: VdotSyncErrorType.notConnected,
    );
  }

  factory VdotSyncResult.error(String message) {
    return VdotSyncResult(
      success: false,
      error: message,
      errorType: VdotSyncErrorType.apiError,
    );
  }

  factory VdotSyncResult.requiresReauth() {
    return const VdotSyncResult(
      success: false,
      error: 'Please reconnect your V.O2 account',
      errorType: VdotSyncErrorType.requiresReauth,
    );
  }

  factory VdotSyncResult.networkError(String message) {
    return VdotSyncResult(
      success: false,
      error: message,
      errorType: VdotSyncErrorType.network,
    );
  }

  final bool success;
  final String? error;
  final VdotSyncErrorType errorType;
  final int newWorkouts;
  final int updated;
  final int deleted;
  final int skipped;
  final int filtered;
  final List<Activity> activities;

  bool get hasChanges => (newWorkouts + updated + deleted) > 0;
  bool get needsReauth => errorType == VdotSyncErrorType.requiresReauth;
  bool get isNetworkError => errorType == VdotSyncErrorType.network;

  String get summary {
    if (!success) {
      if (needsReauth) return 'Please reconnect your V.O2 account';
      if (isNetworkError) return 'No internet connection. Please try again.';
      return error ?? 'Sync failed';
    }
    if (newWorkouts == 0 && skipped == 0) return 'No workouts found';
    if (newWorkouts == 0) return 'All $skipped workouts already synced';
    return '$newWorkouts new workout${newWorkouts == 1 ? '' : 's'} synced';
  }
}

enum VdotSyncErrorType {
  none,
  notConnected,
  requiresReauth,
  network,
  apiError,
}
