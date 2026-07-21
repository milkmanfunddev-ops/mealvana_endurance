import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/app_startup_provider.dart';
import 'app_startup_loading_widget.dart';
import 'app_startup_error_widget.dart';

/// Widget to manage asynchronous app initialization
/// Follows Andrea Bizzotto's initialization pattern with MaterialApp.builder
///
/// This widget wraps the router child and manages the app startup flow:
/// - Shows loading screen during initialization
/// - Shows error screen with retry if initialization fails
/// - Passes router child to onLoaded callback when ready
///
/// Deep links and URL navigation work immediately since GoRouter
/// is initialized before this widget.
class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key, required this.onLoaded});

  /// Callback that receives the router child when initialization is complete
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

      // Success - pass router child to callback
      data: (_) => onLoaded(context),
    );
  }
}
