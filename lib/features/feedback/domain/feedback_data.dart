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

/// Confidence level for survey (1-5 scale)
enum ConfidenceLevel {
  notAtAll(1, 'Not at all'),
  aLittle(2, 'A little'),
  somewhat(3, 'Somewhat'),
  very(4, 'Very'),
  extremely(5, 'Extremely');

  const ConfidenceLevel(this.value, this.label);
  final int value;
  final String label;

  static ConfidenceLevel fromValue(int value) {
    return ConfidenceLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => ConfidenceLevel.somewhat,
    );
  }
}

/// Reuse intent for survey
enum ReuseIntent {
  yes('yes', 'Yes'),
  maybe('maybe', 'Maybe'),
  no('no', 'No');

  const ReuseIntent(this.value, this.label);
  final String value;
  final String label;

  static ReuseIntent fromValue(String value) {
    return ReuseIntent.values.firstWhere(
      (intent) => intent.value == value,
      orElse: () => ReuseIntent.maybe,
    );
  }
}

/// Reasons why the plan missed expectations
enum MissedReason {
  tooGeneric('too_generic', 'Too generic'),
  tooMuchEffort('too_much_effort', 'Too much effort'),
  giIssues('gi_issues', 'GI issues'),
  wrongTiming('wrong_timing', 'Wrong timing'),
  foodsNotRight('foods_not_right', 'Foods not right'),
  amountsNotRight('amounts_not_right', 'Amounts are not right'),
  other('other', 'Other');

  const MissedReason(this.value, this.label);
  final String value;
  final String label;

  static MissedReason fromValue(String value) {
    return MissedReason.values.firstWhere(
      (reason) => reason.value == value,
      orElse: () => MissedReason.other,
    );
  }
}

/// Notification preference for reminders
class NotificationPreference {
  const NotificationPreference({
    required this.dayOfWeek,
    required this.hour,
    required this.minute,
    required this.isRecurring,
  });

  final int dayOfWeek; // 1=Monday, 4=Thursday, 6=Saturday
  final int hour;
  final int minute;
  final bool isRecurring;

  DateTime getNextReminderDate() {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    // Find next occurrence of the specified day
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'hour': hour,
    'minute': minute,
    'isRecurring': isRecurring,
  };
}

/// Complete survey response model
class SurveyResponse {
  const SurveyResponse({
    required this.confidenceLevel,
    required this.reuseIntent,
    this.reminderPreference,
    this.missedReason,
    this.missedOther,
    this.deviceId,
    this.planName,
    this.timestamp,
  });

  final ConfidenceLevel confidenceLevel;
  final ReuseIntent reuseIntent;
  final NotificationPreference? reminderPreference; // Only if reuseIntent = yes
  final MissedReason? missedReason; // Only if reuseIntent = maybe/no
  final String? missedOther; // Only if missedReason = other
  final String? deviceId;
  final String? planName;
  final DateTime? timestamp;

  Map<String, dynamic> toJson() => {
    'confidence_level': confidenceLevel.value,
    'confidence_label': confidenceLevel.label,
    'reuse_intent': reuseIntent.value,
    'reminder_requested': reminderPreference != null,
    'reminder_day_of_week': reminderPreference?.dayOfWeek,
    'reminder_hour': reminderPreference?.hour,
    'reminder_minute': reminderPreference?.minute,
    'reminder_recurring': reminderPreference?.isRecurring,
    'missed_reasons': missedReason != null ? [missedReason!.value] : null,
    'missed_other': missedOther,
    'device_id': deviceId,
    'plan_name': planName,
    'timestamp': timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
  };
}