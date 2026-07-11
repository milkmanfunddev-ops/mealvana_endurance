import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';

/// Regression tests for Notion 395e3fdb: "Delete-workout undo snackbar persists".
///
/// The user-visible contract: after deleting an activity, the "Activity deleted"
/// snackbar must disappear on its own within its 3s duration (plus the backstop
/// margin). It must not stick on screen forever.
///
/// These drive the exact ScaffoldMessenger call sequence that
/// `FuelTimelineScreen._deleteActivityWithUndo` performs, because the defect
/// lives in that sequence's interaction with ScaffoldMessenger — not in the
/// activities controller.
void main() {
  const showDuration = Duration(seconds: 3);
  const backstop = Duration(milliseconds: 250);

  /// Mirrors `_deleteActivityWithUndo`'s snackbar half exactly.
  void deleteWithUndo(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = MealvanaSnackbar.showInfo(
      context,
      'Activity deleted',
      duration: showDuration,
      actionLabel: 'Undo',
      onAction: () {},
    );
    Timer(showDuration + backstop, () {
      try {
        controller.close();
      } catch (_) {
        // Controller already completed/closed.
      }
    });
  }

  Future<void> pumpHost(
    WidgetTester tester,
    void Function(BuildContext) onPressed,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => onPressed(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('auto-dismisses when no snackbar was already showing', (
    tester,
  ) async {
    await pumpHost(tester, deleteWithUndo);

    await tester.tap(find.text('go'));
    await tester.pump(); // schedule
    await tester.pump(const Duration(milliseconds: 750)); // entrance animation
    expect(find.text('Activity deleted'), findsOneWidget);

    // Let the 3s duration + backstop + exit animation elapse.
    await tester.pump(showDuration + backstop);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Activity deleted'),
      findsNothing,
      reason: 'snackbar must auto-dismiss, not stick on screen',
    );
  });

  testWidgets(
    'auto-dismisses even when another snackbar is already on screen',
    (tester) async {
      // This is the real-world case: the user already has a snackbar up (e.g. a
      // prior action), then deletes an activity. clearSnackBars() reverses the
      // outgoing bar but leaves it as _snackBars.first, so the new bar is queued
      // SECOND — which is what breaks the backstop close() and the auto-dismiss
      // timer.
      await pumpHost(tester, (context) {
        MealvanaSnackbar.showInfo(
          context,
          'Some earlier message',
          duration: const Duration(seconds: 10),
        );
        deleteWithUndo(context);
      });

      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Drain the full lifetime: entrance + duration + backstop + exit.
      await tester.pump(showDuration + backstop);
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.text('Activity deleted'),
        findsNothing,
        reason:
            'snackbar must auto-dismiss even when it was queued behind another',
      );
      expect(find.text('Some earlier message'), findsNothing);
    },
  );
}
