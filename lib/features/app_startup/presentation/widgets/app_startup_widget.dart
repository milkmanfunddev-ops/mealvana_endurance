import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../application/app_startup_service.dart';
import 'app_startup_loading_widget.dart';
import 'app_startup_error_widget.dart';

/// Widget to manage asynchronous app initialization
/// Follows Andrea Bizzotto's initialization pattern
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key, required this.onLoaded});
  
  final WidgetBuilder onLoaded;

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
      
      // Success - navigate based on startup result
      data: (result) => _handleSuccessNavigation(context, result),
    );
  }

  Widget _handleSuccessNavigation(BuildContext context, AppStartupResult result) {
    // Use WidgetsBinding to ensure navigation happens after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (result.navigationState) {
        case AppStartupState.onboarding:
          context.go('/onboarding/profile');
          break;
        case AppStartupState.planScreen:
          context.go('/plan');
          break;
      }
    });
    
    // Return the loaded widget while navigation is processing
    return onLoaded(context);
  }
}