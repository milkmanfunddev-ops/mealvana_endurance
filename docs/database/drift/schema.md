# Drift Database Schema (Version 3)

## Overview

The Drift database serves as the local, offline-first storage for Mealvana Endurance. Version 3 adds user-specific food management capabilities to enable users to save custom foods from barcode scanning and manage their personal food preferences.

## Schema Evolution

### Version 1 (2025)
- **New Architecture**: Complete alignment with updated Supabase schema
- **Added Tables**: product_types (for smart food recommendations)
- **Simplified Foods**: Removed complex serving logic, added simplified display names
- **Enhanced Plans**: Added complete metadata and versioning support
- **Migration Strategy**: Clean slate approach - all existing databases reset to v1

### Version 2
- **Updated foods table**: Aligned with Supabase schema changes

### Version 3 (Current)
- **User Food Management**: Added user_foods, user_food_categories, user_hidden_foods tables
- **Barcode Scanning Support**: Enable persistent storage of scanned foods
- **Food Hiding**: Allow users to hide generic foods from recommendations
- **Category Assignment**: Users can assign timing categories to their custom foods

## Table Definitions

### 1. user_profiles

**Purpose**: User biometric data and preferences
**Primary Key**: id (device_id)

```dart
@DataClassName('UserProfileEntry')
class UserProfilesTable extends Table {
  TextColumn get id => text()();                    // Device ID (PK)
  TextColumn get gender => text()();                // male/female/other
  DateTimeColumn get birthday => dateTime()();      // User's birthdate
  IntColumn get heightFeet => integer()();          // Height feet component
  IntColumn get heightInches => integer()();        // Height inches component
  RealColumn get weightPounds => real()();          // Weight in pounds
  BoolColumn get runsWithWaterBottle => boolean()(); // Water bottle preference
  TextColumn get gutTraining => text()();           // low/moderate/high
  BoolColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get appVersion => text()();
  
  // Notification preferences
  BoolColumn get notificationsEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get defaultReminderDay => integer().withDefault(const Constant(4))(); // Thursday
  IntColumn get defaultReminderHour => integer().withDefault(const Constant(17))(); // 5 PM
  IntColumn get defaultReminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get defaultReminderRecurring => boolean().withDefault(const Constant(false))();
  
  // Temporary plan storage
  TextColumn get tempPlanData => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'users';
}
```

### 2. food_preferences

**Purpose**: User preferences for individual foods
**Primary Key**: Composite (userId, foodId)

```dart
@DataClassName('FoodPreferenceEntry')
class FoodPreferencesTable extends Table {
  TextColumn get userId => text()();               // References user_profiles.id
  TextColumn get foodId => text()();               // References foods.name or food ID
  TextColumn get preference => text()();           // like/dislike/willing_to_try
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId, foodId};
}
```

**🚨 CRITICAL: Enum Format Constraint**

The `preference` column has a CHECK constraint that enforces underscore format:

```sql
CHECK (preference IN ('like', 'dislike', 'willing_to_try'))
```

**When writing to this table:**
```dart
// ✅ CORRECT - Use .value to get underscore format
preference: entry.value.value, // "willing_to_try"

// ❌ WRONG - .name gives camelCase and fails constraint
preference: entry.value.name,  // "willingToTry" - CHECK constraint violation!
```

**When reading from this table:**
```dart
// ✅ CORRECT - Match against .value
final preference = FoodPreference.values.firstWhere(
  (p) => p.value == row.preference, // Matches "willing_to_try"
  orElse: () => FoodPreference.dislike,
);
```

### 3. nutrition_plans

**Purpose**: Generated nutrition plans with full history and versioning
**Primary Key**: id (UUID)

```dart
@DataClassName('NutritionPlanEntry')
class NutritionPlans extends Table {
  /// UUID primary key (matches Supabase nutrition_plans.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Device ID (foreign key reference to users.device_id)
  TextColumn get deviceId => text().named('device_id')();

  /// Plan data stored as JSON (matches Supabase nutrition_plans.plan_data)
  TextColumn get planData => text().named('plan_data')();

  /// Plan metadata (matches Supabase schema)
  TextColumn get planId => text().named('plan_id')();
  TextColumn get planName => text().named('plan_name')();
  RealColumn get distanceMiles => real().nullable().named('distance_miles')();
  RealColumn get paceMinutesPerMile => real().nullable().named('pace_minutes_per_mile')();
  IntColumn get totalCalories => integer().nullable().named('total_calories')();
  TextColumn get notes => text().nullable()();

  /// Versioning and sync (matches Supabase schema)
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get lastModifiedBy => text().nullable().named('last_modified_by')();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable().named('client_updated_at')();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false)).named('is_deleted')();
  TextColumn get conflictResolution => text().nullable().named('conflict_resolution')();

  /// Timestamps (matches Supabase schema)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(device_id, plan_id)', // Match Supabase unique constraint
  ];
}
```

