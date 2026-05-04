import 'package:accessibility_tools/accessibility_tools.dart';
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
      final userId = ref.read(appExternalDepsProvider).supabaseClient
          .auth.currentUser?.id;
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

    // Activity-upload notifications (Garmin, etc.) route to the fuel log screen
    // so the user can rate the workout and log what they actually ate vs
    // what they planned. Seed the stack with /plan first, then push /fuel-log
    // on top — that way the close/back buttons pop back to the activity
    // detail screen instead of crashing with "nothing to pop".
    if (type == 'activity') {
      router.go('/plan', extra: {'activityId': activityId});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        router.push(
          '/fuel-log',
          extra: {'activityId': activityId, 'isNewActivity': false},
        );
      });
      return;
    }

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
                collectMetaData: (metaData) => metaData
                  ..userEmail = ref
                      .read(appExternalDepsProvider)
                      .supabaseClient
                      .auth
                      .currentUser
                      ?.email
                  ..userId = ref
                      .read(appExternalDepsProvider)
                      .supabaseClient
                      .auth
                      .currentUser
                      ?.id
                  ..custom['auth_provider'] =
                      ref
                          .read(appExternalDepsProvider)
                          .supabaseClient
                          .auth
                          .currentUser
                          ?.appMetadata['provider'] ??
                      'unknown',
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
/// 2. In **debug builds only**, wrap the tree in `_DevAccessibilityTools`
///    which provides the wrench testing-tools panel + checker overlay —
///    available in dev flavor, stripped from release/prod by `kDebugMode`.
///
/// Ordering matters: `AccessibilityTools` injects an overridden MediaQuery
/// (text scale, locale, etc.) for descendants. The clamp must read
/// MediaQuery from a context underneath it, hence the inner `Builder`.
Widget _appShell(BuildContext context, Widget child) {
  Widget clampScaler(BuildContext innerContext) {
    final mq = MediaQuery.of(innerContext);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
        ),
      ),
      child: child,
    );
  }

  if (kDebugMode) {
    return _DevAccessibilityTools(child: Builder(builder: clampScaler));
  }
  return Builder(builder: clampScaler);
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
      child: widget.child,
    );
  }
}
