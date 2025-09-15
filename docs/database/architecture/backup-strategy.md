# Backup and Recovery Strategy

## Overview

The Mealvana Endurance backup strategy protects user data during database migrations, system updates, and unexpected failures. This document outlines our comprehensive approach to data protection and recovery.

## Backup Targets

### Critical User Data
- **User Profiles**: Biometric data, preferences, settings
- **Food Preferences**: Like/dislike/willing-to-try selections
- **Nutrition Plans**: Generated plans with full history
- **Macro Targets**: Custom macro adjustments
- **Feedback**: User satisfaction ratings and comments

### System Data
- **App Content**: Cached UI text and algorithm parameters
- **Food Database**: Local food cache with timestamps
- **Analytics Queue**: Pending analytics events
- **Sync Status**: Last sync timestamps and pending operations

## Migration Backup Strategy

### Pre-Migration Backup
```dart
class MigrationBackupService {
  static const String BACKUP_KEY_PREFIX = 'migration_backup_';
  
  Future<bool> createBackup(int fromVersion, int toVersion) async {
    try {
      final backupKey = '${BACKUP_KEY_PREFIX}v${fromVersion}_to_v${toVersion}';
      final timestamp = DateTime.now().toIso8601String();
      
      // Backup critical user data
      final backup = MigrationBackup(
        version: fromVersion,
        timestamp: timestamp,
        userProfiles: await _backupUserProfiles(),
        foodPreferences: await _backupFoodPreferences(),
        nutritionPlans: await _backupNutritionPlans(),
        macroTargets: await _backupMacroTargets(),
        feedback: await _backupFeedback(),
      );
      
      // Store backup in SharedPreferences as JSON
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(backupKey, jsonEncode(backup.toJson()));
      
      logger.info('Migration backup created: $backupKey');
      return true;
    } catch (e) {
      logger.error('Failed to create migration backup', error: e);
      return false;
    }
  }
}
```

### Feature Flag Protection
```dart
class MigrationProtection {
  static const String MIGRATION_FLAG = 'drift_v2_migration_completed';
  static const String BACKUP_VERIFIED = 'migration_backup_verified';
  
  Future<bool> isMigrationSafe() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if migration already completed
    if (prefs.getBool(MIGRATION_FLAG) == true) {
      return true;
    }
    
    // Verify backup exists and is valid
    final backupExists = await verifyBackupExists();
    if (!backupExists) {
      logger.error('Migration backup missing - aborting migration');
      return false;
    }
    
    // Mark backup as verified
    await prefs.setBool(BACKUP_VERIFIED, true);
    return true;
  }
}
```

### Migration Execution with Rollback
```dart
class SafeMigrationExecutor {
  Future<bool> executeMigration() async {
    if (!await MigrationProtection().isMigrationSafe()) {
      throw MigrationException('Migration prerequisites not met');
    }
    
    try {
      // Create backup before migration
      final backupSuccess = await MigrationBackupService().createBackup(1, 2);
      if (!backupSuccess) {
        throw MigrationException('Failed to create backup');
      }
      
      // Execute migration in transaction
      await database.transaction(() async {
        await _migrateDatabaseSchema();
        await _migrateContentFromSharedPrefs();
        await _initialFoodSync();
      });
      
      // Mark migration as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(MigrationProtection.MIGRATION_FLAG, true);
      
      logger.info('Migration completed successfully');
      return true;
      
    } catch (e) {
      logger.error('Migration failed, initiating rollback', error: e);
      await _rollbackMigration();
      return false;
    }
  }
  
  Future<void> _rollbackMigration() async {
    try {
      // Restore from backup
      await MigrationBackupService().restoreFromBackup();
      
      // Reset migration flags
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(MigrationProtection.MIGRATION_FLAG);
      await prefs.remove(MigrationProtection.BACKUP_VERIFIED);
      
      logger.info('Migration rollback completed');
    } catch (e) {
      logger.error('Rollback failed - manual recovery required', error: e);
      throw CriticalMigrationException('Both migration and rollback failed', e);
    }
  }
}
```

