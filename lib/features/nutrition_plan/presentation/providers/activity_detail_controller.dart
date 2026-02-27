import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';
import '../../../activities/application/activities_service.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/food_item_data.dart';
import '../../domain/time_slot_assignment.dart';
import '../../application/proportional_scaling_service.dart';
import '../../application/by_hour_apportionment_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../activities/domain/activity_reminder.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../application/nutrition_plan_service.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../data/template_foods_repository.dart';
import '../../../../shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'activity_detail_state.dart';

part 'activity_detail_controller.g.dart';

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

  /// When set, the next food added via reapportion will be placed only in this hour.
  int? _pendingAddFoodHourIndex;

  Future<NutritionPlanRepository> get _nutritionPlanRepository async =>
      await ref.read(nutritionPlanRepositoryProvider.future);

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) async {
    // CRITICAL FIX: Use userIdProvider (same source as ActivitiesController)
    // This was causing user ID mismatch bug where activities created with one ID
    // were being queried with a different ID
    final userId = await ref.read(userIdProvider.future);

    // DIAGNOSTIC LOGGING: Track user ID source for debugging
    final authUser = await _authService.getCurrentUser();
    _logger.info(
      'Loading activity detail',
      context: 'ACTIVITY_DETAIL_CONTROLLER',
      data: {
        'activityId': activityId,
        'userIdFromProvider': userId,
        'authUserId': authUser?.id ?? 'null',
        'idsMatch': userId == authUser?.id,
      },
    );

    final activity = await _activitiesService.getActivityById(userId, activityId);

    if (activity == null) {
      _logger.error(
        'Activity not found in database',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        data: {
          'activityId': activityId,
          'userId': userId,
          'authUserId': authUser?.id,
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
        // Enrich food items with displayNamePlural/servingSize from template_foods
        nutritionPlan = await _enrichFoodItemsFromTemplateFoods(nutritionPlan);
      }
    } catch (e) {
      _logger.error('Error loading nutrition plan for activity', error: e);
    }

    // Load completion if exists
    ActivityCompletion? completion;
    if (activity.isCompleted && activity.completedAt != null) {
      // Generate integer IDs from string UUID using hashCode
      final completionId = activity.id.hashCode;
      final activityIdInt = activity.id.hashCode;

      completion = ActivityCompletion(
        id: completionId,
        activityId: activityIdInt,
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
  Future<void> _saveNutritionPlanToActivity(String activityId, NutritionPlan plan) async {
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
  // FOOD ENRICHMENT
  // ============================================================================

  /// Enrich food items in a nutrition plan with displayNamePlural and servingSize
  /// from the local template_foods table.
  Future<NutritionPlan> _enrichFoodItemsFromTemplateFoods(NutritionPlan plan) async {
    try {
      final templateFoodsRepo = ref.read(templateFoodsRepositoryProvider);
      final allTemplateFoods = await templateFoodsRepo.getAllTemplateFoods();

      // Build a lookup map by ID for fast matching
      final foodLookup = <String, dynamic>{};
      for (final tf in allTemplateFoods) {
        foodLookup[tf.id] = tf;
      }

      FoodItemData enrichFood(FoodItemData food) {
        final tf = foodLookup[food.id];
        if (tf == null) return food;
        return FoodItemData(
          id: food.id,
          name: food.name,
          quantity: food.quantity,
          imageAddress: food.imageAddress ?? tf.imageAddress,
          description: food.description ?? tf.description,
          timing: food.timing,
          nutritionalInfo: food.nutritionalInfo,
          instructions: food.instructions,
          displayName: food.displayName ?? tf.displayName,
          displayNamePlural: food.displayNamePlural ?? tf.displayNamePlural,
          displayOverride: food.displayOverride,
          servingSize: food.servingSize ?? tf.servingSize,
          isDrink: food.isDrink,
          templateId: food.templateId,
          scaleMultiplier: food.scaleMultiplier,
        );
      }

      final enrichedSections = plan.sections.map((section) {
        if (section.hasSubPhases) {
          final enrichedSubPhases = section.subPhases!.map((sp) {
            return sp.copyWith(
              foodItems: sp.foodItems.map(enrichFood).toList(),
            );
          }).toList();
          return section.copyWith(subPhases: enrichedSubPhases);
        }
        return section.copyWith(
          foodItems: section.foodItems.map(enrichFood).toList(),
        );
      }).toList();

      return plan.copyWith(sections: enrichedSections);
    } catch (e) {
      _logger.warning('Failed to enrich food items from template_foods: $e');
      return plan;
    }
  }

  // ============================================================================
  // UNIFIED FOOD MODIFICATION METHODS
  // ============================================================================

  /// Check if a category matches a section by ID or title using flexible prefix matching
  ///
  /// Supports all activity types: running, cycling, swimming, brick
  /// Categories: 'before_run', 'during_run', 'during_swim', 'during_cycling', 'transition', 'after_run'
  bool _categoryMatchesSection(String category, String sectionId, String sectionTitle) {
    final categoryLower = category.toLowerCase();
    final sectionIdLower = sectionId.toLowerCase();
    final titleLower = sectionTitle.toLowerCase();

    // Handle transition category (brick-specific)
    if (categoryLower == 'transition') {
      return sectionIdLower.startsWith('t') && sectionIdLower.length <= 2; // T1, T2
    }

    // Handle sport-specific during categories (brick workouts)
    if (categoryLower.startsWith('during_')) {
      final sportSuffix = categoryLower.replaceFirst('during_', '');

      // Must be a during section
      if (!sectionIdLower.contains('during') && !titleLower.startsWith('during')) {
        return false;
      }

      // Match sport from title
      if (sportSuffix == 'swim' || sportSuffix == 'swimming') {
        return titleLower.contains('swim');
      }
      if (sportSuffix == 'cycling' || sportSuffix == 'bike' || sportSuffix == 'ride') {
        return titleLower.contains('bike') || titleLower.contains('cycle') || titleLower.contains('ride');
      }
      if (sportSuffix == 'run' || sportSuffix == 'running') {
        // For 'during_run', match any during section that contains 'run' OR
        // any during section that doesn't contain swim/bike/cycle (backward compat)
        return titleLower.contains('run') ||
               (!titleLower.contains('swim') && !titleLower.contains('bike') && !titleLower.contains('cycle'));
      }
    }

    // Extract phase prefix (e.g., 'before' from 'before_run')
    final phasePrefix = categoryLower.split('_').first;

    // Flexible prefix matching for before/after
    if (phasePrefix == 'before') {
      return sectionIdLower.contains('before') || titleLower.startsWith('before');
    }
    if (phasePrefix == 'after') {
      return sectionIdLower.contains('after') || titleLower.startsWith('after');
    }
    if (phasePrefix == 'during') {
      return sectionIdLower.contains('during') || titleLower.startsWith('during');
    }

    return false;
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
        if (_categoryMatchesSection(category, section.id, section.title)) {
          // If the section has sub-phases (V2 template plans), apply transform to each sub-phase's foods
          if (section.hasSubPhases) {
            final updatedSubPhases = section.subPhases!.map((subPhase) {
              final updatedItems = transform(subPhase.foodItems);
              return subPhase.copyWith(foodItems: updatedItems);
            }).toList();
            return section.copyWith(subPhases: updatedSubPhases);
          }
          final updatedItems = transform(section.foodItems);

          // Keep byHourData in sync when food items change
          ByHourData? updatedByHour = section.byHourData;
          if (updatedByHour != null) {
            final service = ByHourApportionmentService();
            updatedByHour = service.reapportion(
              existing: updatedByHour,
              currentFoodItems: updatedItems,
              targetHourIndex: _pendingAddFoodHourIndex,
            );
            _pendingAddFoodHourIndex = null;
          }

          return section.copyWith(
            foodItems: updatedItems,
            byHourData: updatedByHour,
          );
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

  /// Update a food quantity within a sub-phase, applying proportional scaling
  /// to all sibling items in the same sub-phase.
  ///
  /// [subPhaseIndex] - Index of the sub-phase within the before section
  /// [foodIndex] - Index of the changed food within the sub-phase
  /// [newQuantity] - New quantity for the changed food
  Future<void> updateSubPhaseQuantityWithScaling(
    int subPhaseIndex,
    int foodIndex,
    double newQuantity,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) {
      _logger.warning('Cannot updateSubPhaseQuantityWithScaling: no nutrition plan');
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      final updatedSections = currentPlan.sections.map((section) {
        if (_categoryMatchesSection('before_run', section.id, section.title) &&
            section.hasSubPhases) {
          final updatedSubPhases = section.subPhases!.asMap().entries.map((entry) {
            if (entry.key == subPhaseIndex) {
              final subPhase = entry.value;
              // Apply proportional scaling to all items in this sub-phase
              final scaledSubPhase = ProportionalScalingService.scaleSubPhase(
                subPhase,
                foodIndex,
                newQuantity,
              );
              return scaledSubPhase;
            }
            return entry.value;
          }).toList();
          return section.copyWith(subPhases: updatedSubPhases);
        }
        return section;
      }).toList();

      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        updatedAt: DateTime.now(),
      );

      state = AsyncData(currentState.copyWith(
        nutritionPlan: updatedPlan,
        hasUnsavedChanges: false,
      ));

      // Auto-save
      final activity = currentState.activity;
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
        _logger.info('updateSubPhaseQuantityWithScaling: Auto-saved nutrition plan');
      }

      _logger.info('updateSubPhaseQuantityWithScaling SUCCESS',
        context: 'ActivityDetailController',
        data: {
          'subPhaseIndex': subPhaseIndex,
          'foodIndex': foodIndex,
          'newQuantity': newQuantity,
        },
      );
    } catch (error, stackTrace) {
      _logger.error('Error in updateSubPhaseQuantityWithScaling',
          error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Set the target hour index for the next food add operation.
  /// Called before navigating to food picker from "ADD TO HOUR X".
  void setPendingAddFoodHourIndex(int? hourIndex) {
    _pendingAddFoodHourIndex = hourIndex;
  }

  // ============================================================================
  // BY-HOUR VIEW METHODS
  // ============================================================================

  /// Initialize byHourData for a during-activity section on first toggle.
  ///
  /// [category] - The section category (e.g., 'during_run', 'during_bike')
  /// [durationMinutes] - Duration of the during phase in minutes
  Future<void> initializeByHourData(String category, int durationMinutes) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    // Find the target section
    final targetSection = currentPlan.sections.firstWhere(
      (s) => _categoryMatchesSection(category, s.id, s.title),
      orElse: () => currentPlan.sections.first,
    );

    // Already initialized - skip
    if (targetSection.byHourData != null) return;

    final service = ByHourApportionmentService();
    final byHourData = service.apportion(
      foodItems: targetSection.foodItems,
      durationMinutes: durationMinutes,
    );

    if (byHourData == null) return;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title)) {
        return section.copyWith(byHourData: byHourData);
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    // Auto-save to persist byHourData
    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }

    _logger.info('initializeByHourData SUCCESS',
      context: 'ActivityDetailController',
      data: {
        'category': category,
        'durationMinutes': durationMinutes,
        'assignmentCount': byHourData.assignments.length,
      },
    );
  }

  /// Move a food item to a different time slot (drag & drop).
  Future<void> moveFoodToTimeSlot(
    String foodId,
    String category,
    TimeSlot newTimeSlot,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        final updatedAssignments = section.byHourData!.assignments.map((a) {
          if (a.foodItemId == foodId) {
            return a.copyWith(timeSlot: newTimeSlot);
          }
          return a;
        }).toList();

        return section.copyWith(
          byHourData: section.byHourData!.copyWith(
            assignments: updatedAssignments,
          ),
        );
      }
      return section;
    }).toList();

    final updatedPlan = currentPlan.copyWith(
      sections: updatedSections,
      updatedAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(nutritionPlan: updatedPlan));

    // Auto-save
    final activity = currentState.activity;
    if (activity != null) {
      await _saveNutritionPlanToActivity(activity.id, updatedPlan);
    }
  }

  // ============================================================================
  // BUSINESS LOGIC METHODS (moved from ActivityDetailScreen for FOA compliance)
  // ============================================================================

  /// Regenerate nutrition plan after schedule change
  /// Returns true on success, false on failure
  Future<bool> regenerateNutritionPlan() async {
    final currentState = state.value;
    if (currentState?.activity == null) return false;

    final activity = currentState!.activity!;

    try {
      final nutritionService = ref.read(nutritionPlanServiceProvider);
      await nutritionService.regenerateForScheduleChange(activity);

      // Refresh controller data from database
      ref.invalidateSelf();

      _trackAnalytics('nutrition_plan_regenerated_after_schedule_change', {
        'activity_id': activity.id,
        'activity_type': activity.activityType.name,
        'provider': activity.syncedFromProvider ?? 'manual',
        'distance_miles': activity.distanceMiles?.toString(),
        'duration_minutes': activity.durationMinutes?.toString(),
      });

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to regenerate nutrition plan',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activity.id},
      );
      return false;
    }
  }

  /// Delete the current activity
  /// Returns true on success, false on failure
  Future<bool> deleteActivity() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) return false;

      await _activitiesService.deleteActivity(
        deviceId: user.id,
        activityId: activityId,
      );

      _trackAnalytics('activity_deleted', {
        'activity_id': activityId,
        'deleted_from': 'activity_detail_screen',
      });

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to delete activity',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activityId},
      );
      return false;
    }
  }

  /// Track an analytics event
  void _trackAnalytics(String event, Map<String, dynamic> properties) {
    try {
      final analytics = ref.read(appExternalDepsProvider);
      analytics.analytics.track(event, properties: properties);
    } catch (e) {
      // Silently fail analytics
    }
  }

  /// Track a user-facing analytics event (callable from UI)
  void trackEvent(String event, Map<String, dynamic> properties) {
    _trackAnalytics(event, properties);
  }

  // ============================================================================
  // SWIPE HINT STATE MANAGEMENT
  // ============================================================================

  static const String swipeHintShownKey = 'activity_detail_swipe_hint_shown';

  /// Check if the swipe hint has been shown before
  bool checkSwipeHintShown(SharedPreferences prefs) {
    try {
      return prefs.getBool(swipeHintShownKey) ?? false;
    } catch (e) {
      return true; // Assume shown on error
    }
  }

  /// Mark the swipe hint as shown
  Future<void> markSwipeHintShown(SharedPreferences prefs) async {
    try {
      await prefs.setBool(swipeHintShownKey, true);
    } catch (e) {
      // Silently fail
    }
  }
}
