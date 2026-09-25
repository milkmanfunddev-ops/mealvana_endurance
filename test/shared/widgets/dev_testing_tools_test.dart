// Finding 12-002 (ticket 68): the dev "Open testing tools" button sat on
// Ask Vana, so a tap on the launcher's centre opened the tools instead.
// Both build modes' overlays must sit clear of the launcher.
import 'package:accessibility_tools/accessibility_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/dev_testing_tools.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_launcher.dart';

// The launcher on its home-shell spot: a full-screen Stack, right/bottom
// insets from the design component (vana_companion.dart).
Widget _host({required bool withIssueChecker, required VoidCallback onAsk}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          // The 393x852 phone's home-indicator inset (the shell tells the
          // system nothing else).
          data: mq.copyWith(
            padding: const EdgeInsets.only(bottom: 34),
            viewPadding: const EdgeInsets.only(bottom: 34),
          ),
          child: DevTestingTools(
            withIssueChecker: withIssueChecker,
            child: Stack(
              children: [
                Positioned(
                  right: VanaLauncher.rightInset,
                  bottom: VanaLauncher.bottomInset,
                  child: VanaLauncher(semanticLabel: 'Ask Vana', onTap: onAsk),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Finder _toolsButton() => find.byWidgetPredicate(
  (w) => w is FloatingActionButton && w.child is Icon,
  description: 'Open testing tools',
);

void main() {
  setUp(() {
    // The package renders nothing under a test binding unless told to.
    AccessibilityTools.debugRunCheckersInTests = true;
  });
  tearDown(() => AccessibilityTools.debugRunCheckersInTests = false);

  for (final withIssueChecker in [false, true]) {
    final mode = withIssueChecker ? 'debug (package overlay)' : 'release';

    testWidgets('$mode: the tools button sits clear of Ask Vana', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var asked = 0;
      await tester.pumpWidget(
        _host(withIssueChecker: withIssueChecker, onAsk: () => asked++),
      );
      await tester.pump();

      expect(_toolsButton(), findsOneWidget);
      final tools = tester.getRect(_toolsButton());
      final launcher = tester.getRect(find.byType(VanaLauncher));
      expect(
        tools.overlaps(launcher),
        isFalse,
        reason: 'tools $tools overlaps Ask Vana $launcher',
      );
      // Still in the launcher's column, just above it: no new corner taken.
      expect(tools.bottom, lessThanOrEqualTo(launcher.top));
      expect(tools.right, lessThanOrEqualTo(launcher.right + 8));

      // The finding's failing step: a tap on Ask Vana's centre.
      await tester.tapAt(launcher.center);
      await tester.pump();
      expect(asked, 1);
      expect(find.text('Text direction'), findsNothing);
    });
  }

  testWidgets('the app under the tools keeps its real safe-area padding', (
    tester,
  ) async {
    EdgeInsets? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: EdgeInsets.only(top: 59, bottom: 34),
            viewPadding: EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: DevTestingTools(
            withIssueChecker: false,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.paddingOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    expect(seen, const EdgeInsets.only(top: 59, bottom: 34));
  });
}
