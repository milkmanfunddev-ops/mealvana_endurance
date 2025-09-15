# Drift Migration Strategy: Version 1 → Version 2

## Overview

This document outlines the migration strategy from Mealvana Endurance's current manual schema management (v1) to proper Drift migrations (v2). The migration adds 5 new tables while preserving all existing user data.

## Current State Analysis

### Version 1 Issues
- **Schema Version**: Hardcoded to `1` forever
- **Migration Strategy**: Just calls `m.createAll()` - no real versioning
- **Schema Management**: Custom `DatabaseSchemaManager` bypasses Drift
- **Food Data**: No local caching - always fetches from Supabase
- **Content**: Stored in SharedPreferences instead of database

### Version 1 Tables (Preserved)
- `users` (UserProfilesTable)
- `food_preferences` (FoodPreferencesTable)
- `nutrition_plans` (NutritionPlans)
- `macro_targets_table` (MacroTargetsTable)
- `feedback` (FeedbackTable)

## Migration Strategy: "Fake History"

We use the "Fake History" approach - treating v1 as if it was always a proper Drift migration, while preserving all existing user data.

### Why "Fake History"?
1. **Preserves User Data**: No data loss during migration
2. **Simple Implementation**: Minimal migration code required
3. **Low Risk**: Existing tables remain untouched
4. **Future Compatibility**: Sets up proper Drift versioning going forward

### Alternative Approaches (Rejected)
- **Nuclear Option**: Drop all tables and recreate ❌ (Data loss)
- **Full History**: Complex detection and repair ❌ (Over-engineering)
- **Keep Manual System**: Continue with DatabaseSchemaManager ❌ (Technical debt)

## Migration Implementation

### 1. Schema Snapshot Generation

Before making any changes, capture the current v1 state:

```bash
# Generate v1 schema snapshot
dart run drift_dev schema dump lib/shared/database/app_database.dart drift_schemas/1.json
```

### 2. Database Class Updates

Update `AppDatabase` to support proper migrations:

```dart
@DriftDatabase(tables: [
  // Existing v1 tables (preserved)
  UserProfilesTable,
  FoodPreferencesTable,
  NutritionPlans,
  MacroTargetsTable,
  FeedbackTable,
  
  // New v2 tables
  FoodsTable,
  CategoriesTable,
  FoodCategoriesTable,
  BrandsTable,
  AppContentTable,
])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 2; // Increment from hardcoded 1
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      // For fresh installs, create all tables
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Handle v1 -> v2 migration
      if (from == 1 && to == 2) {
        await _migrateV1ToV2(m);
      }
    },
    beforeOpen: (details) async {
      // Enable foreign key support
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
  
  Future<void> _migrateV1ToV2(Migrator m) async {
    print('🔄 Migrating database from v1 to v2...');
    
    // Step 1: Create new tables only (existing tables untouched)
    await m.createTable(foodsTable);
    await m.createTable(categoriesTable);  
    await m.createTable(foodCategoriesTable);
    await m.createTable(brandsTable);
    await m.createTable(appContentTable);
    
    print('✅ New tables created');
    
    // Step 2: Migrate content from SharedPreferences to database
    await _migrateContentFromSharedPrefs();
    
    // Step 3: Initial sync of food data
    await _initialFoodSync();
    
    // Step 4: Populate categories
    await _populateCategories();
    
    print('✅ Migration v1 -> v2 completed');
  }
}
```

### 3. Migration Safety Features

