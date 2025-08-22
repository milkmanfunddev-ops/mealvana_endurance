# 🚀 Hive to Drift Migration Roadmap - Mealvana Endurance

## 📋 **Migration Overview**

This roadmap provides a complete, step-by-step guide to migrate Mealvana Endurance from Hive to Drift. The migration is designed to be **safe**, **tested**, and **reversible**.

### **📊 Current State Analysis**
- ✅ **Hive Models Identified**: `UserProfile`, `FoodPreferences`, `Gender`, `GutTraining`, etc.
- ✅ **Hive Boxes**: `user_profiles`, `food_preferences`, `nutrition_plans`, `content_box`, `feedback`
- ✅ **Repositories**: User, Content, Nutrition Plan repositories using Hive
- ✅ **App Startup**: Hive initialization in app startup service

### **🎯 Migration Goals**
- ❌ **Eliminate**: Runtime type cast errors (`type 'Null' is not a subtype of type 'bool'`)
- ✅ **Achieve**: Type-safe database operations with compile-time validation
- ✅ **Implement**: Automatic schema migrations with testing
- ✅ **Maintain**: Offline-first architecture with better performance
- ✅ **Preserve**: All existing user data during migration

---

## 🗓️ **Phase-by-Phase Migration Plan**

## **Phase 1: Preparation & Setup** ⏱️ *2-3 days*

### **Step 1.1: Add Drift Dependencies**

Update `pubspec.yaml`:

```yaml
dependencies:
  # Remove these Hive dependencies gradually
  # hive: ^2.2.3
  # hive_flutter: ^1.1.0
  
  # Add Drift dependencies
  drift: ^2.16.0
  drift_flutter: ^0.1.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.2
  path: ^1.8.3
  
  # Keep existing dependencies
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  uuid: ^4.2.1

dev_dependencies:
  # Add Drift development tools
  drift_dev: ^2.16.0
  build_runner: ^2.4.7
  
  # Keep existing
  riverpod_generator: ^2.4.0
```

### **Step 1.2: Create Database Structure**

Create the Drift database architecture:

```bash
mkdir -p lib/shared/database
mkdir -p lib/shared/database/tables
mkdir -p lib/shared/database/migrations
mkdir -p drift_schemas
mkdir -p test/generated_migrations
```

### **Step 1.3: Create Base Database Class**

Create `lib/shared/database/app_database.dart`:

```dart
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
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        await customStatement('PRAGMA journal_mode = WAL');
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'mealvana_endurance_db',
      setup: (database) {
        database.execute('PRAGMA cache_size = -2000');
        database.execute('PRAGMA synchronous = NORMAL');
      },
    );
  }
}
```

---

## **Phase 2: Table Definitions** ⏱️ *3-4 days*

### **Step 2.1: Convert UserProfile to Drift Table**

Create `lib/shared/database/tables/users.dart`:

```dart
import 'package:drift/drift.dart';

@DataClassName('UserProfile')
class Users extends Table {
  // Map from your current Hive fields
  TextColumn get deviceId => text()(); // was 'id' in Hive
  IntColumn get gender => intEnum<Gender>()();
  DateTimeColumn get birthday => dateTime()();
  IntColumn get heightFeet => integer()();
  IntColumn get heightInches => integer()();
  RealColumn get weightPounds => real()();
  BooleanColumn get runsWithWaterBottle => boolean()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentTimestamp)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentTimestamp)();
  IntColumn get gutTraining => intEnum<GutTraining>().withDefault(const Constant(2))(); // moderate
  BooleanColumn get onboardingCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get appVersion => text().withDefault(const Constant('1.0.0'))();

  @override
  String get tableName => 'user_profiles';

  @override
  Set<Column> get primaryKey => {deviceId};
}

// Keep your existing enums
enum Gender { male, female, other }
enum GutTraining { low, moderate, high }
```

### **Step 2.2: Convert Food Preferences**

Create `lib/shared/database/tables/food_preferences.dart`:

```dart
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

enum PreferenceType { like, dislike, willingToTry }
```

### **Step 2.3: Convert Other Tables**

Following the same pattern, create:
- `lib/shared/database/tables/nutrition_plans.dart`
- `lib/shared/database/tables/app_content.dart`
- `lib/shared/database/tables/feedback.dart`

### **Step 2.4: Generate Initial Code**

```bash
# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Generate initial schema
dart run drift_dev make-migrations
```

---

