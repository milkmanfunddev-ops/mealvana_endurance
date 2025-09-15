# Repository Patterns

## Overview

This document outlines the repository patterns used in Mealvana Endurance for data access and manipulation. Repositories provide a clean abstraction layer between business logic and database operations, following the Feature-Oriented Architecture (FOA) pattern.

## Repository Architecture

### Base Repository Pattern
```dart
abstract class BaseRepository<T, ID> {
  final AppDatabase database;
  
  BaseRepository(this.database);
  
  // Common CRUD operations
  Future<T?> findById(ID id);
  Future<List<T>> findAll();
  Future<T> save(T entity);
  Future<void> delete(ID id);
  
  // Common query helpers
  Future<int> count();
  Future<bool> exists(ID id);
}
```

## Core Repositories

### 1. User Repository

Manages user profiles and preferences with device-based authentication.

```dart
@Riverpod(keepAlive: true)
class UserRepository extends BaseRepository<UserProfile, String> {
  UserRepository(AppDatabase database) : super(database);
  
  /// Get current user profile by device ID
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final entry = await (database.select(database.userProfilesTable)
        ..limit(1)).getSingleOrNull();
      
      if (entry == null) return null;
      
      return _convertToDomainUserProfile(entry);
    } catch (e) {
      logger.error('Failed to get current user profile', error: e);
      return null;
    }
  }
  
  /// Save or update user profile
  Future<UserProfile> saveUserProfile(UserProfile profile) async {
    try {
      final companion = UserProfilesTableCompanion(
        id: Value(profile.deviceId),
        gender: Value(profile.gender.name),
        birthday: Value(profile.birthday),
        heightFeet: Value(profile.heightFeet),
        heightInches: Value(profile.heightInches),
        weightPounds: Value(profile.weightPounds),
        runsWithWaterBottle: Value(profile.runsWithWaterBottle),
        gutTraining: Value(profile.gutTraining.name),
        onboardingCompleted: Value(profile.onboardingCompleted),
        createdAt: Value(profile.createdAt ?? DateTime.now()),
        updatedAt: Value(DateTime.now()),
        appVersion: Value(profile.appVersion ?? ''),
        notificationsEnabled: Value(profile.notificationsEnabled),
        defaultReminderDay: Value(profile.defaultReminderDay),
        defaultReminderHour: Value(profile.defaultReminderHour),
        defaultReminderMinute: Value(profile.defaultReminderMinute),
        defaultReminderRecurring: Value(profile.defaultReminderRecurring),
      );
      
      await database.into(database.userProfilesTable)
          .insertOnConflictUpdate(companion);
      
      logger.info('User profile saved successfully');
      return profile;
    } catch (e) {
      logger.error('Failed to save user profile', error: e);
      rethrow;
    }
  }
  
  /// Update specific user preferences
  Future<void> updateUserPreferences({
    bool? notificationsEnabled,
    int? reminderDay,
    int? reminderHour,
    int? reminderMinute,
    bool? reminderRecurring,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (notificationsEnabled != null) {
        updates['notifications_enabled'] = notificationsEnabled;
      }
      if (reminderDay != null) {
        updates['default_reminder_day'] = reminderDay;
      }
      // ... other preference updates
      
      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();
        
        await database.customUpdate(
          'UPDATE users SET ${updates.keys.map((k) => '$k = ?').join(', ')} WHERE id = ?',
          variables: [...updates.values.map(Variable.new), Variable(_getCurrentDeviceId())],
        );
      }
    } catch (e) {
      logger.error('Failed to update user preferences', error: e);
      rethrow;
    }
  }
  
  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final user = await getCurrentUserProfile();
    return user?.onboardingCompleted ?? false;
  }
  
  UserProfile _convertToDomainUserProfile(UserProfileEntry entry) {
    return UserProfile(
      deviceId: entry.id,
      gender: Gender.values.firstWhere((g) => g.name == entry.gender),
      birthday: entry.birthday,
      heightFeet: entry.heightFeet,
      heightInches: entry.heightInches,
      weightPounds: entry.weightPounds,
      runsWithWaterBottle: entry.runsWithWaterBottle,
      gutTraining: GutTraining.values.firstWhere((gt) => gt.name == entry.gutTraining),
      onboardingCompleted: entry.onboardingCompleted,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      appVersion: entry.appVersion,
      notificationsEnabled: entry.notificationsEnabled,
      defaultReminderDay: entry.defaultReminderDay,
      defaultReminderHour: entry.defaultReminderHour,
      defaultReminderMinute: entry.defaultReminderMinute,
      defaultReminderRecurring: entry.defaultReminderRecurring,
    );
  }
}
```

