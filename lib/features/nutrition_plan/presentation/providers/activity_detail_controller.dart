import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../calendar/domain/activity.dart';
import '../../../calendar/domain/activity_completion.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../domain/nutrition_plan.dart' show NutritionPlan;
import '../../domain/macro_targets.dart';
import '../../../calendar/application/calendar_service.dart';
import 'distance_page_gut_entry_controller.dart';
import '../../../../shared/services/logging_service.dart';

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

      final activity = await _calendarService.getActivityById('current-user', activityId);

      if (activity == null) {
        throw Exception('Activity not found: $activityId');
      }

      // Load nutrition plan if linked
      NutritionPlan? nutritionPlan;
      // TODO: Load nutrition plan by activityId when repository method exists

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

          final activityId = await calendarController.createActivity(
            title: pendingData.title,
            scheduledDateTime: currentState.scheduledDateTime ?? pendingData.scheduledDateTime,
            activityType: ActivityType.running,
            distanceMiles: pendingData.distanceMiles,
            paceTargetMinutesPerMile: pendingData.paceMinutesPerMile,
            intensityLevel: pendingData.intensityLevel,
            notes: pendingData.notes,
          );

          // TODO: Link nutrition plan to activity when method is implemented
          // For now, the nutrition plan is already saved with the correct planId

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

          return currentState.copyWith(
            isSaving: false,
            activity: updatedActivity,
          );
        }
      } catch (error) {
        _logger.error('Error saving activity', error: error);
        rethrow;
      }
    });
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

    state = AsyncData(currentState.copyWith(scheduledDateTime: newDateTime));
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
