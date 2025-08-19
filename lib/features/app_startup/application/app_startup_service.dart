import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../auth/data/user_repository.dart';
import '../../auth/domain/user_preferences.dart';
import '../../content/application/content_service.dart';
import '../../content/data/content_repository.dart';
import '../../content/domain/app_content.dart';
import '../../nutrition_plan/application/nutrition_plan_service.dart';
import '../../nutrition_plan/domain/nutrition_plan.dart';
import '../../nutrition_plan/domain/food_item.dart';

part 'app_startup_service.g.dart';

/// Navigation state after app initialization
enum AppStartupState {
  onboarding,
  planScreen,
}

/// Result of app initialization
class AppStartupResult {
  final AppStartupState navigationState;
  final String deviceId;
  final UserProfile? user;
  final NutritionPlan? currentPlan;

  const AppStartupResult({
    required this.navigationState,
    required this.deviceId,
    this.user,
    this.currentPlan,
  });
}

/// Service for app initialization logic
class AppStartupService {
  AppStartupService({
    required this.userRepository,
    required this.contentService,
    required this.nutritionPlanService,
  });

  final UserRepository userRepository;
  final ContentService contentService;
  final NutritionPlanService nutritionPlanService;

  /// Initialize app and determine navigation state
  Future<AppStartupResult> initialize() async {
    try {
      // 1. Get device ID
      final deviceId = await _getDeviceId();
      
      // 2. Initialize content service (load from cache/Supabase)
      await contentService.initialize();
      
      // 3. Check if user exists locally
      final localUser = userRepository.getUserProfile();
      
      // 4. Try to sync with Supabase if we have local user
      UserProfile? user = localUser;
      if (localUser != null) {
        try {
          // Sync user data with Supabase
          user = await userRepository.syncUserWithSupabase(deviceId, localUser);
          
          // Try to load current nutrition plan
          final currentPlan = await nutritionPlanService.getLatestNutritionPlan();
          
          return AppStartupResult(
            navigationState: AppStartupState.planScreen,
            deviceId: deviceId,
            user: user,
            currentPlan: currentPlan,
          );
        } catch (e) {
          // Supabase error - continue with local data
          debugPrint('Supabase sync failed: $e, continuing with local data');
          final currentPlan = await nutritionPlanService.getLatestNutritionPlan();
          
          return AppStartupResult(
            navigationState: AppStartupState.planScreen,
            deviceId: deviceId,
            user: localUser,
            currentPlan: currentPlan,
          );
        }
      }
      
      // 5. No local user - check Supabase for existing user
      try {
        final supabaseUser = await userRepository.getUserFromSupabase(deviceId);
        if (supabaseUser != null) {
          // Save to local cache
          await userRepository.saveUserProfile(supabaseUser);
          
          // Try to load their plan
          final currentPlan = await nutritionPlanService.getLatestNutritionPlan();
          
          return AppStartupResult(
            navigationState: AppStartupState.planScreen,
            deviceId: deviceId,
            user: supabaseUser,
            currentPlan: currentPlan,
          );
        }
      } catch (e) {
        debugPrint('Failed to check Supabase for user: $e');
      }
      
      // 6. No user found anywhere - go to onboarding
      return AppStartupResult(
        navigationState: AppStartupState.onboarding,
        deviceId: deviceId,
      );
      
    } catch (e) {
      debugPrint('App startup failed: $e');
      rethrow;
    }
  }

  /// Get unique device identifier
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else {
      return 'unknown_device';
    }
  }
}

@riverpod
AppStartupService appStartupService(Ref ref) {
  return AppStartupService(
    userRepository: ref.watch(userRepositoryProvider),
    contentService: ref.watch(contentServiceProvider),
    nutritionPlanService: ref.watch(nutritionPlanServiceProvider),
  );
}

/// Hive initialization provider - must be initialized first
@Riverpod(keepAlive: true)
Future<void> hiveInitialization(Ref ref) async {
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive adapters
  Hive.registerAdapter(FoodItemAdapter());
  Hive.registerAdapter(FoodCategoryAdapter());
  Hive.registerAdapter(NutritionInfoAdapter());
  Hive.registerAdapter(UserProfileAdapter());
  Hive.registerAdapter(GenderAdapter());
  Hive.registerAdapter(FoodPreferencesAdapter());
  Hive.registerAdapter(FoodPreferenceAdapter());
  Hive.registerAdapter(GutTrainingAdapter());
  Hive.registerAdapter(AppContentAdapter());
}

/// Main app startup provider following Andrea's pattern
@Riverpod(keepAlive: true)
Future<AppStartupResult> appStartup(Ref ref) async {
  ref.onDispose(() {
    // Invalidate dependencies when app startup is invalidated
    ref.invalidate(appStartupServiceProvider);
  });

  // 1. First ensure Hive is initialized
  await ref.watch(hiveInitializationProvider.future);

  // 2. Then eagerly initialize async dependencies (boxes)
  await ref.watch(userBoxProvider.future);
  await ref.watch(preferencesBoxProvider.future);
  // Nutrition plan storage now handled by Edge Functions - no local storage needed
  await ref.watch(contentBoxProvider.future);

  // 3. Finally run the startup service
  final startupService = ref.watch(appStartupServiceProvider);
  return await startupService.initialize();
}