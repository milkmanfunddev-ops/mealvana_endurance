// Regression: an events row with `event_date` set but `start_time` NULL must
// still appear under "Upcoming Events". Before the fix the list resolved a
// row's date only from the linked activity or from `startTime`, never from
// the domain `event.eventDate`, so such rows were silently dropped.
//
// Override pattern copied from test/smoke_tests/events_meal_logging_smoke_test.dart:
// both async controllers replaced by subclasses whose build() returns a fixed
// list, external deps mocked, AppConfig.forTesting().

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/events_list_screen.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

const _eventName = 'Undated-start Half Marathon';

class _FixedEventsController extends EventsController {
  _FixedEventsController(this._events);
  final List<Event> _events;

  @override
  Future<List<Event>> build() async => _events;
}

class _NoActivitiesController extends ActivitiesController {
  @override
  Future<List<Activity>> build() async => const <Activity>[];
}

Event _event({DateTime? eventDate, String? startTime}) {
  final now = DateTime.now();
  return Event(
    id: 'evt-undated-start',
    userId: 'user-1',
    eventType: ActivityType.running,
    eventSubtype: 'half_marathon',
    eventName: _eventName,
    eventDate: eventDate,
    startTime: startTime,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpList(WidgetTester tester, List<Event> events) async {
  tester.view.physicalSize = standardPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        eventsControllerProvider.overrideWith(
          () => _FixedEventsController(events),
        ),
        activitiesControllerProvider.overrideWith(
          _NoActivitiesController.new,
        ),
      ],
      child: wrapForTest(const EventsListScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'event with event_date but no start_time is listed under Upcoming',
    (tester) async {
      final fourteenDaysOut = DateTime.now().add(const Duration(days: 14));
      await _pumpList(tester, [_event(eventDate: fourteenDaysOut)]);

      expect(
        find.byKey(const ValueKey('my_events.upcoming_heading')),
        findsOneWidget,
      );
      expect(find.text(_eventName), findsOneWidget);
    },
  );

  testWidgets(
    'unparseable start_time falls back to event_date instead of dropping',
    (tester) async {
      final fourteenDaysOut = DateTime.now().add(const Duration(days: 14));
      await _pumpList(
        tester,
        [_event(eventDate: fourteenDaysOut, startTime: 'not-a-timestamp')],
      );

      expect(
        find.byKey(const ValueKey('my_events.upcoming_heading')),
        findsOneWidget,
      );
      expect(find.text(_eventName), findsOneWidget);
    },
  );

  testWidgets(
    'event with no date signal at all is still skipped',
    (tester) async {
      await _pumpList(tester, [_event()]);

      expect(
        find.byKey(const ValueKey('my_events.upcoming_heading')),
        findsNothing,
      );
      expect(find.text(_eventName), findsNothing);
    },
  );
}
