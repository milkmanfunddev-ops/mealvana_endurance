// Sentry MEALVANA-ENDURANCE-DEV-5S (ticket 24a): the iPhone 17 Pro Max
// events in this issue (402x874 logical, 26 / 35 / 36 px on the right) fired
// as the athlete tapped an event card and EventDetailScreen pushed. The
// header card's date Row held an unflexed "Wednesday, September 30, 2026"
// beside the calendar icon, so a long weekday + month ran off the card.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/event_detail_screen.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../helpers/widget_test_harness.dart';

final _at = DateTime(2026, 9, 25);

final _event = Event(
  id: 'evt-1',
  userId: 'u1',
  eventType: ActivityType.running,
  eventSubtype: 'marathon',
  eventName: 'Chicago Marathon',
  location: 'Chicago, IL',
  startTime: '2026-09-30T07:00:00.000',
  goalTimeMinutes: 210,
  createdAt: _at,
  updatedAt: _at,
);

final _activity = Activity(
  id: 'act-1',
  userId: 'u1',
  activityType: ActivityType.running,
  title: 'Chicago Marathon',
  scheduledDateTime: DateTime(2026, 9, 30, 7),
  createdAt: _at,
  updatedAt: _at,
);

Future<void> _pump(WidgetTester tester, {Activity? activity}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const EventDetailScreen(eventId: 'evt-1'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        inMemoryDatabaseOverride(),
        eventDetailProvider(
          'evt-1',
        ).overrideWith((ref) async => (activity: activity, event: _event)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('DEV-5S: the header date fits a 402-wide phone (event date)', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('event_details.event_date')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('DEV-5S: the header date fits a 402-wide phone (activity date)', (
    tester,
  ) async {
    await _pump(tester, activity: _activity);

    expect(
      find.byKey(const ValueKey('event_details.event_date')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
