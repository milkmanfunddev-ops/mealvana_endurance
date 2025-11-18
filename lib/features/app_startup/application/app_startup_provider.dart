import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_startup_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../features/auth/domain/user_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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

      // 1. Initialize Drift database (must be first - other operations depend on it)
      _logger.info('🔄 Starting database initialization...', context: 'APP_STARTUP');
      await startupService.initializeDatabase();
      _logger.info('✅ Database initialization complete', context: 'APP_STARTUP');

      // 2. Initialize Supabase Anonymous Auth (must be early - user identity required for subsequent operations)
      _logger.info('🔄 Initializing Supabase Anonymous Auth...', context: 'APP_STARTUP');
      await startupService.initializeSupabaseAuth();
      _logger.info('✅ Supabase Auth initialized', context: 'APP_STARTUP');

      // 3-5. Run independent operations in parallel for faster startup
      // These operations don't depend on each other, so we can run them concurrently
      _logger.info('🔄 Starting parallel initialization (analytics, sentry, session)...', context: 'APP_STARTUP');
      await Future.wait([
        startupService.initializeAnalytics().then((_) {
          _logger.info('✅ Analytics initialized', context: 'APP_STARTUP');
        }),
        startupService.setSentryUserContext().then((_) {
          _logger.info('✅ Sentry context set', context: 'APP_STARTUP');
        }),
        startupService.checkUserSession().then((_) {
          _logger.info('✅ User session checked', context: 'APP_STARTUP');
        }),
      ]);
      _logger.info('✅ Parallel initialization complete', context: 'APP_STARTUP');

      // 5. Unified data sync - Fire and forget, happens in background
      // User sees UI immediately with cached local data
      // This significantly improves startup time (5-20s → 2-3s)
      // Note: Seed database ensures foods are available on first launch
      // Background sync updates foods without blocking startup
      _logger.info('🔄 Starting background data sync...', context: 'APP_STARTUP');
      unawaited(startupService.syncAllAppData());

      // 6. Check for plans needing feedback (fast - local database query)
      _logger.info('🔄 Checking for pending feedback...', context: 'APP_STARTUP');
      final activityIdNeedingFeedback = await startupService.checkForPendingFeedback();
      _logger.info('✅ Feedback check complete', context: 'APP_STARTUP');

      // 7. Track startup completion in Sentry
      final sentry = ref.read(appExternalDepsProvider).sentry;
      sentry.addBreadcrumb(
        message: 'App startup completed successfully',
        category: 'app_lifecycle',
        data: {
          'startup_time': DateTime.now().toIso8601String(),
          'sentry_enabled': sentry.isEnabled.toString(),
        },
      );
      await sentry.captureMessage(
        'App startup completed',
        level: SentryLevel.info,
        tags: {
          'lifecycle': 'startup_complete',
          'app_phase': 'ready',
        },
      );

      // 8. Get user state for navigation decisions (using local database - fast)
      _logger.info('🔄 Getting user state for navigation...', context: 'APP_STARTUP');
      final database = ref.read(appDatabaseProvider);
      final user = await database.getCurrentUserProfile();
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;
      _logger.info('✅ User state retrieved (onboarded: $hasCompletedOnboarding)', context: 'APP_STARTUP');

      _logger.info('🎉 App startup completed successfully!', context: 'APP_STARTUP');
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
