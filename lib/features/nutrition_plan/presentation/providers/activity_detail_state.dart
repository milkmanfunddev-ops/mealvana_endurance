import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../domain/fuel_log_data.dart';
import '../../domain/macro_targets.dart';
import '../../domain/nutrition_plan.dart';

/// View mode for completed activities with a fuel log.
enum FuelLogViewMode { planned, actual }

/// Activity Detail Controller State
class ActivityDetailState {
  const ActivityDetailState({
    this.activity,
    this.nutritionPlan,
    this.macroTargets,
    this.completion,
    this.scheduledDateTime,
    this.isSaving = false,
    this.isCompleting = false,
    this.hasUnsavedChanges = false,
    this.isNewActivity = false,
    this.eventName,
    this.error,
    this.hasStaleDuringTarget = false,
    this.staleDuringTargetMessage,
    // Fuel log fields
    this.isFuelLogMode = false,
    this.fuelLogData,
    this.fuelLogViewMode = FuelLogViewMode.planned,
  });

  final Activity? activity;
  final NutritionPlan? nutritionPlan;
  final MacroTargets? macroTargets;
  final ActivityCompletion? completion;
  final DateTime? scheduledDateTime;
  final bool isSaving;
  final bool isCompleting;
  final bool hasUnsavedChanges; // Tracks if nutrition plan has been modified
  final bool
  isNewActivity; // True if this is the first time viewing after creation
  final String? eventName; // Event name from linked event (reverse lookup)
  final String? error;
  final bool hasStaleDuringTarget;
  final String? staleDuringTargetMessage;

  // Fuel log fields
  final bool isFuelLogMode; // true when in fuel logging view
  final FuelLogData? fuelLogData; // in-memory during logging
  final FuelLogViewMode fuelLogViewMode; // planned/actual toggle for completed

  bool get hasActivity => activity != null;
  bool get isCompleted => completion != null;
  bool get hasFuelLog => activity?.fuelLogData != null;

  ActivityDetailState copyWith({
    Activity? activity,
    NutritionPlan? nutritionPlan,
    MacroTargets? macroTargets,
    ActivityCompletion? completion,
    DateTime? scheduledDateTime,
    bool? isSaving,
    bool? isCompleting,
    bool? hasUnsavedChanges,
    bool? isNewActivity,
    String? eventName,
    String? error,
    bool? hasStaleDuringTarget,
    String? staleDuringTargetMessage,
    bool? isFuelLogMode,
    FuelLogData? fuelLogData,
    FuelLogViewMode? fuelLogViewMode,
    bool clearFuelLogData = false,
  }) {
    return ActivityDetailState(
      activity: activity ?? this.activity,
      nutritionPlan: nutritionPlan ?? this.nutritionPlan,
      macroTargets: macroTargets ?? this.macroTargets,
      completion: completion ?? this.completion,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      isSaving: isSaving ?? this.isSaving,
      isCompleting: isCompleting ?? this.isCompleting,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isNewActivity: isNewActivity ?? this.isNewActivity,
      eventName: eventName ?? this.eventName,
      error: error ?? this.error,
      hasStaleDuringTarget: hasStaleDuringTarget ?? this.hasStaleDuringTarget,
      staleDuringTargetMessage:
          staleDuringTargetMessage ?? this.staleDuringTargetMessage,
      isFuelLogMode: isFuelLogMode ?? this.isFuelLogMode,
      fuelLogData: clearFuelLogData ? null : (fuelLogData ?? this.fuelLogData),
      fuelLogViewMode: fuelLogViewMode ?? this.fuelLogViewMode,
    );
  }
}