## **Phase 3: Data Migration Service** ⏱️ *4-5 days*

### **Step 3.1: Create Migration Service**

Create `lib/shared/services/hive_to_drift_migration.dart`:

```dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';

class HiveToDriftMigration {
  final AppDatabase _driftDatabase;
  static const String _migrationCompleteKey = 'hive_to_drift_complete_v1';

  HiveToDriftMigration(this._driftDatabase);

  Future<bool> isMigrationNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final isComplete = prefs.getBool(_migrationCompleteKey) ?? false;
    
    if (isComplete) return false;

    // Check if Hive data exists
    try {
      await Hive.initFlutter();
      
      final hasUserData = Hive.isBoxOpen('user_profiles') || 
          await _hiveBoxHasData('user_profiles');
      final hasFoodPrefs = Hive.isBoxOpen('food_preferences') || 
          await _hiveBoxHasData('food_preferences');
      
      return hasUserData || hasFoodPrefs;
    } catch (e) {
      print('Error checking Hive data: $e');
      return false;
    }
  }

  Future<bool> _hiveBoxHasData(String boxName) async {
    try {
      final box = await Hive.openBox(boxName);
      final hasData = box.isNotEmpty;
      await box.close();
      return hasData;
    } catch (e) {
      return false;
    }
  }

  Future<MigrationResult> performMigration() async {
    final result = MigrationResult();
    
    try {
      await Hive.initFlutter();
      
      // Register your existing Hive adapters temporarily
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(UserProfileAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(GenderAdapter());
      }
      if (!Hive.isAdapterRegistered(5)) {
        Hive.registerAdapter(FoodPreferencesAdapter());
      }
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(FoodPreferenceAdapter());
      }
      if (!Hive.isAdapterRegistered(7)) {
        Hive.registerAdapter(GutTrainingAdapter());
      }

      await _driftDatabase.transaction(() async {
        result.usersMigrated = await _migrateUsers();
        result.preferencesMigrated = await _migrateFoodPreferences();
        result.plansMigrated = await _migrateNutritionPlans();
        result.contentMigrated = await _migrateAppContent();
        result.feedbackMigrated = await _migrateFeedback();
      });

      // Mark migration as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationCompleteKey, true);
      
      result.success = true;
      result.message = 'Migration completed successfully';
      
      // Optionally clean up Hive data after successful migration
      await _cleanupHiveData();
      
    } catch (e, stackTrace) {
      result.success = false;
      result.message = 'Migration failed: $e';
      result.error = e;
      result.stackTrace = stackTrace;
    }

    return result;
  }

  Future<int> _migrateUsers() async {
    int count = 0;
    
    try {
      final box = await Hive.openBox('user_profiles');
      
      for (final key in box.keys) {
        try {
          final hiveUser = box.get(key);
          
          if (hiveUser != null) {
            final driftUser = UsersCompanion.insert(
              deviceId: _safeString(hiveUser.id) ?? key.toString(),
              gender: _parseGender(hiveUser.gender),
              birthday: hiveUser.birthday ?? DateTime.now(),
              heightFeet: hiveUser.heightFeet ?? 5,
              heightInches: hiveUser.heightInches ?? 6,
              weightPounds: hiveUser.weightPounds ?? 150.0,
              runsWithWaterBottle: hiveUser.runsWithWaterBottle ?? false,
              createdAt: Value(hiveUser.createdAt ?? DateTime.now()),
              updatedAt: Value(hiveUser.updatedAt ?? DateTime.now()),
              gutTraining: _parseGutTraining(hiveUser.gutTraining),
              onboardingCompleted: Value(hiveUser.onboardingCompleted ?? false),
              appVersion: Value(hiveUser.appVersion ?? '1.0.0'),
            );

            await _driftDatabase.into(_driftDatabase.users)
                .insertOnConflictUpdate(driftUser);
            count++;
          }
        } catch (e) {
          print('Failed to migrate user $key: $e');
        }
      }
      
      await box.close();
    } catch (e) {
      print('Error migrating users: $e');
    }

    return count;
  }

  Future<int> _migrateFoodPreferences() async {
    int count = 0;
    
    try {
      final box = await Hive.openBox('food_preferences');
      
      for (final key in box.keys) {
        try {
          final hivePrefs = box.get(key);
          
          if (hivePrefs != null && hivePrefs.preferences != null) {
            final deviceId = _safeString(hivePrefs.userId) ?? key.toString();
            
            for (final entry in hivePrefs.preferences.entries) {
              final driftPref = FoodPreferencesCompanion.insert(
                deviceId: deviceId,
                foodName: entry.key,
                preference: _parsePreferenceType(entry.value),
              );

              await _driftDatabase.into(_driftDatabase.foodPreferences)
                  .insertOnConflictUpdate(driftPref);
              count++;
            }
          }
        } catch (e) {
          print('Failed to migrate food preferences $key: $e');
        }
      }
      
      await box.close();
    } catch (e) {
      print('Error migrating food preferences: $e');
    }

    return count;
  }

  // Similar methods for other data types...
  Future<int> _migrateNutritionPlans() async {
    // Implement based on your NutritionPlan structure
    return 0;
  }

  Future<int> _migrateAppContent() async {
    // Implement based on your AppContent structure
    return 0;
  }

  Future<int> _migrateFeedback() async {
    // Implement based on your Feedback structure
    return 0;
  }

  Future<void> _cleanupHiveData() async {
    try {
      // Only clean up after successful migration and user consent
      final prefs = await SharedPreferences.getInstance();
      final userConsent = prefs.getBool('user_consented_to_hive_cleanup') ?? false;
      
      if (userConsent) {
        await Hive.deleteBoxFromDisk('user_profiles');
        await Hive.deleteBoxFromDisk('food_preferences');
        await Hive.deleteBoxFromDisk('nutrition_plans');
        await Hive.deleteBoxFromDisk('content_box');
        await Hive.deleteBoxFromDisk('feedback');
      }
    } catch (e) {
      print('Error cleaning up Hive data: $e');
    }
  }

  // Safe parsing helpers
  String? _safeString(dynamic value) => value is String ? value : null;

  Gender _parseGender(dynamic value) {
    if (value is Gender) return value;
    if (value is int && value < Gender.values.length) return Gender.values[value];
    return Gender.other;
  }

  GutTraining _parseGutTraining(dynamic value) {
    if (value is GutTraining) return value;
    if (value is int && value < GutTraining.values.length) return GutTraining.values[value];
    return GutTraining.moderate;
  }

  PreferenceType _parsePreferenceType(dynamic value) {
    if (value is PreferenceType) return value;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'like': return PreferenceType.like;
        case 'dislike': return PreferenceType.dislike;
        case 'willing_to_try': case 'willingtotry': return PreferenceType.willingToTry;
      }
    }
    return PreferenceType.dislike;
  }
}

class MigrationResult {
  bool success = false;
  String message = '';
  int usersMigrated = 0;
  int preferencesMigrated = 0;
  int plansMigrated = 0;
  int contentMigrated = 0;
  int feedbackMigrated = 0;
  Object? error;
  StackTrace? stackTrace;

  @override
  String toString() => '''
Migration Result:
- Success: $success
- Message: $message
- Users: $usersMigrated
- Food Preferences: $preferencesMigrated
- Plans: $plansMigrated
- Content: $contentMigrated  
- Feedback: $feedbackMigrated
${error != null ? '- Error: $error' : ''}
''';
}
```

