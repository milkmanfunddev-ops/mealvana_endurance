import 'package:flutter/foundation.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../domain/nutrition_plan.dart';

/// Activity Detail Controller State
class ActivityDetailState {
  const ActivityDetailState({
    this.activity,
    this.nutritionPlan,
    this.completion,
    this.scheduledDateTime,
    this.isSaving = false,
    this.isCompleting = false,
    this.hasUnsavedChanges = false,
    this.isNewActivity = false,
    this.error,
  });

  final Activity? activity;
  final NutritionPlan? nutritionPlan;
  final ActivityCompletion? completion;
  final DateTime? scheduledDateTime;
  final bool isSaving;
  final bool isCompleting;
  final bool hasUnsavedChanges; // Tracks if nutrition plan has been modified
  final bool isNewActivity; // True if this is the first time viewing after creation
  final String? error;

  bool get hasActivity => activity != null;
  bool get isCompleted => completion != null;

  ActivityDetailState copyWith({
    Activity? activity,
    NutritionPlan? nutritionPlan,
    ActivityCompletion? completion,
    DateTime? scheduledDateTime,
    bool? isSaving,
    bool? isCompleting,
    bool? hasUnsavedChanges,
    bool? isNewActivity,
    String? error,
  }) {
    return ActivityDetailState(
      activity: activity ?? this.activity,
      nutritionPlan: nutritionPlan ?? this.nutritionPlan,
      completion: completion ?? this.completion,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      isSaving: isSaving ?? this.isSaving,
      isCompleting: isCompleting ?? this.isCompleting,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isNewActivity: isNewActivity ?? this.isNewActivity,
      error: error ?? this.error,
    );
  }
}

