import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/carb_loading_food_repository.dart';
import '../data/carb_loading_user_food_repository.dart';
import '../domain/carb_loading_food.dart';
import '../domain/carb_loading_user_food.dart' as domain;
import '../domain/meal_type.dart' as domain;

part 'carb_loading_food_service.g.dart';

/// Service for managing carb loading foods (both default and user-created)
/// Provides business logic layer between controllers and repositories
class CarbLoadingFoodService {
  const CarbLoadingFoodService({
    required CarbLoadingFoodRepository foodRepository,
    required CarbLoadingUserFoodRepository userFoodRepository,
  }) : _foodRepository = foodRepository,
       _userFoodRepository = userFoodRepository;

  final CarbLoadingFoodRepository _foodRepository;
  final CarbLoadingUserFoodRepository _userFoodRepository;

  /// Get all foods suitable for a specific meal type (default + user foods)
  Future<List<dynamic>> getAllFoodsForMealType({
    required String deviceId,
    required domain.MealType mealType,
  }) async {
    final defaultFoods = await _foodRepository.getFoodsByMealType(mealType.id);
    final userFoods = await _userFoodRepository.getUserFoodsByMealType(
      deviceId,
      mealType.id,
    );

    // Combine both lists
    return [...defaultFoods, ...userFoods];
  }

  /// Get only default foods for a meal type
  Future<List<CarbLoadingFood>> getDefaultFoodsForMealType(
    domain.MealType mealType,
  ) async {
    return _foodRepository.getFoodsByMealType(mealType.id);
  }

  /// Get only user foods for a meal type
  Future<List<domain.CarbLoadingUserFood>> getUserFoodsForMealType({
    required String deviceId,
    required domain.MealType mealType,
  }) async {
    return _userFoodRepository.getUserFoodsByMealType(deviceId, mealType.id);
  }

  /// Search all foods (default + user) by name
  Future<List<dynamic>> searchAllFoods({
    required String deviceId,
    required String searchTerm,
  }) async {
    final defaultFoods = await _foodRepository.searchFoodsByName(searchTerm);
    final userFoods = await _userFoodRepository.searchUserFoodsByName(
      deviceId,
      searchTerm,
    );

    return [...defaultFoods, ...userFoods];
  }

  /// Get all meal types
  /// Returns all meal types from the MealType enum
  Future<List<domain.MealType>> getAllMealTypes() async {
    return domain.MealType.values;
  }

  /// Create a new user food
  Future<domain.CarbLoadingUserFood> createUserFood({
    required String deviceId,
    required String userId,
    required String name,
    required String displayName,
    String? displayNamePlural,
    required double carbsPerServing,
    String? imageAddress,
    required List<domain.MealType> mealTypes,
  }) async {
    return _userFoodRepository.createUserFood(
      deviceId: deviceId,
      userId: userId,
      name: name,
      displayName: displayName,
      displayNamePlural: displayNamePlural,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      mealTypeIds: mealTypes.map((mt) => mt.id).toList(),
    );
  }

  /// Update a user food
  Future<domain.CarbLoadingUserFood> updateUserFood({
    required String id,
    String? name,
    String? displayName,
    String? displayNamePlural,
    double? carbsPerServing,
    String? imageAddress,
    List<domain.MealType>? mealTypes,
  }) async {
    return _userFoodRepository.updateUserFood(
      id: id,
      name: name,
      displayName: displayName,
      displayNamePlural: displayNamePlural,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      mealTypeIds: mealTypes?.map((mt) => mt.id).toList(),
    );
  }

  /// Delete a user food (soft delete)
  Future<void> deleteUserFood(String id) async {
    return _userFoodRepository.deleteUserFood(id);
  }

  /// Get a specific default food by ID
  Future<CarbLoadingFood?> getDefaultFoodById(String id) async {
    return _foodRepository.getFoodById(id);
  }

  /// Get a specific user food by ID
  Future<domain.CarbLoadingUserFood?> getUserFoodById(String id) async {
    return _userFoodRepository.getUserFoodById(id);
  }

  /// Get all user foods for a device
  Future<List<domain.CarbLoadingUserFood>> getAllUserFoods(
    String deviceId,
  ) async {
    return _userFoodRepository.getAllUserFoods(deviceId);
  }

  /// Watch all foods for a meal type (for real-time UI updates)
  Stream<List<dynamic>> watchAllFoodsForMealType({
    required String deviceId,
    required domain.MealType mealType,
  }) async* {
    // Note: This is a simplified version. For production, you might want to use
    // StreamGroup or combine streams more efficiently
    await for (final defaultFoods in _foodRepository.watchFoodsByMealType(
      mealType.id,
    )) {
      final userFoods = await _userFoodRepository.getUserFoodsByMealType(
        deviceId,
        mealType.id,
      );
      yield [...defaultFoods, ...userFoods];
    }
  }

  /// Validate that a food is suitable for a specific meal type
  bool isFoodSuitableForMealType({
    required dynamic food,
    required domain.MealType mealType,
  }) {
    if (food is CarbLoadingFood) {
      return food.isSuitableForMeal(mealType);
    } else if (food is domain.CarbLoadingUserFood) {
      return food.isSuitableForMeal(mealType);
    }
    return false;
  }

  /// Get carbs per serving for any food (default or user)
  double getCarbsPerServing(dynamic food) {
    if (food is CarbLoadingFood) {
      return food.carbsPerServing;
    } else if (food is domain.CarbLoadingUserFood) {
      return food.carbsPerServing;
    }
    throw ArgumentError('Invalid food type');
  }

  /// Get display name for any food
  String getDisplayName(dynamic food) {
    if (food is CarbLoadingFood) {
      return food.displayName;
    } else if (food is domain.CarbLoadingUserFood) {
      return food.displayName;
    }
    throw ArgumentError('Invalid food type');
  }

  /// Get food ID for any food
  /// Returns String for global foods, int for user foods
  dynamic getFoodId(dynamic food) {
    if (food is CarbLoadingFood) {
      return food.id; // String (UUID)
    } else if (food is domain.CarbLoadingUserFood) {
      return food.id; // int
    }
    throw ArgumentError('Invalid food type');
  }

  /// Check if food is a user food
  bool isUserFood(dynamic food) {
    return food is domain.CarbLoadingUserFood;
  }

  /// Check if food is a default food
  bool isDefaultFood(dynamic food) {
    return food is CarbLoadingFood;
  }
}

@riverpod
CarbLoadingFoodService carbLoadingFoodService(Ref ref) {
  return CarbLoadingFoodService(
    foodRepository: ref.watch(carbLoadingFoodRepositoryProvider),
    userFoodRepository: ref.watch(carbLoadingUserFoodRepositoryProvider),
  );
}