#### Backup and Recovery System
```dart
class MigrationBackupService {
  static const String MIGRATION_FLAG = 'drift_v2_migration_completed';
  static const String BACKUP_KEY = 'migration_backup_v1_to_v2';
  
  Future<bool> createPreMigrationBackup() async {
    try {
      print('💾 Creating pre-migration backup...');
      
      // Backup all critical user data to SharedPreferences
      final backup = MigrationBackup(
        version: 1,
        timestamp: DateTime.now().toIso8601String(),
        userProfiles: await _backupUserProfiles(),
        foodPreferences: await _backupFoodPreferences(),
        nutritionPlans: await _backupNutritionPlans(),
        macroTargets: await _backupMacroTargets(),
        feedback: await _backupFeedback(),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(BACKUP_KEY, jsonEncode(backup.toJson()));
      
      print('✅ Pre-migration backup created');
      return true;
    } catch (e) {
      print('❌ Failed to create backup: $e');
      return false;
    }
  }
  
  Future<void> restoreFromBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final backupJson = prefs.getString(BACKUP_KEY);
    
    if (backupJson == null) {
      throw Exception('No backup found for restoration');
    }
    
    final backup = MigrationBackup.fromJson(jsonDecode(backupJson));
    
    // Restore all user data
    await database.transaction(() async {
      await _restoreUserProfiles(backup.userProfiles);
      await _restoreAllUserData(backup);
    });
    
    print('✅ Data restored from backup');
  }
}
```

#### Feature Flag Protection
```dart
class MigrationProtection {
  static const String MIGRATION_FLAG = 'drift_v2_migration_completed';
  
  Future<bool> shouldRunMigration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(MIGRATION_FLAG) != true;
  }
  
  Future<void> markMigrationCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(MIGRATION_FLAG, true);
  }
  
  Future<void> resetMigrationFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(MIGRATION_FLAG);
  }
}
```

### 4. Safe Migration Executor

```dart
class SafeMigrationExecutor {
  Future<bool> executeMigrationSafely() async {
    try {
      // Step 1: Verify prerequisites
      if (!await _verifyMigrationPrerequisites()) {
        throw MigrationException('Migration prerequisites not met');
      }
      
      // Step 2: Create backup
      final backupService = MigrationBackupService();
      final backupSuccess = await backupService.createPreMigrationBackup();
      if (!backupSuccess) {
        throw MigrationException('Failed to create backup - aborting migration');
      }
      
      // Step 3: Execute migration in transaction
      await database.transaction(() async {
        await database.runMigration(fromVersion: 1, toVersion: 2);
      });
      
      // Step 4: Validate migration success
      await _validateMigrationSuccess();
      
      // Step 5: Mark as completed
      await MigrationProtection().markMigrationCompleted();
      
      print('✅ Migration completed successfully');
      return true;
      
    } catch (e) {
      print('❌ Migration failed: $e');
      await _rollbackMigration();
      return false;
    }
  }
  
  Future<void> _rollbackMigration() async {
    try {
      print('🔄 Rolling back failed migration...');
      
      // Close current database connection
      await database.close();
      
      // Delete corrupted database file
      final dbFile = File(await _getDatabasePath());
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      
      // Restore from backup
      await MigrationBackupService().restoreFromBackup();
      
      // Reset migration flag
      await MigrationProtection().resetMigrationFlag();
      
      print('✅ Rollback completed');
    } catch (e) {
      print('❌ Rollback failed: $e');
      throw CriticalMigrationException('Both migration and rollback failed', e);
    }
  }
}
```

## Data Migration Details

### 1. Content Migration (SharedPreferences → Database)

```dart
Future<void> _migrateContentFromSharedPrefs() async {
  try {
    print('📄 Migrating content from SharedPreferences...');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Check for cached content in SharedPreferences
    final cachedContentJson = prefs.getString('cached_content');
    if (cachedContentJson != null) {
      final cachedContent = jsonDecode(cachedContentJson);
      
      // Convert to AppContent model and save to database
      final appContent = AppContentEntry(
        id: uuid.v4(),
        version: cachedContent['version'] ?? 1,
        environment: cachedContent['environment'] ?? 'production',
        locale: cachedContent['locale'] ?? 'en',
        content: jsonEncode(cachedContent['content']),
        isActive: true,
        createdAt: DateTime.now(),
        lastSyncAt: DateTime.tryParse(cachedContent['lastSync'] ?? ''),
        isCached: true,
      );
      
      await into(appContentTable).insert(appContent);
      
      // Remove from SharedPreferences after successful migration
      await prefs.remove('cached_content');
      await prefs.remove('content_last_sync');
      
      print('✅ Content migrated successfully');
    }
  } catch (e) {
    print('⚠️ Content migration failed: $e');
    // Non-critical - app can fallback to defaults
  }
}
```

