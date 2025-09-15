# Drift Database Schema (Version 6)

## Overview

The Drift database serves as the local, offline-first storage for Mealvana Endurance. Version 6 builds upon the foundation established in v2 with incremental improvements for better display names and solver optimization.

## Schema Evolution

### Version 1 → Version 2 Migration
- **Preserved Tables**: user_profiles, food_preferences, nutrition_plans, macro_targets, feedback
- **New Tables**: foods, categories, food_categories, brands, app_content
- **Migration Strategy**: "Fake History" approach - treat v1 as always having proper Drift migrations

### Version 5 → Version 6 Migration
- **Added Fields**: `display_name_plural` and `to_exclude_from_solver` to foods table
- **Purpose**: Better UI display names and solver optimization control
- **Migration Strategy**: Column additions using `addColumn()` operations

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

### 3. nutrition_plans

**Purpose**: Generated nutrition plans with full history
**Primary Key**: id (UUID)

```dart
@DataClassName('NutritionPlanEntry')
class NutritionPlans extends Table {
  TextColumn get id => text()();                   // UUID (PK)
  TextColumn get userId => text()();               // References user_profiles.id
  TextColumn get planName => text()();             // User-friendly plan name
  TextColumn get planData => text()();             // JSON nutrition plan data
  RealColumn get distanceMiles => real().nullable()();
  RealColumn get paceMinutesPerMile => real().nullable()();
  IntColumn get totalCalories => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  // Sync tracking
  TextColumn get lastModifiedBy => text().nullable()();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get conflictResolution => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
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

### 6. foods ⭐ NEW IN V2

**Purpose**: Local cache of food database from Supabase
**Primary Key**: id (UUID)

```dart
@DataClassName('FoodEntry')
class FoodsTable extends Table {
  TextColumn get id => text()();                   // UUID (PK)
  TextColumn get name => text().nullable()();
  TextColumn get displayName => text().nullable()(); // Display name for UI
  TextColumn get displayNamePlural => text().nullable()(); // Plural form for UI
  TextColumn get imageAddress => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get nutritionalInfo => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime().nullable()();

  // Serving information
  RealColumn get servingAmount => real().nullable()();
  TextColumn get servingUnit => text().nullable()();
  TextColumn get servingUnitPlural => text().nullable()();
  TextColumn get servingQualifier => text().nullable()();
  TextColumn get servingSize => text().nullable()();

  // Suitability flags
  BoolColumn get beforeRunSuitable => boolean().withDefault(const Constant(false))();
  BoolColumn get duringRunSuitable => boolean().withDefault(const Constant(false))();
  BoolColumn get afterRunSuitable => boolean().withDefault(const Constant(false))();
  BoolColumn get runPortable => boolean().withDefault(const Constant(false))();
  BoolColumn get requiresPreparation => boolean().withDefault(const Constant(false))();
  BoolColumn get aidStationAvailable => boolean().withDefault(const Constant(false))();
  BoolColumn get isElectrolyte => boolean().withDefault(const Constant(false))();
  BoolColumn get toExcludeFromSolver => boolean().withDefault(const Constant(false))();
  IntColumn get maxServingsBefore => integer().nullable()();
  IntColumn get maxServingsDuring => integer().nullable()();
  IntColumn get maxServingsAfter => integer().nullable()();

  // Nutritional values per serving
  IntColumn get sodiumMg => integer().nullable()();
  IntColumn get caffeineMg => integer().nullable()();
  IntColumn get potassiumMg => integer().nullable()();
  RealColumn get fatPerServing => real().nullable()();
  RealColumn get carbsPerServing => real().nullable()();
  RealColumn get proteinPerServing => real().nullable()();
  IntColumn get caloriesPerServing => integer().nullable()();
  RealColumn get fluidMlPerServing => real().nullable()();

  // Brand and purchasing
  TextColumn get brandId => text().nullable()();   // References brands.id
  TextColumn get productType => text().nullable()(); // gel/chew/drink_mix/etc
  TextColumn get purchaseUrl => text().nullable()();
  TextColumn get affiliateSource => text().nullable()();

  // Food preferences filtering (added in v2.1)
  BoolColumn get showInPreferences => boolean().withDefault(const Constant(false))();
  IntColumn get preferencePriority => integer().withDefault(const Constant(999))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 7. categories ⭐ NEW IN V2

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

### 9. brands ⭐ NEW IN V2

**Purpose**: Brand information for affiliate features
**Primary Key**: id (UUID)

```dart
@DataClassName('BrandEntry')
class BrandsTable extends Table {
  TextColumn get id => text()();                   // UUID (PK)
  TextColumn get name => text()();
  TextColumn get websiteUrl => text().nullable()();
  TextColumn get affiliateProgramUrl => text().nullable()();
  TextColumn get affiliateNetwork => text().nullable()();
  TextColumn get defaultAffiliateUrl => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### 10. app_content ⭐ NEW IN V2

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

## Relationships and Foreign Keys

### Explicit Relationships
- **food_preferences.userId** → **user_profiles.id**
- **nutrition_plans.userId** → **user_profiles.id**
- **macro_targets.userId** → **user_profiles.id**
- **macro_targets.planId** → **nutrition_plans.id** (optional)
- **food_categories.foodId** → **foods.id**
- **food_categories.categoryId** → **categories.id**
- **foods.brandId** → **brands.id** (optional)

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
CREATE INDEX idx_nutrition_plans_user_created ON nutrition_plans(user_id, created_at DESC);
CREATE INDEX idx_nutrition_plans_user_active ON nutrition_plans(user_id) WHERE is_deleted = 0;

-- Food searches
CREATE INDEX idx_foods_name ON foods(name);
CREATE INDEX idx_foods_before_run ON foods(before_run_suitable) WHERE before_run_suitable = 1;
CREATE INDEX idx_foods_during_run ON foods(during_run_suitable) WHERE during_run_suitable = 1;
CREATE INDEX idx_foods_preferences ON foods(show_in_preferences) WHERE show_in_preferences = 1;
CREATE INDEX idx_foods_preference_priority ON foods(preference_priority, name);

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

// Get foods for preferences screen (ordered by priority)
final preferenceFoods = await (database.select(database.foodsTable)
  ..where(database.foodsTable.showInPreferences.equals(true))
  ..orderBy([
    (t) => OrderingTerm.asc(t.preferencePriority),
    (t) => OrderingTerm.asc(t.name)
  ])).get();

// Get foods with brand information
final foodsWithBrands = await (database.select(database.foodsTable)
  ..join([
    leftOuterJoin(database.brandsTable,
      database.brandsTable.id.equalsExp(database.foodsTable.brandId))
  ])).get();
```

### Nutrition Plan Management
```dart
// Save new plan
await database.saveNutritionPlan(plan);

// Get user's latest plan
final latestPlan = await database.getLatestNutritionPlan(userId);

// Get plan history
final allPlans = await database.getAllNutritionPlans(userId);

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