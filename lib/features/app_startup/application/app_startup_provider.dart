import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_startup_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/sentry_service.dart';
import '../../../shared/services/logging_service.dart';
import '../../../features/auth/domain/user_preferences.dart';

part 'app_startup_provider.g.dart';

/// Data returned by AppStartup for navigation decisions
class AppStartupData {
  const AppStartupData({
    required this.user,
    required this.hasCompletedOnboarding,
    this.planIdNeedingFeedback,
  });

  final UserProfile? user;
  final bool hasCompletedOnboarding;
  final String? planIdNeedingFeedback;
}

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
@riverpod
class AppStartup extends _$AppStartup {
  LoggingService get _logger => AppLogger.instance;
  
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
      
      // 5. Check and refresh food data if needed (for updated image URLs)
      await startupService.checkAndRefreshFoodData();
      
      // 6. Initialize nutrition plans (now using Drift)
      await startupService.initializeNutritionPlans();
      
      // 7. Check for plans needing feedback
      final planIdNeedingFeedback = await startupService.checkForPendingFeedback();
      
      // 8. Track startup completion in Sentry
      final sentryService = ref.read(sentryServiceProvider);
      await sentryService.trackAppStartupCompleted();
      
      // 9. Get user state for navigation decisions
      final database = ref.read(appDatabaseProvider);
      final user = await database.getCurrentUserProfile();
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;
      
      return AppStartupData(
        user: user,
        hasCompletedOnboarding: hasCompletedOnboarding,
        planIdNeedingFeedback: planIdNeedingFeedback,
      );
    } catch (e, stackTrace) {
      _logger.error('App startup initialization failed', 
        context: 'APP_STARTUP',
        error: e,
        stackTrace: stackTrace
      );
      rethrow; // Re-throw to trigger error state in AsyncNotifier
    }
  }
}