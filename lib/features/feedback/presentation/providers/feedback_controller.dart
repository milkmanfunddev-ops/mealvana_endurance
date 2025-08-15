import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/feedback_service.dart';
import '../../domain/feedback_data.dart';
import 'feedback_provider.dart';

/// Simple controller for feedback submission using our new system
/// This replaces the old feedback controller with our new feedback workflow
class FeedbackController extends StateNotifier<AsyncValue<void>> {
  FeedbackController() : super(const AsyncData(null));

  /// Submit feedback using our new feedback response system
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    state = const AsyncLoading();

    try {
      final feedbackService = FeedbackService();
      final success = await feedbackService.submitFeedback(feedback);
      
      if (success) {
        state = const AsyncData(null);
        return true;
      } else {
        state = AsyncError('Failed to submit feedback', StackTrace.current);
        return false;
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Test feedback connection
  Future<bool> testConnection() async {
    state = const AsyncLoading();
    
    try {
      final feedbackService = FeedbackService();
      final success = await feedbackService.testFormConnection();
      
      state = const AsyncData(null);
      return success;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

/// Provider for simple feedback controller
final feedbackControllerProvider = 
    StateNotifierProvider<FeedbackController, AsyncValue<void>>((ref) {
  return FeedbackController();
});

/// Legacy provider - redirects to our new feedback submission provider
final legacyFeedbackControllerProvider = feedbackSubmissionProvider;