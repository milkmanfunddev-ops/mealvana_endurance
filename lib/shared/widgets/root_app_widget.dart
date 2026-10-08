import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiredash/wiredash.dart';
import '../../theme/kyle_design/app_theme.dart';
import '../../theme/kyle_design/theme_provider.dart';
import '../../features/app_startup/application/app_startup_provider.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';
import '../core/app_router.dart';
import '../../features/auth/data/pending_signup_store.dart';
import '../services/privacy/analytics_consent.dart';
import '../core/bootstrap/bootstrap.dart' show appNavigatorKey;
import '../services/report/report.dart';
import '../services/app_config.dart';
import '../services/app_external_deps.dart';
import '../../features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import '../../features/nutrition_plan/application/night_before_nudge_service.dart';
import '../../features/nutrition_plan/domain/night_before_nudge_engine.dart';
import '../../features/nutrition_plan/presentation/providers/night_before_nudge_coordinator.dart';
import '../../features/activities/data/activities_repository.dart';
import '../services/auth/auth_listener_service.dart';
import '../services/notification_service.dart';
import '../services/notification_intent_routes.dart';
import '../services/launch_trail.dart';
import '../../features/daily_macros/data/daily_macro_targets_repository.dart';
import '../../features/auth/application/auth_service.dart';
import '../services/support/support_identity.dart';
import 'dev_testing_tools.dart';

/// Root app widget that handles app initialization and navigation
/// Following Andrea Bizzotto's patterns for app startup with deep link support
/// Now using Kyle's design system with dual theme support
///
/// Key architectural pattern:
/// - MaterialApp.router is initialized immediately with GoRouter
/// - MaterialApp.builder wraps the router child with AppStartupWidget
/// - This allows deep links to be processed while app initializes
/// - Critical for OAuth redirects (e.g., com.milkman.mealvanaendurance://auth-callback)
/// G27: where a carb-load nudge tap lands — the event's details screen.
/// Pure so the L2 pins the mapping without pumping the root widget.
/// Kept as the carb-nudge's named entry point; the table in
/// notification_intent_routes.dart is the single decision point.
String notificationRouteForCarbEvent(String eventId) =>
    destinationForIntent('carb_event', eventId).location;

/// Dev only: shows this process's launch tape, at most once per process.
///
/// Skips a tape with no notification in it (see
/// [LaunchTrail.hasNotificationEvidence]) and any call after the first
/// dialog: each resume calls this again, and keyed on tape length every
/// resume stacked another dialog on the last (Finding 01-011).
@visibleForTesting
void showLaunchTrailDialogOnce(BuildContext? ctx, Report report) {
  if (LaunchTrail.isEmpty) return;
  if (!LaunchTrail.hasNotificationEvidence) return;
  if (LaunchTrail.dialogShown) {
    const line = 'trail dialog skipped: already shown this process';
    LaunchTrail.add(line);
    report.breadcrumb(line, category: 'push');
    return;
  }
  if (ctx == null || !ctx.mounted) return;
  LaunchTrail.markDialogShown();
  showDialog<void>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: const Text('Launch trail (dev)'),
      content: SingleChildScrollView(
        child: SelectableText(
          LaunchTrail.text,
          style: const TextStyle(fontSize: 11, height: 1.4),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: const Text('Dismiss'),
        ),
      ],
    ),
  );
}

/// The collection running now, if any. See [collectResumeTaps].
Future<void>? _resumeCollection;