### 4. macro_targets

**Purpose**: Custom macro adjustments and targets
**Primary Key**: id (UUID)

```dart
@DataClassName('MacroTargetEntry')
class MacroTargetsTable extends Table {
  TextColumn get id => text()();                   // UUID (PK)
  TextColumn get userId => text()();               // References user_profiles.id
  TextColumn get planId => text().nullable()();    // Optional plan reference
  
  // Pre-run targets
  RealColumn get preRunCarbs => real().nullable()();
  RealColumn get preRunProtein => real().nullable()();
  RealColumn get preRunFat => real().nullable()();
  RealColumn get preRunFluids => real().nullable()();
  RealColumn get preRunSodium => real().nullable()();
  
  // During-run targets
  RealColumn get duringRunCarbsTotal => real().nullable()();
  RealColumn get duringRunCarbsPerHour => real().nullable()();
  RealColumn get duringRunFluidsTotal => real().nullable()();
  RealColumn get duringRunFluidsPerHour => real().nullable()();
  RealColumn get duringRunSodiumTotal => real().nullable()();
  RealColumn get duringRunSodiumPerHour => real().nullable()();
  
  // Post-run targets
  RealColumn get postRunCarbs => real().nullable()();
  RealColumn get postRunProtein => real().nullable()();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 5. feedback

**Purpose**: User feedback and satisfaction ratings
**Primary Key**: id (UUID)

```dart
@DataClassName('FeedbackEntry')
class FeedbackTable extends Table {
  TextColumn get id => text()();                   // UUID (PK)
  IntColumn get satisfactionLevel => integer().nullable()(); // 1-3 scale
  TextColumn get satisfactionEmoji => text().nullable()();
  TextColumn get satisfactionLabel => text().nullable()();
  IntColumn get confidenceLevel => integer().nullable()();
  TextColumn get confidenceLabel => text().nullable()();
  TextColumn get reuseIntent => text().nullable()();
  BoolColumn get reminderRequested => boolean().withDefault(const Constant(false))();
  TextColumn get missedReasons => text().nullable()();
  TextColumn get missedOther => text().nullable()();
  
  // Reminder settings
  IntColumn get reminderDayOfWeek => integer().nullable()();
  IntColumn get reminderHour => integer().withDefault(const Constant(17))();
  IntColumn get reminderMinute => integer().withDefault(const Constant(0))();
  BoolColumn get reminderRecurring => boolean().withDefault(const Constant(false))();
  
