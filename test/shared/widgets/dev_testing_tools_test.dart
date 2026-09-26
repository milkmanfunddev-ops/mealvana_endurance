// The dev testing tools' one control (ticket 141; findings 12-002, 100-001,
// 118-001). The package's two 48pt buttons sat bottom-right and covered Ask
// Vana, then the right end of every full-width bottom button (Welcome's
// Build My Plan, the paywall's Continue) and a sheet row's ⋮ menu. One small
// pill now hugs the top edge, inside the status bar strip plus a few points,
// and a tap offers both tools (debug) or opens the wrench panel (release).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/dev_testing_tools.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_launcher.dart';

const _padding = EdgeInsets.only(top: 59, bottom: 34);

/// A phone screen with the controls the findings named: a full-width
/// bottom button where Welcome's Build My Plan and the paywall's Continue
/// sit, a trailing ⋮ in a row near the bottom, and Ask Vana in its slot.
Widget _host({
  required bool withIssueChecker,
  required VoidCallback onAsk,
  required VoidCallback onBottomButton,
  required VoidCallback onRowMenu,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(393, 852),
        padding: _padding,
        viewPadding: _padding,
      ),
      child: DevTestingTools(
        withIssueChecker: withIssueChecker,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () {}),
            title: const Text('Timeline'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {},
              ),
            ],
          ),
          body: Stack(
            children: [
              // A row's trailing ⋮ where 100-001 found it (368,696).
              Positioned(
                right: 10,
                top: 690 - 59 - 56,
                child: IconButton(
                  key: const ValueKey('row_menu'),
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'List options',
                  onPressed: onRowMenu,
                ),
              ),
              // Build My Plan (30,729 342×57) / Continue (16,772 370×56).
              Positioned(
                left: 16,
                right: 16,
                bottom: 34 + 30,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    key: const ValueKey('bottom_button'),
                    onPressed: onBottomButton,
                    child: const Text('Continue'),
                  ),
                ),
              ),
              Positioned(
                right: VanaLauncher.rightInset,
                bottom: VanaLauncher.bottomInset - 34,
                child: VanaLauncher(semanticLabel: 'Ask Vana', onTap: onAsk),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final _pill = find.byKey(DevTestingTools.pillKey);

void main() {
  for (final withIssueChecker in [false, true]) {
    final mode = withIssueChecker ? 'debug' : 'release';

    testWidgets('$mode: one pill at the top edge, inside the status bar '
        'strip plus a few points, clear of every control', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var asked = 0, pressed = 0, menus = 0;
      await tester.pumpWidget(
        _host(
          withIssueChecker: withIssueChecker,
          onAsk: () => asked++,
          onBottomButton: () => pressed++,
          onRowMenu: () => menus++,
        ),
      );
      await tester.pump();

      expect(_pill, findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      final pill = tester.getRect(_pill);
      expect(pill.top, greaterThanOrEqualTo(0));
      expect(pill.bottom, lessThanOrEqualTo(_padding.top + 12));
      expect(pill.center.dx, closeTo(393 / 2, 1));
      expect(pill.height, lessThanOrEqualTo(20));
      // Clear of the bar's back button, title glyphs and action.
      expect(pill.overlaps(tester.getRect(find.byType(BackButton))), isFalse);
      expect(
        pill.overlaps(tester.getRect(find.byTooltip('Settings'))),
        isFalse,
      );
      expect(pill.overlaps(tester.getRect(find.text('Timeline'))), isFalse);

      // The findings' failing taps: the right end of the bottom button,
      // the row's ⋮, Ask Vana's centre.
      await tester.tapAt(const Offset(360, 757));
      await tester.tapAt(const Offset(370, 772));
      await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('row_menu'))));
      await tester.tapAt(tester.getCenter(find.byType(VanaLauncher)));
      await tester.pump();
      expect(pressed, 2);
      expect(menus, 1);
      expect(asked, 1);
      expect(find.text('Text direction'), findsNothing);
    });
  }

  testWidgets('debug: a tap offers both tools as named buttons; Testing tools '
      'opens the wrench panel', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        withIssueChecker: true,
        onAsk: () {},
        onBottomButton: () {},
        onRowMenu: () {},
      ),
    );
    await tester.pump();

    await tester.tap(_pill);
    await tester.pump();
    final tools = find.byKey(DevTestingTools.toolsMenuKey);
    final issues = find.byKey(DevTestingTools.issuesMenuKey);
    expect(tools, findsOneWidget);
    expect(issues, findsOneWidget);
    expect(tester.getSize(tools).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(tools),
      isSemantics(label: 'Open testing tools', isButton: true),
    );
    final issuesNode = tester.getSemantics(issues);
    expect(issuesNode, isSemantics(isButton: true));
    expect(issuesNode.label, contains('accessibility issue'));

    await tester.tap(tools);
    await tester.pumpAndSettle();
    expect(find.text('Text direction'), findsOneWidget);
    expect(tools, findsNothing, reason: 'the menu closes with the choice');
    handle.dispose();
  });

  testWidgets('release: a tap opens the wrench panel straight away', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        withIssueChecker: false,
        onAsk: () {},
        onBottomButton: () {},
        onRowMenu: () {},
      ),
    );
    await tester.pump();

    await tester.tap(_pill);
    await tester.pumpAndSettle();
    expect(find.text('Text direction'), findsOneWidget);
    expect(find.byKey(DevTestingTools.toolsMenuKey), findsNothing);
  });

  testWidgets('the app under the tools keeps its real safe-area padding', (
    tester,
  ) async {
    EdgeInsets? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: _padding,
            viewPadding: _padding,
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
    expect(seen, _padding);
  });
}
