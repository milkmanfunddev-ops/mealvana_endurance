import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../calendar/domain/activity.dart';
import '../../../calendar/domain/activity_completion.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../domain/nutrition_plan.dart' show NutritionPlan;
import '../../domain/macro_targets.dart';
import '../../../calendar/application/calendar_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../activities/domain/activity_reminder.dart';
import 'distance_page_gut_entry_controller.dart';
import '../../../../shared/services/logging_service.dart';
import '../../data/nutrition_plan_repository.dart';
import 'nutrition_plan_controller.dart';

part 'activity_detail_controller.g.dart';

/// Activity Detail Controller State
class ActivityDetailState {
  const ActivityDetailState({
    required this.mode,
    this.activity,
    this.nutritionPlan,
    this.completion,
    this.macroTargets,
    this.pendingActivityData,
    this.scheduledDateTime,
    this.pendingReminder,
    this.isSaving = false,
    this.isCompleting = false,
    this.hasUnsavedChanges = false,
    this.error,
  });

  final String mode; // 'create' or 'view'
  final Activity? activity;
  final NutritionPlan? nutritionPlan;
  final ActivityCompletion? completion;
  final MacroTargets? macroTargets;
  final PendingActivityData? pendingActivityData;
  final DateTime? scheduledDateTime;
  final ActivityReminder? pendingReminder; // For create mode
  final bool isSaving;
  final bool isCompleting;
  final bool hasUnsavedChanges; // Tracks if nutrition plan has been modified
  final String? error;

  bool get isCreateMode => mode == 'create';
  bool get isViewMode => mode == 'view';
  bool get hasActivity => activity != null;
  bool get isCompleted => completion != null;

  ActivityDetailState copyWith({
    String? mode,
    Activity? activity,
    NutritionPlan? nutritionPlan,
    ActivityCompletion? completion,
    MacroTargets? macroTargets,
    PendingActivityData? pendingActivityData,
    DateTime? scheduledDateTime,
    ActivityReminder? pendingReminder,
    bool? isSaving,
    bool? isCompleting,
    bool? hasUnsavedChanges,
    String? error,
  }) {
    return ActivityDetailState(
      mode: mode ?? this.mode,
      activity: activity ?? this.activity,
      nutritionPlan: nutritionPlan ?? this.nutritionPlan,
      completion: completion ?? this.completion,
      macroTargets: macroTargets ?? this.macroTargets,
      pendingActivityData: pendingActivityData ?? this.pendingActivityData,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      pendingReminder: pendingReminder ?? this.pendingReminder,
      isSaving: isSaving ?? this.isSaving,
      isCompleting: isCompleting ?? this.isCompleting,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      error: error ?? this.error,
    );
  }
}

/// Activity Detail Controller
/// Manages activity creation, updates, and completion
@riverpod
class ActivityDetailController extends _$ActivityDetailController {
  AppLogger get _logger => ref.read(appLoggerProvider);
  CalendarService get _calendarService => ref.read(calendarServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);

  Future<NutritionPlanRepository> get _nutritionPlanRepository async =>
      await ref.read(nutritionPlanRepositoryProvider.future);

  @override
  FutureOr<ActivityDetailState> build({
    required String mode,
    String? activityId,
    PendingActivityData? pendingActivityData,
    MacroTargets? macroTargets,
  }) async {
    if (mode == 'create') {
      // Create mode: Use pending activity data
      return ActivityDetailState(
        mode: mode,
        pendingActivityData: pendingActivityData,
        macroTargets: macroTargets,
        scheduledDateTime: pendingActivityData?.scheduledDateTime,
      );
    } else {
      // View mode: Load activity from database
      if (activityId == null) {
        throw Exception('Activity ID required for view mode');
      }

      // Get current user's ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      final activity = await _calendarService.getActivityById(userId, activityId);

      if (activity == null) {
        throw Exception('Activity not found: $activityId');
      }

      // Load nutrition plan if linked to this activity
      NutritionPlan? nutritionPlan;
      try {
        final repository = await _nutritionPlanRepository;
        nutritionPlan = await repository.getNutritionPlanByActivityId(userId, activityId);
        if (nutritionPlan != null) {
          _logger.info('Loaded nutrition plan for activity: ${nutritionPlan.id}');
        } else {
          _logger.info('No nutrition plan linked to activity: $activityId');
        }
      } catch (e) {
        _logger.error('Error loading nutrition plan for activity', error: e);
      }

      // Load completion if exists
      ActivityCompletion? completion;
      if (activity.isCompleted) {
        completion = await _calendarService.getCompletionForActivity(activityId);
      }

      return ActivityDetailState(
        mode: mode,
        activity: activity,
        nutritionPlan: nutritionPlan,
        completion: completion,
        scheduledDateTime: activity.scheduledDateTime,
      );
    }
  }

