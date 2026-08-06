import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_startup_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/version_check_service.dart';
import '../../../shared/services/privacy/analytics_consent.dart';
import '../../../shared/services/privacy/privacy_region_service.dart';
import '../../../shared/services/performance_telemetry.dart';
import '../../../shared/models/version_check_result.dart';
import '../../../features/auth/data/user_repository.dart';
import '../../../features/auth/domain/user_preferences.dart';
import '../../../features/onboarding/application/onboarding_snapshot_service.dart';
import '../../../features/onboarding/data/onboarding_survey_repository.dart';

part 'app_startup_provider.g.dart';

/// Data returned by AppStartup for navigation decisions
class AppStartupData {
  const AppStartupData({
    required this.user,
    required this.hasCompletedOnboarding,
    this.isLoggedOut = false,
    this.forceUpgradeRequired = false,
    this.currentVersion,
    this.requiredVersion,
    this.resyncRequired = false,
    this.localSchemaVersion,
    this.remoteSchemaVersion,
  });

  final UserProfile? user;
  final bool hasCompletedOnboarding;

  /// True when user has logged out but still has local data
  /// In this state: no Supabase session, but local profile exists with onboardingCompleted = true
  final bool isLoggedOut;

  /// True when app version is below minimum required version
  final bool forceUpgradeRequired;
  final String? currentVersion;
  final String? requiredVersion;

