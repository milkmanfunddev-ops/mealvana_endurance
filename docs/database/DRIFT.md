# Drift Database Implementation Guide

## 📋 **Table of Contents**
- [What is Drift?](#what-is-drift)
- [Why Drift for Mealvana Endurance?](#why-drift-for-mealvana-endurance)
- [Core Concepts](#core-concepts)
- [Database Setup](#database-setup)
- [Table Definitions](#table-definitions)
- [Schema Migrations](#schema-migrations)
- [Query Operations](#query-operations)
- [Repository Patterns](#repository-patterns)
- [Advanced Features](#advanced-features)
- [Performance Optimization](#performance-optimization)
- [Testing Strategies](#testing-strategies)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## What is Drift?

**Drift** is a reactive persistence library for Flutter and Dart, built on top of SQLite. It provides a powerful, type-safe way to work with databases while offering excellent tooling for migrations, queries, and code generation.

### Key Features

🔧 **Type-Safe Database Operations**
- Compile-time validation of SQL queries
- Generated Dart classes for all tables and queries
- Strong typing prevents runtime errors

📊 **Advanced Query Builder**
- Fluent API for building complex SQL queries
- Support for joins, subqueries, and aggregations
- Compile-time verification of query correctness

🔄 **Automatic Schema Migrations**
- Built-in versioning system
- Auto-generated migration code
- Comprehensive migration testing

⚡ **High Performance**
- Direct SQLite integration
- Prepared statements for optimal performance
- Support for concurrent operations

🧪 **Excellent Testing Support**
- In-memory database for unit tests
- Migration test generation
- Schema validation tools

## Why Drift for Mealvana Endurance?

### Migration from Hive Benefits

| Aspect | Hive (Previous) | Drift (Current) | Improvement |
|--------|-----------------|-----------------|-------------|
| **Type Safety** | Runtime type cast errors | Compile-time validation | ✅ Zero runtime type errors |
| **Migrations** | Manual, error-prone | Automatic generation | ✅ Safe schema evolution |
| **Relationships** | Limited support | Full SQL relationships | ✅ Complex data modeling |
| **Queries** | Basic key-value | Full SQL support | ✅ Powerful data retrieval |
| **Performance** | File-based storage | Optimized SQLite | ✅ Better query performance |
| **Testing** | Manual testing | Auto-generated tests | ✅ Comprehensive coverage |

### Perfect Fit for Nutrition App

🍏 **Complex Food Relationships**
- Many-to-many relationships between foods and categories
- User preferences linked to specific foods
- Nutrition plans with detailed macro calculations

📱 **Offline-First Architecture**
- Full functionality without network connection
- Local data persistence with sync capabilities
- Immediate response for user interactions

🔄 **Schema Evolution**
- Safe addition of new nutrition metrics
- Algorithm parameter updates
- User preference system enhancements

## Core Concepts

### 1. Database Classes

```dart
@DriftDatabase(tables: [Users, FoodPreferences, NutritionPlans])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;
  
  // Migration strategy defined here
}
```

### 2. Table Definitions

```dart
@DataClassName('UserProfile')
class Users extends Table {
  TextColumn get deviceId => text()();
  IntColumn get gender => intEnum<Gender>()();
  DateTimeColumn get birthday => dateTime()();
  
  @override
  Set<Column> get primaryKey => {deviceId};
}
```

### 3. Generated Code

Drift automatically generates:
- Data classes (`UserProfile`, `FoodPreference`)
- Companion classes for inserts (`UsersCompanion`)
- Database accessor methods
- Migration helpers

### 4. Query Building

```dart
// Type-safe query building
final users = await select(database.users)
  .where((user) => user.gender.equals(Gender.male.index))
  .get();
```

## Database Setup

### Basic Configuration

```dart
// lib/shared/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Import table definitions
import 'tables/users.dart';
import 'tables/food_preferences.dart';
import 'tables/nutrition_plans.dart';
import 'tables/app_content.dart';
import 'tables/feedback.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  FoodPreferences,
  NutritionPlans,
  AppContent,
  Feedback,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: stepByStep(
        // Migration steps will be auto-generated
      ),
      beforeOpen: (details) async {
        // Configure SQLite settings
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'mealvana_endurance_db',
      setup: (database) {
        // Optimize for mobile performance
        database.execute('PRAGMA cache_size = -2000'); // 2MB cache
        database.execute('PRAGMA synchronous = NORMAL');
      },
    );
  }
}
```

### Dependency Injection

```dart
// lib/shared/providers/database_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
}
```

## Table Definitions

### User Profiles Table

```dart
// lib/shared/database/tables/users.dart
import 'package:drift/drift.dart';

@DataClassName('UserProfile')
class Users extends Table {
  // Primary key - device identifier for privacy
  TextColumn get deviceId => text()();
  
  // User demographics
  IntColumn get gender => intEnum<Gender>()();
  DateTimeColumn get birthday => dateTime()();
  
  // Physical characteristics  
  IntColumn get heightFeet => integer()();
  IntColumn get heightInches => integer()();
  RealColumn get weightPounds => real()();
  
  // Running preferences
  BooleanColumn get runsWithWaterBottle => boolean()();
  IntColumn get gutTraining => intEnum<GutTraining>().withDefault(const Constant(1))();
  
  // App state
  BooleanColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get appVersion => text().withDefault(const Constant('1.0.0'))();
  
  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();

  @override
  String get tableName => 'user_profiles';

  @override
  Set<Column> get primaryKey => {deviceId};

  // Custom indexes for performance
  @override
  List<Index> get customIndexes => [
    Index('idx_users_onboarding', [onboardingCompleted]),
    Index('idx_users_updated', [updatedAt]),
  ];
}

// Enums for type safety
enum Gender { male, female, other }
enum GutTraining { low, moderate, high }
```

### Food Preferences Table

```dart
// lib/shared/database/tables/food_preferences.dart
@DataClassName('FoodPreference')
class FoodPreferences extends Table {
  // UUID primary key
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  
  // Foreign key to users table
  TextColumn get deviceId => text().references(Users, #deviceId, onDelete: KeyAction.cascade)();
  
  // Food identification
  TextColumn get foodName => text()();
  
  // Preference level (like, dislike, willing_to_try)
  IntColumn get preference => intEnum<PreferenceType>()();
  
  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();

  @override
  String get tableName => 'food_preferences';

  @override
  Set<Column> get primaryKey => {id};

  // Ensure one preference per user per food
  @override
  List<Set<Column>> get uniqueKeys => [
    {deviceId, foodName},
  ];

  // Performance indexes
  @override
  List<Index> get customIndexes => [
    Index('idx_food_prefs_device', [deviceId]),
    Index('idx_food_prefs_device_food', [deviceId, foodName]),
    Index('idx_food_prefs_preference', [preference]),
  ];
}

enum PreferenceType { like, dislike, willingToTry }
```

### Nutrition Plans Table

```dart
// lib/shared/database/tables/nutrition_plans.dart
@DataClassName('NutritionPlan')
class NutritionPlans extends Table {
  // UUID primary key
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  
  // Foreign key to users
  TextColumn get deviceId => text().references(Users, #deviceId, onDelete: KeyAction.cascade)();
  
  // Plan metadata
  TextColumn get planName => text().nullable()();
  RealColumn get distance => real()();
  IntColumn get paceMinutes => integer()();
  IntColumn get paceSeconds => integer()();
  IntColumn get durationMinutes => integer()();
  
  // Plan data as JSON for flexibility
  TextColumn get planData => text().map(const JsonConverter())();
  
  // Versioning for conflict resolution
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get conflictResolution => text().withDefault(const Constant('last_write_wins'))();
  DateTimeColumn get clientUpdatedAt => dateTime().nullable()();
  
  // Soft delete support
  BooleanColumn get isDeleted => boolean().withDefault(const Constant(false))();
  
  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();

  @override
  String get tableName => 'nutrition_plans';

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get customIndexes => [
    Index('idx_nutrition_plans_device', [deviceId]),
    Index('idx_nutrition_plans_device_active', [deviceId, isDeleted]),
    Index('idx_nutrition_plans_updated', [updatedAt]),
  ];
}

// JSON converter for flexible plan data
class JsonConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonConverter();
  
  @override
  Map<String, dynamic> fromSql(String fromDb) {
    return json.decode(fromDb) as Map<String, dynamic>;
  }
  
  @override
  String toSql(Map<String, dynamic> value) {
    return json.encode(value);
  }
}
```

### App Content Table

```dart
// lib/shared/database/tables/app_content.dart
@DataClassName('AppContent')
class AppContent extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  
  // Environment targeting
  TextColumn get environment => text()(); // 'development', 'production'
  TextColumn get locale => text()(); // 'en-US', 'es-ES'
  
  // Content versioning
  IntColumn get version => integer()();
  BooleanColumn get isActive => boolean().withDefault(const Constant(true))();
  
  // Content data as JSON
  TextColumn get content => text().map(const JsonConverter())();
  
  // Metadata
  TextColumn get contentType => text()(); // 'ui_text', 'algorithm_params'
  TextColumn get description => text().nullable()();
  
  // Audit fields
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();

  @override
  String get tableName => 'app_content';

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get customIndexes => [
    Index('idx_app_content_env_locale', [environment, locale, isActive]),
    Index('idx_app_content_type', [contentType]),
  ];
}
```

### Feedback Table

```dart
// lib/shared/database/tables/feedback.dart
@DataClassName('UserFeedback')
class Feedback extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  
  // Satisfaction rating (1-3 scale)
  IntColumn get satisfactionLevel => integer().check(satisfactionLevel.isBetweenValues(1, 3))();
  TextColumn get satisfactionEmoji => text()();
  TextColumn get satisfactionLabel => text()();
  
  // Feedback content
  TextColumn get appFeedback => text().nullable()();
  TextColumn get suggestions => text().nullable()();
  
  // Context
  TextColumn get planName => text().nullable()();
  TextColumn get userName => text().nullable()();
  
  // Sync status
  BooleanColumn get synced => boolean().withDefault(const Constant(false))();
  
  // Timestamp
  DateTimeColumn get timestamp => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();

  @override
  String get tableName => 'feedback';

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Index> get customIndexes => [
    Index('idx_feedback_satisfaction', [satisfactionLevel]),
    Index('idx_feedback_synced', [synced]),
    Index('idx_feedback_timestamp', [timestamp]),
  ];
}
```

## Schema Migrations

### Migration Workflow

1. **Modify Schema**: Update table definitions
2. **Increment Version**: Bump `schemaVersion` in database class
3. **Generate Migration**: Run `dart run drift_dev make-migrations`
4. **Test Migration**: Run generated tests
5. **Deploy**: Release with confidence

### Migration Commands

```bash
# Generate migration after schema changes
dart run drift_dev make-migrations

# Export schema for version control
dart run drift_dev schema dump lib/shared/database/app_database.dart drift_schemas/

# Generate migration tests
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

# Run migration tests
dart test test/generated_migrations/
```

### Example Migration

```dart
// After adding a column and incrementing schemaVersion to 2
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        // Add new column with default value
        await m.addColumn(schema.users, schema.users.onboardingCompleted);
      },
      from2To3: (m, schema) async {
        // Create new table
        await m.createTable(schema.feedback);
      },
      from3To4: (m, schema) async {
        // Complex migration with data transformation
        await m.alterTable(TableMigration(
          schema.nutritionPlans,
          columnTransformer: {
            schema.nutritionPlans.planData: const Constant('{}'),
          },
        ));
      },
    ),
  );
}
```

### Migration Testing

```dart
// test/generated_migrations/schema_test.dart
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  
  group('Schema migrations', () {
    test('migration from v1 to v2 works correctly', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final executor = await verifier.startAt(1);
      
      // Insert test data in v1 schema
      await executor.runInsert(
        'INSERT INTO user_profiles (device_id, gender, birthday, height_feet, height_inches, weight_pounds, runs_with_water_bottle) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ['test-device', 0, '1990-01-01', 5, 10, 170.0, 1],
      );
      
      // Migrate to v2
      final database = AppDatabase.forTesting(executor);
      await verifier.migrateAndValidate(database, 2);
      
      // Verify data integrity and new column
      final user = await database.select(database.users).getSingle();
      expect(user.deviceId, 'test-device');
      expect(user.onboardingCompleted, false); // Should have default value
    });
    
    test('all migrations chain correctly', () async {
      // Test complete migration chain from v1 to latest
      final verifier = SchemaVerifier(GeneratedHelper());
      await verifier.migrateAndValidate(
        AppDatabase.forTesting(await verifier.startAt(1)),
        AppDatabase().schemaVersion,
      );
    });
  });
}
```

## Query Operations

### Basic CRUD Operations

```dart
class UserRepository {
  final AppDatabase _database;
  
  UserRepository(this._database);

  // CREATE
  Future<void> createUser(UserProfile user) async {
    await _database.into(_database.users).insert(user);
  }

  // READ - Single user
  Future<UserProfile?> getUser(String deviceId) async {
    return await (_database.select(_database.users)
          ..where((u) => u.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  // READ - All users (admin function)
  Future<List<UserProfile>> getAllUsers() async {
    return await _database.select(_database.users).get();
  }

  // UPDATE
  Future<void> updateUser(UserProfile user) async {
    await _database.update(_database.users).replace(user);
  }

  // DELETE
  Future<void> deleteUser(String deviceId) async {
    await (_database.delete(_database.users)
          ..where((u) => u.deviceId.equals(deviceId)))
        .go();
  }
}
```

### Advanced Queries

```dart
// Complex WHERE clauses
Future<List<UserProfile>> getActiveUsers() async {
  return await (_database.select(_database.users)
        ..where((u) => u.onboardingCompleted.equals(true))
        ..where((u) => u.createdAt.isBiggerThanValue(
            DateTime.now().subtract(const Duration(days: 30)))))
      .get();
}

// JOIN operations
Future<List<UserWithPreferences>> getUsersWithPreferences() async {
  final query = _database.select(_database.users).join([
    leftOuterJoin(
      _database.foodPreferences,
      _database.foodPreferences.deviceId.equalsExp(_database.users.deviceId),
    ),
  ]);

  final results = await query.get();
  
  return results.map((row) {
    final user = row.readTable(_database.users);
    final preferences = row.readTableOrNull(_database.foodPreferences);
    return UserWithPreferences(user: user, preferences: preferences);
  }).toList();
}

// Aggregation queries
Future<int> getTotalUsers() async {
  final result = await _database
      .selectOnly(_database.users)
      .addColumns([_database.users.deviceId.count()])
      .getSingle();
      
  return result.read(_database.users.deviceId.count()) ?? 0;
}

// Subqueries
Future<List<UserProfile>> getUsersWithManyPreferences() async {
  final subquery = _database.selectOnly(_database.foodPreferences)
      .addColumns([_database.foodPreferences.deviceId.count()])
      .where(_database.foodPreferences.deviceId.equalsExp(_database.users.deviceId))
      .map((row) => row.read(_database.foodPreferences.deviceId.count()) ?? 0);
  
  return await (_database.select(_database.users)
        ..where((u) => subquery.isBiggerThanValue(5)))
      .get();
}
```

### Reactive Queries with Streams

```dart
// Watch for changes
Stream<UserProfile?> watchUser(String deviceId) {
  return (_database.select(_database.users)
        ..where((u) => u.deviceId.equals(deviceId)))
      .watchSingleOrNull();
}

// Watch multiple records
Stream<List<FoodPreference>> watchUserPreferences(String deviceId) {
  return (_database.select(_database.foodPreferences)
        ..where((fp) => fp.deviceId.equals(deviceId)))
      .watch();
}

// Transform streams
Stream<bool> watchOnboardingStatus(String deviceId) {
  return watchUser(deviceId)
      .map((user) => user?.onboardingCompleted ?? false);
}
```

## Repository Patterns

### Base Repository Interface

```dart
// lib/shared/data/repositories/base_repository.dart
abstract class BaseRepository<T> {
  Future<void> insert(T entity);
  Future<T?> findById(String id);
  Future<List<T>> findAll();
  Future<void> update(T entity);
  Future<void> delete(String id);
  Stream<T?> watchById(String id);
  Stream<List<T>> watchAll();
}
```

### User Repository Implementation

```dart
// lib/shared/data/repositories/user_repository.dart
class DriftUserRepository implements BaseRepository<UserProfile> {
  final AppDatabase _database;
  
  DriftUserRepository(this._database);

  @override
  Future<void> insert(UserProfile user) async {
    await _database.transaction(() async {
      await _database.into(_database.users).insert(user);
    });
  }

  @override
  Future<UserProfile?> findById(String deviceId) async {
    return await (_database.select(_database.users)
          ..where((u) => u.deviceId.equals(deviceId)))
        .getSingleOrNull();
  }

  @override
  Future<List<UserProfile>> findAll() async {
    return await _database.select(_database.users).get();
  }

  @override
  Future<void> update(UserProfile user) async {
    await _database.transaction(() async {
      await _database.update(_database.users).replace(
        user.copyWith(updatedAt: DateTime.now()),
      );
    });
  }

  @override
  Future<void> delete(String deviceId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.users)
            ..where((u) => u.deviceId.equals(deviceId)))
          .go();
    });
  }

  @override
  Stream<UserProfile?> watchById(String deviceId) {
    return (_database.select(_database.users)
          ..where((u) => u.deviceId.equals(deviceId)))
        .watchSingleOrNull();
  }

  @override
  Stream<List<UserProfile>> watchAll() {
    return _database.select(_database.users).watch();
  }

  // Domain-specific methods
  Future<void> completeOnboarding(String deviceId) async {
    await (_database.update(_database.users)
          ..where((u) => u.deviceId.equals(deviceId)))
        .write(UsersCompanion(
          onboardingCompleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Future<List<UserProfile>> findByGutTraining(GutTraining training) async {
    return await (_database.select(_database.users)
          ..where((u) => u.gutTraining.equals(training.index)))
        .get();
  }
}
```

### Food Preferences Repository

```dart
// lib/shared/data/repositories/food_preferences_repository.dart
class DriftFoodPreferencesRepository {
  final AppDatabase _database;
  
  DriftFoodPreferencesRepository(this._database);

  Future<void> savePreferences(
    String deviceId,
    Map<String, PreferenceType> preferences,
  ) async {
    await _database.transaction(() async {
      // Clear existing preferences
      await (_database.delete(_database.foodPreferences)
            ..where((fp) => fp.deviceId.equals(deviceId)))
          .go();
      
      // Insert new preferences in batch
      await _database.batch((batch) {
        for (final entry in preferences.entries) {
          batch.insert(
            _database.foodPreferences,
            FoodPreferencesCompanion.insert(
              deviceId: deviceId,
              foodName: entry.key,
              preference: entry.value,
            ),
          );
        }
      });
    });
  }

  Future<Map<String, PreferenceType>> getPreferences(String deviceId) async {
    final preferences = await (_database.select(_database.foodPreferences)
          ..where((fp) => fp.deviceId.equals(deviceId)))
        .get();
    
    return {
      for (final pref in preferences)
        pref.foodName: pref.preference
    };
  }

  Future<List<String>> getLikedFoods(String deviceId) async {
    final liked = await (_database.select(_database.foodPreferences)
          ..where((fp) => fp.deviceId.equals(deviceId))
          ..where((fp) => fp.preference.equals(PreferenceType.like.index)))
        .get();
    
    return liked.map((pref) => pref.foodName).toList();
  }

  Future<void> updatePreference(
    String deviceId,
    String foodName,
    PreferenceType preference,
  ) async {
    await _database.into(_database.foodPreferences).insertOnConflictUpdate(
      FoodPreferencesCompanion.insert(
        deviceId: deviceId,
        foodName: foodName,
        preference: preference,
      ),
    );
  }

  Stream<Map<String, PreferenceType>> watchPreferences(String deviceId) {
    return (_database.select(_database.foodPreferences)
          ..where((fp) => fp.deviceId.equals(deviceId)))
        .watch()
        .map((preferences) => {
          for (final pref in preferences)
            pref.foodName: pref.preference
        });
  }
}
```

## Advanced Features

### Custom SQL Functions

```dart
// lib/shared/database/custom_functions.dart
extension CustomQueries on AppDatabase {
  // Raw SQL for complex operations
  Future<List<Map<String, dynamic>>> getUserStats() async {
    return await customSelect('''
      SELECT 
        COUNT(*) as total_users,
        COUNT(CASE WHEN onboarding_completed = 1 THEN 1 END) as completed_onboarding,
        AVG(weight_pounds) as avg_weight
      FROM user_profiles
    ''').get();
  }

  // Parameterized custom queries
  Future<List<UserProfile>> findUsersByAgeRange(int minAge, int maxAge) async {
    final today = DateTime.now();
    final maxBirthDate = DateTime(today.year - minAge, today.month, today.day);
    final minBirthDate = DateTime(today.year - maxAge, today.month, today.day);
    
    return await customSelect('''
      SELECT * FROM user_profiles 
      WHERE birthday BETWEEN ? AND ?
    ''', variables: [
      Variable.withDateTime(minBirthDate),
      Variable.withDateTime(maxBirthDate),
    ]).map((row) {
      return UserProfile(
        deviceId: row.read<String>('device_id'),
        gender: Gender.values[row.read<int>('gender')],
        birthday: row.read<DateTime>('birthday'),
        // ... map other fields
      );
    }).get();
  }
}
```

### Database Views

```dart
// lib/shared/database/views/user_summary_view.dart
@UseRowClass(UserSummary)
abstract class UserSummaryView extends View {
  Users get users => select([
    users.deviceId,
    users.gender,
    users.onboardingCompleted,
    users.createdAt,
  ]);
  
  FoodPreferences get preferences => select([
    preferences.deviceId.count().as('preference_count'),
  ]);

  @override
  Query as() => select([
    users.deviceId,
    users.gender,
    users.onboardingCompleted,
    users.createdAt,
    preferences.preference.count().as('preference_count'),
  ])
  .from(users)
  .leftOuterJoin(preferences, preferences.deviceId.equalsExp(users.deviceId))
  .groupBy([users.deviceId]);
}

@DataClassName('UserSummary')
class UserSummary {
  final String deviceId;
  final Gender gender;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final int preferenceCount;
  
  UserSummary({
    required this.deviceId,
    required this.gender,
    required this.onboardingCompleted,
    required this.createdAt,
    required this.preferenceCount,
  });
}
```

### Triggers and Constraints

```dart
// lib/shared/database/tables/users.dart
class Users extends Table {
  // ... column definitions ...

  // Custom constraints
  @override
  List<String> get customConstraints => [
    'CHECK (height_feet > 0 AND height_feet < 10)',
    'CHECK (height_inches >= 0 AND height_inches < 12)',
    'CHECK (weight_pounds > 0 AND weight_pounds < 1000)',
  ];
}

// Custom triggers can be added in migration
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      
      // Add trigger to update timestamp
      await m.execute('''
        CREATE TRIGGER update_user_timestamp 
        AFTER UPDATE ON user_profiles
        BEGIN
          UPDATE user_profiles 
          SET updated_at = CURRENT_TIMESTAMP 
          WHERE device_id = NEW.device_id;
        END
      ''');
    },
  );
}
```

## Performance Optimization

### Indexing Strategies

```dart
// Composite indexes for common query patterns
class FoodPreferences extends Table {
  // ... columns ...

  @override
  List<Index> get customIndexes => [
    // Single column indexes
    Index('idx_food_prefs_device', [deviceId]),
    Index('idx_food_prefs_preference', [preference]),
    
    // Composite indexes for complex queries
    Index('idx_food_prefs_device_pref', [deviceId, preference]),
    Index('idx_food_prefs_device_food', [deviceId, foodName]),
    
    // Partial indexes for specific conditions
    Index('idx_food_prefs_liked', [deviceId], 
          where: preference.equals(PreferenceType.like.index)),
  ];
}
```

### Prepared Statements

```dart
class OptimizedQueries {
  final AppDatabase _database;
  
  // Prepared statements for frequently used queries
  late final Selectable<UserProfile> _getUserByDevice;
  late final Selectable<FoodPreference> _getPreferencesByDevice;
  
  OptimizedQueries(this._database) {
    _getUserByDevice = _database.select(_database.users)
      ..where((u) => u.deviceId.equals(Variable.withString()));
      
    _getPreferencesByDevice = _database.select(_database.foodPreferences)
      ..where((fp) => fp.deviceId.equals(Variable.withString()));
  }
  
  Future<UserProfile?> getUserFast(String deviceId) async {
    return await _getUserByDevice.getSingleOrNull();
  }
  
  Future<List<FoodPreference>> getPreferencesFast(String deviceId) async {
    return await _getPreferencesByDevice.get();
  }
}
```

### Batch Operations

```dart
// Efficient bulk operations
Future<void> insertManyUsers(List<UserProfile> users) async {
  await _database.batch((batch) {
    for (final user in users) {
      batch.insert(_database.users, user);
    }
  });
}

// Bulk updates
Future<void> updateAllUserVersions(String newVersion) async {
  await _database.transaction(() async {
    await _database.update(_database.users).write(
      UsersCompanion(
        appVersion: Value(newVersion),
        updatedAt: Value(DateTime.now()),
      ),
    );
  });
}
```

### Connection Optimization

```dart
static QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'mealvana_db',
    setup: (database) {
      // Performance optimizations
      database.execute('PRAGMA cache_size = -8000'); // 8MB cache
      database.execute('PRAGMA journal_mode = WAL'); // Write-ahead logging
      database.execute('PRAGMA synchronous = NORMAL'); // Balanced durability
      database.execute('PRAGMA foreign_keys = ON'); // Referential integrity
      database.execute('PRAGMA temp_store = MEMORY'); // In-memory temp storage
      
      // Optional: connection pooling for high-load scenarios
      database.execute('PRAGMA max_page_count = 1073741823'); // ~4TB limit
    },
  );
}
```

## Testing Strategies

### Unit Testing Setup

```dart
// test/database/database_test_setup.dart
class DatabaseTestSetup {
  static AppDatabase createTestDatabase() {
    return AppDatabase.forTesting(NativeDatabase.memory());
  }
  
  static Future<AppDatabase> createPopulatedTestDatabase() async {
    final database = createTestDatabase();
    
    // Insert test data
    await database.into(database.users).insert(
      UsersCompanion.insert(
        deviceId: 'test-device',
        gender: Gender.male,
        birthday: DateTime(1990, 1, 1),
        heightFeet: 5,
        heightInches: 10,
        weightPounds: 170.0,
        runsWithWaterBottle: true,
      ),
    );
    
    await database.into(database.foodPreferences).insertAll([
      FoodPreferencesCompanion.insert(
        deviceId: 'test-device',
        foodName: 'Oatmeal',
        preference: PreferenceType.like,
      ),
      FoodPreferencesCompanion.insert(
        deviceId: 'test-device',
        foodName: 'Energy Gel',
        preference: PreferenceType.willingToTry,
      ),
    ]);
    
    return database;
  }
}
```

### Repository Testing

```dart
// test/repositories/user_repository_test.dart
void main() {
  late AppDatabase database;
  late DriftUserRepository repository;

  setUp(() async {
    database = DatabaseTestSetup.createTestDatabase();
    repository = DriftUserRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('UserRepository', () {
    test('should insert and retrieve user', () async {
      final user = UsersCompanion.insert(
        deviceId: 'test-device',
        gender: Gender.female,
        birthday: DateTime(1995, 6, 15),
        heightFeet: 5,
        heightInches: 6,
        weightPounds: 140.0,
        runsWithWaterBottle: false,
      );

      await repository.insert(user);
      final retrieved = await repository.findById('test-device');

      expect(retrieved, isNotNull);
      expect(retrieved!.deviceId, 'test-device');
      expect(retrieved.gender, Gender.female);
    });

    test('should update user successfully', () async {
      final user = UsersCompanion.insert(
        deviceId: 'test-device',
        gender: Gender.male,
        birthday: DateTime(1990, 1, 1),
        heightFeet: 5,
        heightInches: 10,
        weightPounds: 170.0,
        runsWithWaterBottle: true,
      );

      await repository.insert(user);
      
      final retrieved = await repository.findById('test-device');
      final updated = retrieved!.copyWith(
        onboardingCompleted: true,
        weightPounds: 165.0,
      );
      
      await repository.update(updated);
      final final = await repository.findById('test-device');

      expect(final!.onboardingCompleted, true);
      expect(final.weightPounds, 165.0);
    });

    test('should watch user changes', () async {
      final user = UsersCompanion.insert(
        deviceId: 'test-device',
        gender: Gender.other,
        birthday: DateTime(1985, 12, 25),
        heightFeet: 6,
        heightInches: 2,
        weightPounds: 180.0,
        runsWithWaterBottle: true,
      );

      await repository.insert(user);
      
      final stream = repository.watchById('test-device');
      
      expect(stream, emits(isA<UserProfile>()
          .having((u) => u.deviceId, 'deviceId', 'test-device')));
          
      // Update user and verify stream emits change
      await repository.completeOnboarding('test-device');
      
      expect(stream, emits(isA<UserProfile>()
          .having((u) => u.onboardingCompleted, 'completed', true)));
    });
  });
}
```

### Integration Testing

```dart
// test/integration/database_integration_test.dart
void main() {
  late AppDatabase database;

  setUp(() async {
    database = DatabaseTestSetup.createTestDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  test('should handle complete user flow', () async {
    // Create user
    final user = UsersCompanion.insert(
      deviceId: 'integration-test',
      gender: Gender.female,
      birthday: DateTime(1992, 3, 10),
      heightFeet: 5,
      heightInches: 4,
      weightPounds: 125.0,
      runsWithWaterBottle: false,
    );
    
    await database.into(database.users).insert(user);

    // Add food preferences
    await database.batch((batch) {
      batch.insert(database.foodPreferences, 
          FoodPreferencesCompanion.insert(
            deviceId: 'integration-test',
            foodName: 'Banana',
            preference: PreferenceType.like,
          ));
      batch.insert(database.foodPreferences, 
          FoodPreferencesCompanion.insert(
            deviceId: 'integration-test',
            foodName: 'Sports Drink',
            preference: PreferenceType.like,
          ));
    });

    // Create nutrition plan
    final plan = NutritionPlansCompanion.insert(
      deviceId: 'integration-test',
      distance: 10.0,
      paceMinutes: 8,
      paceSeconds: 30,
      durationMinutes: 85,
      planData: {
        'preRun': ['Banana'],
        'duringRun': ['Sports Drink'],
        'afterRun': ['Recovery Shake'],
      },
    );
    
    await database.into(database.nutritionPlans).insert(plan);

    // Verify complete data structure
    final retrievedUser = await database.select(database.users)
        .where((u) => u.deviceId.equals('integration-test'))
        .getSingle();
        
    final preferences = await database.select(database.foodPreferences)
        .where((fp) => fp.deviceId.equals('integration-test'))
        .get();
        
    final plans = await database.select(database.nutritionPlans)
        .where((np) => np.deviceId.equals('integration-test'))
        .get();

    expect(retrievedUser.deviceId, 'integration-test');
    expect(preferences.length, 2);
    expect(plans.length, 1);
    expect(plans.first.planData['preRun'], contains('Banana'));
  });
}
```

## Best Practices

### 1. Schema Design

✅ **DO:**
- Use meaningful table and column names
- Add appropriate constraints and indexes
- Include audit fields (created_at, updated_at)
- Use enums for limited value sets
- Design for query patterns you'll actually use

❌ **DON'T:**
- Create unnecessary indexes (they slow down writes)
- Use overly generic column names
- Skip foreign key constraints
- Store JSON when relational design is better

### 2. Query Optimization

✅ **DO:**
- Use prepared statements for repeated queries
- Leverage indexes for WHERE clauses
- Use batch operations for bulk changes
- Stream results for reactive UI updates

❌ **DON'T:**
- Query in loops (use JOINs or IN clauses)
- Fetch unnecessary columns
- Ignore query performance in tests
- Use SELECT * in production code

### 3. Transaction Management

✅ **DO:**
- Use transactions for related operations
- Keep transactions short and focused
- Handle rollback scenarios
- Use batch operations within transactions

❌ **DON'T:**
- Leave transactions open for long periods
- Nest transactions unnecessarily
- Ignore transaction errors
- Perform network calls within transactions

### 4. Migration Safety

✅ **DO:**
- Test all migrations thoroughly
- Use step-by-step migrations
- Include data migration scripts
- Plan rollback strategies

❌ **DON'T:**
- Skip migration testing
- Make breaking changes without migration
- Ignore data integrity during migrations
- Deploy without backup plans

## Common Patterns

### Repository Provider Pattern

```dart
// lib/shared/providers/repository_providers.dart
@riverpod
DriftUserRepository userRepository(UserRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  return DriftUserRepository(database);
}

@riverpod
DriftFoodPreferencesRepository foodPreferencesRepository(
    FoodPreferencesRepositoryRef ref) {
  final database = ref.watch(appDatabaseProvider);
  return DriftFoodPreferencesRepository(database);
}
```

### Service Layer Pattern

```dart
// lib/features/auth/application/auth_service.dart
class AuthService {
  final DriftUserRepository _userRepository;
  final DriftFoodPreferencesRepository _preferencesRepository;
  
  AuthService(this._userRepository, this._preferencesRepository);
  
  Future<void> completeOnboarding({
    required UserProfile user,
    required Map<String, PreferenceType> preferences,
  }) async {
    // Use transaction to ensure consistency
    await _userRepository._database.transaction(() async {
      await _userRepository.update(
        user.copyWith(onboardingCompleted: true),
      );
      
      await _preferencesRepository.savePreferences(
        user.deviceId,
        preferences,
      );
    });
  }
}
```

### Data Sync Pattern

```dart
// lib/shared/services/sync_service.dart
class SyncService {
  final AppDatabase _database;
  final ApiClient _apiClient;
  
  SyncService(this._database, this._apiClient);
  
  Future<void> syncToServer(String deviceId) async {
    final user = await _database.select(_database.users)
        .where((u) => u.deviceId.equals(deviceId))
        .getSingleOrNull();
        
    if (user != null) {
      try {
        await _apiClient.updateUser(user.toJson());
        
        // Mark as synced
        await _database.update(_database.users)
            .where((u) => u.deviceId.equals(deviceId))
            .write(UsersCompanion(
              updatedAt: Value(DateTime.now()),
            ));
      } catch (e) {
        // Handle sync failure
        print('Sync failed: $e');
      }
    }
  }
}
```

## Troubleshooting

### Common Issues

**1. Migration Errors**
```
Error: Cannot add non-null column without default value
```
**Solution:** Add default value or make column nullable:
```dart
BooleanColumn get newField => boolean().withDefault(const Constant(false))();
```

**2. Foreign Key Violations**
```
Error: FOREIGN KEY constraint failed
```
**Solution:** Ensure foreign keys are enabled and references exist:
```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

**3. Unique Constraint Violations**
```
Error: UNIQUE constraint failed
```
**Solution:** Use `insertOnConflictUpdate` or check for existing records:
```dart
await database.into(database.users).insertOnConflictUpdate(user);
```

**4. Type Cast Errors**
```
Error: type 'Null' is not a subtype of type 'DateTime'
```
**Solution:** Use nullable columns or provide defaults:
```dart
DateTimeColumn get timestamp => dateTime().nullable()();
// or
DateTimeColumn get timestamp => dateTime().withDefault(currentTimestamp)();
```

### Performance Issues

**1. Slow Queries**
- Add appropriate indexes
- Use `EXPLAIN QUERY PLAN` to analyze
- Consider query restructuring

**2. Memory Issues**
- Use streaming for large result sets
- Implement pagination
- Close database connections properly

**3. Lock Timeouts**
- Keep transactions short
- Avoid long-running operations in transactions
- Use WAL mode for better concurrency

### Debugging Tips

```dart
// Enable SQL logging in debug mode
void main() {
  if (kDebugMode) {
    // Log all SQL statements
    driftRuntimeOptions.debugPrint = (statement) {
      print('SQL: $statement');
    };
  }
  
  runApp(MyApp());
}

// Use database inspector
extension DatabaseDebugging on AppDatabase {
  Future<void> printTableStats() async {
    final users = await select(this.users).get();
    final preferences = await select(foodPreferences).get();
    final plans = await select(nutritionPlans).get();
    
    print('Database Stats:');
    print('  Users: ${users.length}');
    print('  Food Preferences: ${preferences.length}');
    print('  Nutrition Plans: ${plans.length}');
  }
}
```

---

This comprehensive Drift guide provides everything needed to understand, implement, and maintain the database layer for Mealvana Endurance. The type-safe, migration-friendly architecture ensures robust data management while supporting the app's offline-first nutrition planning requirements.