// Unsaved-changes guard on EditMealLogScreen.
//
// Regression coverage for the reported bug: "Food-log quantity reverts after
// leaving and returning to the page." Root cause was that editing a food
// component (e.g. changing its quantity) only mutates in-memory state until the
// screen-level "Save changes" button is pressed. Navigating away without
// pressing it silently discarded the edit, so it "reverted" on re-entry.
//
// The fix wraps the screen in a PopScope that intercepts back-navigation and
// prompts before discarding. These tests assert:
//   1. Editing a component's quantity then pressing back shows "Discard
//      changes?" (the edit is protected).
//   2. Pressing back with no edits leaves immediately (no nag dialog).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/edit_meal_log_screen.dart';

import '../../helpers/widget_test_harness.dart';

MealLog _componentLog() {
  final now = DateTime(2026, 7, 1, 8, 30);
  return MealLog(
    id: 'log-1',
    userId: 'user-1',
    logDate: '2026-07-01',
    slot: MealSlot.breakfast,
    name: 'Rice bowl',
    source: MealLogSource.photo,
    components: const [
      MealComponent(
        name: 'White rice',
        portion: '1 cup',
        calories: 200,
        carbG: 44,
        proteinG: 4,
        fatG: 0,
      ),
    ],
    calories: 200,
    carbsG: 44,
    proteinG: 4,
    fatG: 0,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpEditScreen(WidgetTester tester, MealLog log) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/edit', extra: {'log': log}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/edit',
        builder: (_, __) => const EditMealLogScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [mockAppExternalDeps()],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();

  // Navigate into the edit screen (so there's a route beneath it to pop to).
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('Edit Meal'), findsOneWidget);
}

void main() {
  testWidgets(
    'editing a component quantity then pressing back prompts before discarding',
    (tester) async {
      await _pumpEditScreen(tester, _componentLog());

      // Open the per-component edit dialog.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit Item'), findsOneWidget);

      // Change the quantity (this only updates in-memory state).
      final qtyField = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Quantity',
      );
      expect(qtyField, findsOneWidget);
      await tester.enterText(qtyField, '2');
      await tester.pump();

      // Save the component dialog — writes to the widget's _components, NOT the
      // database (that only happens on "Save changes").
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      // Now press the app-bar back button. The guard must intercept it.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);

      // "Keep editing" dismisses the dialog and stays on the edit screen.
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Edit Meal'), findsOneWidget);
    },
  );

  testWidgets(
    'pressing back with no edits leaves without a discard prompt',
    (tester) async {
      await _pumpEditScreen(tester, _componentLog());

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // No nag dialog, and we're back on the home route.
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'exposes a photo re-scan entry point on the edit screen',
    (tester) async {
      // A log with no photo yet offers to "Scan a photo".
      await _pumpEditScreen(tester, _componentLog());
      expect(find.text('Scan a photo'), findsOneWidget);
      expect(find.text('Re-scan photo'), findsNothing);
    },
  );
}
