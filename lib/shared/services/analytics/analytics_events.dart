import 'package:uuid/uuid.dart';
import 'analytics_tracker.dart';

/// Extension methods for analytics events defined in docs/features/analytics/README.md
/// These are the ONLY events that should be tracked in the app
extension AnalyticsEvents on AnalyticsTracker {
  // Helper to generate plan IDs
  static const _uuid = Uuid();
  static String generatePlanId() => _uuid.v4();

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
    required String planId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required String gutTrainingLevel,
  }) {
    return track('plan_generation_started', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'distance_miles': distanceMiles,
      'pace_minutes_per_mile': paceMinutesPerMile,
      'gut_training_level': gutTrainingLevel,
    });
  }

  Future<void> trackPlanGenerationFailed({
    required String deviceId,
    required String planId,
    required double distanceMiles,
    required double paceMinutesPerMile,
    required String errorMessage,
  }) {
    return track('plan_generation_failed', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'distance_miles': distanceMiles,
      'pace_minutes_per_mile': paceMinutesPerMile,
      'error_message': errorMessage,
    });
  }

  Future<void> trackPlanGenerated({
    required String deviceId,
    required String planId,
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
      'plan_id': planId,
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

  Future<void> trackPlanSaved({
    required String deviceId,
    required String planId,
    required int timeSinceGenerationStarted,
    required bool isFirstPlan,
    required int totalPlansSaved,
  }) {
    return track('plan_saved', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'time_since_generation_started': timeSinceGenerationStarted,
      'is_first_plan': isFirstPlan,
      'total_plans_saved': totalPlansSaved,
    });
  }

  // 3. Plan Modification Events

  Future<void> trackMacrosEdited({
    required String deviceId,
    required String planId,
    required String macroType,
    required double oldValue,
    required double newValue,
  }) {
    return track('macros_edited', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'macro_type': macroType,
      'old_value': oldValue,
      'new_value': newValue,
    });
  }

  Future<void> trackMacroInfoViewed({
    required String deviceId,
    required String planId,
    required String macroType,
  }) {
    return track('macro_info_viewed', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'macro_type': macroType,
    });
  }

  Future<void> trackPlanItemDeleted({
    required String deviceId,
    required String planId,
    required String itemName,
    required String phase,
  }) {
    return track('plan_item_deleted', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'item_name': itemName,
      'phase': phase,
    });
  }

  Future<void> trackPlanItemSwapped({
    required String deviceId,
    required String planId,
    required String oldItemName,
    required String newItemName,
    required String phase,
  }) {
    return track('plan_item_swapped', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'old_item_name': oldItemName,
      'new_item_name': newItemName,
      'phase': phase,
    });
  }

  Future<void> trackPlanItemAdded({
    required String deviceId,
    required String planId,
    required String itemName,
    required String phase,
  }) {
    return track('plan_item_added', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'item_name': itemName,
      'phase': phase,
    });
  }

  // 4. Reminder Events

  Future<void> trackReminderSet({
    required String deviceId,
    required String planId,
    required DateTime reminderTime,
  }) {
    return track('reminder_set', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': DateTime.now().toIso8601String(),
      'reminder_time': reminderTime.toIso8601String(),
    });
  }

  Future<void> trackReminderScheduled({
    required String deviceId,
    required String planId,
    required DateTime reminderTime,
  }) {
    return track('reminder_scheduled', properties: {
      'device_id': deviceId,
      'plan_id': planId,
      'timestamp': reminderTime.toIso8601String(), // When reminder will fire
      'scheduled_at': DateTime.now().toIso8601String(), // When scheduling occurred
    });
  }

  Future<void> trackReminderClicked({
    required String deviceId,
    required String planId,
  }) {
    return track('reminder_clicked', properties: {
      'device_id': deviceId,
      'plan_id': planId,
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
    required String planId,
    required int confidenceLevel,
    required String reuseIntent,
    required bool reminderRequested,
    String? message,
  }) {
    return track('feedback_submitted', properties: {
      'plan_id': planId,
      'confidence_level': confidenceLevel,
      'reuse_intent': reuseIntent,
      'reminder_requested': reminderRequested,
      if (message != null && message.isNotEmpty) 'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
