import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:wiredash/wiredash.dart';
import '../../theme/kyle_design/app_theme.dart';
import '../../theme/kyle_design/theme_provider.dart';
import '../../features/app_startup/presentation/widgets/app_startup_widget.dart';
import '../core/app_router.dart';
import '../services/app_config.dart';
import '../services/auth/auth_listener_service.dart';
import 'responsive_content_wrapper.dart';

/// Root app widget that handles app initialization and navigation
/// Following Andrea Bizzotto's patterns for app startup with deep link support
/// Now using Kyle's design system with dual theme support
///
/// Key architectural pattern:
/// - MaterialApp.router is initialized immediately with GoRouter
/// - MaterialApp.builder wraps the router child with AppStartupWidget
/// - This allows deep links to be processed while app initializes
/// - Critical for OAuth redirects (e.g., com.milkman.mealvanaendurance://auth-callback)
class RootAppWidget extends ConsumerWidget {
  const RootAppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              feedbackOptions: const WiredashFeedbackOptions(
                email: EmailPrompt.optional,
                screenshot: ScreenshotPrompt.optional,
                labels: [
                  Label(id: 'bug', title: '🐛 Bug Report'),
                  Label(id: 'feature', title: '✨ Feature Request'),
                  Label(id: 'nutrition', title: '🥗 Nutrition Feedback'),
                  Label(id: 'ui', title: '🎨 UI/UX Feedback'),
                ],
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
                  return AppStartupWidget(
                    // Pass router child back when initialization is complete
                    // Wrapped with ResponsiveContentWrapper for web/iPad support
                    onLoaded: (_) => _RouteAwareWrapper(
                      goRouter: goRouter,
                      child: child!,
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
                  return AppStartupWidget(
                    onLoaded: (_) => _RouteAwareWrapper(
                      goRouter: goRouter,
                      child: child!,
                    ),
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
                  return AppStartupWidget(
                    onLoaded: (_) => _RouteAwareWrapper(
                      goRouter: goRouter,
                      child: child!,
                    ),
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

/// Listens to GoRouter route changes and wraps content with
/// ResponsiveContentWrapper, passing isFullWidth for coach portal routes.
///
/// Uses the full route match list to detect if /coach is anywhere in the
/// navigation stack. This ensures screens pushed from the coach portal
/// (e.g. /distancepacegut, /events/create, /plan) remain full-width.
class _RouteAwareWrapper extends StatelessWidget {
  const _RouteAwareWrapper({
    required this.goRouter,
    required this.child,
  });

  final GoRouter goRouter;
  final Widget child;

  bool _isCoachSession() {
    try {
      // Use routeInformationProvider.value directly instead of
      // routerDelegate.currentConfiguration.matches. The delegate may not
      // have processed the new route yet when ListenableBuilder fires,
      // causing isFullWidth to be false on page refresh at /coach.
      final path = goRouter.routeInformationProvider.value.uri.path;
      return path == '/coach' || path.startsWith('/coach/');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: goRouter.routeInformationProvider,
      builder: (context, _) {
        final isCoachPortal = kIsWeb && _isCoachSession();
        return ResponsiveContentWrapper(
          isFullWidth: isCoachPortal,
          child: child,
        );
      },
    );
  }
}
