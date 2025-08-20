import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/app_startup_service.dart';
import '../../../features/auth/application/auth_service.dart';
import '../../../features/auth/domain/user_preferences.dart';

part 'app_startup_provider.g.dart';

/// Data returned by AppStartup for navigation decisions
class AppStartupData {
  const AppStartupData({
    required this.user,
    required this.hasCompletedOnboarding,
  });

  final UserProfile? user;
  final bool hasCompletedOnboarding;
}

/// AsyncNotifier for app startup initialization
/// This coordinates the AppStartupService and provides async state management
@Riverpod(keepAlive: true)
class AppStartup extends _$AppStartup {
  @override
  Future<AppStartupData> build() async {
    try {
      final AppStartupService startupService = ref.read(appStartupServiceProvider);
      
      // 1. Initialize local storage (Hive)
      await startupService.initializeLocalStorage();
      
      // 2. Initialize analytics with device ID
      await startupService.initializeAnalytics();
      
      // 3. Check and restore user session if exists
      await startupService.checkUserSession();
      
      // 4. Sync nutrition plans from Supabase to cache
      await startupService.syncNutritionPlans();
      
      print('✅ App startup initialization completed');
      
      // 5. Get user state for navigation decisions
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      final hasCompletedOnboarding = user != null ? await authService.hasCompletedOnboarding() : false;
      
      return AppStartupData(
        user: user,
        hasCompletedOnboarding: hasCompletedOnboarding,
      );
    } catch (e) {
      print('❌ App startup initialization failed: $e');
      rethrow; // Re-throw to trigger error state in AsyncNotifier
    }
  }
}