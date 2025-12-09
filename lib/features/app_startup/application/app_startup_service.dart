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
import '../../../shared/services/sync/data_sync_service.dart';
import '../../nutrition_plan/data/food_repository.dart';
import '../../auth/data/user_repository.dart';
import '../../settings/presentation/providers/settings_controller.dart';
import '../../activities/presentation/providers/activities_controller.dart';
import '../../events/presentation/providers/events_controller.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/preferences_service.dart';
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
  
  /// Initialize Drift database with v2 migration support
  Future<void> initializeDatabase() async {
    try {
      // Touch the database provider so migrations run.
      // The database is ready immediately - Drift's LazyDatabase handles
      // async initialization internally (onCreate, onUpgrade, beforeOpen).
      final db = ref.read(appDatabaseProvider);

      // Trigger lazy initialization by accessing the database
      // This ensures onCreate/migration runs before we proceed
      // Use a simple table query instead of SELECT 1 to verify schema is ready
      try {
        await db.select(db.userProfilesTable).get();
      } catch (e) {
        // On fresh install, table might not exist yet - that's OK
        // The important part is that onCreate has completed
      }

    } catch (e, stackTrace) {
      _logger.error('Database initialization failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow; // Re-throw to trigger error handling in AppStartupWidget
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

  /// Initialize Supabase Anonymous Authentication
  /// Creates or restores an anonymous auth session for the user
  /// This is the foundation for all Supabase Auth-based operations
  Future<void> initializeSupabaseAuth() async {
    try {
      // Check if we already have a session (SDK auto-restores from secure storage)
      final existingSession = _supabase.auth.currentSession;

      if (existingSession != null) {
        // Session restored - Sentry breadcrumb for tracking (analytics deferred)
        _sentry.addBreadcrumb(
          message: 'Supabase session restored',
          category: 'auth',
          data: {
            'user_id': existingSession.user.id,
          },
        );
        // Don't return early - setup listener in finally block
      } else {
        // No existing session - create anonymous user
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
      // Setup auth state listener ONCE, regardless of path taken
      // This prevents duplicate listeners that cause race conditions
      setupAuthStateListener();
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
        // Get the old user ID before clearing data
        final oldUserId = session?.user.id;

        await _analytics.track('user_signed_out', properties: {
          'old_user_id': oldUserId,
          'timestamp': DateTime.now().toIso8601String(),
        });

        try {
          // CRITICAL: Clear sync timestamp so next sign-in does a FULL sync
          // Without this, incremental sync returns 0 activities (nothing changed since last sync)
          // but local DB is empty because clearUserScopedData() deleted everything
          if (oldUserId != null) {
            final prefs = await ref.read(sharedPreferencesProvider.future);
            await prefs.remove('last_sync_timestamp_$oldUserId');
            _logger.info(
              'Cleared sync timestamp for signed-out user',
              context: 'AUTH',
              data: {'userId': oldUserId},
            );
          }

          // Clear all local user data - user is fully logged out
          // They will need to go through onboarding again or sign in
          final database = ref.read(appDatabaseProvider);
          await database.clearUserScopedData();

          _logger.info(
            'Cleared all local user data on sign-out',
            context: 'AUTH',
            data: {'old_user_id': oldUserId},
          );

          // Ensure providers dependent on user identity refresh immediately
          ref.invalidate(userIdProvider);
          ref.invalidate(activitiesControllerProvider);
          ref.invalidate(allEventsProvider);
          ref.invalidate(nextUpcomingEventProvider);
          ref.invalidate(settingsControllerProvider);
          ref.invalidate(appStartupProvider);

          _sentry.addBreadcrumb(
            message: 'User fully signed out - local data cleared',
            category: 'auth',
            data: {
              'old_user_id': oldUserId,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        } catch (e, stackTrace) {
          _logger.error(
            'Failed to clear local data after sign-out',
            context: 'AUTH',
            error: e,
            stackTrace: stackTrace,
          );

          await _sentry.reportCriticalError(
            e,
            stackTrace: stackTrace,
            context: 'sign_out_data_clear_failed',
            tags: {
              'error_type': 'local_data_clear_failed',
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
  Future<void> _performPostAuthSync(String userId) async {
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

    } catch (e) {
      _logger.error('Failed to sync remote profile on sign in', context: 'AUTH', error: e);
    }

    // CRITICAL: Sync activities/events BEFORE invalidating their providers
    // This prevents the race condition where UI queries empty local DB
    try {
      await syncAllAppData();

      // NOW invalidate providers - data is already in local DB
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(nextUpcomingEventProvider);

      _logger.info('Post-auth sync completed - providers invalidated', context: 'AUTH');
    } catch (e) {
      _logger.error('Failed to sync app data on sign in', context: 'AUTH', error: e);
      // Still invalidate providers so UI can show whatever local data exists
      ref.invalidate(activitiesControllerProvider);
      ref.invalidate(allEventsProvider);
      ref.invalidate(nextUpcomingEventProvider);
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

  /// Unified data sync - single network call to sync-all-data edge function
  /// Syncs ALL app data: calendar, foods, carb loading foods, meal types
  /// Returns true if sync was successful, false otherwise
  /// Non-blocking: app continues with cached data if sync fails
  ///
  /// MULTI-DEVICE FIX: Now properly invalidates providers after sync completes
  /// to ensure UI reflects newly downloaded data
  Future<bool> syncAllAppData() async {
    try {
      final database = ref.read(appDatabaseProvider);

      // CRITICAL: Always prefer Supabase auth user ID over local database
      // After sign-out, local DB has the anonymous user, but after sign-in
      // we need to sync with the OAuth user's data
      final supabaseUser = _supabase.auth.currentUser;

      // Priority: Supabase auth ID > local DB profile ID
      String? userIdForSync = supabaseUser?.id;

      if (userIdForSync == null) {
        // Fallback to local DB only if no Supabase session (offline mode)
        final user = await database.getCurrentUserProfile();
        userIdForSync = user?.id;
      }

      if (userIdForSync == null) {
        // This is normal on fresh install before onboarding
        // Reference data will be downloaded after onboarding completes
        _logger.info(
          'No user ID available for sync - skipping (fresh install)',
          context: 'APP_STARTUP',
        );
        return true;
      }

      _logger.info(
        'syncAllAppData using user ID',
        context: 'APP_STARTUP',
        data: {
          'userIdForSync': userIdForSync,
          'supabaseUserId': supabaseUser?.id,
        },
      );

      // Call unified sync service - single network call
      final dataSyncService = ref.read(dataSyncServiceProvider);
      final success = await dataSyncService.syncAllData(userIdForSync);

      // MULTI-DEVICE FIX: Invalidate providers AFTER sync completes
      // This ensures UI reflects the newly downloaded data
      if (success) {
        _logger.info(
          'Sync completed successfully - invalidating providers',
          context: 'APP_STARTUP',
        );
        ref.invalidate(activitiesControllerProvider);
        ref.invalidate(allEventsProvider);
        ref.invalidate(nextUpcomingEventProvider);
        ref.invalidate(settingsControllerProvider);
      }

      return success;
    } catch (e, stackTrace) {
      _logger.error(
        'Unified data sync error',
        context: 'APP_STARTUP',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
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
  Future<int?> checkForPendingFeedback() async {
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
