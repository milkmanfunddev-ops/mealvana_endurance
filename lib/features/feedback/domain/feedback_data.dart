/// Data model for user feedback with emoji slider
class FeedbackData {
  const FeedbackData({
    required this.sessionId,
    required this.satisfactionLevel,
    this.comment,
    this.timestamp,
    this.planId,
  });

  final String sessionId;
  final SatisfactionLevel satisfactionLevel;
  final String? comment;
  final DateTime? timestamp;
  final String? planId; // Associated nutrition plan

  @override
  String toString() => 'FeedbackData(sessionId: $sessionId, level: $satisfactionLevel)';
}

/// Three-level satisfaction rating for emoji slider
enum SatisfactionLevel {
  tooMuch(value: 1, emoji: '😞', label: 'Much more than what I think I should use'),
  justRight(value: 2, emoji: '🤗', label: 'Pretty close to what I think I should use'),
  tooLittle(value: 3, emoji: '😊', label: 'Much less than what I think I should use');

  const SatisfactionLevel({
    required this.value,
    required this.emoji,
    required this.label,
  });

  final int value;
  final String emoji;
  final String label;

  static SatisfactionLevel fromValue(int value) {
    return SatisfactionLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => SatisfactionLevel.justRight,
    );
  }
}

/// App feedback options for radio buttons
enum AppFeedbackOption {
  likeIt('I like it! Remind me to use it'),
  hasPotential('It has potential but I need it to...'),
  notInterested('Not interested');

  const AppFeedbackOption(this.label);
  final String label;
}

/// Feedback response for Google Forms submission
class FeedbackResponse {
  const FeedbackResponse({
    required this.satisfactionLevel,
    this.appFeedback,
    this.suggestions,
    this.planName,
    this.userName,
    this.timestamp,
  });

  final SatisfactionLevel satisfactionLevel;
  final AppFeedbackOption? appFeedback;
  final String? suggestions; // For "It has potential but I need it to..." field
  final String? planName;
  final String? userName;
  final DateTime? timestamp;

  /// Convert to map for Google Forms submission
  Map<String, dynamic> toFormData() {
    return {
      'satisfaction': satisfactionLevel.value,
      'satisfaction_emoji': satisfactionLevel.emoji,
      'satisfaction_label': satisfactionLevel.label,
      'app_feedback': appFeedback?.label ?? '',
      'suggestions': suggestions ?? '',
      'plan_name': planName ?? '',
      'user_name': userName ?? '',
      'timestamp': timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  @override
  String toString() => 'FeedbackResponse(level: $satisfactionLevel, appFeedback: $appFeedback, suggestions: ${suggestions?.length ?? 0} chars)';
}