### 2. Initial Food Sync

```dart
Future<void> _initialFoodSync() async {
  try {
    print('🍎 Performing initial food sync...');
    
    // Fetch all foods from Supabase
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('foods')
        .select('*, food_categories(category_id)')
        .order('name');
    
    final foods = response as List<dynamic>;
    
    // Insert foods in batches for performance
    await batch((batch) {
      for (final foodData in foods) {
        final food = _convertSupabaseFoodToLocal(foodData);
        batch.insert(foodsTable, food);
        
        // Insert food-category relationships
        final categories = foodData['food_categories'] as List?;
        if (categories != null) {
          for (final categoryData in categories) {
            batch.insert(foodCategoriesTable, FoodCategoriesTableCompanion(
              foodId: Value(food.id.value),
              categoryId: Value(categoryData['category_id']),
            ));
          }
        }
      }
    });
    
    print('✅ Food sync completed: ${foods.length} foods cached');
  } catch (e) {
    print('⚠️ Initial food sync failed: $e');
    // Non-critical - app can work with empty food cache initially
  }
}
```

### 3. Category Population

```dart
Future<void> _populateCategories() async {
  try {
    print('📂 Populating categories...');
    
    final categories = [
      CategoriesTableCompanion(id: Value(1), name: Value('before_run')),
      CategoriesTableCompanion(id: Value(2), name: Value('during_run')),
      CategoriesTableCompanion(id: Value(3), name: Value('after_run')),
    ];
    
    for (final category in categories) {
      await into(categoriesTable).insertOnConflictUpdate(category);
    }
    
    print('✅ Categories populated');
  } catch (e) {
    print('❌ Category population failed: $e');
    // This is critical - throw error
    rethrow;
  }
}
```

## Integration with App Startup

### Updated AppStartupService

```dart
class AppStartupService {
  Future<void> initializeDatabase() async {
    try {
      print('📊 Initializing Drift database...');
      
      // Check if migration is needed
      if (await MigrationProtection().shouldRunMigration()) {
        print('🔄 Migration required - executing v1 -> v2 migration');
        
        final migrationSuccess = await SafeMigrationExecutor().executeMigrationSafely();
        if (!migrationSuccess) {
          throw DatabaseException('Migration failed - app may not function correctly');
        }
      }
      
      // Get database instance (will trigger migration if needed)
      final database = await ref.read(databaseProvider.future);
      
      // Remove old manual schema manager since we now use proper migrations
      // final schemaManager = DatabaseSchemaManager(database);
      // await schemaManager.validateAndUpdateSchema();
      
      // Validate database state
      final stats = await database.getDatabaseStats();
      print('📊 Database initialized - Users: ${stats['users']}, Plans: ${stats['plans']}');
      
    } catch (e) {
      print('❌ Database initialization failed: $e');
      rethrow;
    }
  }
}
```

## Testing Strategy

### Pre-Migration Testing
```dart
group('Migration Preparation Tests', () {
  test('backup creation includes all critical data', () async {
    // Setup test data
    await setupTestUserData();
    
    // Create backup
    final success = await MigrationBackupService().createPreMigrationBackup();
    expect(success, isTrue);
    
    // Verify backup completeness
    final backup = await getBackupData();
    expect(backup.userProfiles, isNotEmpty);
    expect(backup.nutritionPlans, isNotEmpty);
  });
  
  test('migration prerequisites are validated', () async {
    final executor = SafeMigrationExecutor();
    
    // Should pass with proper setup
    expect(await executor._verifyMigrationPrerequisites(), isTrue);
    
    // Should fail without backup capability
    mockBackupService.setFailure(true);
    expect(await executor._verifyMigrationPrerequisites(), isFalse);
  });
});
```