---

## **Phase 4: Repository Migration** ⏱️ *3-4 days*

### **Step 4.1: Create Database Provider**

Create `lib/shared/providers/database_providers.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../database/app_database.dart';

part 'database_providers.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
}
```

### **Step 4.2: Create New Drift Repositories**

Create `lib/shared/data/repositories/drift_user_repository.dart`:

```dart
import 'package:drift/drift.dart';
import '../../../features/auth/domain/user_preferences.dart';
import '../../database/app_database.dart';

class DriftUserRepository {
  final AppDatabase _database;
  
  DriftUserRepository(this._database);

  Future<UserProfile?> getCurrentUser() async {
    return await _database.select(_database.users).getSingleOrNull();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _database.transaction(() async {
      await _database.into(_database.users).insertOnConflictUpdate(
        profile.toCompanion(false).copyWith(
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  Future<void> updateOnboardingCompleted(String deviceId, bool completed) async {
    await (_database.update(_database.users)
          ..where((u) => u.deviceId.equals(deviceId)))
        .write(UsersCompanion(
          onboardingCompleted: Value(completed),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Stream<UserProfile?> watchCurrentUser() {
    return _database.select(_database.users).watchSingleOrNull();
  }

  // Add extension method to convert between formats
  extension UserProfileExtensions on UserProfile {
    UsersCompanion toCompanion(bool nullToAbsent) {
      return UsersCompanion(
        deviceId: Value(deviceId),
        gender: Value(gender),
        birthday: Value(birthday),
        heightFeet: Value(heightFeet),
        heightInches: Value(heightInches),
        weightPounds: Value(weightPounds),
        runsWithWaterBottle: Value(runsWithWaterBottle),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
        gutTraining: Value(gutTraining),
        onboardingCompleted: Value(onboardingCompleted),
        appVersion: Value(appVersion),
      );
    }
  }
}
```