  // Context
  TextColumn get planName => text().nullable()();
  TextColumn get userName => text().nullable()();
  DateTimeColumn get timestamp => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(Constant(DateTime.now()))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 6. foods ⭐ UPDATED IN V1

**Purpose**: Local cache of food database from Supabase
**Primary Key**: id (UUID)

```dart
@DataClassName('FoodEntry')
class FoodsTable extends Table {
  /// UUID primary key (matches Supabase foods.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Food name (matches Supabase foods.name)
  TextColumn get name => text().nullable()();

  /// Image URL (matches Supabase foods.image_address)
  TextColumn get imageAddress => text().nullable().named('image_address')();

  /// When the food was created (matches Supabase foods.created_at)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  // Simplified serving information (matches new Supabase schema)
  RealColumn get servingAmount => real().nullable().named('serving_amount')();

  // Serving limits (matches Supabase schema)
  IntColumn get maxServingsBefore => integer().nullable().named('max_servings_before')();
  IntColumn get maxServingsDuring => integer().nullable().named('max_servings_during')();
  IntColumn get maxServingsAfter => integer().nullable().named('max_servings_after')();

  // Nutritional values per serving (matches Supabase schema)
  IntColumn get sodiumMg => integer().nullable().named('sodium_mg')();
  IntColumn get caffeineMg => integer().nullable().named('caffeine_mg')();
  IntColumn get potassiumMg => integer().nullable().named('potassium_mg')();
  RealColumn get fatPerServing => real().nullable().named('fat_per_serving')();
  RealColumn get carbsPerServing => real().nullable().named('carbs_per_serving')();
  RealColumn get proteinPerServing => real().nullable().named('protein_per_serving')();
  IntColumn get caloriesPerServing => integer().nullable().named('calories_per_serving')();
  RealColumn get fluidMlPerServing => real().nullable().named('fluid_ml_per_serving')();

  // Food categorization (matches new Supabase schema)
  TextColumn get productTypeId => text().nullable().named('product_type_id')(); // References product_types.id

  // Food preferences and solver configuration (matches Supabase schema)
  BoolColumn get showInPreferences => boolean().withDefault(const Constant(false)).named('show_in_preferences')();
  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false)).named('is_electrolyte')();
  BoolColumn get toExcludeFromSolver => boolean().withDefault(const Constant(false)).named('to_exclude_from_solver')();

  // Simplified display names (matches new Supabase schema)
  TextColumn get displayName => text().nullable().withLength(max: 100).named('display_name')(); // e.g., "gel", "banana"
  TextColumn get displayNamePlural => text().nullable().withLength(max: 100).named('display_name_plural')(); // e.g., "gels", "bananas"

  // Serving description (matches Supabase schema)
  TextColumn get servingDescription => text().nullable().named('serving_description')(); // e.g., "1 medium", "1 cup cooked"

  // Serving size (matches Supabase schema)
  TextColumn get servingSize => text().nullable().named('serving_size')(); // e.g., "1 cup", "100g"

  // Additional fields matching Supabase
  TextColumn get description => text().nullable()(); // Product description

  @override
  Set<Column> get primaryKey => {id};
}
```

### 7. product_types ⭐ NEW IN V1

**Purpose**: Standardized food product categories for better recommendations
**Primary Key**: id (UUID)

```dart
@DataClassName('ProductTypeEntry')
class ProductTypesTable extends Table {
  /// UUID primary key (matches Supabase product_types.id)
  TextColumn get id => text().withLength(min: 36, max: 36)();

  /// Unique code identifier (matches Supabase product_types.code)
  TextColumn get code => text()();

  /// Display name (matches Supabase product_types.name)
  TextColumn get name => text()();

  /// Plural form for UI (matches Supabase product_types.name_plural)
  TextColumn get namePlural => text().named('name_plural')();

  /// Sort order for UI display (matches Supabase product_types.sort_order)
  IntColumn get sortOrder => integer().nullable().named('sort_order')();

  /// When the type was created (matches Supabase product_types.created_at)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime).named('created_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'UNIQUE(code)', // Match Supabase unique constraint on code
  ];
}
```

**Pre-populated Data**:
The table includes 16 standardized product types:
- gel, chew, drink_mix, pill, bar, candy
- fruit_fresh, fruit_dried, nut_seed
- dairy, grain, vegetable, meat_fish
- water, sports_drink, other

### 8. categories ⭐ NEW IN V2

**Purpose**: Food timing categories
**Primary Key**: id (Integer)

```dart
@DataClassName('CategoryEntry')
class CategoriesTable extends Table {
  IntColumn get id => integer().autoIncrement()(); // Auto-increment (PK)
  TextColumn get name => text()();                 // before_run/during_run/after_run

  @override
  Set<Column> get primaryKey => {id};
}
```

### 8. food_categories ⭐ NEW IN V2

**Purpose**: Many-to-many relationship between foods and categories
**Primary Key**: Composite (foodId, categoryId)

```dart
@DataClassName('FoodCategoryEntry')
class FoodCategoriesTable extends Table {
  TextColumn get foodId => text()();               // References foods.id
  IntColumn get categoryId => integer()();         // References categories.id

  @override
  Set<Column> get primaryKey => {foodId, categoryId};
}
```

### 9. app_content ⭐ NEW IN V2

**Purpose**: Dynamic UI text and algorithm parameters (replaces SharedPreferences)
**Primary Key**: id (UUID)

```dart
@DataClassName('AppContentEntry')
class AppContentTable extends Table {
  TextColumn get id => text()();                   // UUID (PK)
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get environment => text().withDefault(const Constant('production'))();
  TextColumn get locale => text().withDefault(const Constant('en'))();
  TextColumn get content => text()();              // JSON content data
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();

  // Cache metadata
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  BoolColumn get isCached => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 10. user_foods ⭐ NEW IN V3

**Purpose**: Stores custom foods that users have added or scanned via barcode
**Primary Key**: id (UUID)

```dart
@DataClassName('UserFood')
class UserFoodsTable extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();          // UUID (PK)
  TextColumn get deviceId => text()();                                  // References user_profiles.device_id
  TextColumn get clientFoodId => text().nullable()();                   // Client-generated ID for offline sync
  TextColumn get barcode => text().nullable()();                        // Barcode if scanned
  TextColumn get name => text()();                                      // Food name
  TextColumn get displayName => text().nullable()();                    // Display name
  TextColumn get displayNamePlural => text().nullable()();              // Plural display name
  TextColumn get description => text().nullable()();                    // Food description
  TextColumn get imageAddress => text().nullable()();                   // Image URL

