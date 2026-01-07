import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/feature_survey_data.dart';
import '../providers/feature_survey_controller.dart';
import '../widgets/feature_checkbox_card.dart';
import '../widgets/already_voted_view.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import 'feature_survey_success_screen.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Main feature survey screen
/// Shows either the voting UI or "already voted" view
class FeatureSurveyScreen extends ConsumerWidget {
  const FeatureSurveyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyState = ref.watch(featureSurveyControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      appBar: AppBar(
        title: Text(
          'Feature Survey',
          style: AppTextStyles.sectionTitle.copyWith(
            color: isDark ? AppColors.cream : AppColors.blackberry,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.cream : AppColors.blackberry,
        ),
      ),
      body: surveyState.when(
        data: (state) {
          if (state.hasVoted && state.previousVotes != null) {
            // Show "already voted" view
            return AlreadyVotedView(previousVotes: state.previousVotes!);
          } else {
            // Show voting UI
            return _VotingView(state: state);
          }
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.electrolyte),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.dragonfruit,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Something went wrong',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: AppColors.dragonfruit,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                KylePrimaryButton(
                  text: 'Retry',
                  onPressed: () {
                    ref.invalidate(featureSurveyControllerProvider);
                  },
                  isFullWidth: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The voting UI (before user has voted)
class _VotingView extends ConsumerWidget {
  const _VotingView({required this.state});

  final FeatureSurveyState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = ref.read(featureSurveyControllerProvider.notifier);

    return Column(
      children: [
        // Header section
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Select up to 3 features',
            style: AppTextStyles.sectionTitle.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Features list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: state.availableFeatures.length,
            itemBuilder: (context, index) {
              final feature = state.availableFeatures[index];
              final isSelected =
                  state.selectedFeatures.any((f) => f.id == feature.id);
              final isEnabled =
                  isSelected || state.selectedFeatures.length < 3;

              return FeatureCheckboxCard(
                feature: feature,
                isSelected: isSelected,
                isEnabled: isEnabled,
                onToggle: () => controller.toggleFeature(feature),
              );
            },
          ),
        ),
        // Submit button
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: KylePrimaryButton(
              text: 'Submit Survey',
              onPressed: state.canSubmit && !state.isSubmitting
                  ? () => _handleSubmit(context, ref)
                  : null,
              isLoading: state.isSubmitting,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(featureSurveyControllerProvider.notifier);
    final success = await controller.submitSurvey();

    if (success && context.mounted) {
      // Navigate to success screen
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FeatureSurveySuccessScreen(
            selectedFeatures: state.selectedFeatures,
          ),
        ),
      );
    } else if (!success && context.mounted) {
      // Show error message
      MealvanaSnackbar.showError(
        context,
        controller.errorMessage ?? 'Failed to submit survey. Please try again.',
        actionLabel: 'Retry',
        onAction: () => _handleSubmit(context, ref),
      );
    }
  }
}
