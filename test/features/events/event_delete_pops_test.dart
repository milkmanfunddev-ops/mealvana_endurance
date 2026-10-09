// Ticket 80 (round develop-2026-10, Finding 69-002): deleting an event from
// Event Details showed "Event deleted successfully" but left the deleted
// event's details on screen. The handler called `context.go('/main')`, a
// no-op under the pageless `MaterialPageRoute` most entries push. Ruled
// (Lee 2026-10-09): go back to where the delete came from, My Events when
// nothing is beneath.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  eventName: 'Tw69 2330',
  startTime: '2026-11-07T07:00:00.000',
  createdAt: _at,
  updatedAt: _at,
);

class _FakeEventsController extends EventsController {
  final deleted = <String>[];

  @override
  Future<List<Event>> build() async => const [];

  @override
  Future<void> deleteEvent(String eventId) async => deleted.add(eventId);
}

const _hostKey = ValueKey('host.open_event');

/// A host screen that opens Event Details the way My Events' card does
/// (`event_list_card.dart`: `Navigator.push(MaterialPageRoute(...))`).
class _HostScreen extends StatelessWidget {
  const _HostScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: _hostKey,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const EventDetailScreen(eventId: 'evt-1'),
          ),
        ),
        child: const Text('My Events host'),
      ),
    ),
  );
}

Future<_FakeEventsController> _pump(
  WidgetTester tester,
  GoRouter router,
) async {
  tester.view.physicalSize = standardPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(router.dispose);
  final controller = _FakeEventsController();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        inMemoryDatabaseOverride(),
        eventsControllerProvider.overrideWith(() => controller),
        eventDetailProvider(
          'evt-1',
        ).overrideWith((ref) async => (activity: null, event: _event)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return controller;
}

Future<void> _deleteFromDetails(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('event_details.more_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('event_details.menu_delete')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('event_details.delete_confirm')));
  // Let the delete resolve and the pop run; the snackbars keep their own
  // timers, so pump a bounded time instead of settling.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('a delete from details pushed over My Events returns to it, '
      'with the success snackbar', (tester) async {
    final router = GoRouter(
      initialLocation: '/main',
      routes: [GoRoute(path: '/main', builder: (_, _) => const _HostScreen())],
    );
    final controller = await _pump(tester, router);

    await tester.tap(find.byKey(_hostKey));
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);

    await _deleteFromDetails(tester);

    expect(controller.deleted, ['evt-1']);
    expect(find.byType(EventDetailScreen), findsNothing);
    expect(find.byKey(_hostKey), findsOneWidget);
    expect(find.text('Event deleted successfully'), findsOneWidget);

    // Let the snackbars' timers run out before the test ends.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('a delete from details with nothing beneath (deep link) ends '
      'on My Events', (tester) async {
    final router = GoRouter(
      initialLocation: '/events/evt-1',
      routes: [
        GoRoute(
          path: '/events',
          builder: (_, _) => const Scaffold(body: Text('My Events')),
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (_, _) => const EventDetailScreen(eventId: 'evt-1'),
        ),
      ],
    );
    final controller = await _pump(tester, router);
    expect(find.byType(EventDetailScreen), findsOneWidget);

    await _deleteFromDetails(tester);
    await tester.pumpAndSettle();

    expect(controller.deleted, ['evt-1']);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/events',
    );
    expect(find.text('My Events'), findsOneWidget);
    expect(find.byType(EventDetailScreen), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });
}
