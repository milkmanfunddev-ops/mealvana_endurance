// G7 L2 `entry-row-two-state` + CE-8's race-day row + F1's feasible-set
// subtitle (spec/fueling/carb-loading-entryway.md CE-1/CE-8; desk G15).
//
// The row is data-driven: plan exists → the plan door; no plan + feasible →
// Set Up with the subtitle enumerating ONLY the feasible set; no plan on
// race morning → the window-passed state, visible and inert — never hidden.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/widgets/event_action_buttons_card.dart';

Event event({
  required int daysUntilRace,
  bool hasCarbLoading = false,
}) {
  final now = DateTime.now();
  final race = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: daysUntilRace));
  return Event(
    id: 'event-1',
    userId: 'user-1',
    eventType: ActivityType.running,
    eventDate: race,
    hasCarbLoading: hasCarbLoading,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );
}

Future<void> pumpCard(WidgetTester tester, Event e) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventActionButtonsCard(
              activity: null,
              event: e,
              eventId: e.id,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('plan exists → the row is a door to the plan summary',
      (tester) async {
    await pumpCard(tester, event(daysUntilRace: 5, hasCarbLoading: true));
    expect(find.text('Carb Loading Plan'), findsOneWidget);
    expect(find.text('Set Up Carb Loading'), findsNothing);
  });

  testWidgets('no plan, 5 days out → Set Up + full feasible subtitle',
      (tester) async {
    await pumpCard(tester, event(daysUntilRace: 5));
    expect(find.text('Set Up Carb Loading'), findsOneWidget);
    expect(find.text('3-, 2-, and 1-day protocols'), findsOneWidget);
  });

  testWidgets('no plan, 2 days out → subtitle drops the infeasible 3-Day',
      (tester) async {
    await pumpCard(tester, event(daysUntilRace: 2));
    expect(find.text('2- and 1-day protocols'), findsOneWidget);
  });

  testWidgets('no plan, 1 day out → "1-day protocol"', (tester) async {
    await pumpCard(tester, event(daysUntilRace: 1));
    expect(find.text('1-day protocol'), findsOneWidget);
  });

  testWidgets(
      'race morning → window-passed row, visible and inert (CE-8)',
      (tester) async {
    await pumpCard(tester, event(daysUntilRace: 0));
    expect(find.text('Carb loading window has passed'), findsOneWidget);
    expect(find.text('Set Up Carb Loading'), findsNothing);
    // Inert: tapping navigates nowhere, opens nothing.
    await tester.tap(
      find.text('Carb loading window has passed'),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Carb loading window has passed'), findsOneWidget);
  });
}
