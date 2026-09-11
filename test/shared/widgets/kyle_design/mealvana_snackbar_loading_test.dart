// Loading-snackbar lifecycle guards — born from prod 2026-09-11: after a
// brick ungroup, the 'Ungrouping brick...' loading snackbar stayed on screen
// indefinitely with its spinner animating (stuck banner + a visibly warm
// phone). Release-mode ScaffoldFeatureController.close() silently no-ops
// when the snackbar isn't first in the messenger queue — the debug assert
// that would surface the mismatch is stripped — so dismissal must not depend
// on queue order, and the loading state must bury itself even if every
// dismissal path fails.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  testWidgets('showLoading self-heals: gone within 30s even if NOTHING '
      'ever dismisses it', (tester) async {
    final ctx = await pumpHost(tester);

    MealvanaSnackbar.showLoading(ctx, 'Ungrouping brick...');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ungrouping brick...'), findsOneWidget);

    // The old duration was a literal DAY — a missed dismissal meant the
    // spinner ran until the user force-killed the app.
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(find.text('Ungrouping brick...'), findsNothing);
  });

  testWidgets('clearAll empties the queue regardless of order — the '
      'dismissal path that controller.close() is not', (tester) async {
    final ctx = await pumpHost(tester);
    final messenger = ScaffoldMessenger.of(ctx);

    MealvanaSnackbar.showLoading(ctx, 'Ungrouping brick...');
    await tester.pump();
    // Something else lands in the queue mid-flight (the release-mode race:
    // close() would now target the wrong entry).
    messenger.showSnackBar(const SnackBar(content: Text('interloper')));
    await tester.pump();

    MealvanaSnackbar.clearAll(messenger);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
