import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../activities/data/activities_repository.dart';
import '../../activities/domain/activity.dart';
import '../../auth/application/auth_service.dart';
import '../domain/nutrition_plan.dart';
import 'llm_nutrition_plan_service.dart';

part 'bulk_nutrition_plan_service.g.dart';

/// Progress callback for bulk plan generation
typedef BulkPlanProgressCallback = void Function(BulkPlanProgress progress);

/// Progress state for bulk plan generation
class BulkPlanProgress {
  const BulkPlanProgress({
    required this.total,
    required this.completed,
    required this.failed,
    this.currentActivity,
    this.isComplete = false,
  });

  /// Total number of plans to generate
  final int total;

  /// Number of plans successfully generated
  final int completed;

  /// Number of plans that failed
  final int failed;

  /// Current activity being processed
  final Activity? currentActivity;

  /// Whether all processing is complete
  final bool isComplete;

  /// Progress as a fraction (0.0 to 1.0)
  double get fraction => total > 0 ? (completed + failed) / total : 0.0;

  /// Number still pending
  int get pending => total - completed - failed;

  /// Human-readable status
  String get status {
    if (isComplete) {
      if (failed == 0) {
        return 'Generated $completed nutrition plans';
      }
      return 'Generated $completed plans ($failed failed)';
    }
    return 'Generating plan ${completed + failed + 1} of $total...';
  }

