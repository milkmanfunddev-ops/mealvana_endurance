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
import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../activities/domain/activity_reminder.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../application/nutrition_plan_service.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../data/template_foods_repository.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../domain/carb_adjustment_level.dart';
import '../../domain/nutrition_target_overrides.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../../integrations/presentation/providers/tp_writeback_providers.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
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
  ActivitiesService get _activitiesService =>
      ref.read(activitiesServiceProvider);
  AuthService get _authService => ref.read(authServiceProvider);

  /// When set, the next food added via reapportion will be placed only in this hour.
  int? _pendingAddFoodHourIndex;

  /// Cached gut training level from user profile, loaded in build().
  GutTraining _cachedGutTraining = GutTraining.moderate;

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

    final activity = await _activitiesService.getActivityById(
      userId,
      activityId,
    );

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

    // Cache gut training level from user profile
    try {
      final userRepo = await ref.read(userRepositoryProvider.future);
      final profile = await userRepo.getUserProfile(userId);
      if (profile != null) {
        _cachedGutTraining = profile.gutTraining;
      }
    } catch (e) {
      _logger.warning(
        'Failed to load gut training, using default moderate: $e',
      );
    }

    // Load nutrition plan from activity's nutritionPlanData field
    NutritionPlan? nutritionPlan;
    try {
      final repository = await _nutritionPlanRepository;
      nutritionPlan = await repository.getNutritionPlanByActivityId(
        userId,
        activityId,
      );
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
  Future<void> _saveNutritionPlanToActivity(
    String activityId,
    NutritionPlan plan,
  ) async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.warning('Cannot save nutrition plan: no user found');
        return;
      }

      // Get the activity
      final activity = await _activitiesService.getActivityById(
        user.id,
        activityId,
      );
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

      // Fire-and-forget write-back to TrainingPeaks (never blocks save)
      unawaited(_pushToTrainingPeaks(user.id, updatedActivity, plan));

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

  /// Apply carb feedback adjustment to the user's nutrition target overrides.
  ///
  /// This modifies `nutrition_target_overrides.during.carbRateGPerH` by
  /// multiplying the current rate by [level.adjustmentFactor].
  /// "Just Right" is a no-op.
  Future<void> applyCarbFeedbackAdjustment(CarbAdjustmentLevel level) async {
    // "Just Right" means no change
    if (level == CarbAdjustmentLevel.justRight) return;

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logger.warning('Cannot apply carb feedback: no user');
        return;
      }

      // Determine the base carb rate:
      // 1. If user has an existing during carb override, use that
      // 2. Otherwise, derive from this activity's during section
      double baseRate;
      final existingOverride =
          user.nutritionTargetOverrides?.during?.carbRateGPerH;

      if (existingOverride != null) {
        baseRate = existingOverride;
      } else {
        // Derive from the current activity's during section carbsTarget / duration
        final currentState = state.value;
        final plan = currentState?.nutritionPlan;
        final durationMinutes = currentState?.activity?.durationMinutes
            ?.toDouble();

        if (plan != null && durationMinutes != null && durationMinutes > 0) {
          final duringSection = plan.sections.firstWhere(
            (s) => s.id.contains('during'),
            orElse: () => plan.sections.first,
          );
          final totalCarbs = duringSection.carbsTarget ?? 0;
          baseRate = totalCarbs / (durationMinutes / 60.0);
        } else {
          // No plan data available, skip adjustment
          _logger.warning('Cannot apply carb feedback: no carb rate available');
          return;
        }
      }

      // Apply adjustment factor and clamp to guardrails (0-120 g/hr)
      final newRate = (baseRate * level.adjustmentFactor).clamp(
        NutritionTargetGuardrails.duringMinCarbRateGPerH,
        NutritionTargetGuardrails.duringMaxCarbRateGPerH,
      );

      // Build updated overrides
      final currentOverrides =
          user.nutritionTargetOverrides ?? const NutritionTargetOverrides();
      final updatedOverrides = currentOverrides.copyWith(
        during: () => DuringActivityOverrides(
          carbRateGPerH: newRate,
          sodiumRateMgPerH: currentOverrides.during?.sodiumRateMgPerH,
          fluidRateMlPerH: currentOverrides.during?.fluidRateMlPerH,
        ),
      );

      // Save via settings controller
      final settingsController = ref.read(settingsControllerProvider.notifier);
      await settingsController.saveNutritionTargetOverrides(updatedOverrides);

      _logger.info(
        'Carb feedback applied',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        data: {
          'level': level.name,
          'baseRate': baseRate,
          'newRate': newRate,
          'factor': level.adjustmentFactor,
        },
      );

      _trackAnalytics('carb_feedback_applied', {
        'activity_id': activityId,
        'level': level.name,
        'adjustment_factor': level.adjustmentFactor,
        'base_rate': baseRate,
        'new_rate': newRate,
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Error applying carb feedback',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Update workout notes for a completed activity
  Future<void> updateWorkoutNotes(String? notes) async {
    final currentState = state.value;
    if (currentState == null ||
        currentState.activity == null ||
        currentState.completion == null)
      return;

    state = await AsyncValue.guard(() async {
      try {
        final user = await _authService.getCurrentUser();
        if (user == null || user.id.isEmpty) {
          throw Exception(
            'Cannot update workout notes: user not authenticated',
          );
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
  /// Auto-saves to database and invalidates activities list and calendar
  Future<void> updateScheduledDateTime(DateTime newDateTime) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    try {
      final user = await _authService.getCurrentUser();
      if (user == null || user.id.isEmpty) {
        _logger.warning('Cannot update schedule: user not authenticated');
        return;
      }

      // Update the activity with the new scheduled date/time
      final updatedActivity = currentState.activity!.copyWith(
        scheduledDateTime: newDateTime,
        updatedAt: DateTime.now(),
      );

      // Update local state immediately for UI responsiveness
      state = AsyncData(
        currentState.copyWith(
          scheduledDateTime: newDateTime,
          activity: updatedActivity,
          hasUnsavedChanges: false,
        ),
      );

      // Save to database
      await _activitiesService.updateActivity(
        deviceId: user.id,
        activity: updatedActivity,
      );

      // Invalidate activities list and calendar so they reflect the new date
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(calendarControllerProvider);

      _logger.info(
        'Schedule updated and saved',
        context: 'ACTIVITY_DETAIL_CONTROLLER',
        data: {
          'activityId': activityId,
          'newDateTime': newDateTime.toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error updating scheduled date/time',
        error: e,
        stackTrace: stackTrace,
      );
    }
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

    state = AsyncData(
      currentState.copyWith(activity: updatedActivity, hasUnsavedChanges: true),
    );
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
  Future<NutritionPlan> _enrichFoodItemsFromTemplateFoods(
    NutritionPlan plan,
  ) async {
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
        if (tf == null) return _normalizeFoodQuantity(food);

        // Derive timingCategory from template_foods DB fields
        final derivedTimingCategory = TimingCategory.fromFoodProperties(
          isLiquid: tf.isLiquid ?? false,
          productType: tf.productType ?? 'real_food',
          isElectrolyte: tf.isElectrolyte ?? false,
          carbsPerServing: tf.carbsG ?? 0,
        );

        return _normalizeFoodQuantity(
          FoodItemData(
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
            isDrink:
                food.isDrink ||
                derivedTimingCategory == TimingCategory.sipThroughout ||
                derivedTimingCategory == TimingCategory.fuelDrink,
            templateId: food.templateId,
            scaleMultiplier: food.scaleMultiplier,
            timingCategory: food.timingCategory ?? derivedTimingCategory,
            isIndivisible: food.isIndivisible,
          ),
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
  bool _categoryMatchesSection(
    String category,
    String sectionId,
    String sectionTitle,
  ) {
    final categoryLower = category.toLowerCase();
    final sectionIdLower = sectionId.toLowerCase();
    final titleLower = sectionTitle.toLowerCase();

    // Direct section ID match (e.g., category='during_run', sectionId='during_run')
    if (sectionIdLower == categoryLower) return true;

    // Handle transition category (brick-specific)
    if (categoryLower == 'transition') {
      return sectionIdLower.startsWith('t') &&
          sectionIdLower.length <= 2; // T1, T2
    }

    // Handle sport-specific during categories (brick workouts)
    if (categoryLower.startsWith('during_')) {
      final sportSuffix = categoryLower.replaceFirst('during_', '');

      // Must be a during section
      if (!sectionIdLower.contains('during') &&
          !titleLower.startsWith('during')) {
        return false;
      }

      // Match sport from title
      if (sportSuffix == 'swim' || sportSuffix == 'swimming') {
        return titleLower.contains('swim');
      }
      if (sportSuffix == 'cycling' ||
          sportSuffix == 'bike' ||
          sportSuffix == 'ride') {
        return titleLower.contains('bike') ||
            titleLower.contains('cycle') ||
            titleLower.contains('ride');
      }
      if (sportSuffix == 'run' || sportSuffix == 'running') {
        // For 'during_run', match any during section that contains 'run' OR
        // any during section that doesn't contain swim/bike/cycle (backward compat)
        return titleLower.contains('run') ||
            (!titleLower.contains('swim') &&
                !titleLower.contains('bike') &&
                !titleLower.contains('cycle'));
      }
    }

    // Extract phase prefix (e.g., 'before' from 'before_run')
    final phasePrefix = categoryLower.split('_').first;

    // Flexible prefix matching for before/after
    if (phasePrefix == 'before') {
      return sectionIdLower.contains('before') ||
          titleLower.startsWith('before');
    }
    if (phasePrefix == 'after') {
      return sectionIdLower.contains('after') || titleLower.startsWith('after');
    }
    if (phasePrefix == 'during') {
      return sectionIdLower.contains('during') ||
          titleLower.startsWith('during');
    }

    return false;
  }

  /// Create a FoodItemData from a food object with optional custom amount
  FoodItemData _createFoodItemData(dynamic food, {double? customAmount}) {
    final multiplier = customAmount ?? food.servingAmount ?? 1.0;

    // Derive timing category from product type for proper by-hour placement
    final String productType = (food.productTypeId as String?) ?? 'real_food';
    final isLiquid = _isLikelyLiquidFood(food, productType);
    final isElectrolyte = _isLikelyElectrolyteFood(food, productType);
    final timingCategory = TimingCategory.fromFoodProperties(
      isLiquid: isLiquid,
      productType: productType,
      isElectrolyte: isElectrolyte,
      carbsPerServing: (food.carbsPerServing as num?)?.toDouble() ?? 0,
    );
    final isDrink =
        timingCategory == TimingCategory.sipThroughout ||
        timingCategory == TimingCategory.fuelDrink;

    return _normalizeFoodQuantity(
      FoodItemData(
        id: const Uuid().v4(),
        name: food.name,
        quantity: food.generateQuantityDisplay(customAmount: customAmount),
        imageAddress: food.imageAddress,
        description: food.description,
        instructions: food.instructions,
        displayName: food.displayName,
        displayNamePlural: food.displayNamePlural,
        isIndivisible: isElectrolyte || productType == 'supplement',
        isDrink: isDrink,
        timingCategory: timingCategory,
        nutritionalInfo: NutritionalInfo(
          calories: ((food.caloriesPerServing ?? 0) * multiplier).toInt(),
          carbs: ((food.carbsPerServing ?? 0) * multiplier).toInt(),
          protein: ((food.proteinPerServing ?? 0) * multiplier).toInt(),
          fat: ((food.fatPerServing ?? 0) * multiplier).toInt(),
          sodium: ((food.sodiumMg ?? 0) * multiplier).toInt(),
          fluids: ((food.fluidMlPerServing ?? 0) * multiplier),
        ),
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
    required List<FoodItemData> Function(List<FoodItemData> currentItems)
    transform,
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
            final activityType =
                currentState.activity?.activityType ?? ActivityType.running;
            updatedByHour = service.reapportion(
              existing: updatedByHour,
              currentFoodItems: updatedItems,
              targetHourIndex: _pendingAddFoodHourIndex,
              gutTraining: _cachedGutTraining,
              activityType: activityType,
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
      state = AsyncData(
        currentState.copyWith(
          nutritionPlan: updatedPlan,
          hasUnsavedChanges: false,
        ),
      );

      // Auto-save to prevent data loss on provider rebuild (e.g., navigation)
      final activity = currentState.activity;
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
        _logger.info(
          '$operationName: Auto-saved nutrition plan to prevent data loss',
        );
      }

      _logger.info(
        '$operationName SUCCESS',
        context: 'ActivityDetailController',
        data: {'category': category, 'updatedPlanId': updatedPlan.id},
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Error in $operationName',
        error: error,
        stackTrace: stackTrace,
      );
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Swap a food item in the nutrition plan
  Future<void> swapFoodItem(
    String oldFoodId,
    dynamic newFood,
    String category, {
    double? customAmount,
  }) async {
    _logger.info(
      'swapFoodItem ENTRY',
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
  Future<void> addFoodItem(
    dynamic food,
    String category, {
    double? customAmount,
  }) async {
    _logger.info(
      'addFoodItem ENTRY',
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
      transform: (items) => [
        ...items,
        _createFoodItemData(food, customAmount: customAmount),
      ],
    );
  }

  /// Delete a food item from the nutrition plan
  Future<void> deleteFoodItem(String foodId, String category) async {
    _logger.info(
      'deleteFoodItem ENTRY',
      context: 'ActivityDetailController',
      data: {'foodId': foodId, 'category': category},
    );

    await _updateSectionFoods(
      category: category,
      operationName: 'deleteFoodItem',
      transform: (items) => items.where((item) => item.id != foodId).toList(),
    );
  }

  /// Update the quantity of an existing food item
  Future<void> updateFoodQuantity(
    String foodId,
    String category,
    double newQuantity,
  ) async {
    _logger.info(
      'updateFoodQuantity ENTRY',
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
          final currentQuantity = _parseLeadingQuantity(item.quantity) ?? 1.0;
          final normalizedQty = _roundFriendlyQuantity(
            newQuantity,
            isIndivisible: item.isIndivisible,
          );
          final scaleFactor = currentQuantity > 0
              ? normalizedQty / currentQuantity
              : 1.0;
          final newQuantityDisplay = _buildQuantityLabel(item, normalizedQty);

          final currentNutrition = item.nutritionalInfo;
          final scaledNutrition = currentNutrition != null
              ? NutritionalInfo(
                  calories: currentNutrition.calories != null
                      ? (currentNutrition.calories! * scaleFactor).round()
                      : null,
                  carbs: currentNutrition.carbs != null
                      ? (currentNutrition.carbs! * scaleFactor).round()
                      : null,
                  protein: currentNutrition.protein != null
                      ? (currentNutrition.protein! * scaleFactor).round()
                      : null,
                  fat: currentNutrition.fat != null
                      ? (currentNutrition.fat! * scaleFactor).round()
                      : null,
                  sodium: currentNutrition.sodium != null
                      ? (currentNutrition.sodium! * scaleFactor).round()
                      : null,
                  fluids: currentNutrition.fluids != null
                      ? currentNutrition.fluids! * scaleFactor
                      : null,
                )
              : null;

          return FoodItemData(
            id: item.id,
            name: item.name,
            quantity: newQuantityDisplay,
            imageAddress: item.imageAddress,
            instructions: item.instructions,
            description: item.description,
            displayName: item.displayName,
            displayNamePlural: item.displayNamePlural,
            displayOverride: item.displayOverride,
            servingSize: item.servingSize,
            isDrink: item.isDrink,
            isIndivisible: item.isIndivisible,
            templateId: item.templateId,
            scaleMultiplier: item.scaleMultiplier,
            timingCategory: item.timingCategory,
            nutritionalInfo: scaledNutrition,
          );
        }
        return item;
      }).toList(),
    );
  }

  bool _isLikelyLiquidFood(dynamic food, String productType) {
    final normalizedType = productType.toLowerCase();
    if (normalizedType == 'sports_drink' || normalizedType == 'beverage') {
      return true;
    }

    final fluidMl = (food.fluidMlPerServing as num?)?.toDouble() ?? 0;
    if (fluidMl > 0) return true;

    final searchable = [
      food.name,
      food.displayName,
      food.description,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains('drink') ||
        searchable.contains('water') ||
        searchable.contains('juice') ||
        searchable.contains('smoothie') ||
        searchable.contains('shake');
  }

  bool _isLikelyElectrolyteFood(dynamic food, String productType) {
    if (productType.toLowerCase() == 'supplement') return true;
    final searchable = [
      food.name,
      food.displayName,
      food.description,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains('electrolyte') ||
        searchable.contains('liquid iv') ||
        searchable.contains('salt') ||
        searchable.contains('sodium') ||
        searchable.contains('pickle juice');
  }

  double? _parseLeadingQuantity(String rawQuantity) {
    final match = RegExp(r'^([\d.]+)').firstMatch(rawQuantity.trim());
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  String _formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    if ((value * 10 - (value * 10).round()).abs() < 0.01) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  String _stripParenthetical(String value) {
    return value.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  double _roundFriendlyQuantity(double value, {required bool isIndivisible}) {
    if (value <= 0) return isIndivisible ? 1.0 : 0.5;
    if (isIndivisible) return value.round().toDouble();

    final half = (value * 2).round() / 2;
    final third = (value * 3).round() / 3;
    final halfDiff = (value - half).abs();
    final thirdDiff = (value - third).abs();
    final rounded = thirdDiff + 0.08 < halfDiff ? third : half;
    return (rounded * 100).round() / 100;
  }

  String _buildQuantityLabel(FoodItemData item, double quantity) {
    final qtyStr = _formatQuantity(quantity);
    final existingTailMatch = RegExp(
      r'^[\d.]+\s*(.*)$',
    ).firstMatch(item.quantity.trim());
    final existingTail = existingTailMatch?.group(1)?.trim();

    String label;
    if (quantity != 1 && item.displayNamePlural?.isNotEmpty == true) {
      label = _stripParenthetical(item.displayNamePlural!);
    } else if (item.displayName?.isNotEmpty == true) {
      label = _stripParenthetical(item.displayName!);
    } else if (existingTail != null && existingTail.isNotEmpty) {
      label = _stripParenthetical(existingTail);
    } else {
      label = _stripParenthetical(item.name);
    }

    if (quantity != 1 &&
        item.displayNamePlural?.isEmpty != false &&
        !label.contains(' ') &&
        !label.toLowerCase().endsWith('s')) {
      label = '${label}s';
    }

    return '$qtyStr $label'.trim();
  }

  FoodItemData _normalizeFoodQuantity(FoodItemData food) {
    final currentQuantity = _parseLeadingQuantity(food.quantity);
    if (currentQuantity == null) return food;

    final normalizedQuantity = _roundFriendlyQuantity(
      currentQuantity,
      isIndivisible: food.isIndivisible,
    );
    if ((normalizedQuantity - currentQuantity).abs() < 0.01) return food;

    final newLabel = _buildQuantityLabel(food, normalizedQuantity);
    final scaleFactor = currentQuantity > 0
        ? normalizedQuantity / currentQuantity
        : 1.0;
    final info = food.nutritionalInfo;

    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: newLabel,
      imageAddress: food.imageAddress,
      description: food.description,
      timing: food.timing,
      nutritionalInfo: info != null
          ? NutritionalInfo(
              calories: info.calories != null
                  ? (info.calories! * scaleFactor).round()
                  : null,
              carbs: info.carbs != null
                  ? (info.carbs! * scaleFactor).round()
                  : null,
              protein: info.protein != null
                  ? (info.protein! * scaleFactor).round()
                  : null,
              fat: info.fat != null ? (info.fat! * scaleFactor).round() : null,
              sodium: info.sodium != null
                  ? (info.sodium! * scaleFactor).round()
                  : null,
              fluids: info.fluids != null ? info.fluids! * scaleFactor : null,
            )
          : null,
      instructions: food.instructions,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      displayOverride: food.displayOverride,
      servingSize: food.servingSize,
      isDrink: food.isDrink,
      isIndivisible: food.isIndivisible,
      templateId: food.templateId,
      scaleMultiplier: food.scaleMultiplier,
      timingCategory: food.timingCategory,
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
      _logger.warning(
        'Cannot updateSubPhaseQuantityWithScaling: no nutrition plan',
      );
      return;
    }

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      final updatedSections = currentPlan.sections.map((section) {
        if (_categoryMatchesSection('before_run', section.id, section.title) &&
            section.hasSubPhases) {
          final updatedSubPhases = section.subPhases!.asMap().entries.map((
            entry,
          ) {
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

      state = AsyncData(
        currentState.copyWith(
          nutritionPlan: updatedPlan,
          hasUnsavedChanges: false,
        ),
      );

      // Auto-save
      final activity = currentState.activity;
      if (activity != null) {
        await _saveNutritionPlanToActivity(activity.id, updatedPlan);
        _logger.info(
          'updateSubPhaseQuantityWithScaling: Auto-saved nutrition plan',
        );
      }

      _logger.info(
        'updateSubPhaseQuantityWithScaling SUCCESS',
        context: 'ActivityDetailController',
        data: {
          'subPhaseIndex': subPhaseIndex,
          'foodIndex': foodIndex,
          'newQuantity': newQuantity,
        },
      );
    } catch (error, stackTrace) {
      _logger.error(
        'Error in updateSubPhaseQuantityWithScaling',
        error: error,
        stackTrace: stackTrace,
      );
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
  Future<void> initializeByHourData(
    String category,
    int durationMinutes,
  ) async {
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
    final activityType =
        currentState.activity?.activityType ?? ActivityType.running;
    final byHourData = service.apportion(
      foodItems: targetSection.foodItems,
      durationMinutes: durationMinutes,
      gutTraining: _cachedGutTraining,
      activityType: activityType,
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

    _logger.info(
      'initializeByHourData SUCCESS',
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
    TimeSlot sourceTimeSlot,
    TimeSlot newTimeSlot,
  ) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    final updatedSections = currentPlan.sections.map((section) {
      if (_categoryMatchesSection(category, section.id, section.title) &&
          section.byHourData != null) {
        var moved = false;
        final updatedAssignments = section.byHourData!.assignments.map((a) {
          if (!moved &&
              a.foodItemId == foodId &&
              a.timeSlot == sourceTimeSlot) {
            moved = true;
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
      final updatedActivity = await nutritionService
          .regenerateForScheduleChange(activity);

      // Refresh controller data from database
      ref.invalidateSelf();

      // Fire-and-forget write-back to TrainingPeaks (never blocks regeneration)
      final planData = updatedActivity.nutritionPlanData;
      if (planData != null) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          final plan = NutritionPlan.fromJson(planData);
          unawaited(_pushToTrainingPeaks(user.id, updatedActivity, plan));
        }
      }

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

  /// Fire-and-forget push of nutrition plan summary to TrainingPeaks.
  /// Catches all errors — write-back must never block plan save.
  Future<void> _pushToTrainingPeaks(
    String userId,
    Activity activity,
    NutritionPlan plan,
  ) async {
    try {
      final service = await ref.read(tpWritebackServiceProvider.future);
      await service.pushPlanToWorkout(
        userId: userId,
        activity: activity,
        plan: plan,
      );
    } catch (e) {
      DebugLogger.error('TP write-back failed (non-blocking): $e');
    }
  }
}
