import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/feedback_service.dart';
import '../../domain/feedback_data.dart';
import 'feedback_provider.dart';

part 'feedback_controller.g.dart';

/// Simple controller for feedback submission using our new system
/// This replaces the old feedback controller with our new feedback workflow
@riverpod
class FeedbackController extends _$FeedbackController {
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<void> build() {
    // Initialize controller - no initial async work needed
    return null;
  }

  /// Submit feedback using our new feedback response system
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final feedbackService = FeedbackService(ref);
      final success = await feedbackService.submitFeedback(feedback);
      
      if (!success) {
        final errorMsg = _contentService.getValue(ContentKeys.errorGeneric, 
            defaultValue: 'Failed to submit feedback');
        throw Exception(errorMsg);
      }
    });

    return !state.hasError;
  }

  /// Test feedback connection
  Future<bool> testConnection() async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      final feedbackService = FeedbackService(ref);
      final success = await feedbackService.testFormConnection();
      
      if (!success) {
        final errorMsg = _contentService.getValue(ContentKeys.errorGeneric, 
            defaultValue: 'Connection test failed');
        throw Exception(errorMsg);
      }
    });

    return !state.hasError;
  }
  
  /// Get content-driven error message
  String getErrorMessage(String? error) {
    return _contentService.getValue(ContentKeys.errorGeneric, 
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }
}

/// Legacy provider - redirects to our new feedback submission provider
final legacyFeedbackControllerProvider = feedbackSubmissionProvider;