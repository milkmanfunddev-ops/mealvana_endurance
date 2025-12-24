import 'dart:async';
import 'package:flutter/foundation.dart';
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

  /// Helper to log timing of each parallel operation for debugging
  Future<void> _timedOperation(String name, Future<void> operation) async {
    final sw = Stopwatch()..start();
    debugPrint('[APP_STARTUP] $name started');
    try {
      await operation;
      debugPrint('[APP_STARTUP] $name completed: ${sw.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('[APP_STARTUP] $name FAILED after ${sw.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  @override
  Future<AppStartupData> build() async {
    try {
      final AppStartupService startupService = ref.read(appStartupServiceProvider);

      // 1. CRITICAL PATH: Run only essential initializations in parallel
      // Analytics and device info are deferred to avoid Android startup deadlock
      final stopwatch = Stopwatch()..start();

      debugPrint('[APP_STARTUP] Starting critical path initialization...');

      await Future.wait([
        _timedOperation('initializeDatabase', startupService.initializeDatabase()),
        _timedOperation('initializeSupabaseAuth', startupService.initializeSupabaseAuth()),
        _timedOperation('setSentryUserContext', startupService.setSentryUserContext()),
      ]);

      debugPrint('[APP_STARTUP] Critical path completed: ${stopwatch.elapsedMilliseconds}ms');

      // 2. NON-BLOCKING: Analytics, device info, and push notifications
      // These are deferred to after first frame to avoid Android DeviceInfoPlugin deadlock
      debugPrint('[APP_STARTUP] Scheduling deferred initialization (analytics, device info, push)...');
      unawaited(startupService.initializeDeferredServices());

      // NOTE: No sync on app startup - OAuth-only sync strategy
      // Sync happens after OAuth sign-in (for new device logins)
      // Returning users see cached data and can pull-to-refresh

      // 3. Get navigation data (fast local DB query)
      debugPrint('[APP_STARTUP] Getting navigation data...');
      final database = ref.read(appDatabaseProvider);
      final user = await database.getCurrentUserProfile();
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;
      debugPrint('[APP_STARTUP] User profile loaded: ${stopwatch.elapsedMilliseconds}ms');

      // Check for pending feedback
      debugPrint('[APP_STARTUP] Checking pending feedback...');
      final activityIdNeedingFeedback = await startupService.checkForPendingFeedback();
      debugPrint('[APP_STARTUP] Pending feedback checked: ${stopwatch.elapsedMilliseconds}ms');

      // 6. Track startup completion in Sentry
      final sentry = ref.read(appExternalDepsProvider).sentry;
      sentry.addBreadcrumb(
        message: 'App startup completed successfully',
        category: 'app_lifecycle',
        data: {
          'startup_time': DateTime.now().toIso8601String(),
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
      );

      // Detect logged-out state: no Supabase session but has local profile with completed onboarding
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final currentSession = supabaseClient.auth.currentSession;
      final isLoggedOut = currentSession == null &&
          user != null &&
          hasCompletedOnboarding;

      if (isLoggedOut) {
        debugPrint('[APP_STARTUP] User is logged out but has local data - will redirect to welcome');
      }

      debugPrint('[APP_STARTUP] ✅ STARTUP COMPLETE: ${stopwatch.elapsedMilliseconds}ms total');
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
