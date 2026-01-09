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
    this.isLoggedOut = false,
  });

  final UserProfile? user;
  final bool hasCompletedOnboarding;
  final String? activityIdNeedingFeedback;

  /// True when user has logged out but still has local data
  /// In this state: no Supabase session, but local profile exists with onboardingCompleted = true
  final bool isLoggedOut;
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

      // 1. CRITICAL PATH: Run only essential initializations in parallel
      // Analytics and device info are deferred to avoid Android startup deadlock
      await Future.wait([
        startupService.initializeDatabase(),
        startupService.initializeSupabaseAuth(),
        startupService.setSentryUserContext(),
      ]);

      // 2. NON-BLOCKING: Analytics, device info, and push notifications
      // These are deferred to after first frame to avoid Android DeviceInfoPlugin deadlock
      unawaited(startupService.initializeDeferredServices());

      // NOTE: No sync on app startup - OAuth-only sync strategy
      // Sync happens after OAuth sign-in (for new device logins)
      // Returning users see cached data and can pull-to-refresh

      // 3. Get navigation data (fast local DB query)
      final database = ref.read(appDatabaseProvider);

      // Get current Supabase session to check auth state
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final currentSession = supabaseClient.auth.currentSession;
      final currentAuthUserId = currentSession?.user.id;

      // CRITICAL: Pass currentAuthUserId to getCurrentUserProfile
      // Without this, it returns null even when a valid session exists!
      final user = await database.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;

      // Check for pending feedback
      final activityIdNeedingFeedback = await startupService.checkForPendingFeedback();

      // Track startup completion in Sentry
      final sentry = ref.read(appExternalDepsProvider).sentry;
      sentry.addBreadcrumb(
        message: 'App startup completed successfully',
        category: 'app_lifecycle',
        data: {
          'startup_time': DateTime.now().toIso8601String(),
        },
      );

      final isLoggedOut = currentSession == null &&
          user != null &&
          hasCompletedOnboarding;

      return AppStartupData(
        user: user,
        hasCompletedOnboarding: hasCompletedOnboarding,
        activityIdNeedingFeedback: activityIdNeedingFeedback,
        isLoggedOut: isLoggedOut,
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
