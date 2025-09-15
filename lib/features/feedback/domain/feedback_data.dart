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
    this.dayOfWeek,
    required this.hour,
    required this.minute,
    required this.isRecurring,
    this.customDate,
  });

  final int? dayOfWeek; // 1=Monday, 4=Thursday, 6=Saturday - nullable for custom dates
  final int hour;
  final int minute;
  final bool isRecurring;
  final DateTime? customDate; // For specific date selection

  /// Factory constructor for default Thursday at 5 PM
  factory NotificationPreference.defaultThursday({required bool isRecurring}) {
    return NotificationPreference(
      dayOfWeek: 4, // Thursday
      hour: 17, // 5 PM
      minute: 0,
      isRecurring: isRecurring,
    );
  }

  /// Factory constructor for custom date/time
  factory NotificationPreference.custom({
    required DateTime dateTime,
    required bool isRecurring,
  }) {
    return NotificationPreference(
      dayOfWeek: isRecurring ? dateTime.weekday : null,
      hour: dateTime.hour,
      minute: dateTime.minute,
      isRecurring: isRecurring,
      customDate: isRecurring ? null : dateTime,
    );
  }

  DateTime getNextReminderDate() {
    final now = DateTime.now();
    
    // If it's a one-time reminder with custom date, use that date
    if (!isRecurring && customDate != null) {
      return customDate!;
    }
    
    // For recurring reminders or dayOfWeek-based reminders
    final targetDayOfWeek = dayOfWeek ?? DateTime.thursday;
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    
    // Find next occurrence of the specified day
    while (scheduledDate.weekday != targetDayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }

  /// Get a human-readable description of this reminder
  String getDescription() {
    if (!isRecurring && customDate != null) {
      final date = customDate!;
      final weekday = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday];
      final hour12 = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      return '$weekday, ${date.month}/${date.day} at $hour12:$minute $amPm (one-time)';
    }
    
    final targetDay = dayOfWeek ?? 4;
    final weekday = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][targetDay];
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    final frequency = isRecurring ? 'recurring' : 'one-time';
    
    return '$weekday at $hour12:$minuteStr $amPm ($frequency)';
  }

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'hour': hour,
    'minute': minute,
    'isRecurring': isRecurring,
    'customDate': customDate?.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreference &&
          runtimeType == other.runtimeType &&
          dayOfWeek == other.dayOfWeek &&
          hour == other.hour &&
          minute == other.minute &&
          isRecurring == other.isRecurring &&
          customDate == other.customDate;

  @override
  int get hashCode =>
      dayOfWeek.hashCode ^
      hour.hashCode ^
      minute.hashCode ^
      isRecurring.hashCode ^
      customDate.hashCode;
}

/// Reminder type for survey UI state
enum ReminderType {
  defaultTime('Default time (Thursday at 5:00 PM)'),
  custom('Custom date and time');

  const ReminderType(this.label);
  final String label;
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