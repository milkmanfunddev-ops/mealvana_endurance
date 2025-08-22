# Drift Database Implementation - Mealvana Endurance

## Overview

Drift-based SQLite database implementation for the Mealvana Endurance nutrition planning app, providing type-safe local data persistence with automatic schema migrations, compile-time query validation, and robust relationship management. The database layer supports the app's offline-first architecture with full ACID transaction support.

## Database Architecture

### Table Organization

The app organizes data into structured SQLite tables with proper relationships:

**Core Tables**: Store user profiles, food preferences, and nutrition plans with foreign key constraints ensuring data integrity. All tables include automatic timestamp management and optimistic concurrency control.

**Relationship Tables**: Enable complex many-to-many relationships between foods and categories, users and preferences, with proper indexing for fast queries.

**Content Tables**: Store dynamic app content with versioning support for A/B testing and remote configuration updates.

```dart
// lib/shared/database/app_database.dart
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
        // Generated migration steps
      ),
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'mealvana_db',
      setup: (database) {
        database.execute('PRAGMA journal_mode=WAL');
        database.execute('PRAGMA synchronous=NORMAL');
      },
    );
  }
}
```

### Table Definitions

The database maintains strongly-typed tables for endurance nutrition planning:

**User Profile Table**: Stores complete user profiles with typed columns for biometrics, running preferences, and onboarding status. Includes automatic timestamp management and default values.

**Food Preferences Table**: Maintains relationships between users and their food preferences with foreign key constraints. Supports three preference levels with proper validation.

**Nutrition Plans Table**: Stores generated plans with JSONB data for flexibility and versioning for conflict resolution.

```dart
// lib/shared/database/tables/users.dart
@DataClassName('UserProfile')
class Users extends Table {
  TextColumn get deviceId => text()();
  IntColumn get gender => intEnum<Gender>()();
  DateTimeColumn get birthday => dateTime()();
  IntColumn get heightFeet => integer()();
  IntColumn get heightInches => integer()();
  RealColumn get weightPounds => real()();
  BooleanColumn get runsWithWaterBottle => boolean()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();
  IntColumn get gutTraining => intEnum<GutTraining>().withDefault(const Constant(1))();
  BooleanColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get appVersion => text().withDefault(const Constant('1.0.0'))();

  @override
  String get tableName => 'user_profiles';

  @override
  Set<Column> get primaryKey => {deviceId};
}

// lib/shared/database/tables/food_preferences.dart  
@DataClassName('FoodPreference')
class FoodPreferences extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get deviceId => text().references(Users, #deviceId, onDelete: KeyAction.cascade)();
  TextColumn get foodName => text()();
  IntColumn get preference => intEnum<PreferenceType>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();

  @override
  String get tableName => 'food_preferences';

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {deviceId, foodName},
  ];
}
```

## Repository Implementation

### Type-Safe Data Access

The data access layer uses generated classes for complete type safety:

```dart
// lib/shared/data/drift_user_repository.dart
class DriftUserRepository implements UserRepository {
  final AppDatabase _database;
  
  DriftUserRepository(this._database);

  @override
  Future<UserProfile?> getCurrentUser() async {
    return await (_database.select(_database.users))
        .getSingleOrNull();
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    await _database.transaction(() async {
      await _database.into(_database.users).insertOnConflictUpdate(profile);
    });
  }

  @override
  Stream<UserProfile?> watchCurrentUser() {
    return _database.select(_database.users).watchSingleOrNull();
  }

  @override
  Future<List<FoodPreference>> getFoodPreferences(String deviceId) async {
    return await (_database.select(_database.foodPreferences)
          ..where((fp) => fp.deviceId.equals(deviceId)))
        .get();
  }

  @override
  Future<void> saveFoodPreferences(
    String deviceId, 
    Map<String, PreferenceType> preferences,
  ) async {
    await _database.transaction(() async {
      // Clear existing preferences
      await (_database.delete(_database.foodPreferences)
            ..where((fp) => fp.deviceId.equals(deviceId)))
          .go();
      
      // Insert new preferences with batch operation
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
}
```

### Complex Query Support

Drift enables type-safe complex queries with compile-time validation:

