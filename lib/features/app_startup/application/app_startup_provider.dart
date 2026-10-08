import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_startup_service.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/launch_trail.dart';
import '../../../shared/services/report/report.dart';
import '../../../shared/services/version_check_service.dart';
import '../../../shared/services/privacy/analytics_consent.dart';
import '../../../shared/services/privacy/privacy_region_service.dart';
import '../../../shared/services/report/performance_telemetry.dart';
import '../../../shared/models/version_check_result.dart';
import '../../../features/auth/data/user_repository.dart';
import '../../../features/auth/domain/pending_signup.dart';
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
    this.pendingSignup,
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

  /// A signup quit on Verify your email (ticket 42, 30-007): the root
  /// redirect resumes it at `/auth/post-onboarding?resume=verify`.
  final PendingSignup? pendingSignup;

  /// A copy with the given fields replaced. [user] is a getter so it can be
  /// set to null (`user: () => null`); an omitted argument keeps the value.
  AppStartupData copyWith({
    UserProfile? Function()? user,
    bool? hasCompletedOnboarding,
    bool? isLoggedOut,
  }) {
    return AppStartupData(
      user: user != null ? user() : this.user,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      isLoggedOut: isLoggedOut ?? this.isLoggedOut,
      forceUpgradeRequired: forceUpgradeRequired,
      currentVersion: currentVersion,
      requiredVersion: requiredVersion,
      resyncRequired: resyncRequired,
      localSchemaVersion: localSchemaVersion,
      remoteSchemaVersion: remoteSchemaVersion,
      pendingSignup: pendingSignup,
    );
  }
}

/// The session-dependent part of [AppStartupData]: what [AppStartup.build]
/// reads at launch and [AppStartup.refreshSession] re-reads after an
/// in-session auth change (ticket 56).
typedef _SessionFields = ({
  UserProfile? user,
  bool hasCompletedOnboarding,
  bool isLoggedOut,
  String? authUserId,
});

/// Asks the live startup snapshot to follow an in-session auth change
/// (ticket 56). Callers outside the notifier use this, not the notifier
/// directly: `appStartupProvider` is auto-dispose, and reading its notifier
/// while nothing holds it would start a whole new startup (version check,
/// region, schema). In the app `AppStartupWidget` always holds it; when it
/// does not exist there is no snapshot to refresh, and the skip is written
/// down (D9). Never throws.
Future<void> refreshStartupSnapshot(Ref ref, {required String reason}) async {
  if (!ref.mounted) {
    // The caller's provider was disposed while it awaited; its ref can read
    // nothing, so the global report carries the breadcrumb.
    LaunchTrail.add('startup snapshot refresh skipped ($reason): caller gone');
    SentryReport.global.breadcrumb(
      'Startup snapshot refresh skipped: caller disposed',
      category: 'startup',
      data: {'reason': reason},
    );
    return;
  }
  await refreshStartupSnapshotIn(ref.container, reason: reason);
}

/// [refreshStartupSnapshot] for a caller whose own ref may be gone by the
/// time it asks: a service built by an auto-dispose provider holds the
/// [container] it was built in, which lives as long as the app. Same skip
/// rule (no live startup provider: recorded, D9). Never throws.
Future<void> refreshStartupSnapshotIn(
  ProviderContainer container, {
  required String reason,
}) async {
  if (!container.exists(appStartupProvider)) {
    LaunchTrail.add('startup snapshot refresh skipped ($reason): no startup');
    container
        .read(reportProvider)
        .breadcrumb(
          'Startup snapshot refresh skipped: startup provider not alive',
          category: 'startup',
          data: {'reason': reason},
        );
    return;
  }
  await container
      .read(appStartupProvider.notifier)
      .refreshSession(reason: reason);
}

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
@riverpod
class AppStartup extends _$AppStartup {
  Report get _report => ref.report;

  /// Sequence number of the latest [refreshSession] call. Never reset: Riverpod
  /// reuses this notifier across `invalidate`, so [build] bumps it instead,
  /// which makes a refresh still awaiting from before the rebuild drop its
  /// write.
  int _refreshSeq = 0;

