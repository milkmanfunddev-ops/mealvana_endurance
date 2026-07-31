import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';

/// Regression tests for Notion 395e3fdb: "Delete-workout undo snackbar persists".
///
/// Root cause: Flutter's `SnackBar.persist` defaults to `action != null`
/// (snack_bar.dart:303). A persisting bar still arms its auto-dismiss timer, but
/// the callback early-returns on `persist` and never hides it — so ANY snackbar
/// carrying an action (the "Undo" on delete) stayed up forever, silently
/// ignoring `duration`. `MealvanaSnackbar._show` now passes `persist: false`.
///
/// Contract locked in here: a MealvanaSnackbar honours its `duration` whether or
/// not it has an action, with NO manual dismissal backstop. If these ever fail,
/// do not "fix" them by reintroducing a `Timer(...) => controller.close()` — that
/// hides the defect instead of repairing it.
void main() {
  const showDuration = Duration(seconds: 3);

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

  testWidgets('a snackbar WITH an action auto-dismisses after its duration', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (context) => MealvanaSnackbar.showInfo(
        context,
        'Activity deleted',
        duration: showDuration,
        actionLabel: 'Undo',
        onAction: () {},
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Activity deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // No backstop timer here on purpose: the framework's own timeout must do it.
    await tester.pump(showDuration);
    await tester.pumpAndSettle();

    expect(
      find.text('Activity deleted'),
      findsNothing,
      reason: 'a snackbar with an action must still honour its duration',
    );
  });

  testWidgets('the Undo action still fires when tapped', (tester) async {
    var undone = false;
    await pumpHost(
      tester,
      (context) => MealvanaSnackbar.showInfo(
        context,
        'Activity deleted',
        duration: showDuration,
        actionLabel: 'Undo',
        onAction: () => undone = true,
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
    expect(find.text('Activity deleted'), findsNothing);
  });

  testWidgets('a snackbar WITHOUT an action auto-dismisses', (tester) async {
    await pumpHost(
      tester,
      (context) => MealvanaSnackbar.showInfo(
        context,
        'Plain message',
        duration: showDuration,
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Plain message'), findsOneWidget);

    await tester.pump(showDuration);
    await tester.pumpAndSettle();
    expect(find.text('Plain message'), findsNothing);
  });

  testWidgets('persist: true opts a bar out of auto-dismissal', (tester) async {
    await pumpHost(
      tester,
      (context) => MealvanaSnackbar.showInfo(
        context,
        'Sticky message',
        duration: showDuration,
        actionLabel: 'Undo',
        onAction: () {},
        persist: true,
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.pump(showDuration);
    await tester.pumpAndSettle();

    expect(
      find.text('Sticky message'),
      findsOneWidget,
      reason: 'persist: true must keep the bar up past its duration',
    );

    // Tap through so no snackbar timer is left pending at teardown.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
  });
}