```dart
// lib/shared/data/nutrition_plan_repository.dart
class DriftNutritionPlanRepository implements NutritionPlanRepository {
  final AppDatabase _database;

  DriftNutritionPlanRepository(this._database);

  @override
  Future<List<NutritionPlan>> getPlansForUser(String deviceId) async {
    return await (_database.select(_database.nutritionPlans)
          ..where((np) => np.deviceId.equals(deviceId))
          ..where((np) => np.isDeleted.equals(false))
          ..orderBy([(np) => OrderingTerm.desc(np.createdAt)]))
        .get();
  }

  @override
  Future<NutritionPlan?> getLatestPlan(String deviceId) async {
    return await (_database.select(_database.nutritionPlans)
          ..where((np) => np.deviceId.equals(deviceId))
          ..where((np) => np.isDeleted.equals(false))
          ..orderBy([(np) => OrderingTerm.desc(np.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  // Join query with food preferences
  @override
  Future<List<PlanWithPreferences>> getPlansWithPreferences(String deviceId) async {
    final query = _database.select(_database.nutritionPlans).join([
      leftOuterJoin(
        _database.foodPreferences,
        _database.foodPreferences.deviceId.equalsExp(_database.nutritionPlans.deviceId),
      ),
    ]);

    query.where(_database.nutritionPlans.deviceId.equals(deviceId));

    final results = await query.get();
    
    return results.map((row) {
      final plan = row.readTable(_database.nutritionPlans);
      final preference = row.readTableOrNull(_database.foodPreferences);
      return PlanWithPreferences(plan: plan, preferences: preference);
    }).toList();
  }
}
```

## Schema Migration System

### Automatic Migration Generation

Drift automatically generates migration code based on schema changes:

```bash
# After modifying table definitions and incrementing schemaVersion:
dart run drift_dev make-migrations

# This generates:
# - Schema export files in drift_schemas/
# - Migration step functions 
# - Test files for validating migrations
```

### Generated Migration Example

```dart
// Generated in database.dart
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
        await m.createTable(schema.foodPreferences);
        
        // Add foreign key constraint
        await m.addColumn(schema.foodPreferences, schema.foodPreferences.deviceId);
      },
      from3To4: (m, schema) async {
        // Complex table migration with data transformation
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

Drift generates comprehensive tests for all migrations:

```dart
// test/generated_migrations/schema_test.dart  
void main() {
  group('Migration tests', () {
    test('from version 1 to 2', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final executor = await verifier.startAt(1);
      
      // Create test data in old schema
      await executor.runInsert(
        'INSERT INTO user_profiles (device_id, gender, birthday) VALUES (?, ?, ?)',
        ['test-device', 0, '1990-01-01'],
      );
      
      // Run migration
      final database = AppDatabase.forTesting(executor);
      await verifier.migrateAndValidate(database, 2);
      
      // Verify data integrity
      final user = await database.select(database.users).getSingle();
      expect(user.deviceId, 'test-device');
      expect(user.onboardingCompleted, false); // Should have default
    });
  });
}
```

## Performance Optimization

### Strategic Indexing

Drift supports custom indexes for query optimization:

```dart
@DataClassName('UserProfile')
class Users extends Table {
  // ... column definitions ...

  @override
  List<Index> get customIndexes => [
    Index('idx_users_updated_at', [updatedAt]),
    Index('idx_users_onboarding', [onboardingCompleted]),
  ];
}

@DataClassName('FoodPreference')
class FoodPreferences extends Table {
  // ... column definitions ...

  @override
  List<Index> get customIndexes => [
    Index('idx_food_prefs_device_id', [deviceId]),
    Index('idx_food_prefs_device_food', [deviceId, foodName]),
    Index('idx_food_prefs_preference', [preference]),
  ];
}
```

### Query Optimization

Use prepared statements and batch operations for better performance:

```dart
class OptimizedRepository {
  final AppDatabase _database;

  // Prepared statement for frequent queries
  late final Selectable<UserProfile> _getUserByDevice;
  
  OptimizedRepository(this._database) {
    _getUserByDevice = _database.select(_database.users)
      ..where((u) => u.deviceId.equals(Variable.withString()));
  }

  Future<UserProfile?> getUserFast(String deviceId) async {
    return await _getUserByDevice.getSingleOrNull();
  }

  // Batch operations for bulk inserts
  Future<void> saveManyPreferences(List<FoodPreference> preferences) async {
    await _database.batch((batch) {
      for (final pref in preferences) {
        batch.insert(_database.foodPreferences, pref);
      }
    });
  }
}
```

### Connection Optimization

Configure SQLite for optimal performance:

```dart
static QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'mealvana_db',
    setup: (database) {
      // Enable WAL mode for better concurrency
      database.execute('PRAGMA journal_mode=WAL');
      // Optimize for mobile performance
      database.execute('PRAGMA synchronous=NORMAL');
      // Increase cache size
      database.execute('PRAGMA cache_size=-2000'); // 2MB cache
      // Enable foreign keys
      database.execute('PRAGMA foreign_keys=ON');
    },
  );
}
```

## Data Synchronization

### Offline-First Design

The database supports offline operation with sync capabilities:

```dart
class SyncService {
  final AppDatabase _database;
  final ApiClient _apiClient;

