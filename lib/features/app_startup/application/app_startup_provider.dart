import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_startup_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../features/auth/domain/user_preferences.dart';

part 'app_startup_provider.g.dart';

/// Data returned by AppStartup for navigation decisions
class AppStartupData {
  const AppStartupData({
    required this.user,
    required this.hasCompletedOnboarding,
    this.activityIdNeedingFeedback,
  });

  final UserProfile? user;
  final bool hasCompletedOnboarding;
  final int? activityIdNeedingFeedback;
}

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
@riverpod
class AppStartup extends _$AppStartup {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  
  @override
  Future<AppStartupData> build() async {
    try {
      final AppStartupService startupService = ref.read(appStartupServiceProvider);

      // 1. CRITICAL PATH: Run independent core initializations in parallel
      final stopwatch = Stopwatch()..start();

      await Future.wait([
        startupService.initializeDatabase(),
        startupService.initializeSupabaseAuth(),
        startupService.initializeAnalytics(),
        startupService.setSentryUserContext(),
      ]);

      // 2. Identify user in analytics (requires DB & Auth to be ready)
      await startupService.checkUserSession();

      // 3. Unified data sync - Fire and forget, happens in background
      unawaited(startupService.syncAllAppData());

      // 4. Get navigation data (fast local DB query)
      final database = ref.read(appDatabaseProvider);
      final user = await database.getCurrentUserProfile();
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;

      // Check for pending feedback
      final activityIdNeedingFeedback = await startupService.checkForPendingFeedback();

      // 5. Track startup completion in Sentry
      final sentry = ref.read(appExternalDepsProvider).sentry;
      sentry.addBreadcrumb(
        message: 'App startup completed successfully',
        category: 'app_lifecycle',
        data: {
          'startup_time': DateTime.now().toIso8601String(),
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      return AppStartupData(
        user: user,
        hasCompletedOnboarding: hasCompletedOnboarding,
        activityIdNeedingFeedback: activityIdNeedingFeedback,
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
