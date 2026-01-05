import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/navigation/figma_onboarding_footer.dart';

import '../integration_sync_helpers.dart';
import '../providers/connect_training_controller.dart';
import '../widgets/integration_provider_card.dart';

/// Connect Training Screen - First screen in onboarding flow
///
/// Allows users to connect their training platform (Final Surge, etc.)
/// to automatically import upcoming workouts and generate nutrition plans.
///
/// Flow:
/// 1. User sees available integrations
/// 2. Taps "Connect" on Final Surge
/// 3. OAuth flow in browser
/// 4. Workouts imported
/// 5. Continue to next onboarding step
class ConnectTrainingScreen extends ConsumerWidget {
  const ConnectTrainingScreen({
    super.key,
    this.onContinue,
    this.onBack,
  });

  /// Callback to advance to next page in PageView
  final VoidCallback? onContinue;

  /// Callback to go back (null if first screen)
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectTrainingControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Column(
        children: [
          // Main content
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // Header
                    _buildHeader(context),

                    const SizedBox(height: AppSpacing.xl),

                    // Integration providers list
                    Expanded(
                      child: state.when(
                        data: (data) => _buildProvidersList(context, ref, data),
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: AppColors.dragonfruit),
                        ),
                        error: (error, _) => _buildError(context, ref, error.toString()),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Skip button
                    _buildSkipButton(context, ref),

                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),

          // Footer navigation
          _buildFooter(context, ref, state),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, AsyncValue<ConnectTrainingState> state) {
    return SafeArea(
      top: false,
      child: FigmaOnboardingFooter(
        onContinue: () => _continue(context),
        onBack: onBack,
        canContinue: true,
        isLoading: state.isLoading,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Your Training',
          style: AppTextStyles.pageTitle.copyWith(color: AppColors.textDark),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Import your upcoming workouts to get personalized nutrition plans for each session.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDarkSecondary),
        ),
      ],
    );
  }

  Widget _buildProvidersList(
    BuildContext context,
    WidgetRef ref,
    ConnectTrainingState data,
  ) {
    return ListView(
      children: [
        // Final Surge
        IntegrationProviderCard(
          name: 'Final Surge',
          iconPath: 'assets/images/integrations/final_surge_logo.jpg',
          isAvailable: true,
          isConnected: data.isFinalSurgeConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'final_surge',
          isSyncing: data.isImporting && data.isFinalSurgeConnected,
          athleteName: data.finalSurgeAthleteName,
          onConnect: () => _connectFinalSurge(context, ref),
          onDisconnect: () => _disconnectFinalSurge(context, ref),
          onSync: () => syncFinalSurge(context, ref),
        ),

        const SizedBox(height: AppSpacing.md),

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
          onSync: () => syncTrainingPeaks(context, ref),
        ),

        const SizedBox(height: AppSpacing.md),

        // Strava
        IntegrationProviderCard(
          name: 'Strava',
          iconPath: 'assets/images/integrations/strava_logo.jpg',
          isAvailable: false,
          isConnected: false,
          isConnecting: false,
          comingSoonText: 'Coming Soon',
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

  Widget _buildSkipButton(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton(
        onPressed: () => _skipConnection(context, ref),
        child: Text(
          'Skip for now',
          style: AppTextStyles.buttonTertiary.copyWith(
            color: AppColors.textDarkSecondary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Future<void> _connectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectFinalSurge();

    if (success && context.mounted) {
      // Show success message
      MealvanaSnackbar.showSuccess(
        context,
        'Final Surge connected! Importing workouts...',
      );

      // Import workouts (but don't auto-navigate)
      await controller.importWorkouts();

      if (context.mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          'Workouts imported successfully!',
        );
      }
    }
  }

  Future<void> _disconnectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectFinalSurge();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'Final Surge disconnected');
    }
  }

  Future<void> _connectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectTrainingPeaks();

    if (success && context.mounted) {
      // Show success message
      MealvanaSnackbar.showSuccess(
        context,
        'TrainingPeaks connected! Importing workouts...',
      );

      // Import workouts (but don't auto-navigate)
      await controller.importWorkouts();

      if (context.mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          'Workouts imported successfully!',
        );
      }
    }
  }

  Future<void> _disconnectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectTrainingPeaks();

    if (context.mounted) {
      MealvanaSnackbar.showInfo(context, 'TrainingPeaks disconnected');
    }
  }

  void _skipConnection(BuildContext context, WidgetRef ref) {
    // Track skip and continue
    ref.read(connectTrainingControllerProvider.notifier).trackSkip();
    _continue(context);
  }

  void _continue(BuildContext context) {
    if (onContinue != null) {
      onContinue!();
    }
  }
}