## Backup Data Structures

### Migration Backup Model
```dart
class MigrationBackup {
  final int version;
  final String timestamp;
  final List<Map<String, dynamic>> userProfiles;
  final List<Map<String, dynamic>> foodPreferences;
  final List<Map<String, dynamic>> nutritionPlans;
  final List<Map<String, dynamic>> macroTargets;
  final List<Map<String, dynamic>> feedback;
  
  const MigrationBackup({
    required this.version,
    required this.timestamp,
    required this.userProfiles,
    required this.foodPreferences,
    required this.nutritionPlans,
    required this.macroTargets,
    required this.feedback,
  });
  
  Map<String, dynamic> toJson() => {
    'version': version,
    'timestamp': timestamp,
    'userProfiles': userProfiles,
    'foodPreferences': foodPreferences,
    'nutritionPlans': nutritionPlans,
    'macroTargets': macroTargets,
    'feedback': feedback,
  };
  
  factory MigrationBackup.fromJson(Map<String, dynamic> json) => MigrationBackup(
    version: json['version'],
    timestamp: json['timestamp'],
    userProfiles: List<Map<String, dynamic>>.from(json['userProfiles']),
    foodPreferences: List<Map<String, dynamic>>.from(json['foodPreferences']),
    nutritionPlans: List<Map<String, dynamic>>.from(json['nutritionPlans']),
    macroTargets: List<Map<String, dynamic>>.from(json['macroTargets']),
    feedback: List<Map<String, dynamic>>.from(json['feedback']),
  );
}
```

## Backup Operations

### Backup Creation
```dart
class BackupOperations {
  Future<List<Map<String, dynamic>>> _backupUserProfiles() async {
    final profiles = await database.select(database.userProfilesTable).get();
    return profiles.map((profile) => {
      'id': profile.id,
      'gender': profile.gender,
      'birthday': profile.birthday.toIso8601String(),
      'height_feet': profile.heightFeet,
      'height_inches': profile.heightInches,
      'weight_pounds': profile.weightPounds,
      'runs_with_water_bottle': profile.runsWithWaterBottle,
      'gut_training': profile.gutTraining,
      'onboarding_completed': profile.onboardingCompleted,
      'created_at': profile.createdAt.toIso8601String(),
      'updated_at': profile.updatedAt.toIso8601String(),
    }).toList();
  }
  
  Future<List<Map<String, dynamic>>> _backupFoodPreferences() async {
    final preferences = await database.select(database.foodPreferencesTable).get();
    return preferences.map((pref) => {
      'user_id': pref.userId,
      'food_id': pref.foodId,
      'preference': pref.preference,
      'created_at': pref.createdAt.toIso8601String(),
      'updated_at': pref.updatedAt.toIso8601String(),
    }).toList();
  }
  
  Future<List<Map<String, dynamic>>> _backupNutritionPlans() async {
    final plans = await database.select(database.nutritionPlans).get();
    return plans.map((plan) => {
      'id': plan.id,
      'user_id': plan.userId,
      'plan_name': plan.planName,
      'plan_data': plan.planData,
      'distance_miles': plan.distanceMiles,
      'pace_minutes_per_mile': plan.paceMinutesPerMile,
      'total_calories': plan.totalCalories,
      'notes': plan.notes,
      'created_at': plan.createdAt.toIso8601String(),
      'updated_at': plan.updatedAt.toIso8601String(),
    }).toList();
  }
}
```

