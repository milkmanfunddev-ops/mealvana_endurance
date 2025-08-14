import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/feedback_service.dart';
import '../../../nutrition_plan/application/nutrition_plan_service.dart';

/// Controller for managing feedback submission
class FeedbackController extends StateNotifier<AsyncValue<void>> {
  FeedbackController(this._feedbackService, this._nutritionPlanService) 
      : super(const AsyncData(null));

  final FeedbackService _feedbackService;
  final NutritionPlanService _nutritionPlanService;

  /// Submit feedback about a nutrition plan
  Future<bool> submitPlanFeedback({
    required PlanFeedbackType feedbackType,
    String? additionalComments,
  }) async {
    state = const AsyncLoading();

    try {
      // Get the current plan ID
      final currentPlan = _nutritionPlanService.getLatestNutritionPlan();
      if (currentPlan == null) {
        state = AsyncError('No plan found to provide feedback on', StackTrace.current);
        return false;
      }

      await _feedbackService.submitPlanFeedback(
        planId: currentPlan.id,
        feedbackType: feedbackType,
        additionalComments: additionalComments,
      );

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Submit general app feedback
  Future<bool> submitAppFeedback({
    required AppFeedbackType feedbackType,
    String? suggestions,
    String? reason,
  }) async {
    state = const AsyncLoading();

    try {
      await _feedbackService.submitAppFeedback(
        feedbackType: feedbackType,
        suggestions: suggestions,
        reason: reason,
      );

      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Get feedback summary (for future use)
  Map<String, dynamic> getFeedbackSummary() {
    return _feedbackService.getFeedbackSummary();
  }
}

/// Provider for feedback controller
final feedbackControllerProvider = 
    StateNotifierProvider<FeedbackController, AsyncValue<void>>((ref) {
  final feedbackService = ref.watch(feedbackServiceProvider);
  final nutritionPlanService = ref.watch(nutritionPlanServiceProvider);
  return FeedbackController(feedbackService, nutritionPlanService);
});