  // Serving information
  RealColumn get servingAmount => real().nullable()();
  TextColumn get servingUnit => text().nullable()();

  // Nutritional information
  IntColumn get caloriesPerServing => integer().nullable()();
  RealColumn get carbsPerServing => real().nullable()();
  RealColumn get proteinPerServing => real().nullable()();
  RealColumn get fatPerServing => real().nullable()();
  IntColumn get sodiumMg => integer().nullable()();
  RealColumn get fluidMlPerServing => real().nullable()();

  // Categorization
  TextColumn get productTypeId => text().nullable()();                  // References product_types.id
  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false))();
  BoolColumn get toExcludeFromSolver => boolean().withDefault(const Constant(false))();

  // Sync metadata
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 11. user_food_categories ⭐ NEW IN V3

**Purpose**: Links user foods to timing categories (before_run, during_run, after_run)
**Primary Key**: Composite (userFoodId, categoryId)

```dart
@DataClassName('UserFoodCategory')
class UserFoodCategoriesTable extends Table {
  TextColumn get userFoodId => text().withLength(min: 36, max: 36)();  // References user_foods.id
  IntColumn get categoryId => integer()();                              // References categories.id

  @override
  Set<Column> get primaryKey => {userFoodId, categoryId};
}
```

### 12. user_hidden_foods ⭐ NEW IN V3

**Purpose**: Tracks which generic foods a user has hidden/excluded from recommendations
**Primary Key**: Composite (deviceId, foodId)

```dart
@DataClassName('UserHiddenFood')
class UserHiddenFoodsTable extends Table {
  TextColumn get deviceId => text()();                                  // References user_profiles.device_id
  TextColumn get foodId => text().withLength(min: 36, max: 36)();      // References foods.id

  @override
  Set<Column> get primaryKey => {deviceId, foodId};
}
```

## Relationships and Foreign Keys

### Explicit Relationships
- **food_preferences.userId** → **user_profiles.id**
- **nutrition_plans.deviceId** → **user_profiles.id**
- **macro_targets.userId** → **user_profiles.id**
- **macro_targets.planId** → **nutrition_plans.id** (optional)
- **food_categories.foodId** → **foods.id**
- **food_categories.categoryId** → **categories.id**
- **foods.productTypeId** → **product_types.id** (optional)
- **user_foods.deviceId** → **user_profiles.device_id**
- **user_foods.productTypeId** → **product_types.id** (optional)
- **user_food_categories.userFoodId** → **user_foods.id**
- **user_food_categories.categoryId** → **categories.id**
- **user_hidden_foods.deviceId** → **user_profiles.device_id**
- **user_hidden_foods.foodId** → **foods.id**

### Implicit Relationships
- **food_preferences.foodId** matches **foods.name** or **foods.id**

## Indexes for Performance

### Primary Indexes (Automatic)
All primary keys automatically have unique indexes

