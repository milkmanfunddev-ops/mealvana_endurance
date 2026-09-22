/// overflow-menu spec (PROPOSED v1, paywall ticket 15 — mp-493 §4, mp-494):
///   OM-1  one ⋯ button, a glass circle, named for a screen reader
///   OM-2  a tap opens the menu with exactly the caller's entries, in order,
///         on the glass-sheet recipe over the scrim
///   OM-3  an entry closes the menu, then runs; the scrim closes it and runs
///         nothing
///   OM-4  a destructive entry wears dragonfruit
///   OM-5  Reduce Motion: the menu appears without animating
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/overflow_menu_button.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

const _button = ValueKey('more');
const _restore = ValueKey('restore');
const _delete = ValueKey('delete');

Future<void> _pump(
  WidgetTester tester, {
  required List<OverflowMenuEntry> entries,
  bool reduceMotion = false,
}) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: OverflowMenuButton(
              key: _button,
              semanticLabel: 'More options',
              color: AppColors.cream,
              entries: entries,
            ),
          ),
        ),
      ),
    ),
  );
}

List<OverflowMenuEntry> _entries(List<String> ran) => [
  OverflowMenuEntry(
    key: _restore,
    label: 'Restore purchases',
    onSelected: () => ran.add('restore'),
  ),
  OverflowMenuEntry(
    key: const ValueKey('sign_out'),
    label: 'Sign out',
    onSelected: () => ran.add('sign_out'),
  ),
  OverflowMenuEntry(
    key: _delete,
    label: 'Delete account',
    destructive: true,
    onSelected: () => ran.add('delete'),
  ),
];

void main() {
  testWidgets('OM-1 a named glass circle; the menu is closed', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, entries: _entries([]));

    expect(
      find.descendant(
        of: find.byKey(_button),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byKey(_button)),
      isSemantics(label: 'More options', isButton: true),
    );
    expect(find.byKey(OverflowMenuButton.menuKey), findsNothing);
    handle.dispose();
  });

  testWidgets('OM-2 a tap opens exactly the entries, in order, over the '
      'scrim', (tester) async {
    await _pump(tester, entries: _entries([]));
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(find.byKey(OverflowMenuButton.menuKey), findsOneWidget);
    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(OverflowMenuButton.menuKey),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .toList();
    expect(labels, ['Restore purchases', 'Sign out', 'Delete account']);

    // Anchored under the button, inside the screen.
    final menu = tester.getRect(find.byKey(OverflowMenuButton.menuKey));
    final button = tester.getRect(find.byKey(_button));
    expect(menu.top, greaterThanOrEqualTo(button.bottom));
    expect(menu.right, lessThanOrEqualTo(393));
    expect(menu.left, greaterThanOrEqualTo(0));

    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color, isNotNull);
  });

  testWidgets('OM-3 an entry closes the menu, then runs', (tester) async {
    final ran = <String>[];
    await _pump(tester, entries: _entries(ran));
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_restore));
    await tester.pumpAndSettle();
    expect(ran, ['restore']);
    expect(find.byKey(OverflowMenuButton.menuKey), findsNothing);
  });

  testWidgets('OM-3 a tap on the scrim closes it and runs nothing', (
    tester,
  ) async {
    final ran = <String>[];
    await _pump(tester, entries: _entries(ran));
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(20, 800));
    await tester.pumpAndSettle();
    expect(ran, isEmpty);
    expect(find.byKey(OverflowMenuButton.menuKey), findsNothing);
  });

  testWidgets('OM-4 the destructive entry wears dragonfruit', (tester) async {
    await _pump(tester, entries: _entries([]));
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    Color? colour(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;
    expect(colour('Delete account'), AppColors.dragonfruit);
    expect(colour('Restore purchases'), isNot(AppColors.dragonfruit));
  });

  testWidgets('OM-5 Reduce Motion: shown at once', (tester) async {
    await _pump(tester, entries: _entries([]), reduceMotion: true);
    await tester.tap(find.byKey(_button));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(OverflowMenuButton.menuKey), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