  SyncService(this._database, this._apiClient);

  Future<void> syncUserData(String deviceId) async {
    await _database.transaction(() async {
      // Upload local changes
      final localUser = await _database.select(_database.users)
          .getSingleOrNull();
      
      if (localUser != null) {
        await _apiClient.updateUserProfile(localUser.toJson());
      }

      // Download remote changes  
      final remoteUser = await _apiClient.getUserProfile(deviceId);
      if (remoteUser != null) {
        await _database.into(_database.users)
            .insertOnConflictUpdate(UserProfile.fromJson(remoteUser));
      }
    });
  }

  Future<void> syncFoodPreferences(String deviceId) async {
    final localPrefs = await _database.select(_database.foodPreferences)
        .where((fp) => fp.deviceId.equals(deviceId))
        .get();

    // Convert to API format and sync
    final prefsMap = {
      for (final pref in localPrefs)
        pref.foodName: pref.preference.name
    };

    await _apiClient.saveFoodPreferences(deviceId, prefsMap);
  }
}
```

## Error Handling

### Transaction Safety

Drift provides robust transaction support with automatic rollback:

```dart
Future<void> safeDataOperation() async {
  try {
    await _database.transaction(() async {
      // All operations within this block are atomic
      final user = await _database.select(_database.users).getSingle();
      
      await _database.update(_database.users)
          .replace(user.copyWith(updatedAt: DateTime.now()));
          
      await _database.into(_database.nutritionPlans).insert(newPlan);
      
      // If any operation fails, entire transaction rolls back
    });
  } on DriftException catch (e) {
    // Handle database-specific errors
    if (e.message.contains('UNIQUE constraint failed')) {
      throw DuplicateDataException('Data already exists');
    }
    rethrow;
  } catch (e) {
    // Handle other errors
    throw DatabaseOperationException('Failed to save data: $e');
  }
}
```

### Schema Validation

Drift validates schema compatibility at runtime:

```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onUpgrade: stepByStep(
      // ... migrations ...
    ),
    beforeOpen: (details) async {
      if (details.hadUpgrade) {
        // Verify schema integrity after migration
        await customStatement('PRAGMA foreign_key_check');
        await customStatement('PRAGMA integrity_check');
      }
    },
  );
}
```

## Testing Strategies

### Unit Testing with In-Memory Database

```dart
void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('should handle user CRUD operations', () async {
    final user = UserProfile(
      deviceId: 'test-device',
      gender: Gender.male,
      birthday: DateTime(1990, 1, 1),
      heightFeet: 5,
      heightInches: 10,
      weightPounds: 170.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.moderate,
      onboardingCompleted: false,
      appVersion: '1.0.0',
    );

    // Insert
    await database.into(database.users).insert(user);

    // Read
    final retrieved = await database.select(database.users).getSingle();
    expect(retrieved.deviceId, 'test-device');

    // Update
    await database.update(database.users).replace(
      user.copyWith(onboardingCompleted: true),
    );

    // Verify update
    final updated = await database.select(database.users).getSingle();
    expect(updated.onboardingCompleted, true);

    // Delete
    await database.delete(database.users).go();
    final afterDelete = await database.select(database.users).get();
    expect(afterDelete, isEmpty);
  });
}
```

## Benefits Over Previous Implementation

### Type Safety Improvements
- **Compile-time validation**: All queries validated at build time
- **Generated classes**: Strongly-typed data classes prevent runtime errors  
- **Schema safety**: Impossible to query non-existent columns or tables

### Migration Advantages
- **Automatic generation**: Schema changes generate migration code automatically
- **Testing support**: Every migration gets comprehensive test coverage
- **Version tracking**: Built-in schema versioning prevents data corruption

### Performance Benefits
- **SQL optimization**: Direct SQL queries with proper indexing
- **Batch operations**: Efficient bulk data operations
- **Connection pooling**: Better resource management than file-based storage

### Development Experience
- **Better debugging**: SQL queries visible and debuggable
- **IDE support**: Full autocomplete and refactoring support
- **Clear architecture**: Well-defined layers with dependency injection

This Drift implementation provides a robust, type-safe, and performant foundation for the Mealvana Endurance app's data storage needs while maintaining the offline-first architecture essential for endurance sports applications.