import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/app_startup_provider.dart';
import 'app_startup_loading_widget.dart';
import 'app_startup_error_widget.dart';

/// Widget to manage asynchronous app initialization
/// Follows Andrea Bizzotto's initialization pattern
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize appStartupProvider (and all dependencies)
    final appStartupState = ref.watch(appStartupProvider);
    
    return appStartupState.when(
      // Loading state
      loading: () => const AppStartupLoadingWidget(),
      
      // Error state with retry capability
      error: (e, st) => AppStartupErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(appStartupProvider),
      ),
      
      // Success - navigate to appropriate screen
      data: (appStartupData) => _handleNavigation(context, appStartupData),
    );
  }

  /// Handle navigation after startup and return loading widget
  Widget _handleNavigation(BuildContext context, AppStartupData appStartupData) {
    print('🔍 Determining initial screen after app startup:');
    print('  User exists: ${appStartupData.user != null}');
    print('  User ID: ${appStartupData.user?.id ?? "none"}');
    print('  Onboarding complete: ${appStartupData.hasCompletedOnboarding}');
    
    // Navigate to appropriate screen using postFrameCallback to avoid build context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appStartupData.user == null) {
        print('  → Navigating to WelcomeScreen (no user)');
        context.go('/welcome');
      } else if (!appStartupData.hasCompletedOnboarding) {
        print('  → Navigating to FoodPreferencesScreen (incomplete onboarding)');
        context.go('/onboarding/food-preferences');
      } else {
        print('  → Navigating to PlanScreen (user complete)');
        context.go('/plan');
      }
    });
    
    // Return a loading placeholder while navigation occurs
    return const AppStartupLoadingWidget();
  }
}