import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/feedback_service.dart';
import '../../application/supabase_feedback_service.dart';
import '../../domain/feedback_data.dart';

/// Provider for Google Forms feedback service instance
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService();
});

/// Provider for Supabase feedback service instance  
final supabaseFeedbackServiceProvider = Provider<SupabaseFeedbackService>((ref) {
  return SupabaseFeedbackService();
});

/// Provider for feedback submission state (using Supabase)
final feedbackSubmissionProvider = StateNotifierProvider<FeedbackSubmissionNotifier, FeedbackSubmissionState>((ref) {
  final supabaseService = ref.read(supabaseFeedbackServiceProvider);
  return FeedbackSubmissionNotifier.withSupabase(supabaseService);
});

/// Feedback submission state
class FeedbackSubmissionState {
  const FeedbackSubmissionState({
    this.isSubmitting = false,
    this.lastSubmissionSuccess = false,
    this.errorMessage,
    this.submittedFeedback,
  });

  final bool isSubmitting;
  final bool lastSubmissionSuccess;
  final String? errorMessage;
  final List<FeedbackResponse>? submittedFeedback;

  FeedbackSubmissionState copyWith({
    bool? isSubmitting,
    bool? lastSubmissionSuccess,
    String? errorMessage,
    List<FeedbackResponse>? submittedFeedback,
  }) {
    return FeedbackSubmissionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      lastSubmissionSuccess: lastSubmissionSuccess ?? this.lastSubmissionSuccess,
      errorMessage: errorMessage,
      submittedFeedback: submittedFeedback ?? this.submittedFeedback,
    );
  }
}

/// State notifier for managing feedback submission
class FeedbackSubmissionNotifier extends StateNotifier<FeedbackSubmissionState> {
  FeedbackSubmissionNotifier.withSupabase(this._supabaseFeedbackService) : super(const FeedbackSubmissionState());

  final SupabaseFeedbackService _supabaseFeedbackService;

  /// Submit feedback through Supabase
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
    );

    try {
      final success = await _supabaseFeedbackService.submitFeedback(feedback);
      
      if (success) {
        // Add to local history
        final updatedHistory = [...?state.submittedFeedback, feedback];
        state = state.copyWith(
          isSubmitting: false,
          lastSubmissionSuccess: true,
          submittedFeedback: updatedHistory,
        );
        return true;
      } else {
        state = state.copyWith(
          isSubmitting: false,
          lastSubmissionSuccess: false,
          errorMessage: 'Failed to submit feedback. Please try again.',
        );
        return false;
      }
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        lastSubmissionSuccess: false,
        errorMessage: 'Network error. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Get feedback analytics from Supabase
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      return await _supabaseFeedbackService.getFeedbackStats();
    } catch (error) {
      return {};
    }
  }

  /// Test the database connection
  Future<bool> testConnection() async {
    state = state.copyWith(
      isSubmitting: true,
      errorMessage: null,
    );

    try {
      final success = await _supabaseFeedbackService.testConnection();
      state = state.copyWith(
        isSubmitting: false,
        lastSubmissionSuccess: success,
        errorMessage: success ? null : 'Database connection test failed',
      );
      return success;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        lastSubmissionSuccess: false,
        errorMessage: 'Failed to test database connection: $error',
      );
      return false;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Get feedback submission history
  List<FeedbackResponse> get feedbackHistory => state.submittedFeedback ?? [];

  /// Check if user has submitted feedback recently (within last 24 hours)
  bool hasRecentFeedback() {
    if (state.submittedFeedback?.isEmpty ?? true) return false;
    
    final now = DateTime.now();
    final lastFeedback = state.submittedFeedback!.last;
    final timeDifference = now.difference(lastFeedback.timestamp ?? now);
    
    return timeDifference.inHours < 24;
  }
}