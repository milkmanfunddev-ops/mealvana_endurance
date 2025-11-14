import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/kyle_design/app_theme.dart';
import '../../theme/kyle_design/theme_provider.dart';
import '../core/app_router.dart';

/// Root app widget that handles app initialization and navigation
/// Following Andrea Bizzotto's patterns for app startup
/// Now using Kyle's design system with dual theme support
class RootAppWidget extends ConsumerWidget {
  const RootAppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the theme mode from Kyle's theme provider
    final themeModeAsync = ref.watch(kyleThemeModeProvider);
    
    return ScreenUtilInit(
      designSize: const Size(393, 852), // iPhone 14 Pro size from UI/UX docs
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return themeModeAsync.when(
          data: (themeMode) {
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode, // Use dynamic theme mode from provider
              routerConfig: AppRouter.router,
            );
          },
          loading: () {
            // Show loading screen with dark theme (default)
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              routerConfig: AppRouter.router,
            );
          },
          error: (error, stack) {
            // Fallback to dark theme on error
            return MaterialApp.router(
              title: 'Mealvana Endurance',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.dark,
              routerConfig: AppRouter.router,
            );
          },
        );
      },
    );
  }
}

