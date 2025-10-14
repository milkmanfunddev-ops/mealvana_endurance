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

  /// Handle navigation after startup and return minimal placeholder
  Widget _handleNavigation(BuildContext context, AppStartupData appStartupData) {

    // Navigate to appropriate screen using postFrameCallback to avoid build context issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appStartupData.user == null) {
        context.go('/welcome');
      } else if (!appStartupData.hasCompletedOnboarding) {
        context.go('/onboarding/food-preferences');
      } else if (appStartupData.planIdNeedingFeedback != null) {
        // User has a plan that needs feedback - navigate to the rating screen
        context.go('/plan-how-well/${appStartupData.planIdNeedingFeedback}');
      } else {
        context.go('/main');
      }
    });

    // Return minimal placeholder to prevent flash - just white screen
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(),
    );
  }
}