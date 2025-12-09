import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../../activities/application/activities_service.dart';
import '../../domain/nutrition_plan.dart' show NutritionPlan;
import '../../domain/food_item_data.dart';
import '../../../auth/application/auth_service.dart';
import '../../../activities/domain/activity_reminder.dart';
import '../../../../shared/services/logging_service.dart';
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

        // CRITICAL FIX: Always include the current nutrition plan data when saving
        // The state's nutritionPlan may have been updated (e.g., by food swaps) but
        // the activity object still has the old nutritionPlanData from when it was loaded.
        // We must use the current nutritionPlan from state to avoid overwriting changes.
        final updatedActivity = activity.copyWith(
          scheduledDateTime: currentState.scheduledDateTime,
          nutritionPlanData: currentState.nutritionPlan?.toJson(),
        );

        await _activitiesService.updateActivity(
          deviceId: deviceId,
          activity: updatedActivity,
        );

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

      DebugLogger.info('Nutrition plan saved to activity $activityId');
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

  // ============================================================================
  // UNIFIED FOOD MODIFICATION METHODS
  // ============================================================================

  /// Check if a category matches a section title
  bool _categoryMatchesSection(String category, String sectionTitle) {
    return (category == 'before_run' && sectionTitle == 'Before Run') ||
           (category == 'during_run' && sectionTitle == 'During Run') ||
           (category == 'after_run' && sectionTitle == 'After Run');
  }

  /// Create a FoodItemData from a food object with optional custom amount
  FoodItemData _createFoodItemData(dynamic food, {double? customAmount}) {
    final multiplier = customAmount ?? food.servingAmount ?? 1.0;
    return FoodItemData(
      id: const Uuid().v4(),
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
        fluids: ((food.fluidMlPerServing ?? 0) * multiplier),
      ),
    );
  }

  /// Unified method to modify food items in a nutrition plan section.
  ///
  /// This consolidates add, swap, and delete operations to ensure consistent
  /// behavior and prevent bugs like losing section targets (uses copyWith).
  ///
  /// [category] - The section category ('before_run', 'during_run', 'after_run')
  /// [transform] - Function that transforms the current food items list
  /// [operationName] - Name of the operation for logging
  Future<void> _updateSectionFoods({
    required String category,
    required List<FoodItemData> Function(List<FoodItemData> currentItems) transform,
    required String operationName,
  }) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot $operationName: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      // Update sections, using copyWith to preserve all section properties (including targets)
      final updatedSections = currentPlan.sections.map((section) {
        if (_categoryMatchesSection(category, section.title)) {
          final updatedItems = transform(section.foodItems);
          return section.copyWith(foodItems: updatedItems);
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      // Update state first for immediate UI feedback
      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: false,
      ));

      // Auto-save to prevent data loss on provider rebuild (e.g., navigation)
      final activity = currentState.activity;
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
        _logger.info('$operationName: Auto-saved nutrition plan to prevent data loss');
      }

      _logger.info('$operationName SUCCESS',
        context: 'ActivityDetailController',
        data: {
          'category': category,
          'updatedPlanId': updatedPlan.id,
        },
      );
    } catch (error, stackTrace) {
      _logger.error('Error in $operationName', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
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
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'swapFoodItem',
      transform: (items) => items.map((item) {
        if (item.id == oldFoodId) {
          return _createFoodItemData(newFood, customAmount: customAmount);
        }
        return item;
      }).toList(),
    );
  }

  /// Add a food item to the nutrition plan
  Future<void> addFoodItem(dynamic food, String category, {double? customAmount}) async {
    _logger.info('addFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {
        'foodName': food?.name ?? 'null',
        'category': category,
        'customAmount': customAmount,
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'addFoodItem',
      transform: (items) => [...items, _createFoodItemData(food, customAmount: customAmount)],
    );
  }

  /// Delete a food item from the nutrition plan
  Future<void> deleteFoodItem(String foodId, String category) async {
    _logger.info('deleteFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {
        'foodId': foodId,
        'category': category,
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'deleteFoodItem',
      transform: (items) => items.where((item) => item.id != foodId).toList(),
    );
  }

  /// Update the quantity of an existing food item
  Future<void> updateFoodQuantity(String foodId, String category, double newQuantity) async {
    _logger.info('updateFoodQuantity ENTRY',
      context: 'ActivityDetailController',
      data: {
        'foodId': foodId,
        'category': category,
        'newQuantity': newQuantity,
      },
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'updateFoodQuantity',
      transform: (items) => items.map((item) {
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
      }).toList(),
    );
  }
}
