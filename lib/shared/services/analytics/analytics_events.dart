import 'analytics_tracker.dart';

/// Extension methods for analytics events defined in docs/features/analytics/README.md
/// These are the ONLY events that should be tracked in the app
extension AnalyticsEvents on AnalyticsTracker {
  // 1. User Lifecycle Events

  Future<void> trackUserRegistered({
    required String deviceId,
  }) {
    return track('user_registered', properties: {
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
      'registration_source': 'onboarding',
    });
  }

  Future<void> trackAppOpened({
    required String deviceId,
    required String sessionId,
  }) {
    return track('app_opened', properties: {
      'device_id': deviceId,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 2. Plan Creation & Saving Events

  Future<void> trackPlanGenerationStarted({
    required String deviceId,
    String? activityId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required String gutTrainingLevel,
  }) {
    return track('plan_generation_started', properties: {
      'device_id': deviceId,
      if (activityId != null) 'activity_id': activityId,
      'timestamp': DateTime.now().toIso8601String(),
      'distance_miles': distanceMiles,
      'pace_minutes_per_mile': paceMinutesPerMile,
      'gut_training_level': gutTrainingLevel,
    });
  }

  Future<void> trackPlanGenerationFailed({
    required String deviceId,
    String? activityId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required String errorMessage,
  }) {
    return track('plan_generation_failed', properties: {
      'device_id': deviceId,
      if (activityId != null) 'activity_id': activityId,
      'timestamp': DateTime.now().toIso8601String(),
      'distance_miles': distanceMiles,
      'pace_minutes_per_mile': paceMinutesPerMile,
      'error_message': errorMessage,
    });
  }

  Future<void> trackPlanGenerated({
    required String deviceId,
    String? activityId,
    required String activityType,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required int totalCalories,
    required int totalCarbs,
    required int beforeRunItems,
    required int duringRunItems,
    required int afterRunItems,
    required bool isFirstPlan,
  }) {
    return track('plan_generated', properties: {
      'device_id': deviceId,
      if (activityId != null) 'activity_id': activityId,
      'activity_type': activityType,
      'timestamp': DateTime.now().toIso8601String(),
      'distance_miles': distanceMiles,
      'pace_minutes_per_mile': paceMinutesPerMile,
      'total_calories': totalCalories,
      'total_carbs': totalCarbs,
      'before_run_items': beforeRunItems,
      'during_run_items': duringRunItems,
      'after_run_items': afterRunItems,
      'is_first_plan': isFirstPlan,
    });
  }

  // 3. Plan Modification Events — removed 2026-07. The trackPlanSaved,
  // trackMacrosEdited, trackMacroInfoViewed and trackPlanItem* wrappers were
  // never called anywhere, so their events never reached Mixpanel. Re-add
  // deliberately (with call sites) if plan-modification tracking is wanted.

  // 4. Reminder Events

  Future<void> trackReminderSet({
    required String deviceId,
    required String activityId,
    required DateTime reminderTime,
  }) {
    return track('reminder_set', properties: {
      'device_id': deviceId,
      'activity_id': activityId,
      'timestamp': DateTime.now().toIso8601String(),
      'reminder_time': reminderTime.toIso8601String(),
    });
  }

  Future<void> trackReminderScheduled({
    required String deviceId,
    required String activityId,
    required DateTime reminderTime,
  }) {
    return track('reminder_scheduled', properties: {
      'device_id': deviceId,
      'activity_id': activityId,
      'timestamp': reminderTime.toIso8601String(), // When reminder will fire
      'scheduled_at': DateTime.now().toIso8601String(), // When scheduling occurred
    });
  }

  Future<void> trackReminderClicked({
    required String deviceId,
    required String activityId,
  }) {
    return track('reminder_clicked', properties: {
      'device_id': deviceId,
      'activity_id': activityId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 5. Feedback & Survey Events

  Future<void> trackSurveyCompleted({
    required int confidenceLevel,
    required String reuseIntent,
    required bool reminderRequested,
    String? missedReason,
  }) {
    return track('survey_completed', properties: {
      'confidence_level': confidenceLevel,
      'reuse_intent': reuseIntent,
      'reminder_requested': reminderRequested,
      if (missedReason != null) 'missed_reason': missedReason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> trackFeedbackSubmitted({
    int? activityId,
    required int confidenceLevel,
    required String reuseIntent,
    required bool reminderRequested,
    String? message,
  }) {
    return track('feedback_submitted', properties: {
      if (activityId != null) 'activity_id': activityId,
      'confidence_level': confidenceLevel,
      'reuse_intent': reuseIntent,
      'reminder_requested': reminderRequested,
      if (message != null && message.isNotEmpty) 'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 6. Feature Survey Events

  // 7. Integration & Sync Events

  /// Track when user starts connecting to a training provider
  Future<void> trackIntegrationConnectStarted({
    required String provider,
    required String deviceId,
  }) {
    return track('integration_connect_started', properties: {
      'provider': provider,
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track successful integration connection
  /// Maps to: trainingpeaks_connect_success, final_surge_connect_success
  Future<void> trackIntegrationConnectSuccess({
    required String provider,
    required String deviceId,
    String? athleteName,
  }) {
    return track('integration_connect_success', properties: {
      'provider': provider,
      'device_id': deviceId,
      if (athleteName != null) 'athlete_name': athleteName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track failed integration connection
  /// Maps to: trainingpeaks_connect_failed, final_surge_connect_failed
  Future<void> trackIntegrationConnectFailed({
    required String provider,
    required String deviceId,
    required String errorType,
    String? errorMessage,
  }) {
    return track('integration_connect_failed', properties: {
      'provider': provider,
      'device_id': deviceId,
      'error_type': errorType,
      if (errorMessage != null) 'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track when user disconnects from a training provider
  /// Maps to: trainingpeaks_disconnected, final_surge_disconnected
  Future<void> trackIntegrationDisconnected({
    required String provider,
    required String deviceId,
    String? reason,
  }) {
    return track('integration_disconnected', properties: {
      'provider': provider,
      'device_id': deviceId,
      if (reason != null) 'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track successful workout sync from a training provider
  /// Maps to: trainingpeaks_sync_success, final_surge_sync_success
  Future<void> trackIntegrationSyncSuccess({
    required String provider,
    required String deviceId,
    required int workoutsSynced,
    int? skippedCount,
    int? eventsCount,
  }) {
    return track('integration_sync_success', properties: {
      'provider': provider,
      'device_id': deviceId,
      'workouts_synced': workoutsSynced,
      if (skippedCount != null) 'skipped_count': skippedCount,
      if (eventsCount != null) 'events_count': eventsCount,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track failed workout sync from a training provider
  /// Maps to: trainingpeaks_sync_failed, final_surge_sync_failed
  Future<void> trackIntegrationSyncFailed({
    required String provider,
    required String deviceId,
    required String errorType,
    String? errorMessage,
  }) {
    return track('integration_sync_failed', properties: {
      'provider': provider,
      'device_id': deviceId,
      'error_type': errorType,
      if (errorMessage != null) 'error_message': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 8. Formula Kit (pin) plan-outcome events
  //
  // Fired client-side after a plan generation completes, one event per phase
  // / sub-phase that carried a pin_decision. `pin_set_size` is the count of
  // in-scope candidates the algorithm saw for that phase (not total user
  // pins). Source attribution intentionally omitted — pins fire independent
  // of how the user authored them. See Formula Kit PR 2 substep 7.

  /// Fired when the algorithm honored a pinned template for a phase.
  Future<void> trackPlanUsedPin({
    required String deviceId,
    required String activityId,
    required String templateId,
    required String templateName,
    required String phase, // 'before' | 'during' | 'after'
    String? subPhase, // 'meal' | 'snack' | 'top_up' (Before only)
    required int pinSetSize,
  }) {
    return track('plan_used_pin', properties: {
      'device_id': deviceId,
      'activity_id': activityId,
      'template_id': templateId,
      'template_name': templateName,
      'phase': phase,
      if (subPhase != null) 'sub_phase': subPhase,
      'pin_set_size': pinSetSize,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Fired when pins were supplied but no in-scope pin matched the phase.
  /// `reason` is the wire value from PinFallthroughReason (e.g.
  /// 'no_pin_for_scope') so the server can add new reasons without a client
  /// release.
  Future<void> trackPlanPinFallthrough({
    required String deviceId,
    required String activityId,
    required String phase,
    String? subPhase,
    required String reason,
    required int pinSetSize,
  }) {
    return track('plan_pin_fallthrough', properties: {
      'device_id': deviceId,
      'activity_id': activityId,
      'phase': phase,
      if (subPhase != null) 'sub_phase': subPhase,
      'reason': reason,
      'pin_set_size': pinSetSize,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // 9. Activity Viewing Events

  /// Track when user views/taps on an activity
  /// Includes synced workout information to identify activities from integrations
  Future<void> trackActivityViewed({
    required String deviceId,
    required String activityId,
    required String activityType,
    bool hasNutritionPlan = false,
    bool isSyncedWorkout = false,
    String? syncedFromProvider,
    String? providerWorkoutId,
  }) {
    return track('activity_viewed', properties: {
      'device_id': deviceId,
      'activity_id': activityId,
      'activity_type': activityType,
      'has_nutrition_plan': hasNutritionPlan,
      'is_synced_workout': isSyncedWorkout,
      if (syncedFromProvider != null) 'synced_from_provider': syncedFromProvider,
      if (providerWorkoutId != null) 'provider_workout_id': providerWorkoutId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
