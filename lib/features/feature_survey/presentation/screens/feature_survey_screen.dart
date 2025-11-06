import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/feature_survey_data.dart';
import '../providers/feature_survey_controller.dart';
import '../widgets/feature_checkbox_card.dart';
import '../widgets/already_voted_view.dart';
import '../../../../shared/widgets/primary_button.dart';
import 'feature_survey_success_screen.dart';

/// Main feature survey screen
/// Shows either the voting UI or "already voted" view
class FeatureSurveyScreen extends ConsumerWidget {
  const FeatureSurveyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyState = ref.watch(featureSurveyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Survey'),
        centerTitle: true,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(featureSurveyControllerProvider);
                  },
                  child: const Text('Retry'),
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
    final controller = ref.read(featureSurveyControllerProvider.notifier);

    return Column(
      children: [
        // Header section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Select up to 3 features',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Features list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: PrimaryButton(
              text: 'Submit',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ??
                'Failed to submit survey. Please try again.',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _handleSubmit(context, ref),
          ),
        ),
      );
    }
  }
}
