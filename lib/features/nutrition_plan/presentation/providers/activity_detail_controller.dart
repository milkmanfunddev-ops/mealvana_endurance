import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../../activities/application/activities_service.dart';
import '../../domain/nutrition_plan.dart' show NutritionPlan, PlanSection;
import '../../domain/macro_targets.dart';
import '../../domain/food_item_data.dart';
import '../../domain/pending_activity_data.dart';
import '../../../auth/application/auth_service.dart';
import '../../../activities/domain/activity_reminder.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../data/nutrition_plan_repository.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

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
  ActivitiesService get _activitiesService => ref.read(activitiesServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);
  AnalyticsTracker get _analytics => ref.read(appExternalDepsProvider).analytics;

  Future<NutritionPlanRepository> get _nutritionPlanRepository async =>
      await ref.read(nutritionPlanRepositoryProvider.future);

  @override
  FutureOr<ActivityDetailState> build({
    required String mode,
    int? activityId,
    PendingActivityData? pendingActivityData,
    MacroTargets? macroTargets,
  }) async {
    if (mode == 'create' && activityId == null) {
      // Create mode with no activityId: Use pending activity data (for new activities not yet saved)
      return ActivityDetailState(
        mode: mode,
        pendingActivityData: pendingActivityData,
        macroTargets: macroTargets,
        scheduledDateTime: pendingActivityData?.scheduledDateTime,
      );
    } else if (mode == 'create' && activityId != null) {
      // Create mode with activityId: Load from DB but show "Save Workout" button
      // This handles the case where activity is just created and we're viewing it for the first time
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      final activity = await _activitiesService.getActivityById(userId, activityId);

      if (activity == null) {
        _logger.error(
          'Activity not found in database',
          context: 'ACTIVITY_DETAIL_CONTROLLER',
          data: {
            'activityId': activityId,
            'userId': userId,
            'mode': mode,
          },
        );
        throw Exception('No activity data available');
      }

      // Additional validation
      if (activity.title.isEmpty) {
        _logger.warning(
          'Activity has empty title',
          context: 'ACTIVITY_DETAIL_CONTROLLER',
          data: {'activityId': activityId},
        );
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
      if (activity.isCompleted && activity.completedAt != null) {
        completion = ActivityCompletion(
          id: activity.id,
          activityId: activity.id,
          userId: activity.userId,
          completedAt: activity.completedAt!,
          overallSatisfaction: activity.completionRating,
          textNotes: activity.completionNotes,
          actualDistanceMiles: activity.actualDistanceMiles,
          actualDurationMinutes: activity.actualDurationMinutes,
        );
      }

      return ActivityDetailState(
        mode: mode,
        activity: activity,
        nutritionPlan: nutritionPlan,
        completion: completion,
        macroTargets: macroTargets,
        scheduledDateTime: activity.scheduledDateTime,
      );
    } else {
      // View mode: Load activity from database
      if (activityId == null) {
        throw Exception('Activity ID required for view mode');
      }

      // Get current user's ID
      final user = await _authService.getCurrentUser();
      final userId = user?.id ?? 'unknown';

      final activity = await _activitiesService.getActivityById(userId, activityId);

      if (activity == null) {
        _logger.error(
          'Activity not found in database',
          context: 'ACTIVITY_DETAIL_CONTROLLER',
          data: {
            'activityId': activityId,
            'userId': userId,
            'mode': mode,
          },
        );
        throw Exception('No activity data available');
      }

      // Additional validation: check if activity has required fields
      if (activity.title.isEmpty) {
        _logger.warning(
          'Activity has empty title',
          context: 'ACTIVITY_DETAIL_CONTROLLER',
          data: {'activityId': activityId},
        );
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

      // Load completion if exists - map from activity completion fields
      ActivityCompletion? completion;
      if (activity.isCompleted && activity.completedAt != null) {
        completion = ActivityCompletion(
          id: activity.id,
          activityId: activity.id,
          userId: activity.userId,
          completedAt: activity.completedAt!,
          overallSatisfaction: activity.completionRating,
          textNotes: activity.completionNotes,
          actualDistanceMiles: activity.actualDistanceMiles,
          actualDurationMinutes: activity.actualDurationMinutes,
        );
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
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot save activity: user not authenticated');
        }
        final deviceId = user.id;

        if (currentState.isCreateMode) {
          // CREATE MODE: Check if activity already exists (loaded from DB)
          if (currentState.activity != null) {
            // Activity already exists in DB, no need to create it again
            // This happens when navigating from adjust_macros_screen after activity creation
            _logger.info(
              'Activity already exists, skipping creation',
              context: 'ACTIVITY_DETAIL_CONTROLLER',
              data: {'activityId': currentState.activity!.id},
            );
            return currentState.copyWith(isSaving: false);
          }

          // Activity doesn't exist yet, create it from pending data
          final pendingData = currentState.pendingActivityData;
          if (pendingData == null) {
            throw Exception('Missing pending activity data');
          }

          final createdActivity = await _activitiesService.createActivity(
            deviceId: deviceId,
            userId: deviceId,
            activityType: pendingData.activityType,
            title: pendingData.title,
            scheduledDateTime: currentState.scheduledDateTime ?? pendingData.scheduledDateTime,
            distanceMiles: pendingData.distanceMiles,
            paceTargetMinutesPerMile: pendingData.paceMinutesPerMile,
            intensityLevel: pendingData.intensityLevel,
            notes: pendingData.notes,
            cyclingSpeedMph: pendingData.cyclingSpeedMph,
            cyclingTerrain: pendingData.cyclingTerrain,
            cyclingIndoorOutdoor: pendingData.cyclingIndoorOutdoor,
            cyclingElevationGainFt: pendingData.cyclingElevationGainFt,
            cyclingSessionGoal: pendingData.cyclingSessionGoal,
            swimmingPacePer100mSeconds: pendingData.swimmingPacePer100mSeconds,
            swimmingPoolOrOpenWater: pendingData.swimmingPoolOrOpenWater,
            swimmingWaterTempC: pendingData.swimmingWaterTempC,
            intensityTarget: pendingData.intensityTarget,
            timeBeforeMinutes: pendingData.timeBeforeMinutes,
          );

          // Save the nutrition plan to the newly created activity if we have one
          if (currentState.nutritionPlan != null) {
            await _saveNutritionPlanToActivity(createdActivity.id, currentState.nutritionPlan!);
          }

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

          await _activitiesService.updateActivity(
            deviceId: deviceId,
            activity: updatedActivity,
          );

          // If nutrition plan was modified, save it to this activity
          if (currentState.hasUnsavedChanges && currentState.nutritionPlan != null) {
            await _saveNutritionPlanToActivity(activity.id, currentState.nutritionPlan!);
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

  /// Save nutrition plan to activity's nutritionPlanData field
  Future<void> _saveNutritionPlanToActivity(int activityId, NutritionPlan plan) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.warning('Cannot save nutrition plan: no user found');
        return;
      }

      // Get the activity
      final activity = await _activitiesService.getActivityById(user.id, activityId);
      if (activity == null) {
        _logger.warning('Cannot save nutrition plan: activity not found');
        return;
      }

      // Update activity with nutrition plan JSON
      final updatedActivity = activity.copyWith(
        nutritionPlanData: plan.toJson(),
        updatedAt: DateTime.now(),
      );

      await _activitiesService.updateActivity(
        deviceId: user.id,
        activity: updatedActivity,
      );

      DebugLogger.info('✅ Nutrition plan saved to activity $activityId');
    } catch (e) {
      _logger.error('Error saving nutrition plan to activity', error: e);
      rethrow;
    }
  }

  /// Helper method to map category strings to analytics section names
  String _mapCategoryToSection(String category) {
    switch (category) {
      case 'before_run':
        return 'pre';
      case 'during_run':
        return 'during';
      case 'after_run':
        return 'post';
      default:
        return category;
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
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot complete activity: user not authenticated');
        }

        // Update activity with completion data
        final completedActivity = currentState.activity!.copyWith(
          status: ActivityStatus.completed,
          completedAt: DateTime.now(),
          completionRating: overallSatisfaction,
          completionNotes: textNotes,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: completedActivity,
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
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot update workout notes: user not authenticated');
        }

        // Update activity with new completion notes
        final updatedActivity = currentState.activity!.copyWith(
          completionNotes: notes,
        );

        await _activitiesService.updateActivity(
          deviceId: user.id,
          activity: updatedActivity,
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

  /// Swap a food item in the nutrition plan
  Future<void> swapFoodItem(String oldFoodId, dynamic newFood, String category, {double? customAmount}) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot swap food: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;
    final activity = currentState.activity; // May be null if not saved yet

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Create a new plan with the swapped food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.map((item) {
            if (item.id == oldFoodId) {
              // Create a new food item from the newFood
              final multiplier = customAmount ?? newFood.servingAmount ?? 1.0;
              return FoodItemData(
                id: newFood.id,
                name: newFood.name,
                quantity: newFood.generateQuantityDisplay(customAmount: customAmount),
                imageAddress: newFood.imageAddress,
                description: newFood.description,
                instructions: newFood.instructions,
                displayName: newFood.displayName,
                displayNamePlural: newFood.displayNamePlural,
                nutritionalInfo: NutritionalInfo(
                  calories: ((newFood.caloriesPerServing ?? 0) * multiplier).toInt(),
                  carbs: ((newFood.carbsPerServing ?? 0) * multiplier).toInt(),
                  protein: ((newFood.proteinPerServing ?? 0) * multiplier).toInt(),
                  fat: ((newFood.fatPerServing ?? 0) * multiplier).toInt(),
                  sodium: ((newFood.sodiumMg ?? 0) * multiplier).toInt(),
                  fluids: ((newFood.fluidMlPerServing ?? 0) * multiplier)),
              );
            }
            return item;
          }).toList();

          return section.copyWith(foodItems: updatedItems);
        }
        return section;
      }).toList();

      // Create updated plan
      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      // Save the updated plan to the activity if it exists (otherwise will save when user clicks "Save Workout")
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
      }

      // Track plan_item_swapped event (only if activity exists)
      if (activity != null) {
        final user = await _authService.getCurrentUser();
        final deviceId = user?.id ?? 'unknown';

        // Find the old item name for tracking
        String oldItemName = oldFoodId;
        for (final section in currentPlan.sections) {
          for (final item in section.foodItems) {
            if (item.id == oldFoodId) {
              oldItemName = item.name;
              break;
            }
          }
        }

        await _analytics.trackPlanItemSwapped(
          deviceId: deviceId,
          activityId: activity.id,
          oldItemName: oldItemName,
          newItemName: newFood.name,
          phase: category,
        );
      }

      // Update state with new plan (mark as unsaved if activity doesn't exist yet)
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: activity == null, // Keep unsaved flag if activity doesn't exist
      ));
    } catch (error, stackTrace) {
      _logger.error('Error swapping food item', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Add a food item to the nutrition plan
  Future<void> addFoodItem(dynamic food, String category, {double? customAmount}) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot add food: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;
    final activity = currentState.activity; // May be null if not saved yet

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Create a new plan with the added food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final multiplier = customAmount ?? food.servingAmount ?? 1.0;
          final newItem = FoodItemData(
            id: food.id,
            name: food.name,
            quantity: food.generateQuantityDisplay(customAmount: customAmount),
            imageAddress: food.imageAddress,
            description: food.description,
            instructions: food.instructions,
            displayName: food.displayName,
            displayNamePlural: food.displayNamePlural,
            nutritionalInfo: NutritionalInfo(
              calories: ((food.caloriesPerServing ?? 0) * multiplier).toInt(),
              carbs: ((food.carbsPerServing ?? 0) * multiplier).toInt(),
              protein: ((food.proteinPerServing ?? 0) * multiplier).toInt(),
              fat: ((food.fatPerServing ?? 0) * multiplier).toInt(),
              sodium: ((food.sodiumMg ?? 0) * multiplier).toInt(),
              fluids: ((food.fluidMlPerServing ?? 0) * multiplier)),
          );

          return PlanSection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            foodItems: [...section.foodItems, newItem],
          );
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      // Save the updated plan to the activity if it exists (otherwise will save when user clicks "Save Workout")
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
      }

      // Track item_added event (only if activity exists)
      if (activity != null) {
        final multiplier = customAmount ?? food.servingAmount ?? 1.0;
        await _analytics.track('plan_item_added', properties: {
          'activity_id': activity.id,
          'screen': 'activity_detail_screen',
          'experiment_variant': 'auto_items_v1',
          'section': _mapCategoryToSection(category),
          'item_name': food.name,
          'item_source': 'generic',
          'carbs_g': (food.carbsPerServing ?? 0) * multiplier,
          'protein_g': (food.proteinPerServing ?? 0) * multiplier,
          'fluids_ml': (food.fluidMlPerServing ?? 0) * multiplier,
          'sodium_mg': (food.sodiumMg ?? 0) * multiplier,
        });
      }

      // Update state with new plan (mark as unsaved if activity doesn't exist yet)
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: activity == null, // Keep unsaved flag if activity doesn't exist
      ));
    } catch (error, stackTrace) {
      _logger.error('Error adding food item', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Delete a food item from the nutrition plan
  Future<void> deleteFoodItem(String foodId, String category) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot delete food: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;
    final activity = currentState.activity; // May be null if not saved yet

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Find the item being deleted for analytics tracking
      String? deletedItemName;
      for (final section in currentPlan.sections) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final itemToDelete = section.foodItems.firstWhere(
            (item) => item.id == foodId,
            orElse: () => FoodItemData(id: '', name: 'Unknown', quantity: ''),
          );
          deletedItemName = itemToDelete.name;
          break;
        }
      }

      // Create a new plan without the deleted food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.where((item) => item.id != foodId).toList();
          return section.copyWith(foodItems: updatedItems);
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      // Save the updated plan to the activity if it exists (otherwise will save when user clicks "Save Workout")
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
      }

      // Track item_removed event (only if activity exists)
      if (activity != null && deletedItemName != null) {
        await _analytics.track('plan_item_removed', properties: {
          'activity_id': activity.id,
          'screen': 'activity_detail_screen',
          'experiment_variant': 'auto_items_v1',
          'section': _mapCategoryToSection(category),
          'item_name': deletedItemName,
        });
      }

      // Update state with new plan (mark as unsaved if activity doesn't exist yet)
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: activity == null, // Keep unsaved flag if activity doesn't exist
      ));
    } catch (error, stackTrace) {
      _logger.error('Error deleting food item', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Update the quantity of an existing food item
  Future<void> updateFoodQuantity(String foodId, String category, double newQuantity) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot update food quantity: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;
    final activity = currentState.activity; // May be null if not saved yet

    // Capture old quantity and item name for analytics tracking
    String? itemName;
    double? oldQuantity;

    for (final section in currentPlan.sections) {
      if ((category == 'before_run' && section.title == 'Before Run') ||
          (category == 'during_run' && section.title == 'During Run') ||
          (category == 'after_run' && section.title == 'After Run')) {
        final item = section.foodItems.firstWhere(
          (item) => item.id == foodId,
          orElse: () => FoodItemData(id: '', name: 'Unknown', quantity: ''),
        );
        if (item.id == foodId) {
          itemName = item.name;
          // Extract the current quantity from the quantity string
          final currentQuantityMatch = RegExp(r'^([\d.]+)').firstMatch(item.quantity);
          oldQuantity = currentQuantityMatch != null
              ? double.tryParse(currentQuantityMatch.group(1)!) ?? 1.0
              : 1.0;
          break;
        }
      }
    }

    try {
      // Create a new plan with the updated food quantity
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.map((item) {
            if (item.id == foodId) {
              final currentNutrition = item.nutritionalInfo;
              if (currentNutrition != null) {
                // Extract the current quantity
                final currentQuantityMatch = RegExp(r'^([\d.]+)').firstMatch(item.quantity);
                final currentQuantity = currentQuantityMatch != null
                    ? double.tryParse(currentQuantityMatch.group(1)!) ?? 1.0
                    : 1.0;

                final scaleFactor = newQuantity / currentQuantity;

                // Generate new quantity display string
                final quantityStr = newQuantity == newQuantity.toInt()
                    ? newQuantity.toInt().toString()
                    : newQuantity.toStringAsFixed(1);
                final isPlural = newQuantity != 1.0;

                String displayName;
                if (isPlural && item.displayNamePlural?.isNotEmpty == true) {
                  displayName = item.displayNamePlural!;
                } else if (item.displayName?.isNotEmpty == true) {
                  displayName = item.displayName!;
                } else {
                  displayName = item.name;
                }

                final newQuantityDisplay = '$quantityStr $displayName';

                return FoodItemData(
                  id: item.id,
                  name: item.name,
                  quantity: newQuantityDisplay,
                  imageAddress: item.imageAddress,
                  instructions: item.instructions,
                  description: item.description,
                  displayName: item.displayName,
                  displayNamePlural: item.displayNamePlural,
                  nutritionalInfo: NutritionalInfo(
                    calories: (currentNutrition.calories! * scaleFactor).round(),
                    carbs: (currentNutrition.carbs! * scaleFactor).round(),
                    protein: (currentNutrition.protein! * scaleFactor).round(),
                    fat: (currentNutrition.fat! * scaleFactor).round(),
                    sodium: (currentNutrition.sodium! * scaleFactor).round(),
                    fluids: currentNutrition.fluids! * scaleFactor,
                  ),
                );
              }
            }
            return item;
          }).toList();

          return section.copyWith(foodItems: updatedItems);
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      // Save the updated plan to the activity if it exists (otherwise will save when user clicks "Save Workout")
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
      }

      // Track item_quantity_changed event (only if activity exists)
      if (activity != null && itemName != null && oldQuantity != null) {
        await _analytics.track('plan_item_quantity_changed', properties: {
          'activity_id': activity.id,
          'screen': 'activity_detail_screen',
          'experiment_variant': 'auto_items_v1',
          'section': _mapCategoryToSection(category),
          'item_name': itemName,
          'old_qty': oldQuantity,
          'new_qty': newQuantity,
          'qty_unit': 'servings',
        });
      }

      // Update state with new plan (mark as unsaved if activity doesn't exist yet)
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: activity == null, // Keep unsaved flag if activity doesn't exist
      ));
    } catch (error, stackTrace) {
      _logger.error('Error updating food quantity', error: error, stackTrace: stackTrace);
    }
  }
}
