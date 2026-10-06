import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;
import '../../../shared/services/device_info_service.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/app_config.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/analytics/internal_user_service.dart';
import '../../../shared/services/privacy/analytics_consent.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/report/report_identity.dart';
import '../../../shared/services/performance_telemetry.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../nutrition_plan/data/food_repository.dart';
import '../../settings/presentation/providers/settings_controller.dart';
import '../../../shared/services/dirty_record_backup_service.dart';
import '../../../shared/models/dirty_record_backup.dart';
import '../presentation/widgets/dirty_record_recovery_dialog.dart';
import '../../ai_credits/data/revenuecat_service.dart';
import '../../auth/application/auth_service.dart';
import '../../../shared/services/launch_trail.dart';
import '../../subscription/application/subscription_status_provider.dart';

/// Service responsible for providing individual startup operations using Drift
/// Following Andrea Bizzotto's app initialization patterns
///
/// NOTE: Auth state listening is now handled by AuthListenerService (initialized in RootAppWidget)
/// This service focuses on non-auth initialization: database, analytics, push notifications, etc.
class AppStartupService {
  AppStartupService(this.ref);
  final Ref ref;

  /// Guards against double-initializing Mixpanel. Analytics can be initialized
  /// from two places now: deferred startup (consent already on file) and
  /// [initializeAnalyticsAfterConsent] (consent granted just now, mid-session).
  bool _analyticsInitialized = false;

