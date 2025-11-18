import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/sync/data_sync_service.dart';
import '../../nutrition_plan/data/food_repository.dart';

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
      _logger.info('🔍 Getting database instance...', context: 'DATABASE');

      // Touch the database provider so migrations run.
      // The database is ready immediately - Drift's LazyDatabase handles
      // async initialization internally (onCreate, onUpgrade, beforeOpen).
      final db = ref.read(appDatabaseProvider);

      _logger.info('🔍 Database instance obtained, triggering initialization...', context: 'DATABASE');

      // Trigger lazy initialization by accessing the database
      // This ensures onCreate/migration runs before we proceed
      // Use a simple table query instead of SELECT 1 to verify schema is ready
      try {
        _logger.info('🔍 Querying user profiles table to verify database...', context: 'DATABASE');
        await db.select(db.userProfilesTable).get();
        _logger.info('✅ Database query successful', context: 'DATABASE');
      } catch (e) {
        _logger.warning('First query failed (expected on fresh install): $e', context: 'DATABASE');
        // On fresh install, table might not exist yet - that's OK
        // The important part is that onCreate has completed
      }

      _logger.info('✅ Database initialization verified', context: 'DATABASE');
    } catch (e, stackTrace) {
      _logger.error('Database initialization failed',
        context: 'DATABASE',
        error: e,
        stackTrace: stackTrace
      );
      rethrow; // Re-throw to trigger error handling in AppStartupWidget
    }
  }
  
  /// Initialize analytics service with proper user identification
  Future<void> initializeAnalytics() async {
    // Get or create device ID for user identification
    final deviceId = await getOrCreateDeviceId();
    await _analytics.initialize();
    await _analytics.identifyUser(deviceId);
    NotificationService.configure(_analytics);

    // Track app opened event with session ID
    final sessionId = const Uuid().v4();
    await _analytics.trackAppOpened(
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }
  
  /// Set Sentry user context during app startup
  Future<void> setSentryUserContext() async {
    try {
      // Sentry is already initialized in main.dart
      // Here we set user context with device ID
      final deviceId = await getOrCreateDeviceId();
      
      await _sentry.setUserContext(
        deviceId: deviceId,
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
  Future<String> getOrCreateDeviceId() async {
    try {
      // Try to get existing device ID from database
      // For now, we'll use a simple approach - store it with the user profile
      // or generate a new one each time during the transition
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use identifierForVendor for iOS (stable across app installs from same vendor)
        return iosInfo.identifierForVendor ?? _generateFallbackId();
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use Android ID (stable across app installs)
        return androidInfo.id;
      } else {
        return _generateFallbackId();
      }
      
    } catch (e) {
      _logger.error('Error getting device ID', error: e);
      return _generateFallbackId();
    }
  }
  
  /// Generate a fallback device ID if platform-specific ID fails
  String _generateFallbackId() {
    return 'device_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (999 * DateTime.now().millisecond)).toString()}';
  }

  /// Initialize Supabase Anonymous Authentication
  /// Creates or restores an anonymous auth session for the user
  /// This is the foundation for all Supabase Auth-based operations
  Future<void> initializeSupabaseAuth() async {
    try {
      _logger.info('🔄 Initializing Supabase Auth...', context: 'AUTH');

      // Check if we already have a session (SDK auto-restores from secure storage)
      final existingSession = _supabase.auth.currentSession;

      if (existingSession != null) {
        _logger.info(
          '✅ Existing Supabase session restored',
          context: 'AUTH',
          data: {
            'user_id': existingSession.user.id,
            'expires_at': existingSession.expiresAt != null
                ? DateTime.fromMillisecondsSinceEpoch(existingSession.expiresAt! * 1000).toIso8601String()
                : null,
          },
        );

        // Track session restoration
        await _analytics.track(
          'auth_session_restored',
          properties: {
            'user_id': existingSession.user.id,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        // Setup auth state listener for OAuth callbacks
        setupAuthStateListener();

        return;
      }

      // No existing session - create anonymous user
      _logger.info('🔄 No session found, creating anonymous user...', context: 'AUTH');

      final response = await _supabase.auth.signInAnonymously();

      if (response.session == null || response.user == null) {
        throw Exception('Failed to create anonymous session - null response');
      }

      _logger.info(
        '✅ Anonymous Supabase user created successfully',
        context: 'AUTH',
        data: {
          'user_id': response.user!.id,
          'session_expires_at': response.session!.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(response.session!.expiresAt! * 1000).toIso8601String()
              : null,
        },
      );

      // Track anonymous user creation
      await _analytics.track(
        'anonymous_auth_created',
        properties: {
          'user_id': response.user!.id,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Add Sentry breadcrumb for tracking
      _sentry.addBreadcrumb(
        message: 'Anonymous Supabase user created',
        category: 'auth',
        data: {
          'user_id': response.user!.id,
          'auth_provider': 'anonymous',
        },
      );

      // Setup auth state listener for OAuth callbacks
      setupAuthStateListener();

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
    }
  }

  /// Setup auth state change listener for session monitoring
  /// Tracks token refreshes and sign-out events
  ///
  /// Note: With native OAuth, account linking completes synchronously
  /// within OAuthService methods, so we no longer need OAuth callbacks here
  void setupAuthStateListener() {
    _logger.info('🔄 Setting up auth state change listener...', context: 'AUTH');

    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      _logger.info(
        'Auth state changed',
        context: 'AUTH',
        data: {
          'event': event.name,
          'user_id': session?.user.id,
          'is_anonymous': session?.user.isAnonymous,
        },
      );

      // Handle token refresh events
      if (event == AuthChangeEvent.tokenRefreshed) {
        _logger.info('Auth token refreshed', context: 'AUTH');
        await _analytics.track('auth_token_refreshed', properties: {
          'user_id': session?.user.id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Handle sign-out events
      if (event == AuthChangeEvent.signedOut) {
        _logger.info('User signed out', context: 'AUTH');
        await _analytics.track('user_signed_out', properties: {
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });

    _logger.info('✅ Auth state listener setup complete', context: 'AUTH');
  }

  /// Check if user has existing session and restore it
  Future<void> checkUserSession() async {
    try {
      _logger.info('🔄 Starting session check...', context: 'APP_STARTUP');

      _logger.info('🔄 Getting database instance...', context: 'APP_STARTUP');
      final database = ref.read(appDatabaseProvider);
      _logger.info('✅ Database instance obtained', context: 'APP_STARTUP');

      // Check if user exists in Drift database
      _logger.info('🔄 Querying for current user profile...', context: 'APP_STARTUP');
      final user = await database.getCurrentUserProfile();
      _logger.info('✅ User profile query complete (user: ${user != null})', context: 'APP_STARTUP');

      if (user != null) {
        _logger.info('🔄 Identifying user in analytics...', context: 'APP_STARTUP');
        // User exists locally - identify them properly in analytics
        await _analytics.identifyUser(
          user.id,
          gender: user.gender.name,
          age: user.age,
          weightPounds: user.weightPounds,
          runsWithWaterBottle: user.runsWithWaterBottle,
          gutTrainingLevel: user.gutTraining.name,
        );
        _logger.info('✅ User identified in analytics', context: 'APP_STARTUP');
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
  Future<bool> syncAllAppData() async {
    try {
      final database = ref.read(appDatabaseProvider);

      // Get current user (required for sync-all-data edge function)
      final user = await database.getCurrentUserProfile();

      if (user == null) {
        _logger.info(
          'No user profile found - skipping sync (fresh install before onboarding)',
          context: 'APP_STARTUP',
        );
        // This is normal on fresh install before onboarding
        // Reference data will be downloaded after onboarding completes
        return true;
      }

      _logger.info(
        'Starting unified data sync',
        context: 'APP_STARTUP',
        data: {'userId': user.id},
      );

      // Call unified sync service - single network call
      final dataSyncService = ref.read(dataSyncServiceProvider);
      final success = await dataSyncService.syncAllData(user.id);

      if (success) {
        _logger.info(
          'Unified data sync completed successfully',
          context: 'APP_STARTUP',
        );
      } else {
        _logger.warning(
          'Unified data sync failed - app continuing with cached/seed data',
          context: 'APP_STARTUP',
        );
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
        _logger.warning(
          'Foods table is empty - attempting fallback load',
          context: 'FOOD_DATA_FALLBACK',
        );

        // Last resort: call get-foods edge function directly
        final foodRepository = ref.read(foodRepositoryProvider);
        await foodRepository.getAllFoods();

        _logger.info(
          'Fallback food load completed',
          context: 'FOOD_DATA_FALLBACK',
        );
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
