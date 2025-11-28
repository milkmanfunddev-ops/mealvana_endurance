import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../../activities/application/activities_service.dart';
import '../../domain/nutrition_plan.dart' show NutritionPlan, PlanSection;
import '../../domain/food_item_data.dart';
import '../../../auth/application/auth_service.dart';
import '../../../activities/domain/activity_reminder.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../data/nutrition_plan_repository.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'activity_detail_controller.g.dart';

/// Activity Detail Controller State
///
/// SIMPLIFIED ARCHITECTURE: This controller uses only activityId as the provider
/// family parameter. All data is loaded from the database, eliminating provider
/// instance mismatches that caused food swap persistence bugs.
///
/// The controller always allows editing regardless of completion status.
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

/// Activity Detail Controller
/// Manages activity viewing, updates, and completion
///
/// SIMPLIFIED: Uses only activityId as the provider family parameter.
/// All data is loaded from the database. This eliminates provider instance
/// mismatches that caused food swap/add operations to not persist.
@riverpod
class ActivityDetailController extends _$ActivityDetailController {
  AppLogger get _logger => ref.read(appLoggerProvider);
  ActivitiesService get _activitiesService => ref.read(activitiesServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);

  Future<NutritionPlanRepository> get _nutritionPlanRepository async =>
      await ref.read(nutritionPlanRepositoryProvider.future);

  @override
  FutureOr<ActivityDetailState> build({
    required int activityId,
    bool isNewActivity = false,
  }) async {
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
        },
      );
      throw Exception('Activity not found');
    }

    // Load nutrition plan from activity's nutritionPlanData field
    NutritionPlan? nutritionPlan;
    try {
      final repository = await _nutritionPlanRepository;
      nutritionPlan = await repository.getNutritionPlanByActivityId(userId, activityId);
      if (nutritionPlan != null) {
        _logger.info('Loaded nutrition plan for activity: ${nutritionPlan.id}');
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
      activity: activity,
      nutritionPlan: nutritionPlan,
      completion: completion,
      scheduledDateTime: activity.scheduledDateTime,
      isNewActivity: isNewActivity,
    );
  }

  /// Save activity and any nutrition plan changes
  Future<void> saveActivity() async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception('Cannot save activity: user not authenticated');
        }
        final deviceId = user.id;
        final activity = currentState.activity!;

        // Update activity with any changes (e.g., scheduled date/time)
        final updatedActivity = activity.copyWith(
          scheduledDateTime: currentState.scheduledDateTime,
        );

        await _activitiesService.updateActivity(
          deviceId: deviceId,
          activity: updatedActivity,
        );

        // Save nutrition plan if modified
        if (currentState.hasUnsavedChanges && currentState.nutritionPlan != null) {
          await _saveNutritionPlanToActivity(activity.id, currentState.nutritionPlan!);
        }

        return currentState.copyWith(
          isSaving: false,
          activity: updatedActivity,
          hasUnsavedChanges: false,
          isNewActivity: false, // No longer a new activity after first save
        );
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

    state = AsyncData(currentState.copyWith(
      scheduledDateTime: newDateTime,
      hasUnsavedChanges: true,
    ));
  }

  /// Update reminder settings
  Future<void> updateReminder(ActivityReminder? reminder) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

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
    _logger.info('swapFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {
        'oldFoodId': oldFoodId,
        'newFoodName': newFood?.name ?? 'null',
        'category': category,
        'customAmount': customAmount,
        'stateIsNull': state.value == null,
        'nutritionPlanIsNull': state.value?.nutritionPlan == null,
      },
    );

    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot swap food: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Create a new plan with the swapped food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.map((item) {
            if (item.id == oldFoodId) {
              // Create a new food item from the newFood with a unique instance ID
              final multiplier = customAmount ?? newFood.servingAmount ?? 1.0;
              return FoodItemData(
                id: const Uuid().v4(), // Generate unique instance ID
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

      // Don't auto-save - let user click Save to persist changes
      // User must now explicitly save by clicking the Save button

      // Update state with new plan and mark as having unsaved changes
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: true, // Always mark as changed, user must click Save
      ));

      _logger.info('swapFoodItem SUCCESS - state updated',
        context: 'ActivityDetailController',
        data: {
          'hasUnsavedChanges': true,
          'updatedPlanId': updatedPlan.id,
        },
      );
    } catch (error, stackTrace) {
      _logger.error('Error swapping food item', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Add a food item to the nutrition plan
  Future<void> addFoodItem(dynamic food, String category, {double? customAmount}) async {
    _logger.info('addFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {
        'foodName': food?.name ?? 'null',
        'category': category,
        'customAmount': customAmount,
        'stateIsNull': state.value == null,
        'nutritionPlanIsNull': state.value?.nutritionPlan == null,
      },
    );

    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot add food: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Create a new plan with the added food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final multiplier = customAmount ?? food.servingAmount ?? 1.0;
          final newItem = FoodItemData(
            id: const Uuid().v4(), // Generate unique instance ID
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

      // Don't auto-save - let user click Save to persist changes
      // User must now explicitly save by clicking the Save button

      // Update state with new plan and mark as having unsaved changes
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: true, // Always mark as changed, user must click Save
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

      // Don't auto-save - let user click Save to persist changes
      // User must now explicitly save by clicking the Save button

      // Update state with new plan and mark as having unsaved changes
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: true, // Always mark as changed, user must click Save
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

      // Don't auto-save - let user click Save to persist changes
      // User must now explicitly save by clicking the Save button

      // Update state with new plan and mark as having unsaved changes
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: true, // Always mark as changed, user must click Save
      ));
    } catch (error, stackTrace) {
      _logger.error('Error updating food quantity', error: error, stackTrace: stackTrace);
    }
  }
}
