import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../application/final_surge_sync_service.dart';
import '../application/training_peaks_sync_service.dart';
import 'providers/connect_training_controller.dart';

/// Shared sync helpers for integration screens.
///
/// These functions handle the UI feedback (snackbars) during sync operations
/// and are used by both the onboarding and settings integration screens.

/// Syncs Final Surge workouts and shows appropriate feedback.
Future<void> syncFinalSurge(BuildContext context, WidgetRef ref) async {
  debugPrint('🔄 Starting Final Surge sync...');

  final currentState = ref.read(connectTrainingControllerProvider).value;
  if (currentState?.syncingProvider == 'final_surge' ||
      currentState?.isImporting == true) {
    if (context.mounted) {
      MealvanaSnackbar.showInfo(
        context,
        'Final Surge sync is already in progress',
        duration: const Duration(seconds: 2),
      );
    }
    return;
  }

  // Capture messenger so we can dismiss even if the originating widget unmounts.
  final messenger = ScaffoldMessenger.maybeOf(context);
  MealvanaSnackbar.showLoading(context, 'Syncing Final Surge workouts...');

  SyncResult result = const SyncResult(success: true);
  try {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    result = await controller.importFinalSurgeWorkouts();
    debugPrint(
      '✅ Final Surge sync complete: ${result.newWorkouts} workouts imported',
    );
  } finally {
    messenger?.hideCurrentSnackBar();
    debugPrint('✅ Loading snackbar dismissed');
  }

  // Show result if context is still valid
  if (context.mounted) {
    final state = ref.read(connectTrainingControllerProvider).value;
    final message = buildWorkoutSyncMessage(
      newCount: result.newWorkouts,
      updatedCount: result.updated,
      deletedCount: result.deleted,
      unchangedCount: result.skipped,
    );

    if (result.success && result.hasChanges) {
      MealvanaSnackbar.showSuccess(
        context,
        message,
        duration: const Duration(seconds: 4),
      );
    } else if (!result.success || state?.errorMessage != null) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
        duration: const Duration(seconds: 4),
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        message,
        duration: const Duration(seconds: 4),
      );
    }
  } else {
    debugPrint(
      '⚠️ Context unmounted after Final Surge sync - cannot show result snackbar',
    );
  }
}

/// Syncs TrainingPeaks workouts and shows appropriate feedback.
Future<void> syncTrainingPeaks(BuildContext context, WidgetRef ref) async {
  debugPrint('🔄 Starting TrainingPeaks sync...');

  final currentState = ref.read(connectTrainingControllerProvider).value;
  if (currentState?.syncingProvider == 'training_peaks' ||
      currentState?.isImporting == true) {
    if (context.mounted) {
      MealvanaSnackbar.showInfo(
        context,
        'TrainingPeaks sync is already in progress',
        duration: const Duration(seconds: 2),
      );
    }
    return;
  }

  // Capture messenger so we can dismiss even if the originating widget unmounts.
  final messenger = ScaffoldMessenger.maybeOf(context);
  MealvanaSnackbar.showLoading(context, 'Syncing TrainingPeaks workouts...');

  TrainingPeaksSyncResult result = const TrainingPeaksSyncResult(success: true);
  try {
    // Run sync (this updates state which shows progress in UI)
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    result = await controller.importTrainingPeaksWorkouts();
    debugPrint(
      '✅ TrainingPeaks sync complete: ${result.newWorkouts} workouts imported',
    );
  } finally {
    messenger?.hideCurrentSnackBar();
    debugPrint('✅ Loading snackbar dismissed');
  }

  debugPrint('🔍 Checking context.mounted: ${context.mounted}');

  // Show result if context is still valid
  if (context.mounted) {
    final state = ref.read(connectTrainingControllerProvider).value;
    final eventInfo =
        state?.hasNextEvent == true && state?.nextEventName != null
        ? '\nNext event: ${state!.nextEventName}'
        : '';

    debugPrint(
      '📊 State after sync - errorMessage: ${state?.errorMessage}, count: ${result.newWorkouts}',
    );

    final message = buildWorkoutSyncMessage(
      newCount: result.newWorkouts,
      updatedCount: result.updated,
      deletedCount: result.deleted,
      unchangedCount: result.unchanged,
    );

    if (result.success && result.hasChanges) {
      MealvanaSnackbar.showSuccess(
        context,
        '$message$eventInfo',
        duration: const Duration(seconds: 4),
      );
    } else if (!result.success || state?.errorMessage != null) {
      MealvanaSnackbar.showError(
        context,
        'Sync failed: ${state?.errorMessage ?? result.error ?? 'Unknown error'}',
        duration: const Duration(seconds: 4),
      );
    } else {
      MealvanaSnackbar.showInfo(
        context,
        '$message$eventInfo',
        duration: const Duration(seconds: 4),
      );
    }
  } else {
    debugPrint(
      '⚠️ Context unmounted after TrainingPeaks sync - cannot show result snackbar',
    );
  }
}

String buildWorkoutSyncMessage({
  required int newCount,
  required int updatedCount,
  required int deletedCount,
  required int unchangedCount,
}) {
  final parts = <String>[];
  if (newCount > 0) {
    parts.add('Imported $newCount new ${_pluralize('workout', newCount)}');
  }
  if (updatedCount > 0) {
    parts.add('Edited $updatedCount ${_pluralize('workout', updatedCount)}');
  }
  if (deletedCount > 0) {
    parts.add('Removed $deletedCount ${_pluralize('workout', deletedCount)}');
  }

  if (parts.isEmpty) {
    if (unchangedCount > 0) {
      return 'All $unchangedCount ${_pluralize('workout', unchangedCount)} already synced';
    }
    return 'No workouts found';
  }

  if (parts.length == 1) {
    return parts.first;
  }
  if (parts.length == 2) {
    return '${parts[0]} and ${parts[1]}';
  }
  return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
}

String _pluralize(String word, int count) => count == 1 ? word : '${word}s';