### 2. Food Repository

Manages local food database cache with sync capabilities.

```dart
@Riverpod(keepAlive: true)
class FoodRepository extends BaseRepository<FoodItem, String> {
  final SupabaseClient _supabase;
  
  FoodRepository(AppDatabase database, this._supabase) : super(database);
  
  /// Get all foods from local cache
  Future<List<FoodItem>> getAllFoods() async {
    try {
      final foods = await database.select(database.foodsTable).get();
      return foods.map(_convertToFoodItem).toList();
    } catch (e) {
      logger.error('Failed to get all foods from cache', error: e);
      
      // Fallback to Supabase if local cache fails
      return await _fetchFoodsFromSupabase();
    }
  }
  
  /// Get foods by category with local joins
  Future<List<FoodItem>> getFoodsByCategory(FoodCategory category) async {
    try {
      final query = database.select(database.foodsTable).join([
        innerJoin(
          database.foodCategoriesTable,
          database.foodCategoriesTable.foodId.equalsExp(database.foodsTable.id),
        ),
        innerJoin(
          database.categoriesTable,
          database.categoriesTable.id.equalsExp(database.foodCategoriesTable.categoryId),
        ),
      ])..where(database.categoriesTable.name.equals(category.name));
      
      final results = await query.get();
      return results.map((row) => _convertToFoodItem(row.readTable(database.foodsTable))).toList();
    } catch (e) {
      logger.error('Failed to get foods by category: ${category.name}', error: e);
      return [];
    }
  }
  
  /// Search foods by name or description
  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final searchPattern = '%${query.trim().toLowerCase()}%';
      
      final foods = await (database.select(database.foodsTable)
        ..where((t) => 
          t.name.lower().like(searchPattern) |
          t.description.lower().like(searchPattern)))
        .get();
      
      return foods.map(_convertToFoodItem).toList();
    } catch (e) {
      logger.error('Failed to search foods', error: e);
      return [];
    }
  }
  
  /// Get foods filtered by user preferences
  Future<List<FoodItem>> getPreferredFoods(
    String userId,
    FoodCategory category, {
    List<String> excludeDisliked = const [],
  }) async {
    try {
      // Get user's food preferences
      final preferences = await database.select(database.foodPreferencesTable)
        .where((t) => t.userId.equals(userId))
        .get();
      
      final preferenceMap = <String, String>{};
      for (final pref in preferences) {
        preferenceMap[pref.foodId] = pref.preference;
      }
      
      // Get foods by category
      final categoryFoods = await getFoodsByCategory(category);
      
      // Sort by preference priority
      categoryFoods.sort((a, b) {
        final aPref = preferenceMap[a.id] ?? 'neutral';
        final bPref = preferenceMap[b.id] ?? 'neutral';
        
        // Priority: like > willing_to_try > neutral > dislike
        final priorityOrder = ['like', 'willing_to_try', 'neutral', 'dislike'];
        
        return priorityOrder.indexOf(aPref).compareTo(priorityOrder.indexOf(bPref));
      });
      
      // Filter out dislikes if requested
      if (excludeDisliked.isNotEmpty) {
        return categoryFoods.where((food) {
          final pref = preferenceMap[food.id];
          return pref != 'dislike' || !excludeDisliked.contains(food.id);
        }).toList();
      }
      
      return categoryFoods;
    } catch (e) {
      logger.error('Failed to get preferred foods', error: e);
      return await getFoodsByCategory(category);
    }
  }
  
  /// Cache foods from Supabase to local database
  Future<int> cacheFoodsFromSupabase() async {
    try {
      final foods = await _fetchFoodsFromSupabase();
      
      // Clear existing cache
      await database.delete(database.foodCategoriesTable).go();
      await database.delete(database.foodsTable).go();
      
      // Insert new data in transaction
      int cachedCount = 0;
      await database.transaction(() async {
        for (final food in foods) {
          await _insertFoodWithCategories(food);
          cachedCount++;
        }
      });
      
      logger.info('Cached $cachedCount foods from Supabase');
      return cachedCount;
    } catch (e) {
      logger.error('Failed to cache foods from Supabase', error: e);
      rethrow;
    }
  }
  
  Future<List<FoodItem>> _fetchFoodsFromSupabase() async {
    final response = await _supabase
        .from('foods')
        .select('''
          *,
          food_categories (
            category_id,
            categories (
              id,
              name  
            )
          ),
          brands (
            id,
            name,
            website_url
          )
        ''')
        .order('name');
    
    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
  }
  
  Future<void> _insertFoodWithCategories(FoodItem food) async {
    // Insert food
    final foodCompanion = _convertFoodItemToCompanion(food);
    await database.into(database.foodsTable).insert(foodCompanion);
    
    // Insert category relationships
    for (final category in food.categories) {
      final categoryId = await _getCategoryId(category);
      if (categoryId != null) {
        await database.into(database.foodCategoriesTable).insert(
          FoodCategoriesTableCompanion(
            foodId: Value(food.id),
            categoryId: Value(categoryId),
          ),
        );
      }
    }
  }
  
  Future<int?> _getCategoryId(FoodCategory category) async {
    final categoryEntry = await (database.select(database.categoriesTable)
      ..where((t) => t.name.equals(category.name)))
      .getSingleOrNull();
    
    return categoryEntry?.id;
  }
  
  FoodItem _convertToFoodItem(FoodEntry entry) {
    return FoodItem(
      id: entry.id,
      name: entry.name ?? '',
      description: entry.description,
      imageUrl: entry.imageAddress,
      instructions: entry.instructions,
      servingAmount: entry.servingAmount,
      servingUnit: entry.servingUnit,
      servingUnitPlural: entry.servingUnitPlural,
      servingQualifier: entry.servingQualifier,
      beforeRunSuitable: entry.beforeRunSuitable,
      duringRunSuitable: entry.duringRunSuitable,
      nutrition: Nutrition(
        calories: entry.caloriesPerServing ?? 0,
        carbs: entry.carbsPerServing ?? 0,
        protein: entry.proteinPerServing ?? 0,
        fat: entry.fatPerServing ?? 0,
        sodium: entry.sodiumMg ?? 0,
        fluids: entry.fluidMlPerServing ?? 0,
        caffeine: entry.caffeineMg,
        potassium: entry.potassiumMg,
      ),
      // Categories will be loaded separately through joins
      categories: [],
    );
  }
}
```

