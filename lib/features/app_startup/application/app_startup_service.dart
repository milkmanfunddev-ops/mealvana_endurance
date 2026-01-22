import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../shared/services/device_info_service.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/push_notification_service.dart';
import '../../../shared/services/app_config.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../nutrition_plan/data/food_repository.dart';
import '../../settings/presentation/providers/settings_controller.dart';
import '../../../shared/services/dirty_record_backup_service.dart';
import '../../../shared/models/dirty_record_backup.dart';
import '../presentation/widgets/dirty_record_recovery_dialog.dart';

/// Service responsible for providing individual startup operations using Drift
/// Following Andrea Bizzotto's app initialization patterns
///
/// NOTE: Auth state listening is now handled by AuthListenerService (initialized in RootAppWidget)
/// This service focuses on non-auth initialization: database, analytics, push notifications, etc.
class AppStartupService {
  AppStartupService(this.ref);
  final Ref ref;

  SentryReporter get _sentry => ref.read(appExternalDepsProvider).sentry;
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  AnalyticsTracker get _analytics => ref.read(appExternalDepsProvider).analytics;
  SupabaseClient get _supabase => ref.read(appExternalDepsProvider).supabaseClient;

  /// Initialize Drift database with v2 migration support and corruption detection
  Future<void> initializeDatabase() async {
    try {
      // Touch the database provider so migrations run.
      // The database is ready immediately - Drift's LazyDatabase handles
      // async initialization internally (onCreate, onUpgrade, beforeOpen).
      final db = ref.read(appDatabaseProvider);

      // CRITICAL FIX: Force LazyDatabase initialization before accessing tables
      // This prevents race condition where background isolate hasn't spawned yet
      // Use PRAGMA user_version (always works, doesn't require schema)
      await db.customSelect('PRAGMA user_version').get();

      // Trigger lazy initialization by accessing the database
      // This ensures onCreate/migration runs before we proceed
      // Try to read user profiles to verify schema is ready
      bool needsRecovery = false;
      try {
        await db.select(db.userProfilesTable).get();
      } catch (e) {
        // If we get a null check error, it means the migration didn't backfill properly
        if (e.toString().contains('Null check operator used on a null value')) {
          _logger.warning(
            'Detected null values in database - will attempt recovery',
            context: 'DATABASE',
          );
          needsRecovery = true;
        }
        // Otherwise on fresh install, table might not exist yet - that's OK
      }

      // AGGRESSIVE FIX: If null values detected, fix them immediately
      if (needsRecovery) {
        try {
          // First check which columns exist (migration may have been interrupted)
          final usersColumns = await db.customSelect("PRAGMA table_info(users)").get();
          final columnNames = usersColumns.map((row) => row.read<String>('name')).toSet();

          // Add missing columns if needed (interrupted migration recovery)
          if (!columnNames.contains('allergies')) {
            await db.customStatement(
              "ALTER TABLE users ADD COLUMN allergies TEXT NOT NULL DEFAULT '{}'"
            );
          }
          if (!columnNames.contains('dietary_preference')) {
            await db.customStatement(
              'ALTER TABLE users ADD COLUMN dietary_preference TEXT'
            );
          }
          if (!columnNames.contains('needs_upload')) {
            await db.customStatement(
              'ALTER TABLE users ADD COLUMN needs_upload INTEGER NOT NULL DEFAULT 0'
            );
          }

          // Now fix null values that slipped through migration
          await db.customStatement(
            "UPDATE users SET allergies = '{}' WHERE allergies IS NULL OR allergies = ''"
          );
          await db.customStatement(
            "UPDATE users SET needs_upload = 0 WHERE needs_upload IS NULL"
          );

          // Verify fix worked
          await db.select(db.userProfilesTable).get();
        } catch (fixError) {
          _logger.error(
            'Failed to fix null values - will delete and recreate database',
            context: 'DATABASE',
            error: fixError,
          );

          // Last resort: delete and recreate
          await db.close();
          await AppDatabase.deleteAndResync();
          ref.invalidate(appDatabaseProvider);

          // Re-read the provider to trigger fresh database creation
          ref.read(appDatabaseProvider);
          return; // Exit early - fresh database is ready
        }
      }

      // CRITICAL: Run database health check after initialization
      // This detects SQLite corruption early before it causes crashes
      final isHealthy = await db.diagnosticDao.isDatabaseHealthy();

      if (!isHealthy) {
        _logger.warning(
          'Database corruption detected during startup - initiating recovery',
          context: 'DATABASE',
        );

        // Close current database connection
        await db.close();

        // Delete corrupted database files
        await AppDatabase.deleteAndResync();

        // Re-initialize with fresh database
        ref.invalidate(appDatabaseProvider);
        final freshDb = ref.read(appDatabaseProvider);

        // Verify fresh database is healthy
        final isFreshHealthy = await freshDb.diagnosticDao.canExecuteQueries();
        if (!isFreshHealthy) {
          throw Exception('Fresh database creation failed after corruption recovery');
        }

        // Trigger full sync will happen automatically when user session is detected
      }

    } catch (e, stackTrace) {
      _logger.error('Database initialization failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );

      // Last resort: try to recover from catastrophic failure
      try {
        await AppDatabase.deleteAndResync();
        ref.invalidate(appDatabaseProvider);
      } catch (recoveryError) {
        _logger.error(
          'Database recovery failed - app cannot continue',
          context: 'DATABASE',
          error: recoveryError,
        );
        rethrow; // Re-throw to trigger error handling in AppStartupWidget
      }
    }
  }

  /// Initialize deferred services after first frame renders.
  /// This includes analytics, device info, and push notifications.
  ///
  /// IMPORTANT: On Android, DeviceInfoPlugin can deadlock if called during
  /// app startup. By deferring these to post-frame, we avoid the deadlock
  /// while still initializing everything promptly.
  Future<void> initializeDeferredServices() async {
    // Wait for first frame to render before initializing these services
    // This avoids Android DeviceInfoPlugin deadlock
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        // 1. Initialize device info (safe after first frame)
        await DeviceInfoService.instance.initialize();

        // 2. Initialize analytics with device ID
        await _initializeAnalytics();

        // 3. Check user session for analytics identification
        await checkUserSession();

        // 4. Initialize push notifications
        await _initializePushNotifications();

        // 5. Sync is_coach status from Supabase (for coach mode)
        // This picks up any admin approvals since last app launch
        await _syncCoachStatus();
      } catch (e, stackTrace) {
        _logger.error(
          'Deferred initialization failed',
          context: 'DEFERRED_INIT',
          error: e,
          stackTrace: stackTrace,
        );
        // Don't rethrow - app should continue even if deferred services fail
      }
    });
  }

  /// Initialize analytics service with proper user identification
  /// Called after first frame to avoid Android DeviceInfoPlugin deadlock
  Future<void> _initializeAnalytics() async {
    try {
      final deviceId = DeviceInfoService.instance.deviceId;
      await _analytics.initialize();
      await _analytics.identifyUser(deviceId);
      NotificationService.configure(_analytics);
      PushNotificationService.configure(_analytics);

      // Track app opened event with session ID
      final sessionId = const Uuid().v4();
      await _analytics.track('app_opened', properties: {
        'device_id': deviceId,
        'session_id': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e, stackTrace) {
      _logger.error(
        'Analytics initialization failed',
        context: 'ANALYTICS',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if analytics fails
    }
  }

  /// Refresh coach status from local coaches table
  /// The coach record is synced via sync-all-data edge function
  /// This just ensures the settings controller is aware of coach status
  Future<void> _syncCoachStatus() async {
    try {
      // Only sync if user is logged in (has session)
      final session = _supabase.auth.currentSession;
      if (session == null) return;

      // Coach record is synced during data sync, just invalidate settings
      // to ensure it picks up the latest coach status from local coaches table
      ref.invalidate(settingsControllerProvider);
    } catch (e, stackTrace) {
      _logger.error(
        'Coach status sync failed',
        context: 'COACH_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if coach sync fails
    }
  }

  /// Initialize OneSignal push notification service
  Future<void> _initializePushNotifications() async {
    try {
      final config = ref.read(appConfigProvider);

      if (config.oneSignalAppId.isEmpty) return;

      // Initialize OneSignal
      await PushNotificationService.initialize(config.oneSignalAppId);

      // Login with device ID for user targeting
      final deviceId = DeviceInfoService.instance.deviceId;
      await PushNotificationService.login(deviceId);

      // Request permission - shows iOS prompt if not already granted
      await PushNotificationService.requestPermission();
    } catch (e, stackTrace) {
      _logger.error(
        'Push notification initialization failed',
        context: 'PUSH_NOTIFICATIONS',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if push notifications fail
    }
  }

  /// Set Sentry user context during app startup
  /// Uses Supabase auth ID (not device ID) to avoid DeviceInfoPlugin deadlock
  Future<void> setSentryUserContext() async {
    try {
      // Use Supabase auth ID if available, otherwise defer to later
      final supabaseUser = _supabase.auth.currentUser;
      final userId = supabaseUser?.id ?? 'anonymous';

      await _sentry.setUserContext(
        deviceId: userId,
        appVersion: '1.1.0+8',
      );

    } catch (e, stackTrace) {
      // Don't use Sentry to report Sentry initialization errors
      _logger.error('Sentry user context error',
        context: 'SENTRY',
        error: e,
        stackTrace: stackTrace
      );
      // Don't rethrow - app should continue even if Sentry fails
    }
  }

  /// Get or create a persistent device ID for analytics
  /// NOTE: Only call this AFTER first frame to avoid Android deadlock
  Future<String> getOrCreateDeviceId() async {
    if (!DeviceInfoService.instance.isInitialized) {
      await DeviceInfoService.instance.initialize();
    }
    return DeviceInfoService.instance.deviceId;
  }

  /// Check if user has existing session and restore it
  Future<void> checkUserSession() async {
    try {
      final database = ref.read(appDatabaseProvider);
      final user = await database.userDao.getCurrentUserProfile();

      if (user != null) {
        // User exists locally - identify them properly in analytics
        await _analytics.identifyUser(
          user.id,
          gender: user.gender.name,
          age: user.age,
          weightPounds: user.weightPounds,
          runsWithWaterBottle: user.runsWithWaterBottle,
          gutTrainingLevel: user.gutTraining.name,
        );
      }
    } catch (e, stackTrace) {
      _logger.error('Session check error',
        context: 'AUTH',
        error: e,
        stackTrace: stackTrace
      );
      // Continue without user session - this is expected on fresh installs
    }
  }

  /// Initialize nutrition plan cache (now using Drift as primary storage)
  Future<void> initializeNutritionPlans() async {
    try {
      final database = ref.read(appDatabaseProvider);
      final currentAuthUserId = _supabase.auth.currentUser?.id;

      // Check if we have a current user
      final user = await database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );

      if (user != null) {
        // Note: Nutrition plans are now embedded in activities table
        // No initialization needed - plans are loaded with activities
      }
    } catch (e) {
      _logger.error('Plan initialization error',
        context: 'NUTRITION_PLAN',
        error: e
      );
      // Continue - app should work without plans (expected on fresh installs)
    }
  }

  /// Emergency fallback: Load foods if local database is empty AND sync failed
  /// This should rarely be called - only if initial sync failed after onboarding
  /// Uses get-foods edge function as last resort
  Future<void> fallbackLoadFoods() async {
    try {
      final database = ref.read(appDatabaseProvider);

      // Check if foods table is empty
      final foodCount = await database.select(database.foodsTable).get().then((rows) => rows.length);

      if (foodCount == 0) {
        // Last resort: call get-foods edge function directly
        final foodRepository = ref.read(foodRepositoryProvider);
        await foodRepository.getAllFoods();
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Fallback food load failed - app will continue with no foods',
        context: 'FOOD_DATA_FALLBACK',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if fallback fails
    }
  }

  /// Check for activities that need feedback after run time has passed
  /// Also checks for notification-based navigation
  Future<String?> checkForPendingFeedback() async {
    try {
      final notificationActivityId = NotificationService.getPendingNavigationActivityId();
      if (notificationActivityId != null) {
        return notificationActivityId;
      }

      final database = ref.read(appDatabaseProvider);
      final currentAuthUserId = _supabase.auth.currentUser?.id;

      // Check if we have a current user
      final user = await database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      if (user == null) return null;

      // Get plans that have a run date/time in the past but no feedback yet
      final now = DateTime.now();
      final planActivities = await database.activityDao.getActivitiesWithNutritionPlans(user.id);

      for (final activity in planActivities) {
        final planDataRaw = activity.nutritionPlanData;
        if (planDataRaw == null || planDataRaw.isEmpty) continue;

        final planJson = jsonDecode(planDataRaw) as Map<String, dynamic>;
        final runDateTimeString = planJson['runDateTime'] as String?;
        if (runDateTimeString == null) continue;

        final runDateTime = DateTime.tryParse(runDateTimeString);
        if (runDateTime == null || runDateTime.isAfter(now)) continue;

        final hasRating = planJson['planRating'] != null;
        final hasNotes = (planJson['journalNotes'] as String?)?.isNotEmpty ?? false;

        if (!hasRating && !hasNotes) {
          return activity.id;
        }
      }

      return null; // No plans need feedback
    } catch (e) {
      _logger.error('Error checking for pending feedback',
        context: 'FEEDBACK_CHECK',
        error: e
      );
      return null; // Continue without feedback check if it fails
    }
  }

  /// Check for dirty record backups on startup and prompt for recovery
  ///
  /// This should be called early in app startup, after database initialization
  /// but before any sync operations. If a backup is found, the user is prompted
  /// to either upload the records or discard them.
  ///
  /// Returns true if backup was handled (uploaded or discarded), false if no backup exists
  Future<bool> checkAndHandleDirtyRecordBackup(BuildContext context) async {
    try {
      final backupService = DirtyRecordBackupService(logger: _logger);

      // Check if backup exists
      final hasBackup = await backupService.hasBackup();
      if (!hasBackup) {
        return false; // No backup to handle
      }

      // Recover the backup
      final backup = await backupService.recoverBackup();
      if (backup == null) {
        _logger.warning(
          'Backup file exists but could not be recovered',
          context: 'DIRTY_RECORD_RECOVERY',
        );
        return false;
      }

      // Show recovery dialog to user
      if (!context.mounted) {
        _logger.warning(
          'Context not mounted, cannot show recovery dialog',
          context: 'DIRTY_RECORD_RECOVERY',
        );
        return false;
      }

      final userChoice = await DirtyRecordRecoveryDialog.show(context, backup);

      if (userChoice == null) {
        // User dismissed dialog (shouldn't happen since barrierDismissible: false)
        _logger.warning(
          'Recovery dialog dismissed without choice',
          context: 'DIRTY_RECORD_RECOVERY',
        );
        return false;
      }

      // Handle user choice
      if (userChoice == RecoveryChoice.upload) {
        await _uploadBackupRecords(backup);
        await _analytics.track('dirty_records_uploaded', properties: {
          'record_count': backup.totalRecordCount,
          'repositories': backup.dirtyRecords.keys.toList(),
        });
      } else {
        await _analytics.track('dirty_records_discarded', properties: {
          'record_count': backup.totalRecordCount,
          'repositories': backup.dirtyRecords.keys.toList(),
        });
      }

      // Delete backup file regardless of choice
      await backupService.deleteBackup();

      _logger.info(
        'Dirty record backup handled successfully',
        data: {
          'choice': userChoice.name,
          'record_count': backup.totalRecordCount,
        },
      );

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to handle dirty record backup',
        context: 'DIRTY_RECORD_RECOVERY',
        error: e,
        stackTrace: stackTrace,
      );

      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'dirty_record_recovery_failed',
        tags: {
          'error_type': 'recovery_handler_failed',
          'operation': 'check_and_handle_backup',
        },
      );

      // Don't rethrow - app should continue even if recovery fails
      return false;
    }
  }

  /// Upload backed up dirty records to Supabase
  ///
  /// This attempts to upload all dirty records from the backup to Supabase.
  /// Records are uploaded per repository using direct Supabase queries.
  Future<void> _uploadBackupRecords(DirtyRecordBackup backup) async {
    int successCount = 0;
    int failureCount = 0;

    // Upload records for each repository
    for (final entry in backup.dirtyRecords.entries) {
      final repositoryKey = entry.key;
      final records = entry.value;

      if (records.isEmpty) continue;

      try {
        // Determine table name from repository key
        final tableName = _getTableNameFromRepositoryKey(repositoryKey);

        // Upload records using upsert
        await _supabase.from(tableName).upsert(records);

        successCount += records.length;

        _logger.info(
          'Successfully uploaded backup records',
          data: {
            'repository': repositoryKey,
            'table': tableName,
            'count': records.length,
          },
        );
      } catch (e, stackTrace) {
        failureCount += records.length;

        _logger.error(
          'Failed to upload backup records',
          context: repositoryKey.toUpperCase(),
          error: e,
          stackTrace: stackTrace,
        );

        // Log to Sentry but continue with other repositories
        await _sentry.reportCriticalError(
          e,
          stackTrace: stackTrace,
          context: 'backup_upload_failed_$repositoryKey',
          tags: {
            'error_type': 'backup_upload_failed',
            'repository': repositoryKey,
            'record_count': records.length.toString(),
          },
        );
      }
    }

    // Log final results
    _logger.info(
      'Backup upload completed',
      data: {
        'total_records': backup.totalRecordCount,
        'success_count': successCount,
        'failure_count': failureCount,
      },
    );

    // Track analytics
    await _analytics.track('backup_upload_completed', properties: {
      'total_records': backup.totalRecordCount,
      'success_count': successCount,
      'failure_count': failureCount,
      'success_rate': backup.totalRecordCount > 0
          ? (successCount / backup.totalRecordCount)
          : 0,
    });
  }

  /// Map repository key to Supabase table name
  String _getTableNameFromRepositoryKey(String repositoryKey) {
    switch (repositoryKey) {
      case 'activities':
        return 'activities';
      case 'events':
        return 'events';
      case 'carb_loading_plans':
        return 'carb_loading_plans';
      case 'carb_loading_days':
        return 'carb_loading_days';
      case 'carb_loading_day_meals':
        return 'carb_loading_day_meals';
      case 'food_preferences':
        return 'food_preferences';
      case 'user_foods':
        return 'user_foods';
      case 'carb_loading_user_foods':
        return 'carb_loading_user_foods';
      case 'feedback':
        return 'feedback';
      case 'coaches':
        return 'coaches';
      case 'coach_athlete_relationships':
        return 'coach_athlete_relationships';
      case 'coach_messages':
        return 'coach_messages';
      default:
        throw ArgumentError('Unknown repository key: $repositoryKey');
    }
  }
}

/// Provider for AppStartupService (Drift version)
final appStartupServiceProvider = Provider<AppStartupService>((ref) {
  return AppStartupService(ref);
});
