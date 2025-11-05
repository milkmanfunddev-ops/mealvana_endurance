import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:convert';
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
  
  /// Initialize Drift database with v2 migration support
  Future<void> initializeDatabase() async {
    try {
      // Touch the database provider so migrations run before the app boots.
      await ref.read(databaseProvider.future);
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
  
  /// Check if user has existing session and restore it
  Future<void> checkUserSession() async {
    try {
      final database = ref.read(appDatabaseProvider);
      
      // Check if user exists in Drift database
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
    } catch (e) {
      _logger.warning('Session check error', 
        context: 'AUTH',
        error: e
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
        // Get latest nutrition plan from Drift
        await database.getLatestNutritionPlan(user.id);
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

  /// Check for plans that need feedback after run time has passed
  /// Also checks for notification-based navigation
  Future<String?> checkForPendingFeedback() async {
    try {
      // First check if user tapped a notification
      final notificationPlanId = NotificationService.getPendingNavigationPlanId();
      if (notificationPlanId != null) {
        return notificationPlanId;
      }
      
      final database = ref.read(appDatabaseProvider);
      
      // Check if we have a current user
      final user = await database.getCurrentUserProfile();
      if (user == null) return null;
      
      // Get plans that have a run date/time in the past but no feedback yet
      final now = DateTime.now();
      final plans = await database.select(database.nutritionPlans).get();
      
      for (final plan in plans) {
        // Parse the plan to check runDateTime
        final planJson = jsonDecode(plan.planData) as Map<String, dynamic>;
        if (planJson.containsKey('runDateTime') && planJson['runDateTime'] != null) {
          final runDateTime = DateTime.parse(planJson['runDateTime']);
          
          // Check if run time has passed and no feedback exists
          if (runDateTime.isBefore(now)) {
            final hasRating = planJson['planRating'] != null;
            final hasNotes = planJson['journalNotes'] != null && 
                             (planJson['journalNotes'] as String).isNotEmpty;
            
            if (!hasRating && !hasNotes) {
              // Found a plan that needs feedback
              return plan.id;
            }
          }
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
