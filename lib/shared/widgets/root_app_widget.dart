import 'dart:async';

// The testing-tools panel is not exported from the package barrel, but it is
// the only half of the package that survives a release build: the issue
// checkers read `RenderObject.debugSemantics`/`debugCreator`, which Flutter
// nulls out in release. The panel only overrides MediaQuery/Theme, so it runs
// anywhere. Reaching into `src/` is safe here because accessibility_tools is
// pinned to an exact version (2.2.3) in pubspec.yaml.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiredash/wiredash.dart';
import '../../theme/kyle_design/app_theme.dart';
import '../../theme/kyle_design/theme_provider.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';
import '../../features/settings/presentation/providers/dev_tools_switch_controller.dart';
import '../../features/meal_planning/presentation/widgets/vana_companion.dart';
import '../core/app_router.dart';
import '../services/app_config.dart';
import '../services/app_external_deps.dart';
import '../../features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import '../services/auth/auth_listener_service.dart';
import '../services/notification_service.dart';
import '../../features/daily_macros/data/daily_macro_targets_repository.dart';
import '../../features/auth/application/auth_service.dart';
import '../../features/subscription/application/pro_paywall_controller.dart';
import '../../features/subscription/domain/trial_reminder.dart';
import '../services/support/support_identity.dart';
import '../../main.dart' show sentryNavigatorKey;
import 'dev_testing_tools.dart';
import 'shake_to_report.dart';

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
String notificationRouteForCarbEvent(String eventId) => '/events/$eventId';

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
      final pendingActivityId =
          NotificationService.getPendingNavigationActivityId();
      final pendingType = NotificationService.getPendingNavigationType();
      if (pendingActivityId != null && pendingActivityId.isNotEmpty) {
        _handleNotificationNavigation(pendingActivityId, pendingType);
      }
      // G27: first-frame nudge sweep (arm/disarm + on-open catch-up).
      ref.read(carbNudgeCoordinatorProvider.notifier).run();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // G27: the on-open catch-up also runs on every foreground resume.
    if (state == AppLifecycleState.resumed) {
      ref.read(carbNudgeCoordinatorProvider.notifier).run();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.setNavigationHandler(null);
    NotificationService.setDailyMacroCacheInvalidator(null);
    super.dispose();
  }

  void _handleNotificationNavigation(String activityId, String? type) {
    if (!mounted || activityId.isEmpty) return;

    // The day-five reminder (mp-456 §3): the tap opens the store's
    // subscription page, where the athlete can cancel, not a screen here.
    if (type == TrialReminder.payloadType) {
      unawaited(_openStoreSubscriptions());
      return;
    }

    final router = ref.read(AppRouter.routerProvider);

    // G27: the carb-load nudge lands the athlete on the event's details
    // screen (the Set Up Carb Loading row lives there).
    if (type == 'carb_event') {
      router.go(notificationRouteForCarbEvent(activityId));
      return;
    }

    // Both activity-upload and reminder notifications now route to the
    // activity-detail screen. ActivityDetailScreen owns the conditional
    // redirect into the fuel-log surface (only when completed + plan exists
    // + not yet logged), which avoids the "no plan" empty-state flash that
    // happened when we unconditionally pushed /fuel-log on top from here.
    router.go('/plan', extra: {'activityId': activityId});
  }

  /// RevenueCat's management URL for this customer, else the platform
  /// store's subscriptions page (the paywall's "Manage subscription" path).
  Future<void> _openStoreSubscriptions() async {
    try {
      final uri = await ref
          .read(proPaywallControllerProvider.notifier)
          .managementUrl();
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[RootApp] store subscriptions page not opened: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Two steps, not four (Lee, 2026-09-09): message → optional
              // screenshot. Every Wiredash entry point (shake, Help → Report
              // a bug, Vana's "Send to the team") is a bug path, so the Bug
              // Report label is attached silently instead of asked for, and
              // the email step is dropped — collectMetaData already carries
              // the profile email. Product/Vana feedback goes to our own
              // `user_feedback` table (features/feedback), not here.
              feedbackOptions: WiredashFeedbackOptions(
                email: EmailPrompt.hidden,
                screenshot: ScreenshotPrompt.optional,
                labels: [
                  Label(
                    id: 'label-lhkcef66w1',
                    title: 'Bug Report',
                    hidden: true,
                  ),
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
                  // Shake-to-report sits inside Wiredash (so it can open it)
                  // and above the router (so it covers every screen).
                  return ShakeToReport(
                    navigatorKey: sentryNavigatorKey,
                    reportVisible: Wiredash.of(context).visible,
                    onShakeDetected: (event) => ref
                        .read(appExternalDepsProvider)
                        .analytics
                        .track(event),
                    onReport: (ctx) =>
                        Wiredash.of(ctx).show(inheritMaterialTheme: true),
                    child: _AppShell(
                      isDev: config.isDevelopment,
                      child: AppStartupWidget(
                        // Pass router child back when initialization is complete,
                        // under the Vana launcher, which floats over every
                        // ordinary route (vana-sheet spec).
                        onLoaded: (_) => VanaCompanionHost(
                          router: goRouter,
                          observer: vanaCompanionObserver,
                          child: child!,
                        ),
                      ),
                    ),
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
                  return _AppShell(
                    isDev: config.isDevelopment,
                    child: AppStartupWidget(onLoaded: (_) => child!),
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
                  return _AppShell(
                    isDev: config.isDevelopment,
                    child: AppStartupWidget(onLoaded: (_) => child!),
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
///    the blue wrench panel and, in debug, the red issue checker). That file
///    holds the tree, the per-build-mode table and where the button sits.
///
/// The clamp wraps the *whole* tools tree so the panel chrome itself respects
/// the ceiling (otherwise the panel UI renders at the raw OS scale, e.g. 3.1×
/// at AX5). `TestingToolsWrapper` inserts its own MediaQuery between the clamp
/// and `child`, so panel slider changes override the clamped value for app
/// content — testers can drive scale freely while the panel chrome stays
/// bounded.
///
/// Show rule is `isDev` (runtime, from AppConfig: `.env.dev.local` sets
/// `APP_ENVIRONMENT=dev`) AND the tester's Settings switch
/// ([devToolsSwitchControllerProvider], per device, default on; ticket 24,
/// mp-271). Deliberately *not* gated on `kDebugMode`, so the installed dev
/// build — a Shorebird/TestFlight release binary — carries the tools for QA.
/// Prod never shows them in any build mode and never reads the switch.
///
/// Flipping the switch swaps the wrapper around [child], which remounts the
/// subtree down to the router's Navigator. The Navigator carries
/// `sentryNavigatorKey` (a GlobalKey), so it and every route below it are
/// reparented with their state intact; the hot-reload re-key in
/// [DevTestingTools] already relies on the same behaviour.
class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child, required this.isDev});

  final Widget child;
  final bool isDev;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final toolsOn =
        isDev && (ref.watch(devToolsSwitchControllerProvider).value ?? true);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        ),
      ),
      child: !toolsOn ? child : DevTestingTools(child: child),
    );
  }
}