/// Collects what iOS left for us while the app was backgrounded: a tapped
/// notification (ticket 34, Finding 22-001) and the native tape lines.
///
/// A backgrounded tap produces no new launch, so it never reaches
/// `getNotificationAppLaunchDetails`; AppDelegate writes its payload to
/// `ios_un_response_payload` (or, legacy, `ios_legacy_resume_payload`) and
/// [NotificationService.consumeLegacyResumeTap] routes it.
///
/// NO DOUBLE HANDLING WITH THE LAUNCH PATH: a tap that LAUNCHED the app is
/// read by `NotificationService.initialize()` from launch details or from
/// `ios_legacy_launch_payload`, a different key. A launch tap and a resume
/// tap never share a key, so neither path can route the other's tap.
///
/// The prefs are RELOADED first. shared_preferences serves reads from a Dart
/// cache filled at launch; AppDelegate writes UserDefaults natively while we
/// are away, so without the reload the cache never shows the tap and both
/// [LaunchTrail.pullNative] and the consume read nothing.
///
/// Runs one at a time: a second resume while one is collecting joins the
/// running one instead of starting another. Two overlapping reloads could
/// otherwise put a just-consumed key back into the cache (a reload's read
/// can predate the other's remove reaching the store) and route the tap
/// twice. A tap written after the running collection reloaded is collected
/// on the next resume.
@visibleForTesting
Future<void> collectResumeTaps(Report report) {
  final running = _resumeCollection;
  if (running != null) {
    const line = 'resume tap collection joined: one already running';
    LaunchTrail.add(line);
    report.breadcrumb(line, category: 'push');
    return running;
  }
  final collection = _collectResumeTaps(report).whenComplete(() {
    _resumeCollection = null;
  });
  _resumeCollection = collection;
  return collection;
}

Future<void> _collectResumeTaps(Report report) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
  } catch (e, st) {
    // Carry on with the cache: a tap already in it still routes.
    LaunchTrail.add('resume prefs reload failed: $e');
    await report.fault(
      e,
      stackTrace: st,
      area: 'push',
      message: 'prefs reload on resume failed; backgrounded tap may be missed',
    );
  }
  // Tape what AppDelegate wrote while we were away (a foreground delivery
  // or a backgrounded tap lands after `begin()` has run), before the
  // consume tapes what it did with it.
  LaunchTrail.pullNative();
  await NotificationService.consumeLegacyResumeTap();
}

/// Why a notification tap cannot route right now, or null when it can
/// (ticket 59, Finding 50-001).
///
/// Routable means "the router would answer `/main` for `/` right now, with a
/// live session": the same [AppRouter.rootRedirect] the router runs on
/// `appStartupProvider`'s data, plus the live-session check the router makes
/// for every protected route. One rule shared with the router, not a second
/// list of conditions (the old guard ignored onboarding). The answer is the
/// reason the HELD line carries:
/// - `no session`: no live Supabase session;
/// - `startup loading` / `startup failed`: startup has no data;
/// - otherwise the root redirect's answer when it is not `/main`
///   (`/welcome`, `/force-upgrade`, `/privacy-consent`,
///   `/auth/post-onboarding?resume=verify`).
///
/// The caller passes the reads the router makes, unchanged:
/// `ref.read(appStartupProvider)`, the live `currentSession != null`,
/// `pendingSignupStoreProvider.isOpen` and `analyticsConsentProvider`'s
/// `needsPrompt` (see [notificationTapGate]).
@visibleForTesting
String? notificationTapHoldReason(
  AsyncValue<AppStartupData> startup, {
  required bool hasSession,
  required bool Function() pendingSignupOpen,
  required bool Function() needsConsentPrompt,
}) {
  if (!hasSession) return 'no session';
  if (startup is! AsyncData<AppStartupData>) {
    return startup.hasError ? 'startup failed' : 'startup loading';
  }
  final target = AppRouter.rootRedirect(
    startup.value,
    pendingSignupOpen: pendingSignupOpen,
    needsConsentPrompt: needsConsentPrompt,
  );
  return target == '/main' ? null : (target ?? 'root redirect undecided');
}

/// Whether a notification tap can route right now. See
/// [notificationTapHoldReason].
@visibleForTesting
bool notificationTapRoutable(
  AsyncValue<AppStartupData> startup, {
  required bool hasSession,
  required bool Function() pendingSignupOpen,
  required bool Function() needsConsentPrompt,
}) =>
    notificationTapHoldReason(
      startup,
      hasSession: hasSession,
      pendingSignupOpen: pendingSignupOpen,
      needsConsentPrompt: needsConsentPrompt,
    ) ==
    null;

