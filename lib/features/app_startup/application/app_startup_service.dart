import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'dart:io';
import '../../../shared/services/analytics_service.dart';
import '../../../shared/services/sentry_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../auth/application/auth_service.dart';
import '../../nutrition_plan/application/nutrition_plan_service.dart';
import '../../auth/domain/user_preferences.dart';

/// Service responsible for providing individual startup operations using Drift
/// Following Andrea Bizzotto's app initialization patterns
/// Replaces the Hive-based AppStartupService
class AppStartupService {
  AppStartupService(this.ref);
  final Ref ref;
  
  SentryService get _sentryService => ref.read(sentryServiceProvider);
  
  /// Initialize Drift database
  Future<void> initializeDatabase() async {
    try {
      print('📊 Initializing Drift database...');
      
      // Get database instance (this will create it if needed)
      final database = await ref.read(databaseProvider.future);
      
      // Verify database is working by getting stats
      final stats = await database.getDatabaseStats();
      print('✅ Drift database initialized successfully');
      print('   - Users: ${stats['users']}');
      print('   - Preferences: ${stats['preferences']}');
      print('   - Plans: ${stats['plans']}');
      
    } catch (e) {
      print('❌ Database initialization error: $e');
      rethrow; // Re-throw to trigger error handling in AppStartupWidget
    }
  }
  
  /// Initialize analytics service with proper user identification
  Future<void> initializeAnalytics() async {
    final analyticsService = ref.read(analyticsServiceProvider);
    
    // Initialize Mixpanel
    await analyticsService.initialize();
    
    // Get or create device ID for user identification
    final deviceId = await getOrCreateDeviceId();
    
    // Identify user in Mixpanel (anonymous until they create profile)
    await analyticsService.identifyUser(deviceId);
    
    // Track app launch
    await analyticsService.trackAppLaunched();
    
    print('📊 Analytics initialized with device ID: $deviceId');
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
      
      _sentryService.addBreadcrumb(
        message: 'App startup user context set',
        category: 'app_lifecycle',
        level: SentryLevel.info,
        data: {
          'device_id': deviceId,
          'startup_phase': 'user_context',
        },
      );
      
      print('📊 Sentry user context set with device ID: $deviceId');
    } catch (e, stackTrace) {
      // Don't use Sentry to report Sentry initialization errors
      print('❌ Sentry user context error: $e');
      // Don't rethrow - app should continue even if Sentry fails
    }
  }
  
  
  /// Get or create a persistent device ID for analytics
  Future<String> getOrCreateDeviceId() async {
    try {
      final database = await ref.read(databaseProvider.future);
      
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
      print('Error getting device ID: $e');
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
      final analyticsService = ref.read(analyticsServiceProvider);
      final database = await ref.read(databaseProvider.future);
      
      print('🔍 Checking for existing user session...');
      
      // Check if user exists in Drift database
      final user = await database.getCurrentUserProfile();
      print('🔍 Local user check: ${user != null ? "Found user ${user.id}" : "No local user"}');
      
      if (user != null) {
        // User exists locally - identify them properly in analytics
        await analyticsService.identifyUser(
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
        
        print('👤 User session restored from Drift: ${user.id}');
      } else {
        // No local user - this is expected for new installs
        print('👤 No user session - new installation');
      }
    } catch (e) {
      print('Session check error: $e');
      // Continue without user session - this is expected on fresh installs
    }
  }
  
  /// Initialize nutrition plan cache (now using Drift as primary storage)
  Future<void> initializeNutritionPlans() async {
    try {
      final database = await ref.read(databaseProvider.future);
      final authService = ref.read(authServiceProvider);
      
      // Check if we have a current user
      final user = await database.getCurrentUserProfile();
      
      if (user != null) {
        // Get latest nutrition plan from Drift
        final latestPlanJson = await database.getLatestNutritionPlan(user.id);
        
        if (latestPlanJson != null) {
          print('📋 Latest nutrition plan found in Drift database');
        } else {
          print('📋 No nutrition plans found for user');
        }
      } else {
        print('📋 No user found - skipping plan initialization');
      }
    } catch (e) {
      print('Plan initialization error: $e');
      // Continue - app should work without plans (expected on fresh installs)
    }
  }
}

/// Provider for AppStartupService (Drift version)
final appStartupServiceProvider = Provider<AppStartupService>((ref) {
  return AppStartupService(ref);
});