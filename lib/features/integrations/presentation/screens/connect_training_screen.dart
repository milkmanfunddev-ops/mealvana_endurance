import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

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
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button (if not first screen)
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  onPressed: onBack,
                ),

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
        // Final Surge - Active
        IntegrationProviderCard(
          name: 'Final Surge',
          description: 'Sync your training plan and upcoming workouts',
          iconPath: 'assets/images/integrations/final_surge_logo.jpg',
          isAvailable: true,
          isConnected: data.isFinalSurgeConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'final_surge',
          athleteName: data.finalSurgeAthleteName,
          onConnect: () => _connectFinalSurge(context, ref),
          onDisconnect: () => _disconnectFinalSurge(context, ref),
        ),

        const SizedBox(height: AppSpacing.md),

        // TrainingPeaks - Active
        IntegrationProviderCard(
          name: 'TrainingPeaks',
          description: 'Import structured workouts from your coach',
          iconPath: 'assets/images/integrations/training_peaks_logo.jpg',
          isAvailable: true,
          isConnected: data.isTrainingPeaksConnected,
          isConnecting: data.isConnecting && data.connectingProvider == 'training_peaks',
          athleteName: data.trainingPeaksAthleteName,
          onConnect: () => _connectTrainingPeaks(context, ref),
          onDisconnect: () => _disconnectTrainingPeaks(context, ref),
        ),

        const SizedBox(height: AppSpacing.md),

        // Strava - Coming Soon
        IntegrationProviderCard(
          name: 'Strava',
          description: 'Sync your planned activities',
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
      // Show success and continue
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Final Surge connected! Importing workouts...'),
          backgroundColor: AppColors.success,
        ),
      );

      // Import workouts and continue
      await controller.importWorkouts();
      if (context.mounted) {
        _continue(context);
      }
    }
  }

  Future<void> _disconnectFinalSurge(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectFinalSurge();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Final Surge disconnected'),
          backgroundColor: AppColors.blackberry,
        ),
      );
    }
  }

  Future<void> _connectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    final success = await controller.connectTrainingPeaks();

    if (success && context.mounted) {
      // Show success and continue
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('TrainingPeaks connected! Importing workouts...'),
          backgroundColor: AppColors.success,
        ),
      );

      // Import workouts and continue
      await controller.importWorkouts();
      if (context.mounted) {
        _continue(context);
      }
    }
  }

  Future<void> _disconnectTrainingPeaks(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(connectTrainingControllerProvider.notifier);
    await controller.disconnectTrainingPeaks();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('TrainingPeaks disconnected'),
          backgroundColor: AppColors.blackberry,
        ),
      );
    }
  }

  void _skipConnection(BuildContext context, WidgetRef ref) {
    // Track skip
    ref.read(connectTrainingControllerProvider.notifier).trackSkip();
    _continue(context);
  }

  void _continue(BuildContext context) {
    if (onContinue != null) {
      onContinue!();
    }
  }
}
