import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'analytics_service.dart';
import '../../features/auth/application/auth_service.dart';
import '../../features/auth/data/user_repository.dart';
import '../../features/nutrition_plan/data/nutrition_plan_local_cache.dart';
import '../../features/nutrition_plan/application/nutrition_plan_service.dart';
import '../../features/auth/domain/user_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service responsible for providing individual startup operations
/// Following Andrea Bizzotto's app initialization patterns
/// The AppStartupProvider will orchestrate calling these methods
class AppStartupService {
  AppStartupService(this.ref);
  final Ref ref;
  
  /// Initialize Hive local storage and adapters
  Future<void> initializeLocalStorage() async {
    try {
      // Initialize Hive (if not already done)
      await Hive.initFlutter();
      
      // Register all Hive adapters (should only run once due to keepAlive)
      Hive.registerAdapter(UserProfileAdapter());
      Hive.registerAdapter(GenderAdapter());
      Hive.registerAdapter(FoodPreferencesAdapter());
      Hive.registerAdapter(FoodPreferenceAdapter());
      Hive.registerAdapter(GutTrainingAdapter());
      
      // Open required boxes
      if (!Hive.isBoxOpen('user_prefs')) {
        await Hive.openBox('user_prefs');
      }
      
      print('✅ Hive initialized with adapters');
    } catch (e) {
      print('❌ Local storage initialization error: $e');
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
  
  /// Get or create a persistent device ID for analytics
  Future<String> getOrCreateDeviceId() async {
    try {
      // Try to get existing device ID from local storage
      final prefsBox = Hive.box('user_prefs');
      String? deviceId = prefsBox.get('device_id');
      
      if (deviceId == null) {
        // Generate new device ID based on platform
        final deviceInfo = DeviceInfoPlugin();
        
        if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          // Use identifierForVendor for iOS (stable across app installs from same vendor)
          deviceId = iosInfo.identifierForVendor ?? _generateFallbackId();
        } else if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          // Use Android ID (stable across app installs)
          deviceId = androidInfo.id;
        } else {
          deviceId = _generateFallbackId();
        }
        
        // Save device ID for future use
        await prefsBox.put('device_id', deviceId);
      }
      
      return deviceId;
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
      
      // Wait for UserRepository to be fully initialized before proceeding
      await ref.read(userRepositoryProvider.future);
      print('✅ UserRepository fully initialized');
      
      // Check if user exists locally first (using async version to ensure repository is ready)
      final user = await authService.getCurrentUser();
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
            'Has Completed Onboarding': await authService.hasCompletedOnboarding(),
          },
        );
        
        print('👤 User session restored from cache: ${user.id}');
      } else {
        // No local user - check if user exists on Supabase
        final deviceId = await getOrCreateDeviceId();
        print('🔍 Checking Supabase for device ID: $deviceId');
        
        try {
          final authRepositoryEdge = ref.read(authRepositoryEdgeProvider);
          final supabaseUser = await authRepositoryEdge.getUserByDeviceId(deviceId);
          print('🔍 Supabase user check: ${supabaseUser != null ? "Found user ${supabaseUser.id}" : "No user found"}');
          
          if (supabaseUser != null) {
            // User exists on Supabase - save locally and identify in analytics
            final userRepo = await ref.read(userRepositoryProvider.future);
            await userRepo.saveUserProfile(supabaseUser);
            
            await analyticsService.identifyUser(
              supabaseUser.id,
              properties: {
                'Gender': supabaseUser.gender.name,
                'Age': supabaseUser.age,
                'Weight (lbs)': supabaseUser.weightPounds,
                'Height (in)': supabaseUser.heightFeet * 12 + supabaseUser.heightInches,
                'Runs With Water Bottle': supabaseUser.runsWithWaterBottle,
                'Gut Training': supabaseUser.gutTraining.name,
                'Has Completed Onboarding': supabaseUser.onboardingCompleted,
              },
            );
            
            print('👤 User session restored from Supabase: ${supabaseUser.id}');
          } else {
            // No user anywhere - tracking as anonymous
            print('👤 No user session - tracking as anonymous');
          }
        } catch (e) {
          print('Failed to check Supabase for user: $e');
        }
      }
    } catch (e) {
      print('Session check error: $e');
      // Continue without user session - this is expected on fresh installs
    }
  }
  
  /// Sync nutrition plans from Supabase to local cache
  Future<void> syncNutritionPlans() async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        // Initialize nutrition plan cache
        final localCache = ref.read(nutritionPlanLocalCacheProvider);
        await localCache.initialize();
        
        // Sync latest plan from Supabase (this will cache it automatically)
        final nutritionPlanService = ref.read(nutritionPlanServiceProvider);
        final latestPlan = await nutritionPlanService.getLatestNutritionPlan();
        
        if (latestPlan != null) {
          print('📋 Latest nutrition plan synced from Supabase: ${latestPlan.name}');
        } else {
          print('📋 No nutrition plans found for user');
        }
      } else {
        // No user yet - skip plan sync
        print('📋 No user found - skipping plan sync');
      }
    } catch (e) {
      print('Plan sync error: $e');
      // Continue - app should work without plans (expected on fresh installs)
    }
  }
}

/// Provider for AppStartupService
final appStartupServiceProvider = Provider<AppStartupService>((ref) {
  return AppStartupService(ref);
});

