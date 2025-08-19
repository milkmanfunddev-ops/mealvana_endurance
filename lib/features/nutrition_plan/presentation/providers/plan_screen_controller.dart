import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

part 'plan_screen_controller.g.dart';

/// State for the plan screen
class PlanScreenState {
  final String title;
  final String feedbackSuccessMessage;
  final String feedbackFailureMessage;
  final String noPlanMessage;
  final String noPlanDescription;
  final String generatePlanButtonText;
  final String errorMessage;
  final String tryAgainButtonText;
  final String saveButtonText;
  final String savedButtonText;

  const PlanScreenState({
    required this.title,
    required this.feedbackSuccessMessage,
    required this.feedbackFailureMessage,
    required this.noPlanMessage,
    required this.noPlanDescription,
    required this.generatePlanButtonText,
    required this.errorMessage,
    required this.tryAgainButtonText,
    required this.saveButtonText,
    required this.savedButtonText,
  });
}

/// Controller for plan screen content
@riverpod
class PlanScreenController extends _$PlanScreenController {
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<PlanScreenState> build() {
    // Load content synchronously from in-memory cache
    final title = _contentService.getValue(ContentKeys.planScreenTitle, defaultValue: 'Plan');
    final feedbackSuccessMessage = _contentService.getValue(ContentKeys.planScreenFeedbackSuccess, defaultValue: '✅ Thank you for your feedback!');
    final feedbackFailureMessage = _contentService.getValue(ContentKeys.planScreenFeedbackFailure, defaultValue: '❌ Failed to submit feedback. Please try again.');
    final noPlanMessage = _contentService.getValue(ContentKeys.planScreenNoPlan, defaultValue: 'No plan generated yet');
    final noPlanDescription = _contentService.getValue(ContentKeys.planScreenNoPlanDescription, defaultValue: 'Go back and generate your nutrition plan');
    final generatePlanButtonText = _contentService.getValue(ContentKeys.planScreenGeneratePlanButton, defaultValue: 'Generate Plan');
    final errorMessage = _contentService.getValue(ContentKeys.planScreenError, defaultValue: 'Error loading plan');
    final tryAgainButtonText = _contentService.getValue(ContentKeys.planScreenTryAgainButton, defaultValue: 'Try Again');
    final saveButtonText = _contentService.getValue(ContentKeys.planScreenSaveButton, defaultValue: 'Save');
    final savedButtonText = _contentService.getValue(ContentKeys.planScreenSavedButton, defaultValue: 'Saved');

    return PlanScreenState(
      title: title,
      feedbackSuccessMessage: feedbackSuccessMessage,
      feedbackFailureMessage: feedbackFailureMessage,
      noPlanMessage: noPlanMessage,
      noPlanDescription: noPlanDescription,
      generatePlanButtonText: generatePlanButtonText,
      errorMessage: errorMessage,
      tryAgainButtonText: tryAgainButtonText,
      saveButtonText: saveButtonText,
      savedButtonText: savedButtonText,
    );
  }

  /// Refresh content from backend
  Future<void> refreshContent() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }
}