import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application service for managing user feedback
/// Simple service for MVP - will expand with database storage later
class FeedbackService {
  FeedbackService(this.ref);
  final Ref ref;

  /// Submit feedback about a nutrition plan
  Future<void> submitPlanFeedback({
    required String planId,
    required PlanFeedbackType feedbackType,
    String? additionalComments,
  }) async {
    // For MVP, we'll just log the feedback
    // In production, this would save to database/analytics
    final feedback = PlanFeedback(
      planId: planId,
      feedbackType: feedbackType,
      comments: additionalComments,
      submittedAt: DateTime.now(),
    );

    // TODO: Save to database or send to analytics
    // For now, just log it
    print('Plan Feedback Submitted: ${feedback.toJson()}');
  }

  /// Submit general app feedback
  Future<void> submitAppFeedback({
    required AppFeedbackType feedbackType,
    String? suggestions,
    String? reason,
  }) async {
    // For MVP, we'll just log the feedback
    final feedback = AppFeedback(
      feedbackType: feedbackType,
      suggestions: suggestions,
      reason: reason,
      submittedAt: DateTime.now(),
    );

    // TODO: Save to database or send to analytics
    print('App Feedback Submitted: ${feedback.toJson()}');
  }

  /// Get feedback summary (for future analytics)
  Map<String, dynamic> getFeedbackSummary() {
    // Placeholder for future implementation
    return {
      'totalFeedback': 0,
      'planFeedbackCount': 0,
      'appFeedbackCount': 0,
    };
  }
}

/// Data classes for feedback
class PlanFeedback {
  final String planId;
  final PlanFeedbackType feedbackType;
  final String? comments;
  final DateTime submittedAt;

  PlanFeedback({
    required this.planId,
    required this.feedbackType,
    this.comments,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'feedbackType': feedbackType.toString().split('.').last,
      'comments': comments,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }
}

class AppFeedback {
  final AppFeedbackType feedbackType;
  final String? suggestions;
  final String? reason;
  final DateTime submittedAt;

  AppFeedback({
    required this.feedbackType,
    this.suggestions,
    this.reason,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'feedbackType': feedbackType.toString().split('.').last,
      'suggestions': suggestions,
      'reason': reason,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }
}

/// Enum for plan feedback types
enum PlanFeedbackType {
  prettyClose,    // "Pretty close to what I think I should use"
  muchMore,       // "Much more than what I think I should use"
  muchLess,       // "Much less than what I think I should use"
}

/// Enum for app feedback types
enum AppFeedbackType {
  likeIt,         // "I like it! Remind me to use it"
  hasPotential,   // "It has potential but I need it to..."
  notInterested,  // "Not interested"
}

/// Provider for FeedbackService
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  return FeedbackService(ref);
});