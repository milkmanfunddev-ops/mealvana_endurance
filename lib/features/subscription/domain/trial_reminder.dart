/// The day-five reminder (mp-456): one local notification, set on the phone
/// when a purchase starts the free week, that fires at 10:00 local time two
/// days before the trial ends. Pure Dart: the slot, the tap payload and the
/// date maths.
library;

class TrialReminder {
  TrialReminder._();

  /// The notification slot. Distinct from the activity reminders (1, 2) and
  /// the meal-plan check-in and debrief (4101, 4102), so scheduling one never
  /// overwrites another, and a second trial purchase replaces rather than
  /// stacks.
  static const notificationId = 4201;

  /// The payload type the tap handler routes on: a tap opens the store's
  /// subscription page, not a screen in the app.
  static const payloadType = 'trial_ending';

  /// The full tap payload, in the `<type>:<id>` shape
  /// `NotificationService.parseTypedNotificationPayload` reads.
  static const payload = '$payloadType:subscription';

  /// The local hour it fires.
  static const hour = 10;

  /// How many days before the trial ends it fires.
  static const daysBeforeEnd = 2;

  /// 10:00 local on the calendar day two days before [trialEndsAt] (read in
  /// local time), or null when that moment is not after [now]: a reminder
  /// already due would fire at once, which says nothing the store sheet did
  /// not just say.
  static DateTime? fireTimeFor(DateTime trialEndsAt, {required DateTime now}) {
    final end = trialEndsAt.toLocal();
    final when = DateTime(end.year, end.month, end.day - daysBeforeEnd, hour);
    return when.isAfter(now) ? when : null;
  }
}