  /// Save activity (creates new or updates existing)
  Future<void> saveActivity() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    state = await AsyncValue.guard(() async {
      try {
        final calendarController = ref.read(calendarControllerProvider.notifier);

        if (currentState.isCreateMode) {
          // CREATE MODE: Create new activity
          final pendingData = currentState.pendingActivityData;
          if (pendingData == null) {
            throw Exception('Missing pending activity data');
          }

          // Get reminder data if available
          final reminder = currentState.pendingReminder;

          final newActivityId = await calendarController.createActivity(
            title: pendingData.title,
            scheduledDateTime: currentState.scheduledDateTime ?? pendingData.scheduledDateTime,
            activityType: ActivityType.running,
            distanceMiles: pendingData.distanceMiles,
            paceTargetMinutesPerMile: pendingData.paceMinutesPerMile,
            intensityLevel: pendingData.intensityLevel,
            notes: pendingData.notes,
            reminderEnabled: reminder?.enabled ?? false,
            reminderDaysBefore: reminder?.daysBefore,
            reminderTimeOfDay: reminder?.timeOfDay,
            reminderRecurring: reminder?.recurring ?? false,
          );

          // Link the current nutrition plan to the newly created activity
          await _linkCurrentNutritionPlanToActivity(newActivityId);

          return currentState.copyWith(isSaving: false);
        } else {
          // VIEW MODE: Update existing activity
          final activity = currentState.activity;
          if (activity == null) {
            throw Exception('No activity to update');
          }

          final updatedActivity = activity.copyWith(
            scheduledDateTime: currentState.scheduledDateTime,
          );

          await calendarController.updateActivity(updatedActivity);

          // If nutrition plan was modified, ensure it's linked to this activity
          if (currentState.hasUnsavedChanges) {
            await _linkCurrentNutritionPlanToActivity(activity.id);
          }

          return currentState.copyWith(
            isSaving: false,
            activity: updatedActivity,
            hasUnsavedChanges: false,
          );
        }
      } catch (error) {
        _logger.error('Error saving activity', error: error);
        rethrow;
      }
    });
  }

  /// Helper method to link the current nutrition plan to an activity
  Future<void> _linkCurrentNutritionPlanToActivity(String activityId) async {
    try {
      // Get the current nutrition plan from the NutritionPlanController
      final nutritionPlanState = ref.read(nutritionPlanControllerProvider);
      final currentPlan = nutritionPlanState.value?.plan;

      if (currentPlan == null) {
        _logger.info('No nutrition plan to link to activity $activityId');
        return;
      }

      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.warning('Cannot link nutrition plan: no user found');
        return;
      }

      // Link the plan to the activity
      final repository = await _nutritionPlanRepository;
      final success = await repository.updatePlanActivityId(
        user.id,
        currentPlan.id,
        activityId,
      );

      if (success) {
        _logger.info('Successfully linked nutrition plan ${currentPlan.id} to activity $activityId');
      } else {
        _logger.warning('Failed to link nutrition plan to activity');
      }
    } catch (e) {
      _logger.error('Error linking nutrition plan to activity', error: e);
      // Don't rethrow - this is a non-critical operation
    }
  }

  /// Complete activity with ratings and notes
  Future<void> completeActivity({
    required int overallSatisfaction,
    String? textNotes,
  }) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = AsyncData(currentState.copyWith(isCompleting: true));

    state = await AsyncValue.guard(() async {
      try {
        final calendarController = ref.read(calendarControllerProvider.notifier);

        await calendarController.completeActivity(
          activityId: currentState.activity!.id,
          completedAt: DateTime.now(),
          effortRating: null,
          nutritionRating: null,
          overallSatisfaction: overallSatisfaction,
          textNotes: textNotes,
        );

        // Reload activity to get updated completion data
        ref.invalidateSelf();

        return currentState.copyWith(isCompleting: false);
      } catch (error) {
        _logger.error('Error completing activity', error: error);
        rethrow;
      }
    });
  }

  /// Update workout notes for a completed activity
  Future<void> updateWorkoutNotes(String? notes) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null || currentState.completion == null) return;

    state = await AsyncValue.guard(() async {
      try {
        final calendarController = ref.read(calendarControllerProvider.notifier);

        await calendarController.updateActivityCompletion(
          activityId: currentState.activity!.id,
          textNotes: notes,
        );

        // Reload activity to get updated completion data
        ref.invalidateSelf();

        return currentState;
      } catch (error) {
        _logger.error('Error updating workout notes', error: error);
        rethrow;
      }
    });
  }

  /// Update scheduled date/time
  Future<void> updateScheduledDateTime(DateTime newDateTime) async {
    final currentState = state.value;
    if (currentState == null) return;

    // In view mode, mark as changed so Save button appears
    // In create mode, don't mark as changed (user hasn't saved anything yet)
    final hasChanges = currentState.isViewMode;

    state = AsyncData(currentState.copyWith(
      scheduledDateTime: newDateTime,
      hasUnsavedChanges: hasChanges,
    ));
  }

  /// Update reminder settings
  Future<void> updateReminder(ActivityReminder? reminder) async {
    final currentState = state.value;
    if (currentState == null) return;

    // If we have an existing activity, update it with new reminder settings
    if (currentState.activity != null) {
      final updatedActivity = currentState.activity!.copyWith(
        reminderEnabled: reminder?.enabled ?? false,
        reminderDaysBefore: reminder?.daysBefore,
        reminderTimeOfDay: reminder?.timeOfDay,
        reminderRecurring: reminder?.recurring ?? false,
      );

      state = AsyncData(currentState.copyWith(
        activity: updatedActivity,
        hasUnsavedChanges: true,
      ));
    } else {
      // In create mode, store the reminder in pendingReminder
      state = AsyncData(currentState.copyWith(
        pendingReminder: reminder,
        hasUnsavedChanges: true,
      ));
    }
  }

  /// Mark that the nutrition plan has unsaved changes
  void markAsChanged() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));
  }

  /// Clear unsaved changes flag
  void clearChanges() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: false));
  }
}