  @override
  Future<AppStartupData> build() async {
    _refreshSeq++;
    final startupStopwatch = Stopwatch()..start();
    // Read before any await: a `ref` read after the provider is disposed
    // throws UnmountedRefException, which would mask the real failure in the
    // catch below.
    final report = _report;
    try {
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
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

      // 0a'. A reset the app was quit on (124-003): its recovery session is
      // signed out before anything reads the session, RevenueCat included.
      await startupService.endAbandonedRecovery();

      // 0a''. A signup quit on Verify your email (ticket 42): read once,
      // after any recovery session is gone. Never throws.
      final pendingSignup = await startupService.pendingSignupAtLaunch();

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
        await report.note(
          'Force upgrade required',
          area: 'startup',
          data: {
            'current': updateResult.currentVersion,
            'required': updateResult.requiredVersion,
          },
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
        await report.note(
          'Schema resync required',
          area: 'startup',
          data: {
            'local': resyncResult.localSchemaVersion,
            'remote': resyncResult.remoteSchemaVersion,
          },
        );

        // Get user ID for dirty record upload (if logged in)
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
            await report.note(
              'Schema resync deferred to protect anonymous local data - '
              'continuing on the old schema this launch',
              area: 'startup',
            );
          } else {
            await report.degraded(
              const LoggedFault(
                'Schema resync failed - app may be in inconsistent state',
              ),
              area: 'startup',
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
          report.info(
            'Schema resync completed - reinitializing database',
            area: 'startup',
          );

          // Invalidate database provider to create fresh instance with new schema
          ref.invalidate(appDatabaseProvider);

          // Continue with normal startup - database will be fresh and empty
          // User will need to sign in again to sync their data
        }
      }

      // Version check passed - continue with normal startup
      report.info(
        'Version check passed - continuing with normal startup',
        area: 'startup',
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

      // 3. Get navigation data (fast local DB query). The same read
      // refreshSession runs after an in-session auth change; only launch
      // runs the onboarding-snapshot restore.
      final session = await _readSessionFields(restoreSnapshot: true);

      report.breadcrumb(
        'App startup completed successfully',
        category: 'app_lifecycle',
        data: {'startup_time': DateTime.now().toIso8601String()},
      );

      return AppStartupData(
        user: session.user,
        hasCompletedOnboarding: session.hasCompletedOnboarding,
        isLoggedOut: session.isLoggedOut,
        pendingSignup: pendingSignup,
      );
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'App startup initialization failed',
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

  /// Reads the session-dependent fields: the live Supabase session, the local
  /// profile for it, and whether that profile finished onboarding.
  ///
  /// [restoreSnapshot] is launch only ([build]): the anonymous safety net
  /// (onboarding-redesign plan §7) re-imports a lost anonymous user's
  /// onboarding snapshot when no user row exists. A mid-session auth change
  /// is not that recovery case, so [refreshSession] passes false.
  Future<_SessionFields> _readSessionFields({
    required bool restoreSnapshot,
  }) async {
    final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
    final database = ref.read(appDatabaseProvider);

    // Get current Supabase session to check auth state
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
    if (restoreSnapshot) {
      user ??= await _maybeRestoreOnboardingSnapshot(
        currentAuthUserId: currentAuthUserId,
      );
    }
    final hasCompletedOnboarding = user?.onboardingCompleted ?? false;
    final isLoggedOut =
        currentSession == null && user != null && hasCompletedOnboarding;

    return (
      user: user,
      hasCompletedOnboarding: hasCompletedOnboarding,
      isLoggedOut: isLoggedOut,
      authUserId: currentAuthUserId,
    );
  }

  /// Re-reads the session-dependent fields after an in-session auth change
  /// and writes them over the live snapshot (ticket 56). Before this, the
  /// snapshot was read once at launch, so after an in-session login every
  /// `go('/')` read "no user" and landed on Welcome (49-001, 50-005).
  ///
  /// The contract (ticket 59 reads it):
  /// - **When it writes.** Only `AsyncData -> AsyncData`: the old snapshot
  ///   with `user`, `hasCompletedOnboarding` and `isLoggedOut` replaced
  ///   ([AppStartupData.copyWith]). Force-upgrade, resync, the schema
  ///   versions and `pendingSignup` are kept. It never writes `AsyncLoading`
  ///   (`AppStartupWidget` would swap the whole app for the loading screen)
  ///   and never writes an error (#118). It does not notify the router:
  ///   the next redirect reads the new data, nothing navigates by itself.
  ///   Listeners of `appStartupProvider` (the held-tap replay in
  ///   `root_app_widget.dart`) do fire on the write.
  /// - **When it skips** (each skip writes a LaunchTrail line and a
  ///   `startup` breadcrumb, D9): state has no data yet (startup loading,
  ///   reloading or failed; `build` reads the session itself); a later
  ///   call started, or `build` re-ran, while this one awaited (see below);
  ///   the session user changed while it awaited; the provider was disposed;
  ///   or the read threw (reported through `faultUnlessWeather`, area
  ///   `startup`, old snapshot kept).
  /// - **Sequence rule.** Each call takes the next sequence number; it
  ///   writes only if no later call has started and `build` has not re-run
  ///   since (build bumps the number). Last caller wins, so a sign-out
  ///   followed fast by a sign-in never ends on the sign-out's answer.
  /// - With a session but no local profile yet (a fresh login on this
  ///   device), it first awaits `userIdProvider`, which pulls and saves the
  ///   remote profile, then reads.
  ///
  /// Every completed write leaves the LaunchTrail line
  /// `startup snapshot refreshed (signed_in): user=true onboarded=true`
  /// (reason and values vary). Never throws.
  Future<void> refreshSession({required String reason}) async {
    // Read before any await: the ref may be unmounted by the time we write.
    final ref = this.ref;
    final report = _report;
    final seq = ++_refreshSeq;

    void skipped(String why, {Map<String, dynamic>? data}) {
      LaunchTrail.add('startup snapshot refresh skipped ($reason): $why');
      report.breadcrumb(
        'Startup snapshot refresh skipped: $why',
        category: 'startup',
        data: {'reason': reason, ...?data},
      );
    }

    if (state is! AsyncData<AppStartupData>) {
      skipped('startup has no data yet');
      return;
    }

    try {
      final sessionAtStart = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentSession;
      final startUserId = sessionAtStart?.user.id;

      var fields = await _readSessionFields(restoreSnapshot: false);
      if (startUserId != null && fields.user == null && ref.mounted) {
        // A fresh login on this device: userIdProvider pulls the remote
        // profile and saves it locally. Then read again.
        await ref.read(userIdProvider.future);
        if (!ref.mounted) {
          skipped('provider disposed');
          return;
        }
        fields = await _readSessionFields(restoreSnapshot: false);
      }

      if (!ref.mounted) {
        skipped('provider disposed');
        return;
      }
      if (seq != _refreshSeq) {
        skipped('superseded by a later refresh or rebuild');
        return;
      }
      final endUserId = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentSession
          ?.user
          .id;
      if (fields.authUserId != startUserId || endUserId != startUserId) {
        skipped('session user changed during refresh');
        return;
      }
      final current = state;
      if (current is! AsyncData<AppStartupData>) {
        skipped('startup lost its data during refresh');
        return;
      }

      state = AsyncData(
        current.value.copyWith(
          user: () => fields.user,
          hasCompletedOnboarding: fields.hasCompletedOnboarding,
          isLoggedOut: fields.isLoggedOut,
        ),
      );
      LaunchTrail.add(
        'startup snapshot refreshed ($reason): '
        'user=${fields.user != null} onboarded=${fields.hasCompletedOnboarding}',
      );
      report.breadcrumb(
        'Startup snapshot refreshed',
        category: 'startup',
        data: {
          'reason': reason,
          'user': fields.user != null,
          'onboarded': fields.hasCompletedOnboarding,
          'logged_out': fields.isLoggedOut,
        },
      );
    } catch (e, stackTrace) {
      // #118: reported, the old snapshot kept, nothing written into state.
      skipped('read failed, old snapshot kept');
      await report.faultUnlessWeather(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message: 'Startup snapshot refresh failed - keeping the old snapshot',
        data: {'reason': reason},
      );
    }
  }

  /// Restore the onboarding snapshot into Drift when the local database has
  /// no user row (post delete-and-recreate with a lost anonymous session).
  /// Rows are written with `needs_upload = true` so a future session pushes
  /// them. Returns the restored profile, or null when there is no snapshot
  /// or the restore fails (startup proceeds as a fresh install either way).
  Future<UserProfile?> _maybeRestoreOnboardingSnapshot({
    required String? currentAuthUserId,
  }) async {
    final report = _report;
    try {
      final snapshotService = ref.read(onboardingSnapshotServiceProvider);
      final snapshot = await snapshotService.readSnapshot();
      if (snapshot == null) return null;

      // The snapshot is a recovery net for the SAME user whose session was
      // lost. If a different account is signed in (fresh login after a wipe,
      // shared device, deleted account), restoring would resurrect a ghost
      // profile under the wrong session — its dirty rows would then be
      // pushed to Supabase as that user or bounce off RLS forever. Skip.
      if (currentAuthUserId != null &&
          currentAuthUserId != snapshot.profile.id) {
        await report.note(
          'Onboarding snapshot belongs to a different user than the current '
          'session - skipping restore',
          area: 'startup',
          data: {
            'snapshotUserId': snapshot.profile.id,
            'currentAuthUserId': currentAuthUserId,
          },
        );
        return null;
      }

      await report.note(
        'No local user row but an onboarding snapshot exists - restoring '
        'locally with needs_upload=true',
        area: 'startup',
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

      report.breadcrumb(
        'Onboarding snapshot restored after DB recreate',
        category: 'onboarding',
        data: {'userId': snapshot.profile.id},
      );

      return snapshot.profile;
    } catch (e, stackTrace) {
      await report.fault(
        e,
        stackTrace: stackTrace,
        area: 'startup',
        message:
            'Onboarding snapshot restore failed - continuing as fresh install',
      );
      return null;
    }
  }
}
