import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_external_deps.dart';
import '../logging_service.dart';
import '../sentry/sentry_reporter.dart';
import '../analytics/analytics_tracker.dart';
import '../sync/sync_coordinator.dart';
import '../../database/database_provider.dart';
import '../../providers/user_id_provider.dart';
import '../../core/app_router.dart';
import '../../../features/auth/data/user_repository.dart';
import '../../../features/settings/presentation/providers/settings_controller.dart';
import '../../../features/activities/presentation/providers/activities_controller.dart';
import '../../../features/events/presentation/providers/events_controller.dart' as events;
import '../../../features/carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../features/carb_loading/presentation/providers/carb_loading_day_detail_controller.dart';
import '../../../features/carb_loading/presentation/providers/carb_loading_food_selection_controller.dart';
import '../../../features/calendar/presentation/providers/calendar_controller.dart';
import '../../../features/onboarding/presentation/providers/food_preferences_controller.dart';
import '../../../features/integrations/presentation/providers/connect_training_controller.dart';
import '../../../features/nutrition_plan/presentation/providers/macro_targets_controller.dart';

/// Service that manages the Supabase auth state listener.
///
/// This service is initialized ONCE at app startup and NEVER torn down.
/// It listens for auth state changes and invalidates the appropriate providers,
/// but NEVER invalidates appStartupProvider to avoid infinite loops.
///
/// Key design principles:
/// 1. ONE listener for the lifetime of the app
/// 2. Invalidates user-specific providers AND appStartupProvider on sign-out
/// 3. appStartupProvider invalidation triggers router redirect to /welcome
/// 4. Skips invalidation during onboarding sign-out to preserve cached data
class AuthListenerService {
  AuthListenerService(this._ref);

  final Ref _ref;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _isInitialized = false;

  /// Flag to mark when sign-out is triggered during onboarding flow
  /// (to preserve cached onboarding data)
  bool _isOnboardingSignOut = false;

  // Accessors for dependencies
  SupabaseClient get _supabase => _ref.read(appExternalDepsProvider).supabaseClient;
  AppLogger get _logger => _ref.read(appExternalDepsProvider).logger;
  SentryReporter get _sentry => _ref.read(appExternalDepsProvider).sentry;
  AnalyticsTracker get _analytics => _ref.read(appExternalDepsProvider).analytics;

  /// Initialize the auth listener. Should only be called ONCE at app startup.
  void initialize() {
    if (_isInitialized) {
      _logger.warning(
        'AuthListenerService.initialize() called more than once - ignoring',
        context: 'AUTH_LISTENER',
      );
      return;
    }

    _isInitialized = true;
    _setupAuthStateListener();

    _logger.info(
      'AuthListenerService initialized - listening for auth state changes',
      context: 'AUTH_LISTENER',
    );
  }

  /// Mark that the next sign-out is part of onboarding flow
  /// Called by email_signup_screen before signing out existing session
  void markOnboardingSignOut() {
    _isOnboardingSignOut = true;
  }

