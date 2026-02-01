import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import 'providers/connect_training_controller.dart';

/// Shared sync helpers for integration screens.
///
/// These functions handle the UI feedback (snackbars) during sync operations
/// and are used by both the onboarding and settings integration screens.

/// Syncs Final Surge workouts and shows appropriate feedback.
Future<void> syncFinalSurge(BuildContext context, WidgetRef ref) async {
  debugPrint('🔄 Starting Final Surge sync...');

  // Show immediate "syncing" feedback - capture controller to dismiss later
  final snackbarController = MealvanaSnackbar.showLoading(
    context,
    'Syncing Final Surge workouts...',
  );

  int count = 0;
  try {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    count = await controller.importFinalSurgeWorkouts();
    debugPrint('✅ Final Surge sync complete: $count workouts imported');
  } finally {
    // Always dismiss the loading snackbar, even if sync throws
    try {
      snackbarController.close();
      debugPrint('✅ Loading snackbar dismissed');
    } catch (e) {
      debugPrint('⚠️ Could not dismiss loading snackbar: $e');
    }
  }

  // Show result if context is still valid
  if (context.mounted) {
    final state = ref.read(connectTrainingControllerProvider).value;

    if (count > 0) {
      MealvanaSnackbar.showSuccess(
        context,
        'Imported $count new workouts!',
        duration: const Duration(seconds: 4),
      );
    } else if (state?.errorMessage != null) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state!.errorMessage}',
        duration: const Duration(seconds: 4),
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        'All workouts already synced',
        duration: const Duration(seconds: 4),
      );
    }
  } else {
    debugPrint('⚠️ Context unmounted after Final Surge sync - cannot show result snackbar');
  }
}

/// Syncs TrainingPeaks workouts and shows appropriate feedback.
Future<void> syncTrainingPeaks(BuildContext context, WidgetRef ref) async {
  debugPrint('🔄 Starting TrainingPeaks sync...');

  // Show immediate "syncing" feedback - capture controller to dismiss later
  final snackbarController = MealvanaSnackbar.showLoading(
    context,
    'Syncing TrainingPeaks workouts...',
  );

  int count = 0;
  try {
    // Run sync (this updates state which shows progress in UI)
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    count = await controller.importTrainingPeaksWorkouts();
    debugPrint('✅ TrainingPeaks sync complete: $count workouts imported');
  } finally {
    // Always dismiss the loading snackbar, even if sync throws
    try {
      snackbarController.close();
      debugPrint('✅ Loading snackbar dismissed');
    } catch (e) {
      debugPrint('⚠️ Could not dismiss loading snackbar: $e');
    }
  }

  debugPrint('🔍 Checking context.mounted: ${context.mounted}');

  // Show result if context is still valid
  if (context.mounted) {
    final state = ref.read(connectTrainingControllerProvider).value;
    final eventInfo = state?.hasNextEvent == true && state?.nextEventName != null
        ? '\nNext event: ${state!.nextEventName}'
        : '';

    debugPrint('📊 State after sync - errorMessage: ${state?.errorMessage}, count: $count');

    if (count > 0) {
      MealvanaSnackbar.showSuccess(
        context,
        'Imported $count new workouts!$eventInfo',
        duration: const Duration(seconds: 4),
      );
    } else if (state?.errorMessage != null) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state!.errorMessage}',
        duration: const Duration(seconds: 4),
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        'All workouts already synced$eventInfo',
        duration: const Duration(seconds: 4),
      );
    }
  } else {
    debugPrint('⚠️ Context unmounted after TrainingPeaks sync - cannot show result snackbar');
  }
}
