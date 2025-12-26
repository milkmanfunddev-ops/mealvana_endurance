import 'package:flutter/foundation.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';

import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/final_surge_api_client.dart';
import '../data/integrations_repository.dart';
import '../domain/integration.dart';
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
/// Sync behavior:
/// - Only imports NEW workouts (doesn't update existing)
/// - Deleted workouts in Final Surge remain in Mealvana
/// - User can manually delete unwanted activities
class FinalSurgeSyncService {
  FinalSurgeSyncService({
    required FinalSurgeApiClient apiClient,
    required IntegrationsRepository integrationsRepository,
    required ActivitiesRepository activitiesRepository,
    required FinalSurgeTransformer transformer,
  })  : _apiClient = apiClient,
        _integrationsRepository = integrationsRepository,
        _activitiesRepository = activitiesRepository,
        _transformer = transformer;

  final FinalSurgeApiClient _apiClient;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final FinalSurgeTransformer _transformer;

  /// Buffer time before token expiration to trigger proactive refresh (5 min)
  static const _tokenExpirationBuffer = Duration(minutes: 5);

  /// Sync upcoming workouts from Final Surge
  ///
  /// [userId] - The user to sync workouts for
  /// [numDays] - How many days ahead to fetch (default: 7)
  /// [numWorkouts] - Maximum workouts to fetch (default: 21)
  ///
  /// Returns a [SyncResult] with sync statistics.
  ///
  /// Automatically handles token refresh when tokens expire.
  Future<SyncResult> syncWorkouts(
    String userId, {
    int numDays = 7,
    int numWorkouts = 21,
  }) async {
    // 1. Check if user has an active Final Surge integration
    var integration = await _integrationsRepository.getIntegration(
      userId,
      'final_surge',
    );

    if (integration == null || !integration.isActive) {
      return SyncResult.notConnected();
    }

    if (kDebugMode) {
      print('🔄 Starting Final Surge sync for user $userId');
    }

    try {
      // 2. Proactively refresh token if it's about to expire
      integration = await _ensureValidToken(integration);

      // 3. Fetch workouts from Final Surge API
      FinalSurgeWorkoutsResponse response;
      try {
        response = await _apiClient.getUpcomingWorkouts(
          integration.accessToken,
          numDays: numDays,
          numWorkouts: numWorkouts,
        );
      } on TokenExpiredException {
        // Token expired during request - refresh and retry once
        if (kDebugMode) {
          print('⚠️ Token expired during request, refreshing...');
        }
        integration = await _refreshToken(integration);
        response = await _apiClient.getUpcomingWorkouts(
          integration.accessToken,
          numDays: numDays,
          numWorkouts: numWorkouts,
        );
      }

      if (response.hasError) {
        throw FinalSurgeApiException(
          response.errorMessage ?? 'Failed to fetch workouts',
        );
      }

      if (kDebugMode) {
        print('   Fetched ${response.workouts.length} workouts from Final Surge');
      }

      // 4. Transform and filter workouts
      int newCount = 0;
      int skippedCount = 0;
      int filteredCount = 0;
      final newActivities = <Activity>[];

      for (final workoutJson in response.workouts) {
        // Transform (returns null for unsupported workout types)
        final result = _transformer.transform(workoutJson, userId);

        if (result == null) {
          filteredCount++;
          continue;
        }

        // Check if this workout was already imported
        final existing = await _activitiesRepository.findByProviderWorkoutId(
          'final_surge',
          result.providerWorkoutId,
        );

        if (existing != null) {
          skippedCount++;
          continue;
        }

        // Save the new activity
        await _activitiesRepository.insertActivity(result.activity);
        newActivities.add(result.activity);
        newCount++;

        if (kDebugMode) {
          print('   ✓ Imported: ${result.activity.title}');
        }
      }

      // 5. Update sync status
      await _integrationsRepository.updateSyncStatus(
        userId,
        'final_surge',
        status: 'success',
      );

      if (kDebugMode) {
        print('✅ Sync complete: $newCount new, $skippedCount existing, $filteredCount filtered');
      }

      return SyncResult(
        success: true,
        newWorkouts: newCount,
        skipped: skippedCount,
        filtered: filteredCount,
        activities: newActivities,
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
  Future<IntegrationModel> _ensureValidToken(IntegrationModel integration) async {
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
    var integration = await _integrationsRepository.getIntegration(
      userId,
      'final_surge',
    );

    if (integration == null || !integration.isActive) {
      return SyncResult.notConnected();
    }

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

      int newCount = 0;
      int skippedCount = 0;
      int filteredCount = 0;
      final newActivities = <Activity>[];

      for (final workoutJson in response.workouts) {
        final result = _transformer.transform(workoutJson, userId);

        if (result == null) {
          filteredCount++;
          continue;
        }

        final existing = await _activitiesRepository.findByProviderWorkoutId(
          'final_surge',
          result.providerWorkoutId,
        );

        if (existing != null) {
          skippedCount++;
          continue;
        }

        await _activitiesRepository.insertActivity(result.activity);
        newActivities.add(result.activity);
        newCount++;
      }

      await _integrationsRepository.updateSyncStatus(
        userId,
        'final_surge',
        status: 'success',
      );

      return SyncResult(
        success: true,
        newWorkouts: newCount,
        skipped: skippedCount,
        filtered: filteredCount,
        activities: newActivities,
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
}

/// Result of a sync operation
class SyncResult {
  const SyncResult({
    required this.success,
    this.error,
    this.errorType = SyncErrorType.none,
    this.newWorkouts = 0,
    this.skipped = 0,
    this.filtered = 0,
    this.activities = const [],
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
  final int skipped;
  final int filtered;
  final List<Activity> activities;

  /// Whether any new workouts were imported
  bool get hasNewWorkouts => newWorkouts > 0;

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
    return 'SyncResult(success: $success, new: $newWorkouts, skipped: $skipped, filtered: $filtered, errorType: $errorType)';
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
