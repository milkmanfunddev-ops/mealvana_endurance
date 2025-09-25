import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:io';
import 'dart:convert';
import '../../../shared/services/analytics_service.dart';
import '../../../shared/services/sentry_service.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../auth/application/auth_service.dart';
import '../../nutrition_plan/data/food_repository.dart';

/// Service responsible for providing individual startup operations using Drift
/// Following Andrea Bizzotto's app initialization patterns
/// Replaces the Hive-based AppStartupService
class AppStartupService {
  AppStartupService(this.ref);
  final Ref ref;
  
  SentryService get _sentryService => ref.read(sentryServiceProvider);
  LoggingService get _logger => AppLogger.instance;
  
  /// Initialize Drift database with v2 migration support
  Future<void> initializeDatabase() async {
    try {
      // Get database instance (this will create it if needed and trigger migration)
      final database = ref.read(appDatabaseProvider);
      
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
    // Initialize Mixpanel
    await AnalyticsService.initialize();

    // Get or create device ID for user identification
    final deviceId = await getOrCreateDeviceId();

    // Identify user in Mixpanel (anonymous until they create profile)
    await AnalyticsService.identifyUser(deviceId);

    // Track app launch
    await AnalyticsService.trackAppLaunched();
  }
  
  /// Set Sentry user context during app startup
  Future<void> setSentryUserContext() async {
    try {
      // Sentry is already initialized in main.dart
      // Here we set user context with device ID
      final deviceId = await getOrCreateDeviceId();
      
      await _sentryService.setUserContext(
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
      final database = ref.read(appDatabaseProvider);
      
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
      final authService = ref.read(authServiceProvider);
      final database = ref.read(appDatabaseProvider);
      
      // Check if user exists in Drift database
      final user = await database.getCurrentUserProfile();
      
      if (user != null) {
        // User exists locally - identify them properly in analytics
        await AnalyticsService.identifyUser(
          user.id,
          properties: {
            'Gender': user.gender.name,
            'Age': user.age,
            'Weight (lbs)': user.weightPounds,
            'Height (in)': user.heightFeet * 12 + user.heightInches,
            'Runs With Water Bottle': user.runsWithWaterBottle,
            'Gut Training': user.gutTraining.name,
            'Has Completed Onboarding': user.onboardingCompleted,
          },
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
      final authService = ref.read(authServiceProvider);
      
      // Check if we have a current user
      final user = await database.getCurrentUserProfile();
      
      if (user != null) {
        // Get latest nutrition plan from Drift
        final latestPlanJson = await database.getLatestNutritionPlan(user.id);
      }
    } catch (e) {
      _logger.error('Plan initialization error', 
        context: 'NUTRITION_PLAN',
        error: e
      );
      // Continue - app should work without plans (expected on fresh installs)
    }
  }

  /// Check if food data needs refreshing and refresh if necessary
  /// Always pull and cache the latest food data from Supabase on app initialization
  Future<void> checkAndRefreshFoodData() async {
    try {
      // Always fetch fresh food data from Supabase
      final foodRepository = ref.read(foodRepositoryProvider);

      // Sync all foods from database
      // This ensures food IDs returned by edge functions can be resolved locally
      await foodRepository.getAllFoods();

    } catch (e) {
      _logger.error('Food data refresh error',
        context: 'FOOD_DATA',
        error: e
      );
      // Don't throw - app should continue even if food refresh fails
    }
  }

  /// Check for plans that need feedback after run time has passed
  /// Also checks for notification-based navigation
  Future<String?> checkForPendingFeedback() async {
    try {
      // First check if user tapped a notification
      final notificationPlanId = NotificationService.getPendingNavigationPlanId();
      if (notificationPlanId != null) {
        print('📱 DEBUG: Found pending notification navigation for plan: $notificationPlanId');
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