### 3. Nutrition Plan Repository

Manages nutrition plan storage, versioning, and sync.

```dart
@Riverpod(keepAlive: true)
class NutritionPlanRepository extends BaseRepository<NutritionPlan, String> {
  NutritionPlanRepository(AppDatabase database) : super(database);
  
  /// Save nutrition plan with versioning
  Future<NutritionPlan> saveNutritionPlan(NutritionPlan plan) async {
    try {
      final companion = NutritionPlansCompanion(
        id: Value(plan.id),
        userId: Value(plan.userId),
        planName: Value(plan.planName),
        planData: Value(jsonEncode(plan.toJson())),
        distanceMiles: Value(plan.distanceMiles),
        paceMinutesPerMile: Value(plan.paceMinutesPerMile),
        totalCalories: Value(plan.totalCalories),
        notes: Value(plan.notes),
        version: Value(plan.version),
        createdAt: Value(plan.createdAt),
        updatedAt: Value(DateTime.now()),
      );
      
      await database.into(database.nutritionPlans).insertOnConflictUpdate(companion);
      
      logger.info('Nutrition plan saved: ${plan.planName}');
      return plan.copyWith(updatedAt: DateTime.now());
    } catch (e) {
      logger.error('Failed to save nutrition plan', error: e);
      rethrow;
    }
  }
  
  /// Get user's latest nutrition plan
  Future<NutritionPlan?> getLatestNutritionPlan(String userId) async {
    try {
      final entry = await (database.select(database.nutritionPlans)
        ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(1))
        .getSingleOrNull();
      
      return entry != null ? _convertToNutritionPlan(entry) : null;
    } catch (e) {
      logger.error('Failed to get latest nutrition plan', error: e);
      return null;
    }
  }
  
  /// Get all nutrition plans for user with pagination
  Future<List<NutritionPlan>> getAllNutritionPlans(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final entries = await (database.select(database.nutritionPlans)
        ..where((t) => t.userId.equals(userId) & t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(limit, offset: offset))
        .get();
      
      return entries.map(_convertToNutritionPlan).toList();
    } catch (e) {
      logger.error('Failed to get nutrition plans', error: e);
      return [];
    }
  }
  
  /// Save temporary plan (for persistence across app restarts)
  Future<void> saveTempNutritionPlan(NutritionPlan plan) async {
    try {
      await database.customUpdate(
        'UPDATE users SET temp_plan_data = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable(jsonEncode(plan.toJson())),
          Variable(DateTime.now()),
          Variable(plan.userId),
        ],
      );
      
      logger.info('Temporary plan saved');
    } catch (e) {
      logger.error('Failed to save temporary plan', error: e);
    }
  }
  
  /// Get temporary plan
  Future<NutritionPlan?> getTempNutritionPlan(String userId) async {
    try {
      final user = await (database.select(database.userProfilesTable)
        ..where((t) => t.id.equals(userId)))
        .getSingleOrNull();
      
      if (user?.tempPlanData != null) {
        final planJson = jsonDecode(user!.tempPlanData!);
        return NutritionPlan.fromJson(planJson);
      }
      
      return null;
    } catch (e) {
      logger.error('Failed to get temporary plan', error: e);
      return null;
    }
  }
  
  /// Clear temporary plan
  Future<void> clearTempNutritionPlan(String userId) async {
    try {
      await database.customUpdate(
        'UPDATE users SET temp_plan_data = NULL, updated_at = ? WHERE id = ?',
        variables: [Variable(DateTime.now()), Variable(userId)],
      );
    } catch (e) {
      logger.error('Failed to clear temporary plan', error: e);
    }
  }
  
  /// Soft delete nutrition plan
  Future<void> deleteNutritionPlan(String planId) async {
    try {
      await database.update(database.nutritionPlans)
        .where((t) => t.id.equals(planId))
        .write(NutritionPlansCompanion(
          isDeleted: Value(true),
          updatedAt: Value(DateTime.now()),
        ));
      
      logger.info('Nutrition plan deleted: $planId');
    } catch (e) {
      logger.error('Failed to delete nutrition plan', error: e);
      rethrow;
    }
  }
  
  /// Get plans pending sync to Supabase
  Future<List<NutritionPlan>> getPendingSyncPlans(String userId) async {
    try {
      final entries = await (database.select(database.nutritionPlans)
        ..where((t) => 
          t.userId.equals(userId) & 
          t.lastModifiedBy.isNull() &
          t.isDeleted.equals(false)))
        .get();
      
      return entries.map(_convertToNutritionPlan).toList();
    } catch (e) {
      logger.error('Failed to get pending sync plans', error: e);
      return [];
    }
  }
  
  NutritionPlan _convertToNutritionPlan(NutritionPlanEntry entry) {
    final planData = jsonDecode(entry.planData);
    return NutritionPlan.fromJson(planData);
  }
}
```

