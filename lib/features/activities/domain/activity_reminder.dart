/// Activity reminder settings
/// Stores reminder preferences for a specific activity
class ActivityReminder {
  const ActivityReminder({
    required this.enabled,
    required this.daysBefore,
    required this.timeOfDay,
    required this.recurring,
  });

  final bool enabled;
  final int daysBefore; // Number of days before the activity (1-7)
  final String timeOfDay; // Format: "HH:mm" (e.g., "17:00" for 5:00 PM)
  final bool recurring;

  /// Create reminder from database fields
  factory ActivityReminder.fromDatabase({
    required bool enabled,
    int? daysBefore,
    String? timeOfDay,
    required bool recurring,
  }) {
    return ActivityReminder(
      enabled: enabled,
      daysBefore: daysBefore ?? 1, // Default: 1 day before
      timeOfDay: timeOfDay ?? '17:00', // Default: 5:00 PM
      recurring: recurring,
    );
  }

  /// Calculate the reminder DateTime based on activity scheduled date
  DateTime calculateReminderDateTime(DateTime activityDateTime) {
    // Parse time of day
    final timeParts = timeOfDay.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Calculate reminder date (N days before activity)
    final reminderDate = activityDateTime.subtract(Duration(days: daysBefore));

    // Set the time
    return DateTime(
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      hour,
      minute,
    );
  }

  /// Get human-readable description
  String getDescription() {
    final timeParts = timeOfDay.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');

    final daysText = daysBefore == 1 ? 'day' : 'days';
    final recurringText = recurring ? ' (recurring)' : '';

    return '$daysBefore $daysText before at $hour12:$minuteStr $amPm$recurringText';
  }

  ActivityReminder copyWith({
    bool? enabled,
    int? daysBefore,
    String? timeOfDay,
    bool? recurring,
  }) {
    return ActivityReminder(
      enabled: enabled ?? this.enabled,
      daysBefore: daysBefore ?? this.daysBefore,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      recurring: recurring ?? this.recurring,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityReminder &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          daysBefore == other.daysBefore &&
          timeOfDay == other.timeOfDay &&
          recurring == other.recurring;

  @override
  int get hashCode =>
      enabled.hashCode ^
      daysBefore.hashCode ^
      timeOfDay.hashCode ^
      recurring.hashCode;
}
