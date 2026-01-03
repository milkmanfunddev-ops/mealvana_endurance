import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../shared/services/device_info_service.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/push_notification_service.dart';
import '../../../shared/services/app_config.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../nutrition_plan/data/food_repository.dart';
import '../../auth/data/user_repository.dart';
import '../../settings/presentation/providers/settings_controller.dart';
import '../../activities/presentation/providers/activities_controller.dart';
import '../../events/presentation/providers/events_controller.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/sync/sync_coordinator.dart';
import 'app_startup_provider.dart';

/// Service responsible for providing individual startup operations using Drift
/// Following Andrea Bizzotto's app initialization patterns
/// Replaces the Hive-based AppStartupService
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
          _logger.info('Attempting to fix null values in database', context: 'DATABASE');

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

          _logger.info('Successfully fixed null values', context: 'DATABASE');

          // Verify fix worked
          await db.select(db.userProfilesTable).get();
          _logger.info('Database verification passed after fix', context: 'DATABASE');
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

          // Re-read the provider to get fresh database
          final freshDb = ref.read(appDatabaseProvider);

          _logger.info('Database recreated successfully', context: 'DATABASE');
          return; // Exit early - fresh database is ready
        }
      }

      // CRITICAL: Run database health check after initialization
      // This detects SQLite corruption early before it causes crashes
      final isHealthy = await db.isDatabaseHealthy();

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
        final isFreshHealthy = await freshDb.canExecuteQueries();
        if (!isFreshHealthy) {
          throw Exception('Fresh database creation failed after corruption recovery');
        }

        _logger.info(
          'Database recovered successfully - will sync on next login',
          context: 'DATABASE',
        );

        // Trigger full sync will happen automatically when user session is detected
      } else {
        _logger.info('Database health check passed', context: 'DATABASE');
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
        _logger.info('Database recovered after catastrophic failure', context: 'DATABASE');
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
      debugPrint('[DEFERRED_INIT] Post-frame: Starting deferred initialization...');
      final sw = Stopwatch()..start();

      try {
        // 1. Initialize device info (safe after first frame)
        await DeviceInfoService.instance.initialize();
        debugPrint('[DEFERRED_INIT] Device info initialized: ${sw.elapsedMilliseconds}ms');

        // 2. Initialize analytics with device ID
        await _initializeAnalytics();
        debugPrint('[DEFERRED_INIT] Analytics initialized: ${sw.elapsedMilliseconds}ms');

        // 3. Check user session for analytics identification
        await checkUserSession();
        debugPrint('[DEFERRED_INIT] User session checked: ${sw.elapsedMilliseconds}ms');

        // 4. Initialize push notifications
        await _initializePushNotifications();
        debugPrint('[DEFERRED_INIT] Push notifications initialized: ${sw.elapsedMilliseconds}ms');

        debugPrint('[DEFERRED_INIT] ✅ All deferred services initialized: ${sw.elapsedMilliseconds}ms');
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
      await _analytics.trackAppOpened(
        deviceId: deviceId,
        sessionId: sessionId,
      );
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

  /// Initialize OneSignal push notification service
  Future<void> _initializePushNotifications() async {
    try {
      final config = ref.read(appConfigProvider);

      if (config.oneSignalAppId.isEmpty) {
        _logger.info(
          'OneSignal App ID not configured - skipping push notification initialization',
          context: 'PUSH_NOTIFICATIONS',
        );
        return;
      }

      // Initialize OneSignal
      await PushNotificationService.initialize(config.oneSignalAppId);

      // Login with device ID for user targeting
      final deviceId = DeviceInfoService.instance.deviceId;
      await PushNotificationService.login(deviceId);

      // Request permission - shows iOS prompt if not already granted
      final permissionGranted = await PushNotificationService.requestPermission();

      _logger.info(
        'Push notifications initialized successfully',
        context: 'PUSH_NOTIFICATIONS',
        data: {'permission_granted': permissionGranted},
      );
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

  /// Track auth state listener subscription to prevent duplicates
  StreamSubscription<AuthState>? _authStateSubscription;

  /// Flag to prevent infinite loop when signing out due to session mismatch
  /// When true, the signedOut handler skips invalidating appStartupProvider
  /// because we're already handling the state in the startup flow
  bool _isSigningOutDueToMismatch = false;

  /// Flag to skip setting up auth listener when in "logged out with local data" state
  /// This prevents infinite loop: listener setup -> signedOut event -> invalidate -> repeat
  bool _skipAuthListenerSetup = false;

  /// Initialize Supabase Anonymous Authentication
  /// Creates or restores an anonymous auth session for the user
  /// This is the foundation for all Supabase Auth-based operations
  Future<void> initializeSupabaseAuth() async {
    try {
      // Check if we already have a session (SDK auto-restores from secure storage)
      final existingSession = _supabase.auth.currentSession;

      if (existingSession != null) {
        // Session restored from secure storage - verify it matches local data
        final database = ref.read(appDatabaseProvider);
        final localProfile = await database.getCurrentUserProfile();

        if (localProfile != null && localProfile.onboardingCompleted) {
          // Check if restored session matches local profile
          final sessionUserId = existingSession.user.id;
          final localAuthUserId = localProfile.authUserId;
          final localId = localProfile.id;

          // Session matches if authUserId OR id equals session user
          final sessionMatches = localAuthUserId == sessionUserId ||
              localId == sessionUserId;

          if (!sessionMatches) {
            // MISMATCH: Orphan session doesn't match local data
            // This happens when a new anonymous session was created after logout
            // but old local data was preserved. Clear the orphan session.
            _logger.info(
              'Session mismatch detected - clearing orphan Supabase session',
              context: 'AUTH',
              data: {
                'session_user_id': sessionUserId,
                'local_id': localId,
                'local_auth_user_id': localAuthUserId,
              },
            );
            _sentry.addBreadcrumb(
              message: 'Clearing orphan Supabase session - mismatch with local data',
              category: 'auth',
              data: {
                'session_user_id': sessionUserId,
                'local_id': localId,
                'local_auth_user_id': localAuthUserId,
              },
            );

            // Set flags to prevent infinite loop
            // 1. Skip provider invalidation in signedOut handler
            // 2. Skip auth listener setup in finally block
            _isSigningOutDueToMismatch = true;
            _skipAuthListenerSetup = true;

            // Sign out to clear the orphan session
            // Local data is preserved - user can sign back in
            await _supabase.auth.signOut();

            // Return early - app will be in "logged out with local data" state
            // Router will redirect to welcome screen
            return;
          }
        }

        // Session matches local data (or no local data) - proceed normally
        _sentry.addBreadcrumb(
          message: 'Supabase session restored',
          category: 'auth',
          data: {
            'user_id': existingSession.user.id,
          },
        );
        // Don't return early - setup listener in finally block
      } else {
        // No existing session - check if user logged out with local data
        // If so, don't create anonymous user - let them sign back in
        final database = ref.read(appDatabaseProvider);
        final localProfile = await database.getCurrentUserProfile();

        if (localProfile != null && localProfile.onboardingCompleted) {
          // User has logged out but has local data - skip anonymous auth
          // They can sign back in from welcome screen to access their data
          _logger.info(
            'Logged out user with local data detected - skipping anonymous auth',
            context: 'AUTH',
          );
          _sentry.addBreadcrumb(
            message: 'Logged out user with local data - skipping anonymous auth',
            category: 'auth',
            data: {
              'local_user_id': localProfile.id,
              'onboarding_completed': localProfile.onboardingCompleted,
            },
          );
          // Skip auth listener setup - no session to monitor
          // Setting up listener would cause infinite loop (signedOut -> invalidate -> repeat)
          _skipAuthListenerSetup = true;
          // Don't create anonymous user - exit early
          // App router will redirect to welcome screen
          return;
        }

        // No local profile or incomplete onboarding - create anonymous user
        final response = await _supabase.auth.signInAnonymously();

        if (response.session == null || response.user == null) {
          throw Exception('Failed to create anonymous session - null response');
        }

        // Add Sentry breadcrumb for tracking (analytics is deferred to post-frame)
        _sentry.addBreadcrumb(
          message: 'Anonymous Supabase user created',
          category: 'auth',
          data: {
            'user_id': response.user!.id,
            'auth_provider': 'anonymous',
          },
        );
      }
    } catch (e, stackTrace) {
      _logger.error(
        'Supabase Auth initialization failed',
        context: 'AUTH',
        error: e,
        stackTrace: stackTrace,
      );

      // Report critical error to Sentry
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'supabase_auth_init_failure',
        tags: {
          'error_type': 'auth_initialization_failure',
          'operation': 'sign_in_anonymously',
        },
      );

      // Re-throw to trigger error handling in AppStartupWidget
      // User will see error screen with retry option
      rethrow;
    } finally {
      // Check if we should skip listener setup (logged out with local data state)
      if (_skipAuthListenerSetup) {
        _skipAuthListenerSetup = false; // Reset flag
        _logger.info(
          'Skipping auth listener setup - in logged out with local data state',
          context: 'AUTH',
        );
      } else {
        // Setup auth state listener ONCE, regardless of path taken
        // This prevents duplicate listeners that cause race conditions
        setupAuthStateListener();
      }
    }
  }

  /// Setup auth state change listener for session monitoring
  /// Tracks token refreshes and sign-out events
  ///
  /// Note: With native OAuth, account linking completes synchronously
  /// within OAuthService methods, so we no longer need OAuth callbacks here
  ///
  /// IMPORTANT: This listener is now NON-BLOCKING to prevent race conditions
  /// during navigation. Heavy operations are deferred to background.
  void setupAuthStateListener() {
    // Cancel existing subscription to prevent duplicates
    _authStateSubscription?.cancel();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      // Handle token refresh events
      if (event == AuthChangeEvent.tokenRefreshed) {
        await _analytics.track('auth_token_refreshed', properties: {
          'user_id': session?.user.id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Handle sign-out events
      if (event == AuthChangeEvent.signedOut) {
        // Check if this is a mismatch-triggered signout (during startup)
        // If so, skip provider invalidation to prevent infinite loop
        final wasMismatchSignOut = _isSigningOutDueToMismatch;
        _isSigningOutDueToMismatch = false; // Reset flag

        // NOTE: session?.user.id is null here because session is already cleared
        // Sync timestamp is cleared in SettingsController.signOut() BEFORE sign-out
        // while we still have access to the user ID

        await _analytics.track('user_signed_out', properties: {
          'timestamp': DateTime.now().toIso8601String(),
          'was_mismatch_signout': wasMismatchSignOut,
        });

        try {
          // DON'T clear local data - keep for offline-first architecture
          // This allows users to sign back in offline and see their data
          // Data is already isolated by user_id via getCurrentUserProfile()

          // Skip provider invalidation if this was a mismatch signout
          // The startup flow is already handling the state correctly
          if (wasMismatchSignOut) {
            _logger.info(
              'Mismatch signout handled - skipping provider invalidation',
              context: 'AUTH',
            );
          } else {
            // User-initiated signout - invalidate providers so UI shows login screen
            ref.invalidate(userIdProvider);
            ref.invalidate(activitiesControllerProvider);
            ref.invalidate(allEventsProvider);
            ref.invalidate(nextUpcomingEventProvider);
            ref.invalidate(settingsControllerProvider);
            ref.invalidate(appStartupProvider);

            _logger.info(
              'User signed out - keeping local data for offline access',
              context: 'AUTH',
            );
          }

          _sentry.addBreadcrumb(
            message: wasMismatchSignOut
                ? 'Mismatch signout - no invalidation needed'
                : 'User signed out - local data preserved',
            category: 'auth',
            data: {
              'timestamp': DateTime.now().toIso8601String(),
              'was_mismatch_signout': wasMismatchSignOut,
            },
          );
        } catch (e, stackTrace) {
          _logger.error(
            'Failed to handle sign-out',
            context: 'AUTH',
            error: e,
            stackTrace: stackTrace,
          );

          await _sentry.reportCriticalError(
            e,
            stackTrace: stackTrace,
            context: 'sign_out_handler_failed',
            tags: {
              'error_type': 'sign_out_handler_failed',
              'operation': 'sign_out_handler',
            },
          );
        }
      }

      // Handle sign-in events - NON-BLOCKING to prevent navigation hangs
      if (event == AuthChangeEvent.signedIn) {
        final userId = session?.user.id;

        if (userId != null) {
          // Only invalidate the identity provider immediately
          // This allows navigation to proceed without waiting for data sync
          ref.invalidate(userIdProvider);

          // Defer ALL heavy operations to background
          // This prevents race conditions during navigation in release mode
          unawaited(_performPostAuthSync(userId));
        }
      }
    });
  }

  /// Perform post-authentication sync operations in the background
  /// This runs AFTER navigation completes to prevent race conditions
  ///
  /// UPDATED: Now includes full sync for device-based users who skip OAuth
  /// OAuth users still get their sync from OAuthService to prevent duplication
  Future<void> _performPostAuthSync(String userId) async {
    // CRITICAL: Check if user has completed onboarding before syncing
    // During onboarding, no user profile exists yet, so sync would fail
    try {
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.getCurrentUserProfile();

      if (userProfile == null || userProfile.onboardingCompleted != true) {
        _logger.info('Skipping post-auth sync - onboarding not complete', context: 'AUTH');
        return;
      }
    } catch (e) {
      _logger.error('Error checking onboarding status, skipping sync', context: 'AUTH', error: e);
      return;
    }

    try {
      final userRepo = await ref.read(userRepositoryProvider.future);

      // Run ALL network calls in PARALLEL for faster sync (~500ms vs 1.5s)
      // These are independent operations that don't depend on each other
      await Future.wait([
        userRepo.fetchAndSaveRemoteProfile(userId),
        userRepo.fetchAndCacheRemoteFoodPreferences(userId),
        userRepo.syncUserFoodsFromSupabase(userId),
      ]);

      // Invalidate settings provider after profile is loaded
      ref.invalidate(settingsControllerProvider);

      _logger.info('Post-auth user data sync completed', context: 'AUTH');
    } catch (e) {
      _logger.error('Failed to sync remote profile on sign in', context: 'AUTH', error: e);
    }

    // CRITICAL FIX: Trigger full sync for device-based users (anonymous/email)
    // OAuth users get their sync from OAuthService, but device-based users need it here
    // This ensures carb loading foods, nutrition foods, and activities are synced
    try {
      final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
      await syncCoordinator.sync(
        userId: userId,
        trigger: SyncTrigger.manual,
      );
      _logger.info('Full sync completed for device-based user', context: 'AUTH');
    } catch (e) {
      _logger.error('Full sync failed after auth', context: 'AUTH', error: e);
      // Don't rethrow - user can manually sync later
    }
  }

  /// Check if user has existing session and restore it
  Future<void> checkUserSession() async {
    try {
      final database = ref.read(appDatabaseProvider);
      final user = await database.getCurrentUserProfile();

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

      // Check if we have a current user
      final user = await database.getCurrentUserProfile();

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

      // Check if we have a current user
      final user = await database.getCurrentUserProfile();
      if (user == null) return null;

      // Get plans that have a run date/time in the past but no feedback yet
      final now = DateTime.now();
      final planActivities = await database.getActivitiesWithNutritionPlans(user.id);

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
}

/// Provider for AppStartupService (Drift version)
final appStartupServiceProvider = Provider<AppStartupService>((ref) {
  return AppStartupService(ref);
});
