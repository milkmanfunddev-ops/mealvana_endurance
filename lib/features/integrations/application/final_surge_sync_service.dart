import 'package:flutter/foundation.dart';

import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/final_surge_api_client.dart';
import '../data/integrations_repository.dart';
import 'final_surge_transformer.dart';

/// Service for syncing workouts from Final Surge
///
/// MANUAL SYNC ONLY (MVP decision):
/// - User clicks "Sync Now" button
/// - Initial sync during onboarding
/// - No automatic background checking
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

  /// Sync upcoming workouts from Final Surge
  ///
  /// [userId] - The user to sync workouts for
  /// [numDays] - How many days ahead to fetch (default: 7)
  /// [numWorkouts] - Maximum workouts to fetch (default: 21)
  ///
  /// Returns a [SyncResult] with sync statistics.
  Future<SyncResult> syncWorkouts(
    String userId, {
    int numDays = 7,
    int numWorkouts = 21,
  }) async {
    // 1. Check if user has an active Final Surge integration
    final integration = await _integrationsRepository.getIntegration(
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
      // 2. Fetch workouts from Final Surge API
      final response = await _apiClient.getUpcomingWorkouts(
        integration.accessToken,
        numDays: numDays,
        numWorkouts: numWorkouts,
      );

      if (response.hasError) {
        throw FinalSurgeApiException(
          response.errorMessage ?? 'Failed to fetch workouts',
        );
      }

      if (kDebugMode) {
        print('   Fetched ${response.workouts.length} workouts from Final Surge');
      }

      // 3. Transform and filter workouts
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

      // 4. Update sync status
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

  /// Sync workouts for a specific date range
  ///
  /// Useful for syncing past workouts or a longer range.
  Future<SyncResult> syncWorkoutsByDateRange(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final integration = await _integrationsRepository.getIntegration(
      userId,
      'final_surge',
    );

    if (integration == null || !integration.isActive) {
      return SyncResult.notConnected();
    }

    try {
      final response = await _apiClient.getWorkoutsByDateRange(
        integration.accessToken,
        startDate: startDate,
        endDate: endDate,
      );

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
    );
  }

  /// Create an error result
  factory SyncResult.error(String message) {
    return SyncResult(
      success: false,
      error: message,
    );
  }

  final bool success;
  final String? error;
  final int newWorkouts;
  final int skipped;
  final int filtered;
  final List<Activity> activities;

  /// Whether any new workouts were imported
  bool get hasNewWorkouts => newWorkouts > 0;

  /// Total workouts processed (new + skipped + filtered)
  int get totalProcessed => newWorkouts + skipped + filtered;

  /// Human-readable summary
  String get summary {
    if (!success) {
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
    return 'SyncResult(success: $success, new: $newWorkouts, skipped: $skipped, filtered: $filtered)';
  }
}