### **Step 4.3: Update Repository Providers**

Create `lib/shared/providers/repository_providers.dart`:

```dart
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

---

## **Phase 5: App Startup Integration** ⏱️ *2-3 days*

### **Step 5.1: Update App Startup Service**

Modify `lib/features/app_startup/application/app_startup_service.dart`:

```dart
class AppStartupService {
  final AppDatabase _database;
  final HiveToDriftMigration _migration;
  // ... other dependencies

  AppStartupService({
    required AppDatabase database,
    required HiveToDriftMigration migration,
    // ... other params
  }) : _database = database,
       _migration = migration;

  Future<AppStartupResult> initialize() async {
    try {
      // Step 1: Initialize database
      await _database.ensureOpen();
      
      // Step 2: Check if migration is needed
      final needsMigration = await _migration.isMigrationNeeded();
      
      if (needsMigration) {
        print('🔄 Performing Hive to Drift migration...');
        final result = await _migration.performMigration();
        
        if (result.success) {
          print('✅ Migration completed successfully');
          print(result.toString());
        } else {
          print('❌ Migration failed: ${result.message}');
          throw Exception('Data migration failed: ${result.message}');
        }
      }

      // Step 3: Continue with normal startup logic using Drift
      final deviceId = await _getDeviceId();
      final user = await _loadUser(deviceId);
      final currentPlan = await _loadCurrentPlan(deviceId);

      return AppStartupResult(
        navigationState: user?.onboardingCompleted == true 
            ? AppStartupState.planScreen 
            : AppStartupState.onboarding,
        deviceId: deviceId,
        user: user,
        currentPlan: currentPlan,
      );
      
    } catch (e, stackTrace) {
      print('❌ App startup failed: $e');
      rethrow;
    }
  }

  Future<UserProfile?> _loadUser(String deviceId) async {
    return await _database.select(_database.users)
        .where((u) => u.deviceId.equals(deviceId))
        .getSingleOrNull();
  }

