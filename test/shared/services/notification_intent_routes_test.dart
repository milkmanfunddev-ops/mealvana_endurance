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

  test('plan_workout lands on the CREATE-PLAN flow, not activity detail', () {
    // Ruled 2026-09-30: the nudge only fires when no plan exists, so the
    // landing must be the interface that makes one.
    final d = destinationForIntent('plan_workout', id);
    expect(d.location, '/distancepacegut');
    expect(d.extra, {'activityId': id});
  });

  group('hydratePlanWorkoutExtra', () {
    test('a run carries distance; the sport tab is selected', () {
      final e = hydratePlanWorkoutExtra(
        activityId: id,
        activityTypeName: 'running',
        scheduledDateTime: DateTime(2026, 10, 2, 7, 0),
        title: 'Long run',
        durationMinutes: 135,
        distanceMiles: 13.1,
      );
      expect(e['activityType'], 'running');
      expect(e['initialDate'], DateTime(2026, 10, 2, 7, 0));
      expect(e['initialTitle'], 'Long run');
      expect(e['initialDurationMinutes'], 135);
      expect(e['distance'], 13.1);
    });

    test('a RIDE carries distance but never pace', () {
      // Cycling DOES read initialDistance (new_activity_screen.dart:383), so a
      // ride pre-fills its distance like any other sport. It also reinterprets
      // initialPace as 60/pace to get mph, so pace stays out — passing it would
      // quietly turn a ride's pace into a speed.
      final e = hydratePlanWorkoutExtra(
        activityId: id,
        activityTypeName: 'cycling',
        scheduledDateTime: DateTime(2026, 10, 2, 7, 0),
        title: 'Long ride',
        durationMinutes: 150,
        distanceMiles: 40,
      );
      expect(e['activityType'], 'cycling');
      expect(e['initialDurationMinutes'], 150);
      expect(e['distance'], 40);
      expect(e.containsKey('goalPace'), isFalse);
      expect(e.containsKey('initialPace'), isFalse);
    });

    test('pace is never passed for any sport', () {
      for (final sport in ['running', 'cycling', 'swimming', 'brick']) {
        final e = hydratePlanWorkoutExtra(
          activityId: id,
          activityTypeName: sport,
          scheduledDateTime: DateTime(2026, 10, 2, 7, 0),
          title: 't',
          durationMinutes: 120,
          distanceMiles: 10,
        );
        expect(e.containsKey('goalPace'), isFalse, reason: sport);
        expect(e.containsKey('initialPace'), isFalse, reason: sport);
      }
    });

    test('an unknown sport picks no tab rather than the wrong one', () {
      final e = hydratePlanWorkoutExtra(
        activityId: id,
        activityTypeName: 'triathlon',
        scheduledDateTime: DateTime(2026, 10, 2, 7, 0),
        title: 'Race',
      );
      expect(e.containsKey('activityType'), isFalse);
      expect(e['activityId'], id);
    });

    test('missing duration and distance are omitted, not zeroed', () {
      final e = hydratePlanWorkoutExtra(
        activityId: id,
        activityTypeName: 'running',
        scheduledDateTime: DateTime(2026, 10, 2, 7, 0),
        title: 'Run',
        durationMinutes: 0,
        distanceMiles: 0,
      );
      expect(e.containsKey('initialDurationMinutes'), isFalse);
      expect(e.containsKey('distance'), isFalse);
    });
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
