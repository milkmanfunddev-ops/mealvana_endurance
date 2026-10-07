/// My Events under the floating tab bar (testing-wave 03-007, fix ticket 52):
/// scrolled to the end of a full list, New Event comes to rest above the
/// shell's glass tab bar and can be tapped, instead of hiding behind it with
/// an orange sliver showing.
///
/// The host is the `/main` composition as [TabsScreen] mounts the Events tab:
/// [HomeShellChrome] around [EventsListScreen], with the shell's published
/// bottom clearance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/events/presentation/screens/events_list_screen.dart';
import 'package:mealvana_endurance/features/home_shell/presentation/home_shell_chrome.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/kyle_tab_bar.dart';

import '../../helpers/widget_test_harness.dart';

const _newEvent = ValueKey('my_events.new_event_button');

Event _event(String id, DateTime startTime) => Event(
  id: id,
  userId: 'u1',
  eventType: ActivityType.running,
  eventName: 'Race $id',
  startTime: startTime.toIso8601String(),
  createdAt: DateTime(2026, 8, 4),
  updatedAt: DateTime(2026, 8, 4),
);

class _SeededEvents extends EventsController {
  _SeededEvents(this._events);
  final List<Event> _events;

  @override
  Future<List<Event>> build() async => _events;
}

class _NoActivities extends ActivitiesController {
  @override
  Future<List<Activity>> build() async => const [];
}

/// The Events tab as the shell mounts it.
class _EventsTabHost extends StatelessWidget {
  const _EventsTabHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeShellChrome(
        destinations: [
          KyleTabBarDestination(
            id: 'timeline',
            icon: FontAwesomeIcons.solidHouse.data,
            label: 'Timeline',
          ),
          KyleTabBarDestination(
            id: 'food',
            icon: FontAwesomeIcons.bowlFood.data,
            label: 'Food',
          ),
          KyleTabBarDestination(
            id: 'events',
            icon: FontAwesomeIcons.trophy.data,
            label: 'Events',
          ),
          KyleTabBarDestination(
            id: 'learn',
            icon: FontAwesomeIcons.graduationCap.data,
            label: 'Learn',
          ),
        ],
        activeTabId: 'events',
        onSelectTab: (_) {},
        showDateHeader: false,
        body: const EventsListScreen(
          bottomInset: HomeShellChrome.bottomChromeClearancePx,
        ),
      ),
    );
  }
}

Future<void> _pumpAndScrollToEnd(WidgetTester tester, int count) async {
  final now = DateTime.now();
  final events = [
    _event('upcoming', now.add(const Duration(days: 30))),
    for (var i = 1; i < count; i++)
      _event('past$i', now.subtract(Duration(days: 30 * i))),
  ];
  await smokeScreen(
    tester,
    const _EventsTabHost(),
    overrides: [
      eventsControllerProvider.overrideWith(() => _SeededEvents(events)),
      activitiesControllerProvider.overrideWith(_NoActivities.new),
    ],
  );
  addTearDown(tester.view.reset);

  // Fling to the end and let the list come to rest, the way the athlete
  // (and Patrol) would before tapping.
  await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
  await tester.pumpAndSettle();
}

void main() {
  for (final count in [5, 12]) {
    testWidgets('$count events: at the end of the list New Event rests above '
        'the tab bar and can be tapped', (tester) async {
      await _pumpAndScrollToEnd(tester, count);

      expect(find.byKey(_newEvent).hitTestable(), findsOneWidget);
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        tester.getRect(find.byKey(_newEvent)).bottom,
        lessThanOrEqualTo(
          screenHeight - HomeShellChrome.bottomChromeClearancePx,
        ),
        reason: 'the expanded tab bar occupies the bottom clearance',
      );
    });
  }
}