### 4. Food Preference Repository

Manages user food preferences with batch operations.

```dart
@Riverpod(keepAlive: true)
class FoodPreferenceRepository extends BaseRepository<FoodPreference, String> {
  FoodPreferenceRepository(AppDatabase database) : super(database);
  
  /// Save multiple food preferences in batch
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, String> preferences,
  ) async {
    try {
      await database.transaction(() async {
        // Clear existing preferences for user
        await database.delete(database.foodPreferencesTable)
          .where((t) => t.userId.equals(userId))
          .go();
        
        // Insert new preferences
        for (final entry in preferences.entries) {
          final companion = FoodPreferencesTableCompanion(
            userId: Value(userId),
            foodId: Value(entry.key),
            preference: Value(entry.value),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          );
          
          await database.into(database.foodPreferencesTable).insert(companion);
        }
      });
      
      logger.info('Saved ${preferences.length} food preferences for user $userId');
    } catch (e) {
      logger.error('Failed to save food preferences', error: e);
      rethrow;
    }
  }
  
  /// Get user's food preferences as map
  Future<Map<String, String>> getUserFoodPreferences(String userId) async {
    try {
      final preferences = await (database.select(database.foodPreferencesTable)
        ..where((t) => t.userId.equals(userId)))
        .get();
      
      return Map.fromEntries(
        preferences.map((pref) => MapEntry(pref.foodId, pref.preference))
      );
    } catch (e) {
      logger.error('Failed to get user food preferences', error: e);
      return {};
    }
  }
  
  /// Get foods user likes
  Future<List<String>> getLikedFoods(String userId) async {
    return await _getFoodsByPreference(userId, 'like');
  }
  
  /// Get foods user dislikes
  Future<List<String>> getDislikedFoods(String userId) async {
    return await _getFoodsByPreference(userId, 'dislike');
  }
  
  /// Update single food preference
  Future<void> updateFoodPreference(
    String userId,
    String foodId,
    String preference,
  ) async {
    try {
      await database.into(database.foodPreferencesTable).insertOnConflictUpdate(
        FoodPreferencesTableCompanion(
          userId: Value(userId),
          foodId: Value(foodId),
          preference: Value(preference),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      
      logger.info('Updated food preference: $foodId = $preference');
    } catch (e) {
      logger.error('Failed to update food preference', error: e);
      rethrow;
    }
  }
  
  Future<List<String>> _getFoodsByPreference(String userId, String preference) async {
    try {
      final results = await (database.select(database.foodPreferencesTable)
        ..where((t) => t.userId.equals(userId) & t.preference.equals(preference)))
        .get();
      
      return results.map((pref) => pref.foodId).toList();
    } catch (e) {
      logger.error('Failed to get foods by preference: $preference', error: e);
      return [];
    }
  }
}
```