### Custom Indexes (Recommended)
```sql
-- User lookups
CREATE INDEX idx_user_profiles_device_id ON users(id);

-- Food preference queries
CREATE INDEX idx_food_preferences_user ON food_preferences(user_id);
CREATE INDEX idx_food_preferences_user_food ON food_preferences(user_id, food_id);

-- Plan queries
CREATE INDEX idx_nutrition_plans_device_created ON nutrition_plans(device_id, created_at DESC);
CREATE INDEX idx_nutrition_plans_device_active ON nutrition_plans(device_id) WHERE is_deleted = 0;
CREATE INDEX idx_nutrition_plans_device_plan ON nutrition_plans(device_id, plan_id);

-- Food searches
CREATE INDEX idx_foods_name ON foods(name);
CREATE INDEX idx_foods_preferences ON foods(show_in_preferences) WHERE show_in_preferences = 1;
CREATE INDEX idx_foods_product_type ON foods(product_type_id);

-- Product type lookups
CREATE INDEX idx_product_types_code ON product_types(code);
CREATE INDEX idx_product_types_sort ON product_types(sort_order, name);

-- Category lookups
CREATE INDEX idx_food_categories_category ON food_categories(category_id);
CREATE INDEX idx_food_categories_food ON food_categories(food_id);

-- Content management
CREATE INDEX idx_app_content_env_locale ON app_content(environment, locale);
CREATE INDEX idx_app_content_active ON app_content(is_active) WHERE is_active = 1;
```

## Common Query Patterns

### User Profile Operations
```dart
// Get current user
final user = await database.getCurrentUserProfile();

// Update user profile
await database.updateUserProfile(updatedUser);

// Check onboarding status
final hasCompleted = user?.onboardingCompleted ?? false;
```

### Food Preference Management
```dart
// Get user's preferred foods
final likedFoods = await database.getLikedFoods(userId);
final dislikedFoods = await database.getDislikedFoods(userId);

// Save food preferences
await database.saveFoodPreferences(userId, preferences);
```

### Food Database Queries
```dart
// Get foods by category
final beforeRunFoods = await (database.select(database.foodsTable)
  ..join([
    leftOuterJoin(database.foodCategoriesTable,
      database.foodCategoriesTable.foodId.equalsExp(database.foodsTable.id))
  ])
  ..where(database.categoriesTable.name.equals('before_run'))).get();

// Search foods by name
final searchResults = await (database.select(database.foodsTable)
  ..where(database.foodsTable.name.like('%$searchTerm%'))).get();

// Get foods for preferences screen
final preferenceFoods = await (database.select(database.foodsTable)
  ..where(database.foodsTable.showInPreferences.equals(true))
  ..orderBy([
    (t) => OrderingTerm.asc(t.name)
  ])).get();

// Get foods with product type information
final foodsWithDetails = await (database.select(database.foodsTable)
  ..join([
    leftOuterJoin(database.productTypesTable,
      database.productTypesTable.id.equalsExp(database.foodsTable.productTypeId))
  ])).get();

// Get foods by product type
final gelFoods = await (database.select(database.foodsTable)
  ..join([
    innerJoin(database.productTypesTable,
      database.productTypesTable.id.equalsExp(database.foodsTable.productTypeId))
  ])
  ..where(database.productTypesTable.code.equals('gel'))).get();
```

### Nutrition Plan Management
```dart
// Save new plan
await database.saveNutritionPlan(plan);

// Get device's latest plan
final latestPlan = await database.getLatestNutritionPlan(deviceId);

// Get plan history for device
final allPlans = await database.getAllNutritionPlans(deviceId);

// Get plan by device and plan ID
final specificPlan = await (database.select(database.nutritionPlans)
  ..where((t) => t.deviceId.equals(deviceId) &
                 t.planId.equals(planId) &
                 t.isDeleted.equals(false))).getSingleOrNull();

// Delete plan (soft delete)
await database.deleteNutritionPlan(planId);
```

### Content Management
```dart
// Get active content for environment/locale
final content = await (database.select(database.appContentTable)
  ..where((t) => t.environment.equals(env) & 
                 t.locale.equals(locale) & 
                 t.isActive.equals(true))
  ..orderBy([(t) => OrderingTerm.desc(t.version)])
  ..limit(1)).getSingleOrNull();

// Cache new content
await database.into(database.appContentTable).insert(contentEntry);
```

## Migration Considerations

### Data Preservation During V1→V2 Migration
- All existing user data preserved
- New tables created empty
- Initial sync populates food/content data
- No data loss during migration

### Future Schema Changes (V2→V3)
- Use proper Drift migration system
- Generate schema snapshots before changes
- Test migrations on copy of production data
- Implement rollback procedures

### Backup Strategy
- Backup before any schema change
- Store critical user data in SharedPreferences during migration
- Verify backup integrity before proceeding
- Implement automated rollback on failure

This schema provides a solid foundation for offline-first functionality while maintaining sync capability with the Supabase backend.