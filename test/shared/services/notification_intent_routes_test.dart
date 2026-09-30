// Notification payloads carry an INTENT, not a screen (ruled 2026-09-30).
//
// These pin the table itself. The point of the indirection is that a local
// notification scheduled today fires days later carrying whatever payload it
// was built with — so a payload naming a screen freezes that decision on the
// device until it fires. Rerouting an intent must stay a one-line edit here.
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/shared/services/notification_intent_routes.dart';

void main() {
  const id = 'e7b1c2d3-0000-4000-8000-000000000000';

  test('carb_event lands on event details, where Set Up Carb Loading lives',
      () {
    final d = destinationForIntent('carb_event', id);
    expect(d.location, '/events/$id');
    expect(d.extra, isNull);
  });

  test('plan_workout lands on the workout screen with its activity', () {
    final d = destinationForIntent('plan_workout', id);
    expect(d.location, '/plan');
    expect(d.extra, {'activityId': id});
  });

  test('the existing typed payloads are unchanged', () {
    for (final intent in ['reminder', 'activity']) {
      final d = destinationForIntent(intent, id);
      expect(d.location, '/plan', reason: '$intent must keep working');
      expect(d.extra, {'activityId': id});
    }
  });

  test('a legacy bare-id payload (null intent) still routes', () {
    final d = destinationForIntent(null, id);
    expect(d.location, '/plan');
    expect(d.extra, {'activityId': id});
  });

  test('an unknown intent from a newer build lands somewhere sensible', () {
    // A device on an older build can receive an intent it has never heard of.
    // Dropping the tap on the floor is the one unacceptable outcome.
    final d = destinationForIntent('recover', id);
    expect(d.location, '/plan');
    expect(d.extra, {'activityId': id});
  });

  test('destinations compare by value, so the table is testable', () {
    expect(
      destinationForIntent('carb_event', id),
      destinationForIntent('carb_event', id),
    );
    expect(
      destinationForIntent('carb_event', id),
      isNot(destinationForIntent('plan_workout', id)),
    );
  });
}
