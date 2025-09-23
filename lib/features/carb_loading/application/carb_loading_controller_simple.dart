import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../features/content/application/content_service.dart';
import '../../../features/auth/data/user_repository.dart';
import '../data/carb_loading_repository_simple.dart';
import '../domain/carb_loading_plan_simple.dart';
import '../domain/carb_foods_list.dart';
import 'carb_loading_edge_service.dart';

part 'carb_loading_controller_simple.g.dart';

/// State for simplified carb loading feature
class CarbLoadingState {
  final CarbLoadingPlan? plan;
  final int selectedDay;
  final String selectedMeal;
  final bool isLoading;
  final String? errorMessage;

  const CarbLoadingState({
    this.plan,
    this.selectedDay = -1,
    this.selectedMeal = 'breakfast',
    this.isLoading = false,
    this.errorMessage,
  });

  CarbLoadingState copyWith({
    CarbLoadingPlan? plan,
    int? selectedDay,
    String? selectedMeal,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CarbLoadingState(
      plan: plan ?? this.plan,
      selectedDay: selectedDay ?? this.selectedDay,
      selectedMeal: selectedMeal ?? this.selectedMeal,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Get current day food selections
  DayFoodSelections? get currentDaySelections {
    return plan?.daySelections[selectedDay];
  }

  /// Get current meal foods
  MealFoods? get currentMeal {
    return currentDaySelections?.meals[selectedMeal];
  }

  /// Get total carbs for current day
  int get currentDayCarbs {
    return currentDaySelections?.totalCarbs ?? 0;
  }

  /// Get total calories for current day
  int get currentDayCalories {
    return currentDaySelections?.totalCalories ?? 0;
  }

  /// Get progress towards daily carb target (0.0 to 1.0+)
  double get carbProgress {
    final target = plan?.dailyCarbTargetG ?? 1;
    return currentDayCarbs / target;
  }
}

/// Repository provider for simplified carb loading
@riverpod
Future<CarbLoadingRepositorySimple> carbLoadingRepositorySimple(Ref ref) async {
  final database = await ref.watch(databaseProvider.future);
  return CarbLoadingRepositorySimple(database: database);
}

/// Simplified carb loading controller following FOA patterns
@riverpod
class CarbLoadingControllerSimple extends _$CarbLoadingControllerSimple {
  // Access services via ref.read()
  Future<CarbLoadingRepositorySimple> get _repository => ref.read(carbLoadingRepositorySimpleProvider.future);
  ContentService get _contentService => ref.read(contentServiceProvider);
  Future<UserRepository> get _userRepository => ref.read(userRepositoryProvider.future);
  CarbLoadingEdgeService get _edgeService => ref.read(carbLoadingEdgeServiceProvider);
  LoggingService get _logger => AppLogger.instance;

  @override
  FutureOr<CarbLoadingState> build() async {
    try {
      // Get current user to check for existing plan
      final userRepository = await _userRepository;
      final user = await userRepository.getCurrentUser();
      if (user == null) {
        return const CarbLoadingState(errorMessage: 'No user found');
      }

      // Try to load existing plan
      final repository = await _repository;
      final existingPlan = await repository.getCurrentPlan(user.id);

      if (existingPlan != null) {
        _logger.info('Loaded existing carb loading plan',
          context: 'CARB_LOADING_CONTROLLER',
          data: {
            'plan_id': existingPlan.id,
            'race_date': existingPlan.raceDate.toIso8601String(),
            'daily_target': existingPlan.dailyCarbTargetG,
          }
        );

        return CarbLoadingState(plan: existingPlan);
      }

      // No existing plan - will need to create one
      return const CarbLoadingState();
    } catch (e) {
      _logger.error('Failed to initialize carb loading controller',
        context: 'CARB_LOADING_CONTROLLER',
        error: e
      );
      return CarbLoadingState(errorMessage: e.toString());
    }
  }

  /// Create a new carb loading plan
  Future<void> createPlan({
    required DateTime raceDate,
    required RaceDistance raceDistance,
    required TrainingVolume trainingVolume,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final user = await userRepository.getCurrentUser();
      if (user == null) {
        throw Exception('No user found');
      }

      // Convert user weight from pounds to kg
      final bodyWeightKg = user.weightPounds * 0.453592;

      // Try to get enhanced targets from edge function
      Map<String, dynamic>? enhancedData;
      try {
        enhancedData = await _edgeService.getEnhancedCarbTargets(
          raceDate: raceDate,
          raceDistance: raceDistance,
          trainingVolume: trainingVolume,
          bodyWeightPounds: user.weightPounds,
          userId: user.id,
        );

        _logger.info('Enhanced carb targets received from edge function',
          context: 'CARB_LOADING_CONTROLLER',
          data: {
            'target_carbs_per_kg': enhancedData['targetCarbsGPerKg'],
            'day_minus_two_carbs': enhancedData['dayMinusTwo']?['totalCarbsG'],
            'day_minus_one_carbs': enhancedData['dayMinusOne']?['totalCarbsG'],
          }
        );
      } catch (e) {
        _logger.warning('Edge function failed, using local calculations',
          context: 'CARB_LOADING_CONTROLLER',
          error: e
        );
      }

      // Create default plan using Featherstone methodology
      // Enhanced data will be used if available, otherwise falls back to local calculation
      final plan = CarbLoadingPlan.createDefault(
        userId: user.id,
        raceDate: raceDate,
        raceDistance: raceDistance,
        trainingVolume: trainingVolume,
        bodyWeightKg: bodyWeightKg,
      );

      // Save to repository
      final repository = await _repository;
      await repository.savePlan(plan);

      _logger.info('Created new carb loading plan',
        context: 'CARB_LOADING_CONTROLLER',
        data: {
          'plan_id': plan.id,
          'race_date': raceDate.toIso8601String(),
          'race_distance': raceDistance.value,
          'daily_target': plan.dailyCarbTargetG,
          'body_weight_kg': bodyWeightKg,
        }
      );

      return CarbLoadingState(plan: plan);
    });
  }

  /// Select a day (-2, -1, 0)
  Future<void> selectDay(int day) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(selectedDay: day));

    _logger.debug('Selected carb loading day',
      context: 'CARB_LOADING_CONTROLLER',
      data: {'day': day}
    );
  }

