import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../../shared/database/database_provider.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'food_preferences_controller.g.dart';

/// State for the food preferences screen
class FoodPreferencesState {
  final List<FoodItem> primaryFoods;
  final List<FoodItem> additionalFoods;
  final List<FoodItem> userFoods;

  const FoodPreferencesState({
    required this.primaryFoods,
    required this.additionalFoods,
    required this.userFoods,
  });

  FoodPreferencesState copyWith({
    List<FoodItem>? primaryFoods,
    List<FoodItem>? additionalFoods,
    List<FoodItem>? userFoods,
  }) {
    return FoodPreferencesState(
      primaryFoods: primaryFoods ?? this.primaryFoods,
      additionalFoods: additionalFoods ?? this.additionalFoods,
      userFoods: userFoods ?? this.userFoods,
    );
  }
}

/// Controller for food preferences screen - follows Andrea Bizzotto's AsyncNotifier pattern
@riverpod
class FoodPreferencesController extends _$FoodPreferencesController {
  // Access repositories via ref
  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);

  @override
  FutureOr<FoodPreferencesState> build() async {
    DebugLogger.info('[FOOD_PREFS_CTRL] 🎬 Initializing food preferences controller...');
    return await _loadFoodPreferences();
  }

  /// Load all food preferences with timeout protection and comprehensive logging
  Future<FoodPreferencesState> _loadFoodPreferences() async {
    DebugLogger.info('[FOOD_PREFS_CTRL] 🔄 Starting food preferences load...');

    final database = ref.read(appDatabaseProvider);

    // Get current user's device ID
    DebugLogger.info('[FOOD_PREFS_CTRL] 📦 Fetching user profile...');
    final userProfile = await database.getCurrentUserProfile();
    final deviceId = userProfile?.id ?? 'unknown';
    DebugLogger.info('[FOOD_PREFS_CTRL] ✅ User profile loaded: deviceId=$deviceId');

    try {
      // Load primary foods, additional foods, and user foods in parallel with timeout
      DebugLogger.info('[FOOD_PREFS_CTRL] 📦 Starting parallel fetch of all food data...');

      final results = await Future.wait([
        _loadPrimaryFoods(),
        _loadAdditionalFoods(),
        _loadUserFoods(deviceId),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          DebugLogger.error('[FOOD_PREFS_CTRL] ⏱️ Future.wait timed out after 15 seconds');
          throw TimeoutException('Failed to load food data - operation timed out after 15 seconds');
        },
      );

      final primaryFoods = results[0] as List<FoodItem>;
      final additionalFoods = results[1] as List<FoodItem>;
      final userFoods = results[2] as List<FoodItem>;

      DebugLogger.info('[FOOD_PREFS_CTRL] ✅ All food data loaded successfully');
      DebugLogger.info('[FOOD_PREFS_CTRL] 📊 Primary: ${primaryFoods.length}, Additional: ${additionalFoods.length}, User: ${userFoods.length}');

      return FoodPreferencesState(
        primaryFoods: primaryFoods,
        additionalFoods: additionalFoods,
        userFoods: userFoods,
      );
    } catch (e, stackTrace) {
      DebugLogger.error('[FOOD_PREFS_CTRL] ❌ Error loading food preferences: $e');
      DebugLogger.error('[FOOD_PREFS_CTRL] 📚 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Load primary foods with individual logging
  Future<List<FoodItem>> _loadPrimaryFoods() async {
    DebugLogger.info('[FOOD_PREFS_CTRL] 📦 Fetching primary foods...');
    try {
      final foods = await _foodRepository.getPrimaryFoodsForPreferences();
      DebugLogger.info('[FOOD_PREFS_CTRL] ✅ Primary foods loaded: ${foods.length} items');
      return foods;
    } catch (e) {
      DebugLogger.error('[FOOD_PREFS_CTRL] ❌ Failed to load primary foods: $e');
      rethrow;
    }
  }

  /// Load additional foods with individual logging
  Future<List<FoodItem>> _loadAdditionalFoods() async {
    DebugLogger.info('[FOOD_PREFS_CTRL] 📦 Fetching additional foods...');
    try {
      final foods = await _foodRepository.getAdditionalFoodsForPreferences();
      DebugLogger.info('[FOOD_PREFS_CTRL] ✅ Additional foods loaded: ${foods.length} items');
      return foods;
    } catch (e) {
      DebugLogger.error('[FOOD_PREFS_CTRL] ❌ Failed to load additional foods: $e');
      rethrow;
    }
  }

  /// Load user foods with individual logging
  Future<List<FoodItem>> _loadUserFoods(String deviceId) async {
    DebugLogger.info('[FOOD_PREFS_CTRL] 📦 Fetching user foods for deviceId=$deviceId...');
    try {
      final database = ref.read(appDatabaseProvider);
      final userFoodsData = await database.getUserFoods(deviceId);

      // Convert user foods to FoodItems
      final userFoods = userFoodsData
          .map((userFood) => database.convertUserFoodToFoodItem(userFood))
          .cast<FoodItem>()
          .toList();

      DebugLogger.info('[FOOD_PREFS_CTRL] ✅ User foods loaded: ${userFoods.length} items');
      return userFoods;
    } catch (e) {
      DebugLogger.error('[FOOD_PREFS_CTRL] ❌ Failed to load user foods: $e');
      rethrow;
    }
  }

  /// Refresh food preferences (called after adding/deleting user foods)
  Future<void> refresh() async {
    DebugLogger.info('[FOOD_PREFS_CTRL] 🔄 Refreshing food preferences...');
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      return await _loadFoodPreferences();
    });
  }

  /// Add a user food and refresh the list
  Future<void> addUserFood(FoodItem food) async {
    DebugLogger.info('[FOOD_PREFS_CTRL] ➕ Adding user food: ${food.name}');

    // The actual save logic is handled in the screen for now (due to category sheet)
    // Just refresh the list after save
    await refresh();
  }

  /// Remove a user food and refresh the list
  Future<void> removeUserFood(FoodItem food) async {
    DebugLogger.info('[FOOD_PREFS_CTRL] ➖ Removing user food: ${food.name}');

    // The actual delete logic is handled in the screen for now
    // Just refresh the list after delete
    await refresh();
  }
}