  /// True when schema version mismatch requires database resync
  final bool resyncRequired;
  final int? localSchemaVersion;
  final int? remoteSchemaVersion;
}

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
@riverpod
class AppStartup extends _$AppStartup {
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  @override
  Future<AppStartupData> build() async {
    final startupStopwatch = Stopwatch()..start();
    try {
      final AppStartupService startupService = ref.read(
        appStartupServiceProvider,
      );

      // 0a. REGION: start the consent-region lookup immediately, but don't wait
      // on it yet — it overlaps the version-check round-trip below, so it
      // usually costs nothing. It must complete before anything reads consent,
      // because until it does we cannot tell a Washington user from a
      // Californian, and the two get different treatment. `ensureResolved()`
      // never throws and returns instantly on a warm cache.
      final regionFuture = ref
          .read(privacyRegionServiceProvider)
          .ensureResolved();

      // 0. VERSION CHECK: Check app version and schema version BEFORE database initialization
      // This prevents incompatible app versions from accessing the database
      final versionCheckService = ref.read(versionCheckServiceProvider);
      final versionCheckResult = await PerformanceTelemetry.measure(
        'startup.version_check',
        versionCheckService.checkVersion,
      );

      // Handle version check results
      if (versionCheckResult.isUpdateRequired) {
        final updateResult = versionCheckResult as VersionCheckUpdateRequired;
        _logger.warning(
          'Force upgrade required: current=${updateResult.currentVersion}, required=${updateResult.requiredVersion}',
          context: 'VERSION_CHECK',
        );
        return AppStartupData(
          user: null,
          hasCompletedOnboarding: false,
          forceUpgradeRequired: true,
          currentVersion: updateResult.currentVersion,
          requiredVersion: updateResult.requiredVersion,
        );
      }

      if (versionCheckResult.isResyncRequired) {
        final resyncResult = versionCheckResult as VersionCheckResyncRequired;
        _logger.warning(
          'Schema resync required: local=${resyncResult.localSchemaVersion}, remote=${resyncResult.remoteSchemaVersion}',
          context: 'VERSION_CHECK',
        );

        // Get user ID for dirty record upload (if logged in)
        final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
        final userId = supabaseClient.auth.currentUser?.id;

        // Perform schema resync: upload dirty records, delete database
        final resyncSuccess = await versionCheckService.performSchemaResync(
          userId,
          targetSchemaVersion: resyncResult.remoteSchemaVersion,
        );

        if (!resyncSuccess) {
          if (versionCheckService.wasDeferredForDataProtection) {
            // Anonymous user with dirty local rows that couldn't reach
            // Supabase (onboarding-redesign plan §7): the database was NOT
            // deleted. Continue on the old schema; the mismatch retries next
            // launch, once the upload has had a chance to succeed.
            _logger.warning(
              'Schema resync deferred to protect anonymous local data - '
              'continuing on the old schema this launch',
              context: 'VERSION_CHECK',
            );
          } else {
            _logger.error(
              'Schema resync failed - app may be in inconsistent state',
              context: 'VERSION_CHECK',
            );
            // Return resyncRequired to show error state
            return AppStartupData(
              user: null,
              hasCompletedOnboarding: false,
              resyncRequired: true,
              localSchemaVersion: resyncResult.localSchemaVersion,
              remoteSchemaVersion: resyncResult.remoteSchemaVersion,
            );
          }
        } else {
          _logger.info(
            'Schema resync completed - reinitializing database',
            context: 'VERSION_CHECK',
          );

          // Invalidate database provider to create fresh instance with new schema
          ref.invalidate(appDatabaseProvider);

          // Continue with normal startup - database will be fresh and empty
          // User will need to sign in again to sync their data
        }
      }

      // Version check passed - continue with normal startup
      _logger.info(
        'Version check passed - continuing with normal startup',
        context: 'VERSION_CHECK',
      );

      // 1. CRITICAL PATH: Run only essential initializations in parallel
      // Analytics and device info are deferred to avoid Android startup deadlock
      // NOTE: Auth state listener is now handled by AuthListenerService (initialized in RootAppWidget)
      await Future.wait([
        PerformanceTelemetry.measure(
          'startup.database_initialization',
          startupService.initializeDatabase,
        ),
        PerformanceTelemetry.measure(
          'startup.sentry_user_context',
          startupService.setSentryUserContext,
        ),
        // Joined here so that by the time this provider hands back data — which
        // is what the router waits on before it can send anyone to the consent
        // screen — the region is settled. Without this the router could gate a
        // Californian on a device-signal guess.
        PerformanceTelemetry.measure(
          'startup.privacy_region',
          () => regionFuture,
        ),
      ]);

      // Region resolution wrote to SharedPreferences behind the synchronous
      // consent reader, so rebuild it before deferred startup consults it.
      ref.invalidate(analyticsConsentProvider);

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
      var user = await PerformanceTelemetry.measure(
        'startup.local_user_lookup',
        () => database.userDao.getCurrentUserProfile(
          currentAuthUserId: currentAuthUserId,
        ),
        threshold: const Duration(milliseconds: 500),
      );

      // Anonymous safety net (onboarding-redesign plan §7): after a
      // delete-and-recreate upgrade, an anonymous user whose session was
      // lost gets nothing back from the re-pull. If no user row exists but
      // an onboarding snapshot does, re-import it locally with
      // needs_upload = true so sync can push it once a session exists.
      user ??= await _maybeRestoreOnboardingSnapshot();
      final hasCompletedOnboarding = user?.onboardingCompleted ?? false;

      // Track startup completion in Sentry
      final sentry = ref.read(appExternalDepsProvider).sentry;
      sentry.addBreadcrumb(
        message: 'App startup completed successfully',
        category: 'app_lifecycle',
        data: {'startup_time': DateTime.now().toIso8601String()},
      );

      final isLoggedOut =
          currentSession == null && user != null && hasCompletedOnboarding;

      return AppStartupData(
        user: user,
        hasCompletedOnboarding: hasCompletedOnboarding,
        isLoggedOut: isLoggedOut,
      );
    } catch (e, stackTrace) {
      _logger.error(
        'App startup initialization failed',
        context: 'APP_STARTUP',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow; // Re-throw to trigger error state in AsyncNotifier
    } finally {
      startupStopwatch.stop();
      PerformanceTelemetry.recordDuration(
        'startup.total',
        startupStopwatch.elapsed,
      );
    }
  }

  /// Restore the onboarding snapshot into Drift when the local database has
  /// no user row (post delete-and-recreate with a lost anonymous session).
  /// Rows are written with `needs_upload = true` so a future session pushes
  /// them. Returns the restored profile, or null when there is no snapshot
  /// or the restore fails (startup proceeds as a fresh install either way).
  Future<UserProfile?> _maybeRestoreOnboardingSnapshot() async {
    try {
      final snapshotService = ref.read(onboardingSnapshotServiceProvider);
      final snapshot = await snapshotService.readSnapshot();
      if (snapshot == null) return null;

      _logger.warning(
        'No local user row but an onboarding snapshot exists - restoring '
        'locally with needs_upload=true',
        context: 'ONBOARDING_SNAPSHOT',
        data: {
          'snapshotUserId': snapshot.profile.id,
          'writtenAt': snapshot.writtenAt.toIso8601String(),
        },
      );

      final userRepository = await ref.read(userRepositoryProvider.future);
      await userRepository.saveUserProfile(snapshot.profile, needsUpload: true);
      await ref
          .read(onboardingSurveyRepositoryProvider)
          .saveSurveyFromDraft(
            userId: snapshot.profile.id,
            draft: snapshot.toSurveyDraft(),
          );

      final sentry = ref.read(appExternalDepsProvider).sentry;
      sentry.addBreadcrumb(
        message: 'Onboarding snapshot restored after DB recreate',
        category: 'onboarding',
        data: {'userId': snapshot.profile.id},
      );

      return snapshot.profile;
    } catch (e, stackTrace) {
      _logger.error(
        'Onboarding snapshot restore failed - continuing as fresh install',
        context: 'ONBOARDING_SNAPSHOT',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