  /// Setup the permanent auth state listener
  void _setupAuthStateListener() {
    _authStateSubscription?.cancel();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      _logger.info(
        'Auth state changed',
        context: 'AUTH_LISTENER',
        data: {
          'event': event.name,
          'has_session': session != null,
          'user_id': session?.user.id,
        },
      );

      // Handle token refresh events
      if (event == AuthChangeEvent.tokenRefreshed) {
        await _analytics.track('auth_token_refreshed', properties: {
          'user_id': session?.user.id,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Handle sign-out events
      if (event == AuthChangeEvent.signedOut) {
        await _handleSignedOut();
      }

      // Handle sign-in events
      if (event == AuthChangeEvent.signedIn && session != null) {
        await _handleSignedIn(session.user.id);
      }
    });
  }

  /// Handle sign-out event
  Future<void> _handleSignedOut() async {
    final wasOnboardingSignOut = _isOnboardingSignOut;
    _isOnboardingSignOut = false; // Reset flag

    await _analytics.track('user_signed_out', properties: {
      'timestamp': DateTime.now().toIso8601String(),
      'was_onboarding_signout': wasOnboardingSignOut,
    });

    _sentry.addBreadcrumb(
      message: wasOnboardingSignOut
          ? 'Onboarding signout - preserving cached data'
          : 'User signed out - invalidating user providers',
      category: 'auth',
      data: {
        'timestamp': DateTime.now().toIso8601String(),
        'was_onboarding_signout': wasOnboardingSignOut,
      },
    );

    // Skip provider invalidation during onboarding sign-out
    // This preserves cached onboarding data for saveAllOnboardingData()
    if (wasOnboardingSignOut) {
      _logger.info(
        'Onboarding sign-out - skipping provider invalidation',
        context: 'AUTH_LISTENER',
      );
      return;
    }

    try {
      // Invalidate user-specific providers first
      // Core user identity
      _ref.invalidate(userIdProvider);

      // Activities & Events
      _ref.invalidate(activitiesControllerProvider);
      _ref.invalidate(events.allEventsProvider);
      _ref.invalidate(events.nextUpcomingEventProvider);

      // Settings
      _ref.invalidate(settingsControllerProvider);

      // Carb Loading (CRITICAL: was missing, caused data leak between users)
      _ref.invalidate(carbLoadingControllerProvider);
      _ref.invalidate(carbLoadingPlanProvider);           // Family provider
      _ref.invalidate(carbLoadingDaysForPlanProvider);    // Family provider
      _ref.invalidate(carbLoadingDaysForRangeProvider);   // Family provider
      _ref.invalidate(carbLoadingDayDetailControllerProvider); // Family provider
      _ref.invalidate(carbLoadingFoodSelectionControllerProvider);

      // Calendar
      _ref.invalidate(calendarControllerProvider);

      // Food preferences
      _ref.invalidate(foodPreferencesControllerProvider);

      // Integrations
      _ref.invalidate(connectTrainingControllerProvider);

      // Nutrition plan
      _ref.invalidate(macroTargetsControllerProvider);

      // Notify GoRouter to re-evaluate redirects on the current route.
      // The redirect function checks Supabase session directly and
      // redirects to /welcome when no session exists.
      _ref.read(authChangeNotifierProvider).notify();

      _logger.info(
        'User-specific providers invalidated after sign-out',
        context: 'AUTH_LISTENER',
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to handle sign-out',
        context: 'AUTH_LISTENER',
        error: e,
        stackTrace: stackTrace,
      );

      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'sign_out_handler_failed',
        tags: {
          'error_type': 'sign_out_handler_failed',
          'operation': 'sign_out_handler',
        },
      );
    }
  }

  /// Handle sign-in event
  Future<void> _handleSignedIn(String userId) async {
    _sentry.addBreadcrumb(
      message: 'User signed in',
      category: 'auth',
      data: {
        'user_id': userId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // Invalidate userIdProvider immediately so router can react
    _ref.invalidate(userIdProvider);

    _logger.info(
      'User signed in - triggering background sync',
      context: 'AUTH_LISTENER',
      data: {'user_id': userId},
    );

    // Perform post-auth sync in background
    unawaited(_performPostAuthSync(userId));
  }

  /// Perform post-authentication sync operations in the background
  Future<void> _performPostAuthSync(String userId) async {
    // Check if user has completed onboarding before syncing
    try {
      final database = _ref.read(appDatabaseProvider);
      final userProfile = await database.userDao.getCurrentUserProfile(
        currentAuthUserId: userId,
      );

      if (userProfile == null || userProfile.onboardingCompleted != true) {
        _logger.info(
          'User has not completed onboarding - skipping sync',
          context: 'AUTH_LISTENER',
        );
        return;
      }
    } catch (e) {
      _logger.error(
        'Error checking onboarding status, skipping sync',
        context: 'AUTH_LISTENER',
        error: e,
      );
      return;
    }

    try {
      final userRepo = await _ref.read(userRepositoryProvider.future);

      // Run network calls in parallel for faster sync
      await Future.wait([
        userRepo.fetchAndSaveRemoteProfile(userId),
        userRepo.fetchAndCacheRemoteFoodPreferences(userId),
        userRepo.syncUserFoodsFromSupabase(userId),
      ]);

      // Invalidate settings provider after profile is loaded
      _ref.invalidate(settingsControllerProvider);
    } catch (e) {
      _logger.error(
        'Failed to sync remote profile on sign in',
        context: 'AUTH_LISTENER',
        error: e,
      );
    }

    // Trigger full sync for device-based users
    try {
      final syncCoordinator = _ref.read(syncCoordinatorProvider.notifier);
      await syncCoordinator.sync(
        userId: userId,
        trigger: SyncTrigger.manual,
      );
    } catch (e) {
      _logger.error(
        'Full sync failed after auth',
        context: 'AUTH_LISTENER',
        error: e,
      );
    }
  }

  /// Dispose of the auth listener
  void dispose() {
    _authStateSubscription?.cancel();
    _authStateSubscription = null;
    _isInitialized = false;
  }
}

/// Provider for AuthListenerService
/// This is a singleton that lives for the lifetime of the app
final authListenerServiceProvider = Provider<AuthListenerService>((ref) {
  final service = AuthListenerService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
