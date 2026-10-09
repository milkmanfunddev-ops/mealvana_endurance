/// An event write refused because the owner already has another event with
/// the same name on the same calendar day (develop-2026-10 ticket 72).
///
/// The server enforces `events_user_date_name_unique (user_id, event_date,
/// event_name)`; a row that breaks it fails its upload with 23505 forever.
/// `EventsController` checks Drift before the write and throws this instead,
/// and the event form shows `ContentKeys.eventFormDuplicateNameDay`.
class DuplicateEventNameOnDayException implements Exception {
  const DuplicateEventNameOnDayException({
    required this.userId,
    required this.eventName,
    required this.eventDate,
    required this.existingEventId,
  });

  /// The owner of the refused write (the athlete, on a coach's form).
  final String userId;

  /// The trimmed name both events share.
  final String eventName;

  /// The derived calendar day both events fall on.
  final DateTime eventDate;

  /// The event already holding that name and day.
  final String existingEventId;

  @override
  String toString() =>
      'DuplicateEventNameOnDayException: event $existingEventId already has '
      'this name on ${eventDate.toIso8601String()}';
}