  Report get _report => ref.read(reportProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  AnalyticsTracker get _analytics =>
      ref.read(appExternalDepsProvider).analytics;
  SupabaseClient get _supabase =>
      ref.read(appExternalDepsProvider).supabaseClient;

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
      } catch (e, stackTrace) {
        // A null-check error means the migration didn't backfill properly.
        needsRecovery = e.toString().contains(
          'Null check operator used on a null value',
        );
        if (needsRecovery) {
          await _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'startup',
            message: 'Detected null values in database - will attempt recovery',
          );
        } else {
          // The table should exist by now (onCreate ran on open); say so if
          // it did not, instead of treating a failed read as a fresh install.
          await _report.note(
            'Profile table read failed before health check; continuing',
            area: 'startup',
            data: {'error': e.toString()},
          );
        }
      }

      // AGGRESSIVE FIX: If null values detected, fix them immediately
      if (needsRecovery) {
        try {
          // First check which columns exist (migration may have been interrupted)
          final usersColumns = await db
              .customSelect("PRAGMA table_info(users)")
              .get();
          final columnNames = usersColumns
              .map((row) => row.read<String>('name'))
              .toSet();

          // Add missing columns if needed (interrupted migration recovery)
          if (!columnNames.contains('allergies')) {
            await db.customStatement(
              "ALTER TABLE users ADD COLUMN allergies TEXT NOT NULL DEFAULT '{}'",
            );
          }
          if (!columnNames.contains('dietary_preference')) {
            await db.customStatement(
              'ALTER TABLE users ADD COLUMN dietary_preference TEXT',
            );
          }
          if (!columnNames.contains('needs_upload')) {
            await db.customStatement(
              'ALTER TABLE users ADD COLUMN needs_upload INTEGER NOT NULL DEFAULT 0',
            );
          }

          // Now fix null values that slipped through migration
          await db.customStatement(
            "UPDATE users SET allergies = '{}' WHERE allergies IS NULL OR allergies = ''",
          );
          await db.customStatement(
            "UPDATE users SET needs_upload = 0 WHERE needs_upload IS NULL",
          );

          // Verify fix worked
          await db.select(db.userProfilesTable).get();
        } catch (fixError, stackTrace) {
          await _report.fault(
            fixError,
            stackTrace: stackTrace,
            area: 'startup',
            message:
                'Failed to fix null values - will delete and recreate database',
          );

          // Last resort: delete and recreate
          await db.close();
          await AppDatabase.deleteAndResync(
            reason: 'startup_null_profile_recovery_failed',
            oldSchemaVersion: db.schemaVersion,
          );
          ref.invalidate(appDatabaseProvider);

          // Re-read the provider to trigger fresh database creation
          ref.read(appDatabaseProvider);
          return; // Exit early - fresh database is ready
        }
      }

      // Database health check: fast query check every startup,
      // full PRAGMA integrity_check only once every 24 hours
      bool isHealthy;
      final prefs = await SharedPreferences.getInstance();
      final lastFullCheck = prefs.getInt('last_full_db_health_check') ?? 0;
      final hoursSinceFullCheck =
          DateTime.now().millisecondsSinceEpoch - lastFullCheck;
      final needsFullCheck =
          hoursSinceFullCheck > const Duration(hours: 24).inMilliseconds;

      if (needsFullCheck) {
        // Full PRAGMA integrity_check (slow but thorough)
        isHealthy = await db.diagnosticDao.isDatabaseHealthy();
        if (isHealthy) {
          await prefs.setInt(
            'last_full_db_health_check',
            DateTime.now().millisecondsSinceEpoch,
          );
        }
      } else {
        // Fast query check (SELECT COUNT(*) FROM users)
        isHealthy = await db.diagnosticDao.canExecuteQueries();
      }

      if (!isHealthy) {
        await _report.degraded(
          const LoggedFault(
            'Database corruption detected during startup - initiating recovery',
          ),
          area: 'startup',
          tags: {'full_check': needsFullCheck.toString()},
        );

        // Best-effort: upload dirty records before deleting the database
        try {
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            await ref
                .read(syncCoordinatorProvider.notifier)
                .uploadAllDirtyRecords(userId);
          }
        } catch (e, stackTrace) {
          await _report.degraded(
            e,
            stackTrace: stackTrace,
            area: 'startup',
            message:
                'Could not upload dirty records before corruption recovery',
          );
        }

        // Close current database connection
        await db.close();

        // Delete corrupted database files
        await AppDatabase.deleteAndResync(
          reason: 'startup_database_health_check_failed',
          oldSchemaVersion: db.schemaVersion,
        );

        // Re-initialize with fresh database
        ref.invalidate(appDatabaseProvider);
        final freshDb = ref.read(appDatabaseProvider);

        // Verify fresh database is healthy
        final isFreshHealthy = await freshDb.diagnosticDao.canExecuteQueries();
        if (!isFreshHealthy) {
          throw Exception(
            'Fresh database creation failed after corruption recovery',
          );
        }

        // Reset full check timestamp so next startup runs full check
        await prefs.setInt('last_full_db_health_check', 0);
      }
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Database initialization failed',
      );

      // Last resort: try to recover from catastrophic failure
      try {
        await AppDatabase.deleteAndResync(
          reason: 'startup_database_initialization_exception',
          context: e.runtimeType.toString(),
        );
        ref.invalidate(appDatabaseProvider);
      } catch (recoveryError, recoveryStackTrace) {
        await _report.fault(
          recoveryError,
          stackTrace: recoveryStackTrace,
          area: 'startup',
          message: 'Database recovery failed - app cannot continue',
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
  /// One deferred startup step: timed, and ISOLATED.
  ///
  /// The chain used to be six awaits inside a single try/catch, so the first
  /// failure skipped everything after it. That is how a device-info or
  /// analytics hiccup could stop the notification plugin from ever reading the
  /// payload that launched the app. A step that fails now logs and the chain
  /// continues — these are all best-effort services, and none of them is a
  /// reason to abandon the others.
  Future<void> _deferredStep(String name, Future<void> Function() body) async {
    try {
      await PerformanceTelemetry.measure(name, body);
    } catch (e, stackTrace) {
      if (ref.mounted) {
        await _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'startup',
          message: 'Deferred step failed: $name',
          tags: {'step': name},
        );
      }
    }
  }

  Future<void> initializeDeferredServices() async {
    // Wait for first frame to render before initializing these services
    // This avoids Android DeviceInfoPlugin deadlock
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      // The provider (and its Ref) can be disposed before/while this deferred
      // chain runs — e.g. a sign-out that tears down the scope during startup,
      // or a test harness disposing the ProviderScope. Reading `ref` after that
      // throws UnmountedRefException, so bail early and re-check `ref.mounted`
      // before any post-async-gap `ref` use (including logging).
      if (!ref.mounted) return;
      try {
        // 0. Start the tape BEFORE anything can record to it.
        await LaunchTrail.begin();

        // 1. Local notifications FIRST, and this ordering is load-bearing.
        //
        // `NotificationService.initialize()` is what reads
        // `getNotificationAppLaunchDetails` — the payload of the notification
        // that LAUNCHED this process. Until it runs, a tap that cold-started
        // the app does not exist as far as the app is concerned. It used to
        // sit third, behind device-info and analytics, inside one shared
        // try/catch: anything that threw above it meant the launch payload was
        // never read at all and the athlete silently landed on the dashboard
        // (observed on a physical device in release mode, 2026-09-30).
        //
        // Every step is now fault-isolated too, so one failure can no longer
        // swallow the rest of the chain.
        await _deferredStep('deferred.notifications', () async {
          // The OneSignal app id must be in hand BEFORE initialize() runs —
          // it used to arrive via configure() in deferred.analytics, two
          // steps later, so the 1.29.0 "notifications FIRST" reorder left
          // _initializeOneSignal() bailing on an empty id on every fresh
          // install, fleet-wide (patch #3, 2026-10-03). Analytics consent is
          // NOT a gate here: this is push registration, not tracking — the
          // OS permission prompt is push's own consent. The analytics
          // tracker still only attaches in deferred.analytics, after
          // consent, so tap-event tracking is unchanged.
          NotificationService.configureRemotePush(
            oneSignalAppId: ref.read(appConfigProvider).oneSignalAppId,
          );
          await NotificationService.initialize();
        });

        // 2. Initialize device info (safe after first frame)
        await _deferredStep(
          'deferred.device_info',
          DeviceInfoService.instance.initialize,
        );

        // 3. Initialize analytics with device ID
        await _deferredStep('deferred.analytics', _initializeAnalytics);

        // 4. Check user session for analytics identification
        await _deferredStep('deferred.user_session', checkUserSession);

        // 5. Sync is_coach status from Supabase (for coach mode)
        // This picks up any admin approvals since last app launch
        await _deferredStep('deferred.coach_status', _syncCoachStatus);

        // 5b. Role and device_id tags on every following Sentry event.
        await _deferredStep(
          'deferred.report_identity',
          () => syncReportIdentity(ref),
        );

        // 6. Initialize RevenueCat for AI credits.
        // No-op unless aiCreditsEnabled + a RevenueCat key are configured.
        await _deferredStep('deferred.revenuecat', _initializeRevenueCat);

        // 7. Record the version this launch is running.
        // Written once at account creation, users.app_version decays into a
        // record of what the athlete INSTALLED; reconciling per launch is what
        // makes it answer "has this athlete taken the update", which every
        // rollout reading depends on. Self-healing too: profiles created by
        // the reset paths, which cannot reach a provider, are corrected here on
        // the next cold start.
        if (!ref.mounted) return;
        await _deferredStep(
          'deferred.app_version',
          ref.read(authServiceProvider).reconcileAppVersion,
        );
      } catch (e, stackTrace) {
        // Skip reporting if the scope was disposed mid-chain — `_report`
        // reads `ref` and would throw over the original error.
        if (ref.mounted) {
          await _report.fault(
            e,
            stackTrace: stackTrace,
            area: 'startup',
            message: 'Deferred initialization failed',
          );
        }
        // Don't rethrow - app should continue even if deferred services fail
      }
    });
  }

  /// Initialize analytics once the user has granted consent mid-session.
  ///
  /// The consent screen calls this after recording a grant. Without it, a user
  /// who opts in on first run would send nothing until the next cold start:
  /// deferred startup has already run and skipped analytics by then.
  Future<void> initializeAnalyticsAfterConsent() async {
    if (!ref.read(analyticsConsentProvider).allowsAnalytics) return;
    // Device info is normally initialized by deferred startup ahead of us, but
    // it is idempotent and analytics needs the device id below.
    await DeviceInfoService.instance.initialize();
    await _initializeAnalytics();

    // Re-identify. Deferred startup already ran checkUserSession() — but it ran
    // against the NoopAnalyticsTracker, so the identify call went nowhere. And
    // _initializeAnalytics() only falls back to the device id when there is NO
    // local profile, so a returning user who opts in mid-session would other-
    // wise sit unidentified until the next cold start, splitting their events
    // off from their profile.
    await checkUserSession();
  }

  /// Initialize analytics service with proper user identification
  /// Called after first frame to avoid Android DeviceInfoPlugin deadlock
  Future<void> _initializeAnalytics() async {
    // CONSENT GATE. Nothing may reach Mixpanel until the user has said yes —
    // this method both initializes the SDK and fires `app_opened`, so an
    // ungated call is exactly the "SDK fires at launch before consent" pattern
    // Apple rejects for. `unknown` (not yet asked) fails closed.
    //
    // `analyticsTrackerProvider` independently returns a NoopAnalyticsTracker
    // without consent, so this is belt-and-braces — but it is the check that
    // stops `Mixpanel.init` from ever being called.
    if (!ref.read(analyticsConsentProvider).allowsAnalytics) {
      _logger.info(
        'Analytics initialization skipped — no consent on file',
        context: 'ANALYTICS',
      );
      return;
    }
    if (_analyticsInitialized) return;
    _analyticsInitialized = true;

    try {
      final deviceId = DeviceInfoService.instance.deviceId;

      // Must resolve BEFORE Mixpanel starts: the internal flag is registered as
      // a super property during initialize(), and events begin firing (see
      // `app_opened` below) immediately after. Purely local — no network call.
      //
      // Prefs are passed so it can carry testers off the removed
      // "Exclude this device from analytics" toggle onto `is_internal`, rather
      // than silently starting to track them.
      await InternalUserService.instance.initialize(
        prefs: ref.read(sharedPreferencesProvider),
      );

      await _analytics.initialize();

      // Only identify with the anonymous device id when no local profile
      // exists — checkUserSession() (deferred-init step 4) identifies the
      // real user id. Unconditionally identifying with the device id first
      // flip-flopped the Mixpanel distinct_id on every launch, which can
      // split one user across two profiles whenever user.id != device id
      // (authed accounts), breaking retention counts.
      var hasLocalProfile = false;
      try {
        hasLocalProfile =
            await ref
                .read(appDatabaseProvider)
                .userDao
                .getCurrentUserProfile() !=
            null;
      } catch (e) {
        // Treated as anonymous below; the identify call then uses the
        // device id, which is the wrong distinct_id for a signed-in athlete.
        await _report.note(
          'Local profile lookup failed; identifying as anonymous',
          area: 'startup',
          data: {'error': e.toString()},
        );
      }
      if (!hasLocalProfile) {
        await _analytics.identifyUser(deviceId);
      }

      final config = ref.read(appConfigProvider);
      NotificationService.configure(
        _analytics,
        oneSignalAppId: config.oneSignalAppId,
      );

      // Track app opened event with session ID
      final sessionId = const Uuid().v4();
      await _analytics.track(
        'app_opened',
        properties: {
          'device_id': deviceId,
          'session_id': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e, stackTrace) {
      // Allow a later attempt (e.g. the post-consent call) to retry.
      _analyticsInitialized = false;
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Analytics initialization failed',
        tags: {'component': 'analytics'},
      );
      // Don't rethrow - app should continue even if analytics fails
    }
  }

  /// Initialize RevenueCat for the AI-credits feature.
  ///
  /// No-op unless [AppConfig.aiCreditsEnabled] is true and a RevenueCat key is
  /// configured (see [RevenueCatService.configureIfPossible]). Identifies the
  /// RevenueCat customer with the Supabase auth user id so purchase webhooks
  /// credit the correct wallet (token_wallets.user_id == auth.users.id).
  Future<void> _initializeRevenueCat() async {
    try {
      final revenueCat = ref.read(revenueCatServiceProvider);
      await revenueCat.configureIfPossible();
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        await revenueCat.logIn(userId);
      }
      // Pro entitlement: prime the status provider now that the SDK is
      // configured and identified. `refresh()` (re)attaches the CustomerInfo
      // listener and resolves RevenueCat ∪ server row ∪ tester flag, so a
      // provider that was first read before this point (router redirect,
      // tabs) picks up the real answer instead of "not configured".
      await ref.read(subscriptionStatusProvider.notifier).refresh();
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'RevenueCat initialization failed',
        tags: {'component': 'revenuecat'},
      );
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
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Coach status sync failed',
      );
      // Don't rethrow - app should continue even if coach sync fails
    }
  }

  /// Put the Supabase user id on every event from the first frame on. Cheap
  /// and local: role and device id follow in `deferred.report_identity`
  /// (the coach lookup and the device plugin both wait for the first frame).
  Future<void> setSentryUserContext() async {
    final report = ref.read(reportProvider);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        await report.clearUser();
      } else {
        await report.setUser(userId);
      }
    } catch (e, stackTrace) {
      // The app continues without identity; the next event says why.
      await report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Report identity: startup setUser failed',
      );
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
      final user = await database.userDao.getLocalUserProfile();

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

      final authUserId = _supabase.auth.currentUser?.id;
      await NotificationService.setRemotePushUserId(authUserId);
    } catch (e, stackTrace) {
      // A missing profile is null, not a throw: anything caught here is a
      // real failure, and the push user id was not set.
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Session check failed',
      );
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
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Plan initialization failed',
      );
      // Continue - app should work without plans
    }
  }

  /// Emergency fallback: Load foods if local database is empty AND sync failed
  /// This should rarely be called - only if initial sync failed after onboarding
  /// Uses get-foods edge function as last resort
  Future<void> fallbackLoadFoods() async {
    try {
      final database = ref.read(appDatabaseProvider);

      // Check if foods table is empty
      final foodCount = await database
          .select(database.foodsTable)
          .get()
          .then((rows) => rows.length);

      if (foodCount == 0) {
        // Last resort: call get-foods edge function directly
        final foodRepository = ref.read(foodRepositoryProvider);
        await foodRepository.getAllFoods();
      }
    } catch (e, stackTrace) {
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Fallback food load failed - app will continue with no foods',
      );
      // Don't rethrow - app should continue even if fallback fails
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
        await _report.degraded(
          const LoggedFault('Backup file exists but could not be recovered'),
          area: 'startup',
          tags: {'component': 'dirty_record_recovery'},
        );
        return false;
      }

      // Show recovery dialog to user
      if (!context.mounted) {
        await _report.note(
          'Context not mounted, cannot show recovery dialog',
          area: 'startup',
          data: {'record_count': backup.totalRecordCount},
        );
        return false;
      }

      final userChoice = await DirtyRecordRecoveryDialog.show(context, backup);

      if (userChoice == null) {
        // User dismissed dialog (shouldn't happen since barrierDismissible: false)
        await _report.note(
          'Recovery dialog dismissed without choice',
          area: 'startup',
          data: {'record_count': backup.totalRecordCount},
        );
        return false;
      }

      // Handle user choice
      if (userChoice == RecoveryChoice.upload) {
        await _uploadBackupRecords(backup);
        await _analytics.track(
          'dirty_records_uploaded',
          properties: {
            'record_count': backup.totalRecordCount,
            'repositories': backup.dirtyRecords.keys.toList(),
          },
        );
      } else {
        await _analytics.track(
          'dirty_records_discarded',
          properties: {
            'record_count': backup.totalRecordCount,
            'repositories': backup.dirtyRecords.keys.toList(),
          },
        );
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
      await _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Failed to handle dirty record backup',
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

        // Report, then continue with the other repositories.
        await _report.fault(
          e,
          stackTrace: stackTrace,
          area: 'startup',
          message: 'Failed to upload backup records',
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
    await _analytics.track(
      'backup_upload_completed',
      properties: {
        'total_records': backup.totalRecordCount,
        'success_count': successCount,
        'failure_count': failureCount,
        'success_rate': backup.totalRecordCount > 0
            ? (successCount / backup.totalRecordCount)
            : 0,
      },
    );
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