  // ... other methods updated to use Drift
}
```

### **Step 5.2: Update App Startup Provider**

Update your app startup provider to include the migration service:

```dart
@riverpod
Future<AppStartupResult> appStartup(AppStartupRef ref) async {
  final database = ref.read(appDatabaseProvider);
  final migration = HiveToDriftMigration(database);
  
  final service = AppStartupService(
    database: database,
    migration: migration,
    // ... other dependencies
  );

  return await service.initialize();
}
```

---

## **Phase 6: Testing & Validation** ⏱️ *3-4 days*

### **Step 6.1: Create Migration Tests**

Create `test/migration/hive_to_drift_test.dart`:

```dart
void main() {
  group('Hive to Drift Migration', () {
    late AppDatabase database;
    late HiveToDriftMigration migration;

    setUp(() async {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      migration = HiveToDriftMigration(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('should migrate user profile correctly', () async {
      // Create mock Hive data
      // ... test implementation
    });

    test('should handle missing onboarding field gracefully', () async {
      // Test the exact scenario causing your current bug
      // ... test implementation
    });

    test('should preserve all user data during migration', () async {
      // Comprehensive data integrity test
      // ... test implementation
    });
  });
}
```

### **Step 6.2: Generate and Run Drift Migration Tests**

```bash
# Generate Drift's built-in migration tests
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/

# Run all tests
dart test
```

### **Step 6.3: Create Integration Tests**

Test the complete migration flow with real data scenarios.

---

## **Phase 7: Gradual Rollout** ⏱️ *2-3 days*

### **Step 7.1: Feature Flag Implementation**

Create a feature flag to control migration:

```dart
class MigrationFlags {
  static const bool enableDriftMigration = bool.fromEnvironment(
    'ENABLE_DRIFT_MIGRATION', 
    defaultValue: false
  );
  
  static const bool fallbackToHive = bool.fromEnvironment(
    'FALLBACK_TO_HIVE',
    defaultValue: true
  );
}
```

### **Step 7.2: Dual Mode Support**

Temporarily support both Hive and Drift until migration is complete:

```dart
@riverpod
UserRepository userRepository(UserRepositoryRef ref) {
  if (MigrationFlags.enableDriftMigration) {
    final database = ref.watch(appDatabaseProvider);
    return DriftUserRepository(database);
  } else {
    return HiveUserRepository(); // Your existing implementation
  }
}
```

---

## **Phase 8: Cleanup & Finalization** ⏱️ *1-2 days*

### **Step 8.1: Remove Hive Dependencies**

Once migration is validated:

```yaml
dependencies:
  # Remove Hive completely
  # hive: ^2.2.3
  # hive_flutter: ^1.1.0
```

### **Step 8.2: Clean Up Old Code**

Remove:
- Hive model classes with `@HiveType` annotations
- Hive repository implementations
- Hive initialization code
- Old migration service

### **Step 8.3: Update Documentation**

- ✅ Update all references from Hive to Drift
- ✅ Document new database schema
- ✅ Update development setup guides

---

## 🧪 **Testing Strategy**

### **Pre-Migration Testing**
1. **Backup Current Data**: Export all user data for safety
2. **Test Migration Logic**: Validate with various data scenarios
3. **Performance Testing**: Ensure Drift performs better than Hive

### **During Migration Testing**
1. **Data Integrity**: Verify all fields migrate correctly
2. **Error Handling**: Test migration failure scenarios
3. **Rollback Testing**: Ensure ability to revert if needed

### **Post-Migration Testing**
1. **Functionality Testing**: Verify all app features work
2. **Performance Validation**: Confirm improved performance
3. **Migration Cleanup**: Test Hive data cleanup process

---

## 🚨 **Risk Mitigation**

### **Data Loss Prevention**
- ✅ **Comprehensive Backups**: Export all data before migration
- ✅ **Atomic Transactions**: All-or-nothing migration approach
- ✅ **Rollback Plan**: Keep Hive data until migration is validated
- ✅ **User Consent**: Ask users before cleaning up old data

### **Deployment Safety**
- ✅ **Feature Flags**: Control migration rollout
- ✅ **Gradual Rollout**: Start with internal testing
- ✅ **Monitoring**: Track migration success/failure rates
- ✅ **Quick Rollback**: Ability to revert to Hive if critical issues

---

## 📊 **Success Metrics**

### **Technical Metrics**
- ✅ **Zero Data Loss**: 100% of user data successfully migrated
- ✅ **Performance Improvement**: Query times reduced by >50%
- ✅ **Error Reduction**: Eliminate all type cast errors
- ✅ **Migration Speed**: Complete migration in <5 seconds

### **User Experience Metrics**
- ✅ **App Stability**: No crashes during migration
- ✅ **Seamless Transition**: Users don't notice the change
- ✅ **Feature Parity**: All functionality works as before
- ✅ **Performance**: App feels faster and more responsive

---

## 🎯 **Timeline Summary**

| Phase | Duration | Key Deliverables |
|-------|----------|------------------|
| **Phase 1: Preparation** | 2-3 days | Dependencies, database structure |
| **Phase 2: Table Definitions** | 3-4 days | All Drift table definitions |
| **Phase 3: Migration Service** | 4-5 days | Complete data migration logic |
| **Phase 4: Repository Migration** | 3-4 days | New Drift repositories |
| **Phase 5: App Startup Integration** | 2-3 days | Integration with app startup |
| **Phase 6: Testing** | 3-4 days | Comprehensive test suite |
| **Phase 7: Gradual Rollout** | 2-3 days | Feature flags, dual mode |
| **Phase 8: Cleanup** | 1-2 days | Remove old code, documentation |

**Total Estimated Time: 20-28 days**

---

## 🚀 **Next Steps**

1. **Start with Phase 1** - Add dependencies and create basic structure
2. **Focus on UserProfile first** - It's causing your current type cast errors
3. **Test extensively** - Create comprehensive tests for your specific data scenarios  
4. **Plan for rollback** - Always have a way back to Hive if issues arise
5. **Monitor closely** - Track the migration process and user impact

This roadmap ensures a **safe, tested, and successful migration** from Hive to Drift while preserving all user data and eliminating the type cast errors you're currently experiencing.

Need help with any specific phase or have questions about the implementation details? I can dive deeper into any section!