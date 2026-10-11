// CarbPlanSummaryScreen empty state (1.30.0, Xuan's live bug, 2026-10-07):
// when the plan read RESOLVES to nothing — a stale "Carb Loading Plan" door
// after removal, or an event that never had a plan — the page must still
// paint its own header (title + back control) and say it is empty, instead
// of `SizedBox.shrink()`: a blank page the athlete cannot leave.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_plan_summary_screen.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

const eventId = 'event-empty';

void main() {
  Finder backButton() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Back',
  );

  Future<void> pumpAndOpen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The plan read resolves to NOTHING — the removed-plan shape.
          carbLoadingPlanProvider.overrideWith((ref, id) async => null),
          eventDetailProvider.overrideWith(
            (ref, args) async => (
              activity: null,
              event: Event(
                id: eventId,
                userId: 'u',
                eventType: ActivityType.running,
                eventDate: DateTime.now().add(const Duration(days: 5)),
                createdAt: DateTime(2026, 9, 1),
                updatedAt: DateTime(2026, 9, 1),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('test.open_summary'),
              onPressed: () => CarbPlanSummaryScreen.open(context, eventId),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('test.open_summary')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'resolved-null plan: header title, empty message and back control render',
    (tester) async {
      await pumpAndOpen(tester);

      expect(find.byType(CarbPlanSummaryScreen), findsOneWidget);
      expect(find.text('Carb Loading Plan'), findsOneWidget);
      expect(find.byKey(const ValueKey('carb_summary.empty')), findsOneWidget);
      expect(backButton(), findsOneWidget);
      // No plan rows and no plan actions on an empty page.
      expect(
        find.byKey(const ValueKey('carb_summary.remove_plan')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('carb_summary.change_protocol')),
        findsNothing,
      );
    },
  );

  testWidgets('resolved-null plan: the back control pops the page', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    expect(find.byType(CarbPlanSummaryScreen), findsOneWidget);

    await tester.tap(backButton());
    await tester.pumpAndSettle();

    expect(find.byType(CarbPlanSummaryScreen), findsNothing);
    expect(find.byKey(const ValueKey('test.open_summary')), findsOneWidget);
  });
}
