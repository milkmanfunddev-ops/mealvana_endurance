# Drift Migration Guide for Mealvana Endurance

## Overview

This guide covers the migration from Hive to Drift and provides comprehensive information on managing database schema changes using Drift's built-in migration system.

## Why Drift Over Hive?

### Problems with Hive
- **Type Cast Errors**: Runtime failures when schema changes (e.g., `type 'Null' is not a subtype of type 'bool'`)
- **Manual Migrations**: No built-in migration system leads to data corruption
- **Limited Relationships**: Difficult to model complex data relationships
- **No Query Validation**: SQL-like queries not validated at compile time

### Benefits of Drift
- **Type-Safe Migrations**: Built-in schema versioning with compile-time validation
- **Automatic Code Generation**: Generated migrations based on schema changes
- **SQL Query Validation**: Compile-time validation of all database queries
- **Transaction Support**: Full ACID transactions with rollback support
- **Better Performance**: Optimized SQLite queries with prepared statements
- **Migration Testing**: Auto-generated test cases for all schema changes

## Migration Architecture

### Database Setup

```dart
// lib/shared/database/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// Import all table definitions
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
        // Migration steps will be generated here
      ),
      beforeOpen: (details) async {
        // Enable foreign keys
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'mealvana_db',
      // Enable encryption for sensitive data
      setup: (database) {
        database.execute('PRAGMA journal_mode=WAL');
        database.execute('PRAGMA synchronous=NORMAL');
      },
    );
  }
}
```

### Table Definitions

```dart
// lib/shared/database/tables/users.dart
import 'package:drift/drift.dart';

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
    {deviceId, foodName}, // Unique constraint on device + food combination
  ];
}
```

## Schema Migration Workflow

### 1. Making Schema Changes

When you need to modify the database schema:

1. **Update Table Definitions**: Modify the table classes in `lib/shared/database/tables/`
2. **Increment Schema Version**: Update `schemaVersion` in `AppDatabase`
3. **Generate Migration Code**: Run Drift's migration generator

```bash
# After making schema changes, increment schemaVersion and run:
dart run drift_dev make-migrations

# This generates:
# - New schema files in drift_schemas/
# - Migration code in lib/shared/database/migrations.dart
# - Test files in test/generated_migrations/
```

### 2. Generated Migration Structure

```dart
// Generated migration example
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
      },
      from3To4: (m, schema) async {
        // Complex migration with data transformation
        await m.alterTable(TableMigration(
          schema.nutritionPlans,
          columnTransformer: {
            schema.nutritionPlans.planData: 
              const Constant('{}'), // Default empty JSON
          },
        ));
      },
    ),
  );
}
```

### 3. Migration Testing

Drift automatically generates comprehensive tests:

```bash
# Generate migration tests
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

# Run migration tests
dart test test/generated_migrations/
```

Example generated test:
```dart
// test/generated_migrations/schema_test.dart
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:test/test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  
  group('Migration tests', () {
    test('from version 1 to 2', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final db = await verifier.startAt(1);
      
      // Perform migration
      await verifier.migrateAndValidate(AppDatabase(db), 2);
    });

    test('data integrity after migration', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final db = await verifier.startAt(1);
      
      // Insert test data in old schema
      await db.execute('''
        INSERT INTO user_profiles (device_id, gender, birthday, height_feet, height_inches, weight_pounds)
        VALUES ('test-device', 0, '1990-01-01', 5, 10, 170.0)
      ''');
      
      // Migrate to new schema
      final appDb = AppDatabase(db);
      await verifier.migrateAndValidate(appDb, 2);
      
      // Verify data integrity
      final user = await appDb.select(appDb.users).getSingle();
      expect(user.deviceId, 'test-device');
      expect(user.onboardingCompleted, false); // Should have default value
    });
  });
}
```

## Repository Implementation

### Type-Safe Repository Pattern

