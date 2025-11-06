import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/feature_survey_data.dart';
import '../../application/feature_survey_service.dart';

part 'feature_survey_controller.g.dart';

/// Controller for the feature survey screen
/// Manages user's feature selections and submission flow
@riverpod
class FeatureSurveyController extends _$FeatureSurveyController {
  FeatureSurveyService get _service => ref.read(featureSurveyServiceProvider);

  @override
  FutureOr<FeatureSurveyState> build() async {
    // Check if user has already voted
    final hasVoted = await _service.hasVoted();
    final previousVotes = hasVoted ? await _service.getPreviousVotes() : null;

    return FeatureSurveyState(
      availableFeatures: FeatureDefinitions.allFeatures,
      selectedFeatures: [],
      hasVoted: hasVoted,
      previousVotes: previousVotes,
      isSubmitting: false,
    );
  }

  /// Toggle feature selection
  /// Prevents selecting more than 3 features
  void toggleFeature(Feature feature) {
    final currentState = state.value;
    if (currentState == null || currentState.hasVoted) return;

    final selected = currentState.selectedFeatures;
    final isCurrentlySelected = selected.any((f) => f.id == feature.id);

    List<Feature> newSelected;
    if (isCurrentlySelected) {
      // Remove the feature
      newSelected = selected.where((f) => f.id != feature.id).toList();
    } else {
      // Add the feature only if less than 3 are selected
      if (selected.length < 3) {
        newSelected = [...selected, feature];
      } else {
        // Already have 3 selected, don't add
        return;
      }
    }

    state = AsyncValue.data(
      currentState.copyWith(selectedFeatures: newSelected),
    );
  }

  /// Submit survey
  /// Returns true if submission was successful
  Future<bool> submitSurvey() async {
    final currentState = state.value;
    if (currentState == null || !currentState.canSubmit) {
      return false;
    }

    // Set submitting state
    state = AsyncValue.data(currentState.copyWith(isSubmitting: true));

    final success = await AsyncValue.guard(() async {
      await _service.submitSurvey(currentState.selectedFeatures);
      return true;
    });

    if (success.hasValue && success.value == true) {
      // Refresh to show "already voted" state
      ref.invalidateSelf();
      return true;
    } else if (success.hasError) {
      // Reset submitting state on error
      state = AsyncValue.data(currentState.copyWith(isSubmitting: false));
      return false;
    }

    return false;
  }

  /// Get error message if submission failed
  String? get errorMessage {
    final currentState = state;
    if (currentState is AsyncError) {
      return currentState.error.toString();
    }
    return null;
  }
}