### Backup Restoration
```dart
class BackupRestoration {
  Future<void> restoreFromBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final backupKeys = prefs.getKeys()
        .where((key) => key.startsWith(MigrationBackupService.BACKUP_KEY_PREFIX))
        .toList();
    
    if (backupKeys.isEmpty) {
      throw BackupException('No backup found for restoration');
    }
    
    // Use most recent backup
    backupKeys.sort();
    final latestBackupKey = backupKeys.last;
    final backupJson = prefs.getString(latestBackupKey);
    
    if (backupJson == null) {
      throw BackupException('Backup data is null');
    }
    
    final backup = MigrationBackup.fromJson(jsonDecode(backupJson));
    
    // Restore data in transaction
    await database.transaction(() async {
      await _restoreUserProfiles(backup.userProfiles);
      await _restoreFoodPreferences(backup.foodPreferences);
      await _restoreNutritionPlans(backup.nutritionPlans);
      await _restoreMacroTargets(backup.macroTargets);
      await _restoreFeedback(backup.feedback);
    });
    
    logger.info('Backup restoration completed from: $latestBackupKey');
  }
  
  Future<void> _restoreUserProfiles(List<Map<String, dynamic>> profiles) async {
    for (final profileData in profiles) {
      await database.into(database.userProfilesTable).insert(
        UserProfilesTableCompanion(
          id: Value(profileData['id']),
          gender: Value(profileData['gender']),
          birthday: Value(DateTime.parse(profileData['birthday'])),
          heightFeet: Value(profileData['height_feet']),
          heightInches: Value(profileData['height_inches']),
          weightPounds: Value(profileData['weight_pounds']),
          runsWithWaterBottle: Value(profileData['runs_with_water_bottle']),
          gutTraining: Value(profileData['gut_training']),
          onboardingCompleted: Value(profileData['onboarding_completed']),
          createdAt: Value(DateTime.parse(profileData['created_at'])),
          updatedAt: Value(DateTime.parse(profileData['updated_at'])),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }
}
```

## Continuous Backup Strategy

### Daily Backups
```dart
class ContinuousBackupService {
  static const Duration BACKUP_INTERVAL = Duration(days: 1);
  
  void startPeriodicBackups() {
    Timer.periodic(BACKUP_INTERVAL, (_) async {
      await createDailyBackup();
    });
  }
  
  Future<void> createDailyBackup() async {
    try {
      final backup = await _createFullBackup();
      await _storeDailyBackup(backup);
      await _cleanupOldBackups();
    } catch (e) {
      logger.error('Daily backup failed', error: e);
    }
  }
  
  Future<void> _cleanupOldBackups() async {
    final prefs = await SharedPreferences.getInstance();
    const maxBackups = 7; // Keep 7 days of backups
    
    final backupKeys = prefs.getKeys()
        .where((key) => key.startsWith('daily_backup_'))
        .toList();
    
    if (backupKeys.length > maxBackups) {
      backupKeys.sort();
      final keysToRemove = backupKeys.take(backupKeys.length - maxBackups);
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    }
  }
}
```

### Cloud Backup Integration
```dart
class CloudBackupService {
  Future<void> backupToCloud() async {
    if (!await _isCloudBackupEnabled()) return;
    
    try {
      final backup = await _createFullBackup();
      final compressed = await _compressBackup(backup);
      
      // Upload to Supabase storage
      await supabase.storage
          .from('user-backups')
          .upload('${deviceId}/backup_${DateTime.now().toIso8601String()}.json.gz', 
                  compressed);
      
      logger.info('Cloud backup completed');
    } catch (e) {
      logger.error('Cloud backup failed', error: e);
    }
  }
  
  Future<void> restoreFromCloud() async {
    try {
      final files = await supabase.storage
          .from('user-backups')
          .list(path: deviceId);
      
      if (files.isEmpty) {
        throw BackupException('No cloud backups found');
      }
      
      // Get most recent backup
      files.sort((a, b) => b.name!.compareTo(a.name!));
      final latestBackup = files.first;
      
      final compressed = await supabase.storage
          .from('user-backups')
          .download('${deviceId}/${latestBackup.name}');
      
      final backup = await _decompressBackup(compressed);
      await _restoreFromBackupData(backup);
      
      logger.info('Cloud restore completed from: ${latestBackup.name}');
    } catch (e) {
      logger.error('Cloud restore failed', error: e);
      throw BackupException('Failed to restore from cloud', e);
    }
  }
}
```