### Migration Testing
```dart
group('V1 to V2 Migration Tests', () {
  test('migration preserves existing user data', () async {
    // Setup v1 database
    await createV1TestDatabase();
    await addTestUserData();
    
    // Execute migration
    final success = await SafeMigrationExecutor().executeMigrationSafely();
    expect(success, isTrue);
    
    // Verify data preservation
    final users = await database.select(database.userProfilesTable).get();
    expect(users, hasLength(1));
    expect(users.first.id, equals('test-device-id'));
  });
  
  test('migration creates new tables correctly', () async {
    await executeMigration();
    
    // Verify new tables exist
    final tableNames = await database.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'"
    ).get();
    
    final names = tableNames.map((row) => row.data['name']).toList();
    expect(names, contains('foods'));
    expect(names, contains('categories'));
    expect(names, contains('food_categories'));
    expect(names, contains('brands'));
    expect(names, contains('app_content'));
  });
});
```

### Rollback Testing
```dart
group('Migration Rollback Tests', () {
  test('rollback restores data after failed migration', () async {
    // Setup initial data
    await setupTestData();
    
    // Create backup
    await MigrationBackupService().createPreMigrationBackup();
    
    // Simulate migration failure
    mockMigrationFailure();
    
    // Attempt migration (will fail and rollback)
    final success = await SafeMigrationExecutor().executeMigrationSafely();
    expect(success, isFalse);
    
    // Verify data was restored
    final users = await database.select(database.userProfilesTable).get();
    expect(users, isNotEmpty);
  });
});
```

## Monitoring and Rollback Plan

### Migration Monitoring
```dart
class MigrationMonitoring {
  static void trackMigrationStart() {
    analytics.track('migration_started', {
      'from_version': 1,
      'to_version': 2,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static void trackMigrationSuccess(Duration duration) {
    analytics.track('migration_completed', {
      'success': true,
      'duration_ms': duration.inMilliseconds,
    });
  }
  
  static void trackMigrationFailure(String error) {
    analytics.track('migration_failed', {
      'success': false,
      'error': error,
    });
  }
}
```

### Emergency Rollback Procedure

If migration issues are detected in production:

1. **Identify Affected Users**:
   ```dart
   // Check migration status across user base
   SELECT COUNT(*) FROM analytics_events 
   WHERE event_name = 'migration_failed' 
   AND created_at > NOW() - INTERVAL '24 hours';
   ```

2. **Push Rollback Update**:
   ```dart
   // Emergency rollback via feature flag
   class EmergencyRollback {
     static Future<void> rollbackToV1() async {
       await MigrationProtection().resetMigrationFlag();
       await SafeMigrationExecutor()._rollbackMigration();
     }
   }
   ```

3. **Restore App Functionality**:
   ```dart
   // Revert to manual schema management temporarily
   if (await shouldUseManualSchema()) {
     return DatabaseSchemaManager(database);
   }
   ```

## Success Criteria

### Migration Success Indicators
- ✅ All v1 tables preserved with data intact
- ✅ New v2 tables created and populated
- ✅ Content migrated from SharedPreferences to database
- ✅ Initial food sync completed
- ✅ App startup time remains acceptable
- ✅ No user-reported data loss

### Migration Failure Indicators
- ❌ User data missing after migration
- ❌ App crashes on startup
- ❌ Food data not loading
- ❌ Content not displaying correctly
- ❌ Performance significantly degraded

This migration strategy provides a safe, tested path from the current manual schema management to proper Drift migrations while preserving all user data and maintaining app functionality throughout the process.