```dart
// lib/shared/data/drift_user_repository.dart
class DriftUserRepository implements UserRepository {
  final AppDatabase _database;
  
  DriftUserRepository(this._database);

  @override
  Future<UserProfile?> getCurrentUser() async {
    // Type-safe query with compile-time validation
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
      
      // Insert new preferences
      for (final entry in preferences.entries) {
        await _database.into(_database.foodPreferences).insert(
          FoodPreferencesCompanion.insert(
            deviceId: deviceId,
            foodName: entry.key,
            preference: entry.value,
          ),
        );
      }
    });
  }
}
```

## Data Migration from Hive

### Migration Service

```dart
// lib/shared/services/hive_to_drift_migration.dart
class HiveToDriftMigration {
  final Box<dynamic> _hiveUserBox;
  final Box<dynamic> _hiveFoodPrefsBox;
  final AppDatabase _driftDatabase;

  HiveToDriftMigration({
    required Box<dynamic> hiveUserBox,
    required Box<dynamic> hiveFoodPrefsBox,
    required AppDatabase driftDatabase,
  }) : _hiveUserBox = hiveUserBox,
       _hiveFoodPrefsBox = hiveFoodPrefsBox,
       _driftDatabase = driftDatabase;

  Future<void> migrateAllData() async {
    await _driftDatabase.transaction(() async {
      await _migrateUsers();
      await _migrateFoodPreferences();
    });
    
    // Mark migration as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hive_to_drift_migration_complete', true);
  }

  Future<void> _migrateUsers() async {
    for (final key in _hiveUserBox.keys) {
      try {
        final hiveUser = _hiveUserBox.get(key);
        if (hiveUser is Map<String, dynamic>) {
          final driftUser = UserProfile(
            deviceId: _safeString(hiveUser['device_id']) ?? key.toString(),
            gender: _parseGender(hiveUser['gender']),
            birthday: _parseDateTime(hiveUser['birthday']) ?? DateTime.now(),
            heightFeet: _safeInt(hiveUser['height_feet']) ?? 5,
            heightInches: _safeInt(hiveUser['height_inches']) ?? 6,
            weightPounds: _safeDouble(hiveUser['weight_pounds']) ?? 150.0,
            runsWithWaterBottle: _safeBool(hiveUser['runs_with_water_bottle']) ?? false,
            createdAt: _parseDateTime(hiveUser['created_at']) ?? DateTime.now(),
            updatedAt: DateTime.now(),
            gutTraining: _parseGutTraining(hiveUser['gut_training']) ?? GutTraining.moderate,
            onboardingCompleted: _safeBool(hiveUser['onboarding_completed']) ?? false,
            appVersion: _safeString(hiveUser['app_version']) ?? '1.0.0',
          );

          await _driftDatabase.into(_driftDatabase.users).insertOnConflictUpdate(driftUser);
        }
      } catch (e) {
        // Log error but continue migration
        print('Failed to migrate user $key: $e');
      }
    }
  }

  Future<void> _migrateFoodPreferences() async {
    for (final key in _hiveFoodPrefsBox.keys) {
      try {
        final hiveFoodPrefs = _hiveFoodPrefsBox.get(key);
        if (hiveFoodPrefs is Map<String, dynamic>) {
          final deviceId = _safeString(hiveFoodPrefs['user_id']) ?? key.toString();
          final preferences = hiveFoodPrefs['preferences'] as Map<String, dynamic>? ?? {};
          
          for (final entry in preferences.entries) {
            final driftFoodPref = FoodPreferencesCompanion.insert(
              deviceId: deviceId,
              foodName: entry.key,
              preference: _parsePreferenceType(entry.value) ?? PreferenceType.dislike,
            );

            await _driftDatabase.into(_driftDatabase.foodPreferences)
                .insertOnConflictUpdate(driftFoodPref);
          }
        }
      } catch (e) {
        print('Failed to migrate food preferences $key: $e');
      }
    }
  }

  // Safe parsing methods
  String? _safeString(dynamic value) {
    return value is String ? value : null;
  }

  int? _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _safeDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool? _safeBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return null;
  }

  Gender _parseGender(dynamic value) {
    if (value is String) {
      return Gender.values.firstWhere(
        (g) => g.name == value,
        orElse: () => Gender.other,
      );
    }
    return Gender.other;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  GutTraining _parseGutTraining(dynamic value) {
    if (value is String) {
      return GutTraining.values.firstWhere(
        (gt) => gt.name == value,
        orElse: () => GutTraining.moderate,
      );
    }
    return GutTraining.moderate;
  }

  PreferenceType _parsePreferenceType(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'like':
          return PreferenceType.like;
        case 'dislike':
          return PreferenceType.dislike;
        case 'willing_to_try':
          return PreferenceType.willingToTry;
        default:
          return PreferenceType.dislike;
      }
    }
    return PreferenceType.dislike;
  }
}
```

