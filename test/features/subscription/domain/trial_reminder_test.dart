/// The day-five reminder's date maths (mp-456 §2): 10:00 local time two days
/// before the trial ends.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/subscription/domain/trial_reminder.dart';

void main() {
  // A seven-day trial started Tuesday 22 September 2026 at 15:30 local ends
  // Tuesday 29 September at 15:30; the reminder is Sunday 27th at 10:00.
  final start = DateTime(2026, 9, 22, 15, 30);
  final end = DateTime(2026, 9, 29, 15, 30);

  test('fires at 10:00 local two days before the trial ends', () {
    expect(
      TrialReminder.fireTimeFor(end.toUtc(), now: start),
      DateTime(2026, 9, 27, 10),
    );
  });

  test('the end is read in local time, whatever zone the store sent', () {
    // RevenueCat sends the expiry in UTC; the day is the athlete's.
    final lateEvening = DateTime(2026, 9, 29, 23, 45);
    expect(
      TrialReminder.fireTimeFor(lateEvening.toUtc(), now: start),
      DateTime(2026, 9, 27, 10),
    );
  });

  test('crosses a month boundary', () {
    expect(
      TrialReminder.fireTimeFor(DateTime(2026, 10, 1, 9).toUtc(), now: start),
      DateTime(2026, 9, 29, 10),
    );
  });

  test('nothing when that moment has passed', () {
    expect(
      TrialReminder.fireTimeFor(end.toUtc(), now: DateTime(2026, 9, 27, 10)),
      isNull,
    );
  });

  test('the payload is typed so the tap handler can route it', () {
    expect(TrialReminder.payload, 'trial_ending:subscription');
  });
}