## Testing Backup Systems

### Backup Creation Tests
```dart
group('Migration Backup Tests', () {
  test('creates valid backup before migration', () async {
    // Setup test data
    await database.saveTestUserProfile();
    await database.saveTestFoodPreferences();
    await database.saveTestNutritionPlan();
    
    // Create backup
    final success = await MigrationBackupService().createBackup(1, 2);
    expect(success, isTrue);
    
    // Verify backup exists and contains data
    final prefs = await SharedPreferences.getInstance();
    final backupJson = prefs.getString('migration_backup_v1_to_v2');
    expect(backupJson, isNotNull);
    
    final backup = MigrationBackup.fromJson(jsonDecode(backupJson!));
    expect(backup.userProfiles, hasLength(1));
    expect(backup.foodPreferences, isNotEmpty);
    expect(backup.nutritionPlans, hasLength(1));
  });
  
  test('restores data correctly after failed migration', () async {
    // Create backup
    await MigrationBackupService().createBackup(1, 2);
    
    // Simulate migration failure by corrupting database
    await database.deleteAllData();
    
    // Restore from backup
    await MigrationBackupService().restoreFromBackup();
    
    // Verify data restored
    final users = await database.getAllUserProfiles();
    expect(users, hasLength(1));
  });
});
```

### Recovery Scenario Tests
```dart
group('Recovery Scenario Tests', () {
  test('handles corrupted database gracefully', () async {
    // Simulate database corruption
    await database.corruptDatabase();
    
    // App should detect corruption and restore from backup
    final recovery = RecoveryService();
    final recovered = await recovery.detectAndRecover();
    
    expect(recovered, isTrue);
    
    // Verify app functionality restored
    final users = await database.getAllUserProfiles();
    expect(users, isNotEmpty);
  });
  
  test('recovers from incomplete migration', () async {
    // Simulate incomplete migration
    await MigrationExecutor().startMigration();
    await MigrationExecutor().simulateFailure();
    
    // Recovery should restore to previous state
    final recovery = RecoveryService();
    await recovery.recoverFromFailedMigration();
    
    // Verify database is in consistent state
    final isConsistent = await database.validateConsistency();
    expect(isConsistent, isTrue);
  });
});
```

## Recovery Procedures

### Manual Recovery Steps
1. **Detect Issue**: App startup fails or data appears corrupted
2. **Check Backups**: Verify backup exists and is valid
3. **Clear Database**: Remove corrupted database file
4. **Restore Backup**: Import backup data to fresh database
5. **Validate Restore**: Run consistency checks
6. **Resume Normal Operation**: Continue with restored data

### Automated Recovery
```dart
class AutoRecoveryService {
  Future<bool> attemptAutoRecovery() async {
    try {
      // Step 1: Detect issue
      if (!await _detectDatabaseIssue()) return true;
      
      // Step 2: Attempt backup restoration
      if (await _hasValidBackup()) {
        await _restoreFromBackup();
        return true;
      }
      
      // Step 3: Attempt cloud restore
      if (await _hasCloudBackup()) {
        await _restoreFromCloud();
        return true;
      }
      
      // Step 4: Factory reset as last resort
      await _performFactoryReset();
      return false;
      
    } catch (e) {
      logger.error('Auto recovery failed', error: e);
      return false;
    }
  }
}
```

## Best Practices

### 1. Backup Before Changes
- Always create backup before database migrations
- Verify backup integrity before proceeding
- Store backups in multiple locations

### 2. Test Recovery Procedures
- Regularly test backup and restore processes
- Simulate failure scenarios in development
- Validate data integrity after restoration

### 3. Monitor Backup Health
- Track backup success/failure rates
- Alert on backup storage issues
- Monitor backup file sizes and timestamps

### 4. User Communication
- Inform users about backup operations
- Provide clear error messages for recovery
- Offer manual backup options when possible

This comprehensive backup strategy ensures user data is protected throughout the application lifecycle, with multiple recovery options available when issues occur.