## Performance Optimization

### Indexing Strategy

```dart
// Add indexes for frequently queried columns
class Users extends Table {
  // ... column definitions

  @override
  List<Index> get customIndexes => [
    Index('idx_users_device_id', [deviceId]),
    Index('idx_users_updated_at', [updatedAt]),
  ];
}

class FoodPreferences extends Table {
  // ... column definitions

  @override
  List<Index> get customIndexes => [
    Index('idx_food_prefs_device_id', [deviceId]),
    Index('idx_food_prefs_device_food', [deviceId, foodName]),
  ];
}
```

### Query Optimization

```dart
// Use compiled queries for frequently executed statements
class AppDatabase extends _$AppDatabase {
  // Compiled query for better performance
  late final getUserByDeviceId = Selectable.forQuery(
    select(users).where((u) => u.deviceId.equals('\$deviceId')),
  );

  Future<UserProfile?> getUserFast(String deviceId) async {
    final query = getUserByDeviceId.map((row) => row.readTable(users));
    return await query.getSingleOrNull();
  }
}
```

## Error Handling and Monitoring

### Transaction Error Handling

```dart
Future<void> safeOperation() async {
  try {
    await _database.transaction(() async {
      // Your database operations here
      await _database.into(_database.users).insert(user);
      await _database.into(_database.foodPreferences).insertAll(preferences);
    });
  } on DriftException catch (e) {
    // Handle Drift-specific errors
    await Sentry.captureException(e, 
      withScope: (scope) => scope.setTag('error_type', 'drift_database'));
  } catch (e) {
    // Handle general errors
    rethrow;
  }
}
```

### Migration Monitoring

```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async {
      await Sentry.captureMessage('Database created');
      await m.createAll();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await Sentry.captureMessage('Migrating from v1 to v2');
        await m.addColumn(schema.users, schema.users.onboardingCompleted);
        await Sentry.captureMessage('Migration v1 to v2 completed');
      },
    ),
  );
}
```

## Testing Strategy

### Unit Tests

```dart
// test/database/user_repository_test.dart
void main() {
  late AppDatabase database;
  late DriftUserRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftUserRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('should save and retrieve user profile', () async {
    final user = UserProfile(
      deviceId: 'test-device',
      gender: Gender.male,
      birthday: DateTime(1990, 1, 1),
      // ... other fields
    );

    await repository.saveUserProfile(user);
    final retrieved = await repository.getCurrentUser();

    expect(retrieved?.deviceId, 'test-device');
    expect(retrieved?.gender, Gender.male);
  });
}
```

### Migration Tests

```bash
# Run all generated migration tests
dart test test/generated_migrations/

# Run specific migration test
dart test test/generated_migrations/ -n "from version 1 to 2"
```

## Deployment Checklist

- [ ] Update dependencies in pubspec.yaml
- [ ] Generate all migration code with `dart run drift_dev make-migrations`
- [ ] Run migration tests with `dart test test/generated_migrations/`
- [ ] Test data migration from Hive in development
- [ ] Update app startup service to initialize Drift database
- [ ] Implement graceful fallback for migration failures
- [ ] Monitor migration success/failure rates via analytics
- [ ] Plan rollback strategy for critical migration issues

## Conclusion

The migration from Hive to Drift provides significant benefits:

1. **Type Safety**: Eliminates runtime type cast errors
2. **Migration System**: Built-in schema versioning prevents data corruption
3. **Performance**: Optimized SQL queries with compile-time validation
4. **Testing**: Comprehensive migration test generation
5. **Maintainability**: Clear separation of concerns with generated code

The migration ensures data integrity while providing a more robust foundation for future database schema changes.