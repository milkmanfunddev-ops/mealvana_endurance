import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiredash/wiredash.dart';
import '../../theme/kyle_design/app_theme.dart';
import '../../theme/kyle_design/theme_provider.dart';
import '../../features/app_startup/application/app_startup_provider.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';
import '../core/app_router.dart';
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

class RootAppWidget extends ConsumerStatefulWidget {
  const RootAppWidget({super.key});

  @override
  ConsumerState<RootAppWidget> createState() => _RootAppWidgetState();
}

class _RootAppWidgetState extends ConsumerState<RootAppWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  /// A tap that arrived before the router could honour it.
  ///
  /// Cold start only: see [_isRoutableNow]. Held rather than dropped, and
  /// replayed the moment startup resolves.
  ({String id, String? type})? _deferredTap;

  /// Can a deep link survive the root redirect right now?
  ///
  /// THE BUG THIS ANSWERS (2026-09-30). A notification tap that launches the
  /// app from killed used to navigate straight into the router while startup
  /// was still resolving. The global redirect reads `appStartupProvider`, and
  /// until that has data every protected route falls through to the startup
  /// branch and is sent to `/main` — so the athlete landed on the Timeline
  /// holding a nudge that told them to go somewhere else. It was not the two
  /// navigations racing so much as the deep link being evaluated in a window
  /// where the router could only answer "/main".
  ///
  /// Backgrounded taps never hit this: startup has long since resolved, which
  /// is exactly why the bug read as cold-start-only.
  bool _isRoutableNow() {
    final startup = ref.read(appStartupProvider);
    return startup.maybeWhen(
      data: (d) =>
          !d.forceUpgradeRequired && !d.resyncRequired && d.user != null,
      orElse: () => false,
    );
  }

  void _handleNotificationNavigation(String activityId, String? type) {
    if (!mounted || activityId.isEmpty) return;

    // Hold it. Dropping the tap is the failure; arriving late is not.
    if (!_isRoutableNow()) {
      LaunchTrail.add('HELD id=$activityId type=$type (startup not routable)');
      _deferredTap = (id: activityId, type: type);
      return;
    }
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
  /// already cleared `_isRoutableNow()` — the app is past the auth/startup
  /// gate, so '/' will not redirect out from under the push.
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

  /// Replays a held tap once the router can honour it.
  void _flushDeferredTap() {
    final tap = _deferredTap;
    if (tap == null || !_isRoutableNow()) return;
    LaunchTrail.add('REPLAY id=${tap.id} type=${tap.type}');
    _deferredTap = null;
    _handleNotificationNavigation(tap.id, tap.type);
  }

  @override
  Widget build(BuildContext context) {
    // The held-tap release. Startup resolving is the signal that the router
    // can answer with something other than /main, so a cold-start deep link
    // is replayed here rather than being lost to the root redirect.
    ref.listen(appStartupProvider, (_, __) {
      if (mounted) _flushDeferredTap();
    });

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