  BulkPlanProgress copyWith({
    int? total,
    int? completed,
    int? failed,
    Activity? currentActivity,
    bool? isComplete,
  }) {
    return BulkPlanProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      currentActivity: currentActivity ?? this.currentActivity,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Result of generating a single plan
class PlanGenerationResult {
  const PlanGenerationResult({
    required this.activity,
    this.plan,
    this.error,
  });

  final Activity activity;
  final NutritionPlan? plan;
  final String? error;

  bool get success => plan != null;
}

/// Service for generating nutrition plans for multiple activities in parallel chunks
///
/// This service is designed to be called after importing workouts from external
/// training platforms (e.g., Final Surge). It generates nutrition plans for each
/// activity in parallel but limits concurrency to avoid overwhelming the API.
///
/// Example usage:
/// ```dart
/// final results = await bulkPlanService.generatePlansForActivities(
///   activities,
///   onProgress: (progress) => print(progress.status),
/// );
/// ```
class BulkNutritionPlanService {
  BulkNutritionPlanService(this._ref);

  final Ref _ref;

  /// Maximum concurrent plan generations (avoid overwhelming API)
  static const int _maxConcurrency = 3;

  /// Cached services - refreshed on each method call to avoid stale refs
  LLMNutritionPlanService? _cachedLlmService;
  AppLogger? _cachedLogger;
  ActivitiesRepository? _cachedActivitiesRepository;
  AuthService? _cachedAuthService;

  /// Cache dependencies at the start of each operation to avoid using disposed refs
  void _cacheServices() {
    _cachedLlmService = _ref.read(llmNutritionPlanServiceProvider);
    _cachedLogger = _ref.read(appExternalDepsProvider).logger;
    _cachedActivitiesRepository = _ref.read(activitiesRepositoryProvider);
    _cachedAuthService = _ref.read(authServiceProvider);
  }

  LLMNutritionPlanService get _llmService => _cachedLlmService ?? _ref.read(llmNutritionPlanServiceProvider);
  AppLogger get _logger => _cachedLogger ?? _ref.read(appExternalDepsProvider).logger;
  ActivitiesRepository get _activitiesRepository => _cachedActivitiesRepository ?? _ref.read(activitiesRepositoryProvider);
  AuthService get _authService => _cachedAuthService ?? _ref.read(authServiceProvider);

  /// Generate nutrition plans for multiple activities in parallel chunks
  ///
  /// [activities] - List of activities to generate plans for
  /// [onProgress] - Optional callback for progress updates
  /// [maxConcurrency] - Max simultaneous plan generations (default: 3)
  ///
  /// Returns a list of [PlanGenerationResult] with success/failure for each activity.
  Future<List<PlanGenerationResult>> generatePlansForActivities(
    List<Activity> activities, {
    BulkPlanProgressCallback? onProgress,
    int maxConcurrency = _maxConcurrency,
  }) async {
    // Cache services at the start to avoid using disposed refs during async operations
    _cacheServices();
    if (activities.isEmpty) {
      onProgress?.call(const BulkPlanProgress(
        total: 0,
        completed: 0,
        failed: 0,
        isComplete: true,
      ));
      return [];
    }

    final results = <PlanGenerationResult>[];
    int completedCount = 0;
    int failedCount = 0;

    // Initial progress
    onProgress?.call(BulkPlanProgress(
      total: activities.length,
      completed: 0,
      failed: 0,
    ));

    if (kDebugMode) {
      print('🍽️ Starting bulk plan generation for ${activities.length} activities');
    }

    // Process in chunks
    for (int i = 0; i < activities.length; i += maxConcurrency) {
      final chunkEnd = (i + maxConcurrency).clamp(0, activities.length);
      final chunk = activities.sublist(i, chunkEnd);

      if (kDebugMode) {
        print('   Processing chunk ${(i ~/ maxConcurrency) + 1}: activities ${i + 1}-$chunkEnd');
      }

      // Generate plans for this chunk in parallel
      final chunkFutures = chunk.map((activity) => _generatePlanForActivity(activity));
      final chunkResults = await Future.wait(chunkFutures);

      // Process results
      for (final result in chunkResults) {
        results.add(result);
        if (result.success) {
          completedCount++;
        } else {
          failedCount++;
        }
      }

      // Report progress
      onProgress?.call(BulkPlanProgress(
        total: activities.length,
        completed: completedCount,
        failed: failedCount,
        currentActivity: chunkEnd < activities.length ? activities[chunkEnd] : null,
      ));
    }

    // Final progress
    onProgress?.call(BulkPlanProgress(
      total: activities.length,
      completed: completedCount,
      failed: failedCount,
      isComplete: true,
    ));

    if (kDebugMode) {
      print('✅ Bulk plan generation complete: $completedCount succeeded, $failedCount failed');
    }

    return results;
  }

  /// Generate a nutrition plan for a single activity
  Future<PlanGenerationResult> _generatePlanForActivity(Activity activity) async {
    try {
      // Extract activity parameters
      double distanceMiles = activity.distanceMiles ?? 0.0;
      final durationMinutes = activity.durationMinutes ?? 60;

      // Calculate pace if distance is available
      double paceMinutesPerMile = 10.0; // Default pace (10 min/mile)

      if (distanceMiles > 0 && durationMinutes > 0) {
        // Normal case: calculate actual pace from distance and duration
        paceMinutesPerMile = durationMinutes / distanceMiles;
      } else if (distanceMiles <= 0 && durationMinutes > 0) {
        // Swimming/duration-only activities: estimate distance from duration
        // Using default pace of 10 min/mile to calculate "equivalent" distance
        // This ensures macro calculations are based on workout duration
        distanceMiles = durationMinutes / paceMinutesPerMile;

        if (kDebugMode) {
          print('   ℹ️ No distance for "${activity.title}" - using duration ($durationMinutes min) to estimate ${distanceMiles.toStringAsFixed(1)} mi equivalent');
        }
      }

      // Skip only if we have neither distance nor duration
      if (distanceMiles <= 0 && durationMinutes <= 0) {
        _logger.warning(
          'Skipping plan generation for activity with no distance or duration',
          context: 'BULK_PLAN',
        );
        return PlanGenerationResult(
          activity: activity,
          error: 'Activity has no distance or duration specified',
        );
      }

      if (kDebugMode) {
        print('   → Generating plan for "${activity.title}" ($distanceMiles mi @ $paceMinutesPerMile min/mi)');
      }

      // Generate the plan via LLM service
      final plan = await _llmService.generateLLMNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        // Use defaults for other parameters
        timeBeforeRunHours: 2.0,
        activityId: activity.id,
      );

      if (plan != null) {
        if (kDebugMode) {
          print('   ✓ Plan generated for "${activity.title}"');
        }
        return PlanGenerationResult(
          activity: activity,
          plan: plan,
        );
      } else {
        return PlanGenerationResult(
          activity: activity,
          error: 'LLM service returned null',
        );
      }
    } catch (e) {
      _logger.error(
        'Failed to generate plan for activity ${activity.id}',
        context: 'BULK_PLAN',
        error: e,
      );
      return PlanGenerationResult(
        activity: activity,
        error: e.toString(),
      );
    }
  }

  /// Generate plans for activities and save them to the database
  ///
  /// This is a convenience method that combines generation and persistence.
  /// Plans are saved to each activity's nutrition_plan_data field (embedded JSON).
  Future<BulkPlanProgress> generateAndSavePlansForActivities(
    List<Activity> activities, {
    BulkPlanProgressCallback? onProgress,
  }) async {
    // Cache services at the start
    _cacheServices();

    final results = await generatePlansForActivities(
      activities,
      onProgress: onProgress,
    );

    // Get device ID for update operations
    final user = await _authService.getCurrentUser();
    final deviceId = user?.id ?? '';

    if (deviceId.isEmpty) {
      _logger.warning(
        'Cannot save plans: no user found',
        context: 'BULK_PLAN',
      );
      return BulkPlanProgress(
        total: results.length,
        completed: 0,
        failed: results.length,
        isComplete: true,
      );
    }

    // Save each successful plan to its activity
    int savedCount = 0;
    int saveFailedCount = 0;

    for (final result in results) {
      if (result.success && result.plan != null) {
        try {
          // Link the plan to the activity and convert to JSON
          final planWithActivityId = result.plan!.copyWith(
            activityId: result.activity.id,
          );

          // Update activity with the nutrition plan data
          final updatedActivity = result.activity.copyWith(
            nutritionPlanData: planWithActivityId.toJson(),
          );

          await _activitiesRepository.updateActivity(
            deviceId: deviceId,
            activity: updatedActivity,
          );

          savedCount++;

          if (kDebugMode) {
            print('   ✓ Saved plan for "${result.activity.title}"');
          }
        } catch (e) {
          saveFailedCount++;
          _logger.error(
            'Failed to save plan for activity ${result.activity.id}',
            context: 'BULK_PLAN',
            error: e,
          );
        }
      }
    }

    if (kDebugMode) {
      print('💾 Saved $savedCount plans to database ($saveFailedCount save failures)');
    }

    return BulkPlanProgress(
      total: results.length,
      completed: savedCount,
      failed: results.where((r) => !r.success).length + saveFailedCount,
      isComplete: true,
    );
  }
}

/// Provider for BulkNutritionPlanService
@riverpod
BulkNutritionPlanService bulkNutritionPlanService(Ref ref) {
  return BulkNutritionPlanService(ref);
}