  /// Select a meal (breakfast, lunch, etc.)
  Future<void> selectMeal(String meal) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(selectedMeal: meal));

    _logger.debug('Selected meal',
      context: 'CARB_LOADING_CONTROLLER',
      data: {'meal': meal}
    );
  }

  /// Add food to current meal
  Future<void> addFood(String foodName) async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = AsyncValue.data(currentState!.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      final repository = await _repository;
      await repository.addFoodToMeal(
        currentState.plan!.id,
        currentState.selectedDay,
        currentState.selectedMeal,
        foodName,
      );

      // Reload the plan to get updated data
      final updatedPlan = await repository.getPlanById(currentState.plan!.id);
      if (updatedPlan == null) {
        throw Exception('Plan not found after update');
      }

      _logger.info('Added food to meal',
        context: 'CARB_LOADING_CONTROLLER',
        data: {
          'food': foodName,
          'day': currentState.selectedDay,
          'meal': currentState.selectedMeal,
        }
      );

      return currentState.copyWith(
        plan: updatedPlan,
        isLoading: false,
      );
    });
  }

  /// Remove food from current meal
  Future<void> removeFood(String foodName) async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = AsyncValue.data(currentState!.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      final repository = await _repository;
      await repository.removeFoodFromMeal(
        currentState.plan!.id,
        currentState.selectedDay,
        currentState.selectedMeal,
        foodName,
      );

      // Reload the plan to get updated data
      final updatedPlan = await repository.getPlanById(currentState.plan!.id);
      if (updatedPlan == null) {
        throw Exception('Plan not found after update');
      }

      _logger.info('Removed food from meal',
        context: 'CARB_LOADING_CONTROLLER',
        data: {
          'food': foodName,
          'day': currentState.selectedDay,
          'meal': currentState.selectedMeal,
        }
      );

      return currentState.copyWith(
        plan: updatedPlan,
        isLoading: false,
      );
    });
  }

  /// Update food quantity in current meal
  Future<void> updateFoodQuantity(String foodName, int quantity) async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = AsyncValue.data(currentState!.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      final repository = await _repository;
      await repository.updateFoodQuantity(
        currentState.plan!.id,
        currentState.selectedDay,
        currentState.selectedMeal,
        foodName,
        quantity,
      );

      // Reload the plan to get updated data
      final updatedPlan = await repository.getPlanById(currentState.plan!.id);
      if (updatedPlan == null) {
        throw Exception('Plan not found after update');
      }

      _logger.info('Updated food quantity',
        context: 'CARB_LOADING_CONTROLLER',
        data: {
          'food': foodName,
          'quantity': quantity,
          'day': currentState.selectedDay,
          'meal': currentState.selectedMeal,
        }
      );

      return currentState.copyWith(
        plan: updatedPlan,
        isLoading: false,
      );
    });
  }

  /// Get available foods for quick add
  List<CarbFood> get quickAddFoods => CarbFoodsList.quickAddFoods;

  /// Get all available carb foods
  List<CarbFood> get allFoods => CarbFoodsList.foods;

  /// Get content text for UI
  String getContentText(String key, {String? defaultValue}) {
    return _contentService.getValue('carb_loading.$key', defaultValue: defaultValue);
  }

  /// Get day label for UI
  String getDayLabel(int day) {
    switch (day) {
      case -2:
        return getContentText('day_begin');
      case -1:
        return getContentText('day_peak');
      case 0:
        return getContentText('day_fuel');
      default:
        return 'Day $day';
    }
  }

  /// Get meal label for UI
  String getMealLabel(String meal) {
    return getContentText('meal_$meal');
  }

  /// Update existing plan with new race information
  Future<void> updatePlan({
    required DateTime raceDate,
    required RaceDistance raceDistance,
    required TrainingVolume trainingVolume,
  }) async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final user = await userRepository.getCurrentUser();
      if (user == null) {
        throw Exception('No user found');
      }

      // Convert user weight from pounds to kg
      final bodyWeightKg = user.weightPounds * 0.453592;

      // Try to get enhanced targets from edge function
      Map<String, dynamic>? enhancedData;
      try {
        enhancedData = await _edgeService.getEnhancedCarbTargets(
          raceDate: raceDate,
          raceDistance: raceDistance,
          trainingVolume: trainingVolume,
          bodyWeightPounds: user.weightPounds,
          userId: user.id,
        );

        _logger.info('Enhanced carb targets received from edge function during update',
          context: 'CARB_LOADING_CONTROLLER',
          data: enhancedData,
        );
      } catch (e) {
        _logger.warning('Edge function failed during update, using fallback calculation',
          context: 'CARB_LOADING_CONTROLLER',
          error: e.toString(),
        );
      }

      // Use enhanced data if available, otherwise fallback to local calculation
      final double carbsPerKg;
      final int dailyCarbTargetG;

      if (enhancedData != null && enhancedData['dailyCarbTargetG'] != null) {
        carbsPerKg = (enhancedData['dailyCarbTargetG'] as num) / bodyWeightKg;
        dailyCarbTargetG = enhancedData['dailyCarbTargetG'] as int;
      } else {
        // Fallback calculation
        final baseCarbs = 8.0;
        final raceMultiplier = CarbLoadingPlan.getRaceDistanceMultiplier(raceDistance);
        final volumeMultiplier = CarbLoadingPlan.getTrainingVolumeMultiplier(trainingVolume);
        carbsPerKg = baseCarbs * raceMultiplier * volumeMultiplier;
        dailyCarbTargetG = (bodyWeightKg * carbsPerKg).round();
      }

      // Update plan with new race information
      final updatedPlan = currentState!.plan!.copyWith(
        raceDate: raceDate,
        raceDistance: raceDistance,
        trainingVolume: trainingVolume,
        dailyCarbTargetG: dailyCarbTargetG,
        dailyServingsTarget: (dailyCarbTargetG / 50).round(),
        bodyWeightKg: bodyWeightKg,
        carbsPerKgTarget: carbsPerKg,
        updatedAt: DateTime.now(),
      );

      // Save to repository
      final repository = await _repository;
      await repository.savePlan(updatedPlan);

      _logger.info('Updated carb loading plan',
        context: 'CARB_LOADING_CONTROLLER',
        data: {
          'plan_id': updatedPlan.id,
          'race_date': raceDate.toIso8601String(),
          'race_distance': raceDistance.value,
          'daily_target': updatedPlan.dailyCarbTargetG,
        }
      );

      return currentState.copyWith(plan: updatedPlan);
    });
  }

  /// Duplicate current plan with reset progress
  Future<void> duplicatePlan() async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final userRepository = await _userRepository;
      final user = await userRepository.getCurrentUser();
      if (user == null) {
        throw Exception('No user found');
      }

      // Create new plan with same settings but reset progress
      final newPlan = CarbLoadingPlan.createDefault(
        userId: user.id,
        raceDate: currentState!.plan!.raceDate,
        raceDistance: currentState.plan!.raceDistance,
        trainingVolume: currentState.plan!.trainingVolume,
        bodyWeightKg: currentState.plan!.bodyWeightKg,
      );

      // Save to repository
      final repository = await _repository;
      await repository.savePlan(newPlan);

      _logger.info('Duplicated carb loading plan',
        context: 'CARB_LOADING_CONTROLLER',
        data: {
          'original_plan_id': currentState.plan!.id,
          'new_plan_id': newPlan.id,
        }
      );

      return currentState.copyWith(plan: newPlan);
    });
  }

  /// Reset all food selections but keep plan settings
  Future<void> resetProgress() async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      // Reset all day selections to empty
      final resetPlan = currentState!.plan!.copyWith(
        daySelections: {
          -2: DayFoodSelections.empty(),
          -1: DayFoodSelections.empty(),
          0: DayFoodSelections.empty(),
        },
        updatedAt: DateTime.now(),
      );

      // Save to repository
      final repository = await _repository;
      await repository.savePlan(resetPlan);

      _logger.info('Reset carb loading plan progress',
        context: 'CARB_LOADING_CONTROLLER',
        data: {'plan_id': resetPlan.id}
      );

      return currentState.copyWith(plan: resetPlan);
    });
  }

  /// Delete current plan
  Future<void> deletePlan() async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final repository = await _repository;
      await repository.deletePlan(currentState!.plan!.id);

      _logger.info('Deleted carb loading plan',
        context: 'CARB_LOADING_CONTROLLER',
        data: {'plan_id': currentState.plan!.id}
      );

      return const CarbLoadingState();
    });
  }

  /// Refresh current plan
  Future<void> refresh() async {
    final currentState = state.valueOrNull;
    if (currentState?.plan == null) return;

    state = await AsyncValue.guard(() async {
      final repository = await _repository;
      final updatedPlan = await repository.getPlanById(currentState!.plan!.id);
      if (updatedPlan == null) {
        throw Exception('Plan not found');
      }

      return currentState.copyWith(plan: updatedPlan);
    });
  }
}