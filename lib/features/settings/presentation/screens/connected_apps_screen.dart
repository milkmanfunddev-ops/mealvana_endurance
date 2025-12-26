import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../integrations/presentation/providers/connect_training_controller.dart';
import '../../../integrations/presentation/widgets/integration_provider_card.dart';

/// Connected Apps Screen - Settings screen for managing integrations
///
/// Allows users to:
/// - View connected training platforms
/// - Connect new platforms
/// - Disconnect existing platforms
/// - Manually trigger sync
class ConnectedAppsScreen extends ConsumerWidget {
  const ConnectedAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectTrainingControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      appBar: AppBar(
        backgroundColor: AppColors.blackberry,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Connected Apps',
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: state.when(
            data: (data) => _buildContent(context, ref, data),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.dragonfruit),
            ),
            error: (error, _) => _buildError(context, ref, error.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ConnectTrainingState data,
  ) {
    return ListView(
      children: [
        // Header text
        Text(
          'Connect your training platforms to automatically import workouts and generate nutrition plans.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDarkSecondary),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Final Surge
        IntegrationProviderCard(
          name: 'Final Surge',
          iconPath: 'assets/images/integrations/final_surge_logo.jpg',
          isAvailable: false,
          comingSoonText: 'Coming Soon',
          isConnected: data.isFinalSurgeConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'final_surge',
          isSyncing: data.isImporting && data.isFinalSurgeConnected,
          athleteName: data.finalSurgeAthleteName,
          onConnect: () => _connectFinalSurge(context, ref),
          onDisconnect: () => _disconnectFinalSurge(context, ref),
          onSync: () => _syncFinalSurge(context, ref),
        ),

        // Show last sync info when connected
        if (data.isFinalSurgeConnected && data.importedWorkoutsCount > 0) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              'Last sync: ${data.importedWorkoutsCount} workouts imported',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),

        // TrainingPeaks
        IntegrationProviderCard(
          name: 'TrainingPeaks',
          iconPath: 'assets/images/integrations/training_peaks_logo.jpg',
          isAvailable: true,
          isConnected: data.isTrainingPeaksConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'training_peaks',
          isSyncing: data.isImporting && data.isTrainingPeaksConnected,
          athleteName: data.trainingPeaksAthleteName,
          onConnect: () => _connectTrainingPeaks(context, ref),
          onDisconnect: () => _disconnectTrainingPeaks(context, ref),
          onSync: () => _syncTrainingPeaks(context, ref),
        ),

        // Show last sync info and event when connected
        if (data.isTrainingPeaksConnected) ...[
          if (data.importedWorkoutsCount > 0 || data.hasNextEvent) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.importedWorkoutsCount > 0)
                    Text(
                      'Last sync: ${data.importedWorkoutsCount} workouts imported',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
                    ),
                  if (data.hasNextEvent && data.nextEventName != null)
                    Text(
                      'Next event: ${data.nextEventName}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
                    ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: AppSpacing.lg),

        // Strava
        IntegrationProviderCard(
          name: 'Strava',
          iconPath: 'assets/images/integrations/strava_logo.jpg',
          isAvailable: false,
          isConnected: false,
          isConnecting: false,
          comingSoonText: 'Coming Soon',
        ),

        // Error message if any
        if (data.errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dragonfruit.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.dragonfruit, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    data.errorMessage!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.dragonfruit),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Long press hint
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Tip: Long-press "Sync Now" to disconnect',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.dragonfruit,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Something went wrong',
            style: AppTextStyles.sectionTitle.copyWith(color: AppColors.textDark),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            error,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textDarkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          KyleSecondaryButton(
            text: 'Try Again',
            onPressed: () => ref.invalidate(connectTrainingControllerProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _connectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectFinalSurge();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'Final Surge connected!');
    }
  }

  Future<void> _disconnectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectFinalSurge();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'Final Surge disconnected');
    }
  }

  Future<void> _syncFinalSurge(BuildContext context, WidgetRef ref) async {
    debugPrint('🔄 Starting Final Surge sync from Connected Apps...');

    // Show immediate "syncing" feedback
    final loadingController = MealvanaSnackbar.showLoading(
      context,
      'Syncing Final Surge workouts...',
    );

    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final count = await controller.importFinalSurgeWorkouts();

    debugPrint('✅ Final Surge sync complete: $count workouts imported');

    // Dismiss the syncing snackbar and show result
    if (context.mounted) {
      loadingController.close();

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
    }
  }

  Future<void> _syncTrainingPeaks(BuildContext context, WidgetRef ref) async {
    debugPrint('🔄 Starting TrainingPeaks sync from Connected Apps...');

    // Show immediate "syncing" feedback
    final loadingController = MealvanaSnackbar.showLoading(
      context,
      'Syncing TrainingPeaks workouts...',
    );

    // Run sync (this updates state which shows progress in UI)
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final count = await controller.importTrainingPeaksWorkouts();

    debugPrint('✅ TrainingPeaks sync complete: $count workouts imported');

    // Dismiss the syncing snackbar and show result
    if (context.mounted) {
      loadingController.close();

      final state = ref.read(connectTrainingControllerProvider).value;
      final eventInfo = state?.hasNextEvent == true && state?.nextEventName != null
          ? '\nNext event: ${state!.nextEventName}'
          : '';

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
    }
  }

  Future<void> _connectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectTrainingPeaks();

    if (success && context.mounted) {
      MealvanaSnackbar.showSuccess(context, 'TrainingPeaks connected!');
    }
  }

  Future<void> _disconnectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectTrainingPeaks();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'TrainingPeaks disconnected');
    }
  }
}