## Repository Providers

### Riverpod Provider Setup
```dart
// Base database provider
@Riverpod(keepAlive: true)
Future<AppDatabase> database(DatabaseRef ref) async {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
}

// Repository providers
@Riverpod(keepAlive: true)
UserRepository userRepository(UserRepositoryRef ref) {
  final database = ref.watch(databaseProvider).requireValue;
  return UserRepository(database);
}

@Riverpod(keepAlive: true) 
FoodRepository foodRepository(FoodRepositoryRef ref) {
  final database = ref.watch(databaseProvider).requireValue;
  final supabase = ref.watch(supabaseProvider);
  return FoodRepository(database, supabase);
}

@Riverpod(keepAlive: true)
NutritionPlanRepository nutritionPlanRepository(NutritionPlanRepositoryRef ref) {
  final database = ref.watch(databaseProvider).requireValue;
  return NutritionPlanRepository(database);
}

@Riverpod(keepAlive: true)
FoodPreferenceRepository foodPreferenceRepository(FoodPreferenceRepositoryRef ref) {
  final database = ref.watch(databaseProvider).requireValue;
  return FoodPreferenceRepository(database);
}
```

## Best Practices

### 1. Error Handling
- Always wrap database operations in try-catch blocks
- Log errors with context for debugging
- Provide fallback behavior when possible
- Don't let database errors crash the app

### 2. Performance Optimization
- Use transactions for multiple related operations
- Batch insert/update operations when possible
- Implement proper indexing for common queries
- Use joins instead of multiple queries when appropriate

### 3. Data Validation
- Validate data before database operations
- Use database constraints where appropriate
- Handle constraint violations gracefully
- Sanitize user input to prevent injection

### 4. Testing Strategy
- Unit test repository methods in isolation
- Use in-memory databases for testing
- Mock external dependencies (Supabase)
- Test error conditions and edge cases

### 5. Migration Safety
- Always backup data before schema changes
- Test migrations on representative data
- Implement rollback procedures
- Monitor migration success in production

This repository architecture provides a solid foundation for data management while maintaining clean separation of concerns and testability.