/// What the tap guard reads, at one moment: why a tap cannot route (null when
/// it can) and whose session is live (null when signed out).
typedef NotificationTapGate = ({String? holdReason, String? sessionUserId});

/// Reads the gate the way the router reads its redirect. [read] is
/// `WidgetRef.read` in the app and `ProviderContainer.read` in tests.
@visibleForTesting
NotificationTapGate notificationTapGate(
  T Function<T>(ProviderListenable<T> provider) read,
) {
  final session = read(
    appExternalDepsProvider,
  ).supabaseClient.auth.currentSession;
  return (
    holdReason: notificationTapHoldReason(
      read(appStartupProvider),
      hasSession: session != null,
      pendingSignupOpen: () => read(pendingSignupStoreProvider).isOpen,
      needsConsentPrompt: () => read(analyticsConsentProvider).needsPrompt,
    ),
    sessionUserId: session?.user.id,
  );
}

/// The one notification tap the root widget is holding, and the record of
/// what became of it (ticket 59).
///
/// A tap that arrives while the app is not routable is HELD. It is released
/// (REPLAY) when the reason clears in the same session, and DROPPED when the
/// session changes (Lee's ruling 2026-10-08: a tap held across a sign-in or a
/// sign-out is never replayed; no ownership check, no expiry). A newer tap
/// replaces a held one; the root going away drops it.
///
/// Every line goes to [LaunchTrail] (the device tape) and, with the same
/// text, to a `push` breadcrumb (rule D9: the tape alone is not
/// PROD-readable).
class HeldNotificationTap {
  HeldNotificationTap(this._report);

  final Report _report;

  ({String id, String? type, String? sessionUserId})? _held;

  /// The held tap's id, or null.
  String? get heldId => _held?.id;

  bool get isHeld => _held != null;

  /// Holds a tap that cannot route now. A tap already held is dropped: the
  /// newest is the athlete's latest intent.
  void hold(
    String id,
    String? type, {
    required String reason,
    required String? sessionUserId,
  }) {
    dropReplacedBy(id);
    _held = (id: id, type: type, sessionUserId: sessionUserId);
    _write('HELD id=$id type=$type ($reason)', id, type);
  }

  /// Drops the held tap, if any, because a newer tap ([id]) arrived.
  void dropReplacedBy(String id) {
    final old = _held;
    if (old == null) return;
    _held = null;
    _write('DROPPED id=${old.id} (replaced by id=$id)', old.id, old.type);
  }

  /// Re-checks the held tap against [gate]. Returns it, cleared, when it can
  /// route now (and tapes REPLAY); drops it when the session changed since it
  /// was held; otherwise keeps holding it and returns null.
  ({String id, String? type})? takeIfRoutable(NotificationTapGate gate) {
    final tap = _held;
    if (tap == null) return null;
    if (gate.sessionUserId != tap.sessionUserId) {
      _held = null;
      final change = tap.sessionUserId == null
          ? 'signed in'
          : gate.sessionUserId == null
          ? 'signed out'
          : 'account changed';
      _write(
        'DROPPED id=${tap.id} type=${tap.type} (session changed: $change)',
        tap.id,
        tap.type,
      );
      return null;
    }
    if (gate.holdReason != null) return null;
    _held = null;
    _write('REPLAY id=${tap.id} type=${tap.type}', tap.id, tap.type);
    return (id: tap.id, type: tap.type);
  }

  /// The root is going away with a tap still held.
  void dropOnDispose() {
    final tap = _held;
    if (tap == null) return;
    _held = null;
    _write(
      'DROPPED id=${tap.id} type=${tap.type} (root disposed while held)',
      tap.id,
      tap.type,
    );
  }

  /// A tap that was never held or routed: [why] says what stopped it
  /// (`empty id`, `root unmounted`).
  void dropIncoming(String id, String? type, {required String why}) {
    _write('DROPPED id=$id type=$type ($why)', id, type);
  }

