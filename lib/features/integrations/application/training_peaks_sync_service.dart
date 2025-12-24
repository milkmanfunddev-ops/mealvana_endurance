import 'package:flutter/foundation.dart';

import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../data/integrations_repository.dart';
import '../data/training_peaks_api_client.dart';
import 'training_peaks_oauth_service.dart';
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
    required TrainingPeaksOAuthService oauthService,
    required IntegrationsRepository integrationsRepository,
    required ActivitiesRepository activitiesRepository,
    required TrainingPeaksTransformer transformer,
  })  : _apiClient = apiClient,
        _oauthService = oauthService,
        _integrationsRepository = integrationsRepository,
        _activitiesRepository = activitiesRepository,
        _transformer = transformer;

  final TrainingPeaksApiClient _apiClient;
  final TrainingPeaksOAuthService _oauthService;
  final IntegrationsRepository _integrationsRepository;
  final ActivitiesRepository _activitiesRepository;
  final TrainingPeaksTransformer _transformer;

  /// Sync upcoming workouts from TrainingPeaks
  ///
  /// [userId] - The user to sync workouts for
  /// [numDays] - How many days ahead to fetch (default: 14, max: 45)
  ///
  /// Returns a [TrainingPeaksSyncResult] with sync statistics.
  Future<TrainingPeaksSyncResult> syncWorkouts(
    String userId, {
    int numDays = 14,
  }) async {
    // 1. Ensure we have a valid token (refreshes if needed)
    final accessToken = await _oauthService.getValidAccessToken(userId);
    if (accessToken == null) {
      return TrainingPeaksSyncResult.notConnected();
    }

    if (kDebugMode) {
      print('🔄 Starting TrainingPeaks workout sync for user $userId');
    }

    try {
      // 2. Fetch workouts from TrainingPeaks API
      final workouts = await _apiClient.getUpcomingWorkouts(
        accessToken,
        days: numDays,
        includeDescription: true,
      );

      if (kDebugMode) {
        print('   Fetched ${workouts.length} workouts from TrainingPeaks');
      }

      // 3. Transform and filter workouts
      int newCount = 0;
      int skippedCount = 0;
      int filteredCount = 0;
      final newActivities = <Activity>[];

      for (final workoutJson in workouts) {
        // Transform (returns null for unsupported workout types)
        final result = _transformer.transform(workoutJson, userId);

        if (result == null) {
          filteredCount++;
          continue;
        }

        // Check if this workout was already imported
        final existing = await _activitiesRepository.findByProviderWorkoutId(
          'training_peaks',
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
        'training_peaks',
        status: 'success',
      );

      if (kDebugMode) {
        print('✅ Workout sync complete: $newCount new, $skippedCount existing, $filteredCount filtered');
      }

      return TrainingPeaksSyncResult(
        success: true,
        newWorkouts: newCount,
        skipped: skippedCount,
        filtered: filteredCount,
        activities: newActivities,
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

  /// Sync workouts for a specific date range
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

    final accessToken = await _oauthService.getValidAccessToken(userId);
    if (accessToken == null) {
      return TrainingPeaksSyncResult.notConnected();
    }

    try {
      final workouts = await _apiClient.getWorkouts(
        accessToken,
        startDate: startDate,
        endDate: endDate,
        includeDescription: true,
      );

      int newCount = 0;
      int skippedCount = 0;
      int filteredCount = 0;
      final newActivities = <Activity>[];

      for (final workoutJson in workouts) {
        final result = _transformer.transform(workoutJson, userId);

        if (result == null) {
          filteredCount++;
          continue;
        }

        final existing = await _activitiesRepository.findByProviderWorkoutId(
          'training_peaks',
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
        'training_peaks',
        status: 'success',
      );

      return TrainingPeaksSyncResult(
        success: true,
        newWorkouts: newCount,
        skipped: skippedCount,
        filtered: filteredCount,
        activities: newActivities,
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

  /// Sync the next upcoming event from TrainingPeaks (UNIQUE FEATURE!)
  ///
  /// This is a major differentiator from Final Surge - we can auto-import
  /// races for nutrition planning and carb-loading.
  ///
  /// Returns the event data if found, null otherwise.
  Future<TrainingPeaksEventSyncResult> syncNextEvent(String userId) async {
    final accessToken = await _oauthService.getValidAccessToken(userId);
    if (accessToken == null) {
      return TrainingPeaksEventSyncResult.notConnected();
    }

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
        event: event,
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

  /// Full sync: workouts + next event
  ///
  /// Use this for initial onboarding sync.
  Future<TrainingPeaksFullSyncResult> syncAll(
    String userId, {
    int workoutDays = 14,
  }) async {
    if (kDebugMode) {
      print('🔄 Starting full TrainingPeaks sync...');
    }

    // Sync workouts
    final workoutResult = await syncWorkouts(userId, numDays: workoutDays);

    // Sync next event (don't fail if this fails - events are optional)
    TrainingPeaksEventSyncResult? eventResult;
    try {
      eventResult = await syncNextEvent(userId);
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
}

/// Result of a workout sync operation
class TrainingPeaksSyncResult {
  const TrainingPeaksSyncResult({
    required this.success,
    this.error,
    this.newWorkouts = 0,
    this.skipped = 0,
    this.filtered = 0,
    this.activities = const [],
    this.tokenExpired = false,
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
  final int skipped;
  final int filtered;
  final List<Activity> activities;
  final bool tokenExpired;

  /// Whether any new workouts were imported
  bool get hasNewWorkouts => newWorkouts > 0;

  /// Total workouts processed (new + skipped + filtered)
  int get totalProcessed => newWorkouts + skipped + filtered;

  /// Human-readable summary
  String get summary {
    if (!success) {
      if (tokenExpired) {
        return 'Token expired. Please reconnect.';
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
    return 'TrainingPeaksSyncResult(success: $success, new: $newWorkouts, skipped: $skipped, filtered: $filtered)';
  }
}

/// Result of an event sync operation
class TrainingPeaksEventSyncResult {
  const TrainingPeaksEventSyncResult({
    required this.success,
    this.event,
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
      event: null,
    );
  }

  factory TrainingPeaksEventSyncResult.error(String message) {
    return TrainingPeaksEventSyncResult(
      success: false,
      error: message,
    );
  }

  final bool success;
  final TrainingPeaksEventResult? event;
  final String? error;
  final bool tokenExpired;

  bool get hasEvent => event != null;
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
  bool get hasEvent => eventResult?.hasEvent ?? false;

  String get summary {
    final parts = <String>[];
    parts.add(workoutResult.summary);
    if (eventResult?.hasEvent ?? false) {
      parts.add('Next event: ${eventResult!.event!.eventName}');
    }
    return parts.join('. ');
  }
}
