import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../food_preferences/data/food_preferences_repository.dart';

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
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<FoodPreferencesState> build() async {
    // Ensure food preferences are synced before loading
    // This follows the new sync architecture pattern
    await _ensureFoodPreferencesSynced();

    return await _loadFoodPreferences();
  }

  /// Ensure food preferences data is synced from remote
  /// Uses the new SyncCoordinator.ensureSynced pattern with dependency resolution
  Future<void> _ensureFoodPreferencesSynced() async {
    try {
      final userId = await ref.read(userIdProvider.future);
      final repository = await ref.read(
        foodPreferencesRepositoryProvider.future,
      );

      await ref
          .read(syncCoordinatorProvider.notifier)
          .ensureSynced('food_preferences', userId, repository: repository);
    } catch (e, stackTrace) {
      _logger.warning(
        'Food preferences sync failed - proceeding with cached data',
        context: 'FOOD_PREFERENCES_CONTROLLER',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - best effort sync, user sees cached data
    }
  }

  /// Load all food preferences with timeout protection
  Future<FoodPreferencesState> _loadFoodPreferences() async {
    final database = ref.read(appDatabaseProvider);
    final userProfile = await database.userDao.getCurrentUserProfile();
    final userId = userProfile?.id ?? 'unknown';

    final results =
        await Future.wait([
          _loadPrimaryFoods(),
          _loadAdditionalFoods(),
          _loadUserFoods(userId),
        ]).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException(
              'Failed to load food data - operation timed out after 15 seconds',
            );
          },
        );

    final primaryFoods = results[0];
    final additionalFoods = results[1];
    final userFoods = results[2];

    return FoodPreferencesState(
      primaryFoods: primaryFoods,
      additionalFoods: additionalFoods,
      userFoods: userFoods,
    );
  }

  /// Load primary foods
  Future<List<FoodItem>> _loadPrimaryFoods() async {
    return await _foodRepository.getPrimaryFoodsForPreferences();
  }

  /// Load additional foods
  Future<List<FoodItem>> _loadAdditionalFoods() async {
    return await _foodRepository.getAdditionalFoodsForPreferences();
  }

  /// Load user foods
  Future<List<FoodItem>> _loadUserFoods(String userId) async {
    final database = ref.read(appDatabaseProvider);
    final userFoodsData = await database.foodsDao.getUserFoods(userId);

    return userFoodsData
        .map(
          (userFood) => database.foodsDao.convertUserFoodToFoodItem(userFood),
        )
        .toList();
  }

  /// Refresh food preferences (called after adding/deleting user foods)
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await _loadFoodPreferences();
    });
  }

  /// Add a user food and refresh the list
  Future<void> addUserFood(FoodItem food) async {
    await refresh();
  }

  /// Remove a user food and refresh the list
  Future<void> removeUserFood(FoodItem food) async {
    await refresh();
  }
}