  void _write(String line, String id, String? type) {
    LaunchTrail.add(line);
    _report.breadcrumb(line, category: 'push', data: {'id': id, 'type': type});
  }
}

class RootAppWidget extends ConsumerStatefulWidget {
  const RootAppWidget({super.key});

  @override
  ConsumerState<RootAppWidget> createState() => _RootAppWidgetState();
}

class _RootAppWidgetState extends ConsumerState<RootAppWidget>
    with WidgetsBindingObserver {
  /// Captured in [initState] so [dispose] can write down a dropped tap
  /// without reading a provider after unmount.
  late final Report _report;

  /// The tap held until the app can route it (ticket 59).
  late final HeldNotificationTap _heldTap;

  @override
  void initState() {
    super.initState();
    _report = ref.read(reportProvider);
    _heldTap = HeldNotificationTap(_report);
    WidgetsBinding.instance.addObserver(this);

    NotificationService.setNavigationHandler(_handleNotificationNavigation);

    // Register the macro cache invalidator so Garmin activity-upload
    // notifications automatically bust the cache for the affected date.
    NotificationService.setDailyMacroCacheInvalidator((DateTime date) async {
      if (!mounted) return;
      // Use Supabase auth directly — no async wait required.
      final userId = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentUser
          ?.id;
      if (userId == null) return;
      final repo = ref.read(dailyMacroTargetsRepositoryProvider);
      await repo.invalidateForDate(userId, date);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A tap that launched the app may already be waiting here: the plugin's
      // launch details are read during deferred startup, which can land either
      // side of this frame. Whichever way it lands, _handleNotificationNavigation
      // holds the tap until the router can honour it.
      final pendingActivityId =
          NotificationService.getPendingNavigationActivityId();
      final pendingType = NotificationService.getPendingNavigationType();
      if (pendingActivityId != null && pendingActivityId.isNotEmpty) {
        _handleNotificationNavigation(pendingActivityId, pendingType);
      }
      // DEV ONLY: show this launch's tape on screen a few seconds in, so a
      // killed-app tap can be diagnosed on the device with nothing attached.
      // Release builds cannot print, and the failing launch is the one nobody
      // can watch — so the app shows its own working.
      if (ref.read(appConfigProvider).devModeEnabled) {
        Future.delayed(const Duration(seconds: 4), () {
          _showTrailDialog();
        });
      }

      // G27: first-frame nudge sweep (arm/disarm + on-open catch-up).
      ref.read(carbNudgeCoordinatorProvider.notifier).run();
      // Night-before long-workout nudge: same sweep shape, same fail-soft.
      ref.read(nightBeforeNudgeCoordinatorProvider).run();
    });
  }

  /// Dev-only: put the current tape on screen. Used on launch AND on resume —
  /// a BACKGROUNDED tap produces no new launch, so without the resume path the
  /// backgrounded case is unobservable on device, which is how it stayed
  /// "presumed working" until someone finally tried it.
  void _showTrailDialog() {
    if (!mounted) return;
    showLaunchTrailDialogOnce(
      appNavigatorKey.currentContext,
      ref.read(reportProvider),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      LaunchTrail.add('app resumed');
      unawaited(_onResumed(ref.read(reportProvider)));
    }
  }

  /// The resume work, in order: collect a backgrounded tap first (so it
  /// routes before anything else reacts to the resume), then the dev dialog
  /// and the G27 nudge catch-up.
  Future<void> _onResumed(Report report) async {
    await collectResumeTaps(report);
    if (!mounted) {
      const line =
          'resume: root unmounted during tap collection; '
          'nudge catch-up skipped';
      LaunchTrail.add(line);
      report.breadcrumb(line, category: 'push');
      return;
    }
    if (ref.read(appConfigProvider).devModeEnabled) {
      Future.delayed(const Duration(seconds: 3), _showTrailDialog);
    }
    // G27: the on-open catch-up also runs on every foreground resume.
    ref.read(carbNudgeCoordinatorProvider.notifier).run();
    ref.read(nightBeforeNudgeCoordinatorProvider).run();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.setNavigationHandler(null);
    NotificationService.setDailyMacroCacheInvalidator(null);
    _heldTap.dropOnDispose();
    super.dispose();
  }

  /// Can a deep link survive the root redirect right now?
  ///
  /// THE BUG THIS ANSWERS (2026-09-30). A notification tap that launches the
  /// app from killed used to navigate straight into the router while startup
  /// was still resolving. The global redirect reads `appStartupProvider`, and
  /// until that has data every protected route falls through to the startup
  /// branch and is sent to `/main` — so the athlete landed on the Timeline
  /// holding a nudge that told them to go somewhere else.
  ///
  /// Ticket 59 (Finding 50-001): the guard now asks the router's own
  /// question on the live state ([notificationTapGate]). Before, it read a
  /// launch-time "no user" for the whole process, so after an in-session
  /// login every backgrounded tap was held and never released.
  NotificationTapGate _gate() => notificationTapGate(ref.read);

  void _handleNotificationNavigation(String activityId, String? type) {
    if (activityId.isEmpty) {
      _heldTap.dropIncoming(activityId, type, why: 'empty id');
      return;
    }
    if (!mounted) {
      _heldTap.dropIncoming(activityId, type, why: 'root unmounted');
      return;
    }

    // Hold it until it can route, or until the session changes (then it is
    // dropped, never replayed into another session: Lee, 2026-10-08).
    final gate = _gate();
    final reason = gate.holdReason;
    if (reason != null) {
      _heldTap.hold(
        activityId,
        type,
        reason: reason,
        sessionUserId: gate.sessionUserId,
      );
      return;
    }
    // A newer tap that routes now supersedes one still held.
    _heldTap.dropReplacedBy(activityId);
    LaunchTrail.add('routing id=$activityId type=$type');

    // The tap is the attribution anchor for "did the nudge cause a plan".
    // Recorded before navigating so a slow write cannot lose it to the
    // screen transition. The intent carries the variant — only the no-plan
    // one seeds plan attribution.
    if (type == 'plan_workout' || type == 'rehearse_plan') {
      ref
          .read(nightBeforeNudgeServiceProvider)
          .recordTap(
            activityId,
            variant: type == 'rehearse_plan'
                ? NightBeforeVariant.rehearse
                : NightBeforeVariant.noPlan,
          );
    }

    final destination = destinationForIntent(type, activityId);

    // plan_workout lands on the CREATE-PLAN flow, which pre-fills only from
    // the extras it is handed (it self-loads for brick alone). Hydrate from
    // the workout, then navigate. If the lookup fails the athlete still lands
    // on the right screen with the workout linked — blank beats wrong.
    if (type == 'plan_workout') {
      unawaited(_goPrefilled(activityId, destination));
      return;
    }

    _deepLinkTo(destination.location, destination.extra);
  }

  /// A deep link must leave a way back.
  ///
  /// `go` REPLACES the navigation stack, so a nudge tap landed on the create
  /// screen with nothing beneath it: the top-left back control had nothing to
  /// pop and the athlete was trapped with no way out but force-quitting
  /// (filed 2026-10-01). Every shipping nudge tap lands there, so this is the
  /// flagship landing, not an edge case.
  ///
  /// Seed home, then push, so back behaves exactly as it does when the screen
  /// is reached by hand. Safe to do synchronously here because the caller has
  /// already cleared the tap guard ([notificationTapHoldReason]), which asks
  /// the router's own `rootRedirect` for `/main`, so '/' will not redirect
  /// out from under the push.
  void _deepLinkTo(String location, Object? extra) {
    final router = ref.read(AppRouter.routerProvider);
    router.go('/');
    router.push(location, extra: extra);
    // Taped so a later "canPop=false" back-fallback can be read against
    // whether the stack WAS seeded here — the 2026-10-03 regression's open
    // question is what un-seeded it afterwards.
    LaunchTrail.add('deepLinkTo $location (seeded / beneath)');
  }

  Future<void> _goPrefilled(
    String activityId,
    NotificationDestination destination,
  ) async {
    var extra = destination.extra;
    try {
      final userId = ref
          .read(appExternalDepsProvider)
          .supabaseClient
          .auth
          .currentUser
          ?.id;
      final activity = userId == null
          ? null
          : await ref
                .read(activitiesRepositoryProvider)
                .getActivityById(userId, activityId);
      if (activity != null) {
        extra = hydratePlanWorkoutExtra(
          activityId: activityId,
          activityTypeName: activity.activityType.name,
          scheduledDateTime: activity.scheduledDateTime,
          title: activity.title,
          durationMinutes: activity.durationMinutes,
          distanceMiles: activity.distanceMiles,
        );
      }
    } catch (e) {
      // Fall through with the bare id — see above.
      await ref
          .read(reportProvider)
          .note(
            'Activity lookup for notification deep link failed; navigating with bare id',
            area: 'push',
            data: {'activity_id': activityId, 'error': e.toString()},
          );
    }
    if (!mounted) return;
    _deepLinkTo(destination.location, extra);
    LaunchTrail.add('navigated(prefilled) -> ${destination.location}');
  }

  /// Re-checks the held tap: replays it when it can route, drops it when the
  /// session changed since it was held, otherwise keeps holding it.
  void _releaseHeldTap() {
    if (!mounted || !_heldTap.isHeld) return;
    final tap = _heldTap.takeIfRoutable(_gate());
    if (tap != null) _handleNotificationNavigation(tap.id, tap.type);
  }

  @override
  Widget build(BuildContext context) {
    // The held-tap release (ticket 59). The startup snapshot changes when
    // startup resolves and, after ticket 56, on every in-session sign-in,
    // sign-out and onboarding save; a consent decision moves the guard
    // without writing the snapshot. Each re-check replays a tap whose reason
    // cleared in the same session and drops one held across a session change.
    ref.listen(appStartupProvider, (_, __) => _releaseHeldTap());
    ref.listen(analyticsConsentProvider, (_, __) => _releaseHeldTap());

    // Initialize auth listener ONCE at app startup
    // This is a singleton that lives for the lifetime of the app
    // It listens for auth state changes, invalidates user-specific providers,
    // and notifies GoRouter to re-evaluate redirects (triggering navigation to /welcome)
    ref.read(authListenerServiceProvider).initialize();

    // Watch the theme mode from Kyle's theme provider
    final themeModeAsync = ref.watch(kyleThemeModeProvider);
    // Get router from provider
    final goRouter = AppRouter.router(ref);
    // Get Wiredash config
    final config = ref.watch(appConfigProvider);

    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro size from UI/UX docs
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return themeModeAsync.when(
          data: (themeMode) {
            return Wiredash(
              projectId: config.wiredashProjectId,
              secret: config.wiredashSecret,
              // Customize Wiredash theme to match app
              theme: WiredashThemeData(
                brightness: themeMode == ThemeMode.dark
                    ? Brightness.dark
                    : Brightness.light,
                primaryColor: AppTheme.lightTheme.primaryColor,
                // Customize drawing pen colors for annotations
                firstPenColor: Colors.red,
                secondPenColor: Colors.blue,
                thirdPenColor: Colors.green,
                fourthPenColor: Colors.yellow,
              ),
              feedbackOptions: WiredashFeedbackOptions(
                email: EmailPrompt.optional,
                screenshot: ScreenshotPrompt.optional,
                labels: [
                  Label(id: 'label-lhkcef66w1', title: 'Bug Report'),
                  Label(id: 'label-wt5prvrxpl', title: 'Feature Request'),
                  Label(id: 'label-xs0i7er9vl', title: 'Praise'),
                  Label(id: 'label-u1rpq6potz', title: 'Nutrition Feedback'),
                  Label(id: 'label-ovo60gyfw6', title: 'UI/UX Feedback'),
                  Label(id: 'label-1anu74e8gf', title: 'High Priority'),
                ],
                collectMetaData: (metaData) async {
                  final supabaseUser = ref
                      .read(appExternalDepsProvider)
                      .supabaseClient
                      .auth
                      .currentUser;
                  // Prefer the real profile email over an Apple private-relay
                  // address; only fall back to relay when it's all we have.
                  final profile = await ref.read(currentUserProvider.future);
                  metaData
                    ..userEmail = resolveSupportEmail([
                      profile?.email,
                      supabaseUser?.email,
                    ])
                    ..userId = supabaseUser?.id
                    ..custom['auth_provider'] =
                        supabaseUser?.appMetadata['provider'] ?? 'unknown';
                  final name = resolveSupportName(
                    firstName: profile?.firstName,
                    lastName: profile?.lastName,
                    senderName: profile?.senderName,
                  );
                  if (name != null) metaData.custom['name'] = name;
                  return metaData;
                },
              ),
              child: MaterialApp.router(
                title: 'Mealvana Endurance',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode, // Use dynamic theme mode from provider
                routerConfig: goRouter,
                // Wrap router child with AppStartupWidget
                // This is the key to supporting deep links during app initialization
                builder: (context, child) {
                  return _appShell(
                    context,
                    AppStartupWidget(
                      // Pass router child back when initialization is complete
                      onLoaded: (_) => child!,
                    ),
                    isDev: config.isDevelopment,
                  );
                },
              ),
            );
          },
          loading: () {
            // Show loading screen with dark theme (default)
            // Wiredash wraps even loading state to ensure consistent behavior
            return Wiredash(
              projectId: config.wiredashProjectId,
              secret: config.wiredashSecret,
              theme: WiredashThemeData(
                brightness: Brightness.dark,
                primaryColor: AppTheme.darkTheme.primaryColor,
              ),
              child: MaterialApp.router(
                title: 'Mealvana Endurance',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.dark,
                routerConfig: goRouter,
                builder: (context, child) {
                  return _appShell(
                    context,
                    AppStartupWidget(onLoaded: (_) => child!),
                    isDev: config.isDevelopment,
                  );
                },
              ),
            );
          },
          error: (error, stack) {
            // Fallback to dark theme on error
            return Wiredash(
              projectId: config.wiredashProjectId,
              secret: config.wiredashSecret,
              theme: WiredashThemeData(
                brightness: Brightness.dark,
                primaryColor: AppTheme.darkTheme.primaryColor,
              ),
              child: MaterialApp.router(
                title: 'Mealvana Endurance',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: ThemeMode.dark,
                routerConfig: goRouter,
                builder: (context, child) {
                  return _appShell(
                    context,
                    AppStartupWidget(onLoaded: (_) => child!),
                    isDev: config.isDevelopment,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// Shared MaterialApp.builder shell.
///
/// Two responsibilities:
/// 1. Clamp `MediaQuery.textScaler` to [1.0, 1.6] so extreme system font
///    scaling can't break layouts (cut-off CTAs, truncated labels). Bumping
///    the ceiling requires verifying every screen at the new value.
/// 2. In the **dev flavor only**, mount the testing tools ([DevTestingTools]:
///    one pill at the top edge offering the wrench panel and, in debug, the
///    issue checker). That file holds the tree, the per-build-mode table and
///    where the pill sits.
///
/// The clamp wraps the *whole* tools tree so the panel chrome itself respects
/// the ceiling (otherwise the panel UI renders at the raw OS scale, e.g. 3.1×
/// at AX5). `TestingToolsWrapper` inserts its own MediaQuery between the clamp
/// and `child`, so panel slider changes override the clamped value for app
/// content — testers can drive scale freely while the panel chrome stays
/// bounded.
///
/// Show rule is `isDev` alone (runtime, from AppConfig: `.env.dev.local` sets
/// `APP_ENVIRONMENT=dev`). Deliberately *not* gated on `kDebugMode`, so the
/// installed dev build — a Shorebird/TestFlight release binary — carries the
/// tools for QA. Prod never shows them in any build mode.
Widget _appShell(BuildContext context, Widget child, {required bool isDev}) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6),
    ),
    child: !isDev ? child : DevTestingTools(child: child),
  );
}
