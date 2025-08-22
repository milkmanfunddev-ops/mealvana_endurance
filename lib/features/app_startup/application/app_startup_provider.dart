import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_startup_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/sentry_service.dart';
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

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
@Riverpod(keepAlive: true)
class AppStartup extends _$AppStartup {
  @override
  Future<AppStartupData> build() async {
    try {
      final AppStartupService startupService = ref.read(appStartupServiceProvider);
      
      // 1. Initialize Drift database
      await startupService.initializeDatabase();
      
      // 2. Initialize analytics with device ID
      await startupService.initializeAnalytics();
      
      // 3. Set Sentry user context (Sentry already initialized in main.dart)
      await startupService.setSentryUserContext();
      
      // 4. Check and restore user session if exists
      await startupService.checkUserSession();
      
      // 5. Initialize nutrition plans (now using Drift)
      await startupService.initializeNutritionPlans();
      
      print('✅ App startup initialization completed');
      
      // 7. Track startup completion in Sentry
      final sentryService = ref.read(sentryServiceProvider);
      await sentryService.trackAppStartupCompleted();
      
      // 8. Get user state for navigation decisions
      final database = await ref.read(databaseProvider.future);
      final user = await database.getCurrentUserProfile();
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;
      
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