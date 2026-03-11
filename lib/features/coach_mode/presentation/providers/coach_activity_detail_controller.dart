import 'dart:async';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/nutrition_plan_mapper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../activities/data/activities_repository.dart';
import '../../../activities/domain/activity.dart';
import '../../../activities/domain/activity_completion.dart';

part 'coach_activity_detail_controller.g.dart';

class CoachActivityDetailState {
  const CoachActivityDetailState({
    this.activity,
    this.nutritionPlan,
    this.completion,
    this.scheduledDateTime,
    this.isSaving = false,
    this.isCompleting = false,
    this.hasUnsavedChanges = false,
    this.error,
  });

  final Activity? activity;
  final NutritionPlan? nutritionPlan;
  final ActivityCompletion? completion;
  final DateTime? scheduledDateTime;
  final bool isSaving;
  final bool isCompleting;
  final bool hasUnsavedChanges;
  final String? error;

  bool get hasActivity => activity != null;
  bool get isCompleted => completion != null;

  CoachActivityDetailState copyWith({
    Activity? activity,
    NutritionPlan? nutritionPlan,
    ActivityCompletion? completion,
    DateTime? scheduledDateTime,
    bool? isSaving,
    bool? isCompleting,
    bool? hasUnsavedChanges,
    String? error,
  }) {
    return CoachActivityDetailState(
      activity: activity ?? this.activity,
      nutritionPlan: nutritionPlan ?? this.nutritionPlan,
      completion: completion ?? this.completion,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      isSaving: isSaving ?? this.isSaving,
      isCompleting: isCompleting ?? this.isCompleting,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      error: error ?? this.error,
    );
  }
}

/// Controller for the coach view of an activity
@riverpod
class CoachActivityDetailController extends _$CoachActivityDetailController {
  @override
  FutureOr<CoachActivityDetailState> build(String activityId) async {
    return _loadActivity(activityId);
  }

  Future<CoachActivityDetailState> _loadActivity(String activityId) async {
    final repository = ref.read(activitiesRepositoryProvider);
    final activity = await repository.getRemoteActivityById(activityId);

    if (activity == null) {
      throw Exception('Activity not found');
    }

    NutritionPlan? plan;
    if (activity.nutritionPlanData != null) {
      plan = NutritionPlanMapper.fromJson(activity.nutritionPlanData!);
    }

    ActivityCompletion? completion;
    if (activity.status == ActivityStatus.completed && activity.completedAt != null) {
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

    return CoachActivityDetailState(
      activity: activity,
      nutritionPlan: plan,
      completion: completion,
      scheduledDateTime: activity.scheduledDateTime,
    );
  }

  Future<void> saveActivity() async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = AsyncData(currentState.copyWith(isSaving: true));

    state = await AsyncValue.guard(() async {
      final activity = currentState.activity!;
      final repository = ref.read(activitiesRepositoryProvider);

      final updatedActivity = activity.copyWith(
        scheduledDateTime: currentState.scheduledDateTime,
        nutritionPlanData: currentState.nutritionPlan?.toJson(),
      );

      await repository.updateRemoteActivity(updatedActivity);

      return currentState.copyWith(
        isSaving: false,
        activity: updatedActivity,
        hasUnsavedChanges: false,
      );
    });
  }

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

  Future<void> _updateSectionFoods({
    required String category,
    required List<FoodItemData> Function(List<FoodItemData> currentItems) transform,
    required String operationName,
  }) async {
    final currentState = state.value;
    if (currentState?.nutritionPlan == null) return;

    final currentPlan = currentState!.nutritionPlan!;

    state = AsyncData(currentState.copyWith(hasUnsavedChanges: true));

    try {
      final updatedSections = currentPlan.sections.map((section) {
        if (_categoryMatchesSection(category, section.id, section.title)) {
          final updatedItems = transform(section.foodItems);
          return section.copyWith(foodItems: updatedItems);
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

      final activity = currentState.activity;
      if (activity != null) {
         final repository = ref.read(activitiesRepositoryProvider);
         final updatedActivity = activity.copyWith(
           nutritionPlanData: updatedPlan.toJson(),
           updatedAt: DateTime.now(),
         );
         await repository.updateRemoteActivity(updatedActivity);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> swapFoodItem(String oldFoodId, dynamic newFood, String category, {double? customAmount}) async {
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

  Future<void> addFoodItem(dynamic food, String category, {double? customAmount}) async {
    await _updateSectionFoods(
      category: category,
      operationName: 'addFoodItem',
      transform: (items) => [...items, _createFoodItemData(food, customAmount: customAmount)],
    );
  }

  Future<void> deleteFoodItem(String foodId, String category) async {
    await _updateSectionFoods(
      category: category,
      operationName: 'deleteFoodItem',
      transform: (items) => items.where((item) => item.id != foodId).toList(),
    );
  }

  Future<void> updateFoodQuantity(String foodId, String category, double newQuantity) async {
    await _updateSectionFoods(
      category: category,
      operationName: 'updateFoodQuantity',
      transform: (items) => items.map((item) {
        if (item.id == foodId) {
          final currentNutrition = item.nutritionalInfo;
          if (currentNutrition != null) {
            final currentQuantityMatch = RegExp(r'^([\d.]+)').firstMatch(item.quantity);
            final currentQuantity = currentQuantityMatch != null
                ? double.tryParse(currentQuantityMatch.group(1)!) ?? 1.0
                : 1.0;

            final scaleFactor = newQuantity / currentQuantity;

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

  Future<void> completeActivity({
    required int overallSatisfaction,
    String? textNotes,
  }) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = AsyncData(currentState.copyWith(isCompleting: true));

    state = await AsyncValue.guard(() async {
      final activity = currentState.activity!;
      final repository = ref.read(activitiesRepositoryProvider);

      final completedActivity = activity.copyWith(
          status: ActivityStatus.completed,
          completedAt: DateTime.now(),
          completionRating: overallSatisfaction,
          completionNotes: textNotes,
      );

      await repository.updateRemoteActivity(completedActivity);

      return currentState.copyWith(isCompleting: false, activity: completedActivity);
    });
  }

  /// Update completion rating for a completed activity (coach view)
  Future<void> updateCompletionRating(int rating) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = await AsyncValue.guard(() async {
      final updatedActivity = currentState.activity!.copyWith(
        completionRating: rating,
      );

      final repository = ref.read(activitiesRepositoryProvider);
      await repository.updateRemoteActivity(updatedActivity);

      return currentState.copyWith(activity: updatedActivity);
    });
  }

  /// Update workout notes for a completed activity (coach view)
  Future<void> updateWorkoutNotes(String? notes) async {
    final currentState = state.value;
    if (currentState == null || currentState.activity == null) return;

    state = await AsyncValue.guard(() async {
      final updatedActivity = currentState.activity!.copyWith(
        completionNotes: notes,
      );

      final repository = ref.read(activitiesRepositoryProvider);
      await repository.updateRemoteActivity(updatedActivity);

      return currentState.copyWith(activity: updatedActivity);
    });
  }
}
