import 'package:accessibility_tools/accessibility_tools.dart';
// The testing-tools panel is not exported from the package barrel, but it is
// the only half of the package that survives a release build: the issue
// checkers read `RenderObject.debugSemantics`/`debugCreator`, which Flutter
// nulls out in release. The panel only overrides MediaQuery/Theme, so it runs
// anywhere. Reaching into `src/` is safe here because accessibility_tools is
// pinned to an exact version (2.2.3) in pubspec.yaml.
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/test_environment.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/testing_tools_panel.dart';
// ignore: implementation_imports
import 'package:accessibility_tools/src/testing_tools/testing_tools_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:wiredash/wiredash.dart';
import '../../theme/kyle_design/app_theme.dart';
import '../../theme/kyle_design/theme_provider.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';
import '../core/app_router.dart';
import '../services/app_config.dart';
import '../services/app_external_deps.dart';
import '../services/auth/auth_listener_service.dart';
import '../services/notification_service.dart';
import '../../features/daily_macros/data/daily_macro_targets_repository.dart';
import '../../features/auth/application/auth_service.dart';
import '../services/support/support_identity.dart';

/// Root app widget that handles app initialization and navigation
/// Following Andrea Bizzotto's patterns for app startup with deep link support
/// Now using Kyle's design system with dual theme support
///
/// Key architectural pattern:
/// - MaterialApp.router is initialized immediately with GoRouter
/// - MaterialApp.builder wraps the router child with AppStartupWidget
/// - This allows deep links to be processed while app initializes
/// - Critical for OAuth redirects (e.g., com.milkman.mealvanaendurance://auth-callback)
class RootAppWidget extends ConsumerStatefulWidget {
  const RootAppWidget({super.key});

  @override
  ConsumerState<RootAppWidget> createState() => _RootAppWidgetState();
}

class _RootAppWidgetState extends ConsumerState<RootAppWidget> {
  @override
  void initState() {
    super.initState();

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
    });
  }

  @override
  void dispose() {
    NotificationService.setNavigationHandler(null);
    NotificationService.setDailyMacroCacheInvalidator(null);
    super.dispose();
  }

  void _handleNotificationNavigation(String activityId, String? type) {
    if (!mounted || activityId.isEmpty) return;

    final router = ref.read(AppRouter.routerProvider);

    // Both activity-upload and reminder notifications now route to the
    // activity-detail screen. ActivityDetailScreen owns the conditional
    // redirect into the fuel-log surface (only when completed + plan exists
    // + not yet logged), which avoids the "no plan" empty-state flash that
    // happened when we unconditionally pushed /fuel-log on top from here.
    router.go('/plan', extra: {'activityId': activityId});
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
/// 2. In the **dev flavor only**, mount the accessibility testing overlay —
///    the blue wrench button (text scale, bold text, color-blindness
///    simulation, locale, semantics debugger) and, in debug, the red issue
///    checker button.
///
/// Tree order matters:
///
///     MediaQuery(clamp(OS))
///       └ AccessibilityTools / _DevTestingTools
///           ├ TestingToolsWrapper(env override)
///           │   └ child  ← reads env override OR clamped fallback
///           └ Overlay(panel + buttons)  ← reads clamped MediaQuery
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
///
/// Which button appears where:
///
/// | build              | blue wrench | red checker |
/// |--------------------|-------------|-------------|
/// | dev + debug        | yes         | yes         |
/// | dev + release      | yes         | no          |
/// | prod (any mode)    | no          | no          |
///
/// The red checker is debug-only for a reason outside our control: its
/// checkers read `RenderObject.debugSemantics` and `debugCreator`, which
/// Flutter nulls out in release builds. Forcing it on in an installed dev
/// build would just render a button that always finds zero issues, so the
/// release path mounts the testing-tools panel alone.
Widget _appShell(BuildContext context, Widget child, {required bool isDev}) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.6),
    ),
    child: !isDev
        ? child
        : kDebugMode
            ? _DevAccessibilityTools(child: child)
            : _DevTestingTools(child: child),
  );
}

/// Debug-only wrapper around [AccessibilityTools] that **resets the panel's
/// state on every hot reload** by re-keying the widget.
///
/// Why: the package keeps its `TestEnvironment` (text scale, color mode,
/// locale override, etc.) in `_AccessibilityToolsState`. Plain `setState`
/// changes survive hot reload, which made the app stick at e.g. 3.1× text
/// scale or grayscale between iterations with no obvious way to reset.
///
/// `reassemble` fires on every hot reload; bumping a counter and using it
/// as the child's key forces Flutter to dispose the old `AccessibilityTools`
/// and create a fresh one — wiping any panel overrides. Cold launches are
/// also fresh because widget state starts empty.
class _DevAccessibilityTools extends StatefulWidget {
  const _DevAccessibilityTools({required this.child});

  final Widget child;

  @override
  State<_DevAccessibilityTools> createState() => _DevAccessibilityToolsState();
}

class _DevAccessibilityToolsState extends State<_DevAccessibilityTools> {
  int _resetGeneration = 0;

  @override
  void reassemble() {
    super.reassemble();
    _resetGeneration++;
  }

  @override
  Widget build(BuildContext context) {
    return AccessibilityTools(
      key: ValueKey('accessibility-tools-$_resetGeneration'),
      // Silence the per-rebuild console report (it flooded the logs and buried
      // real errors). The on-screen overlay + testing panel still work.
      logLevel: LogLevel.none,
      child: widget.child,
    );
  }
}

/// Dev-flavor testing tools for **release** builds (installed dev app).
///
/// `AccessibilityTools` short-circuits to `child` whenever `!kDebugMode`, so
/// the installed dev build gets nothing from it. This mounts the half of the
/// package that does work outside debug — `TestingToolsWrapper` + the wrench
/// panel — behind the same blue floating button, reproducing the package's own
/// overlay structure so QA sees identical chrome on device and in simulator.
///
/// The red issue-checker button is intentionally absent here; see [_appShell].
class _DevTestingTools extends StatefulWidget {
  const _DevTestingTools({required this.child});

  final Widget child;

  @override
  State<_DevTestingTools> createState() => _DevTestingToolsState();
}

class _DevTestingToolsState extends State<_DevTestingTools> {
  TestEnvironment _environment = const TestEnvironment();
  bool _panelVisible = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Inserts its own MediaQuery/Theme between the clamp and the app, so
        // panel overrides reach app content while panel chrome stays clamped.
        TestingToolsWrapper(environment: _environment, child: widget.child),
        Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => SafeArea(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _TestingToolsButton(
                      onPressed: () =>
                          setState(() => _panelVisible = !_panelVisible),
                    ),
                  ),
                ),
              ),
            ),
            OverlayEntry(
              builder: (context) {
                if (!_panelVisible) return const SizedBox();
                return TestingToolsPanel(
                  environment: _environment,
                  onClose: () => setState(() => _panelVisible = false),
                  onEnvironmentUpdate: (environment) =>
                      setState(() => _environment = environment),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Blue wrench button. Matches the package's own `AccessibilityToolsToggle`
/// (which lives in `src/` and isn't exported) so the two build modes look the
/// same.
class _TestingToolsButton extends StatelessWidget {
  const _TestingToolsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const label = 'Open testing tools';
    return SizedBox.square(
      dimension: 48,
      child: Tooltip(
        message: label,
        child: FloatingActionButton(
          onPressed: onPressed,
          shape: const CircleBorder(),
          elevation: 10,
          hoverElevation: 10,
          backgroundColor: Colors.blue,
          child: const Icon(
            Icons.build,
            size: 24,
            color: Colors.white,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}
