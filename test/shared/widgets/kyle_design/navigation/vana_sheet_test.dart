/// vana-sheet spec (PROPOSED v2, ticket 27 — mp-265):
///   one height — the sheet opens at one standard height and its contents
///          scroll; nothing grows with what it holds, nothing resizes on
///          send or while Vana streams; no expanded state from a drag
///   VS-7   a plain drag down dismisses: past half the sheet, or a flick,
///          the platform bottom sheet's own rule — no custom thresholds
///   VS-2   scrim, system back and the dismiss button close it
///   VS-9   every dismissal condenses into the launcher, none slides away
///   and the composer lets go of focus when the sheet closes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/materials/glass.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/vana_sheet.dart';

const _screen = Size(390, 844);
const _grabber = ValueKey('vana_sheet.grabber');
const _close = ValueKey('vana_sheet.close');
const _composer = ValueKey('composer');

class _Harness {
  _Harness(this.navigator, this.rows, this.focus);
  final NavigatorState navigator;

  /// How many 60 px rows the body holds.
  final ValueNotifier<int> rows;
  final FocusNode focus;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  int rows = 1,
  double topInset = 0,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  final rowCount = ValueNotifier(rows);
  final focus = FocusNode();
  final text = TextEditingController();
  addTearDown(rowCount.dispose);
  addTearDown(focus.dispose);
  addTearDown(text.dispose);

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Center(child: Text('page'))),
    ),
  );
  final navigator = navigatorKey.currentState!;
  unawaited(
    navigator.push(
      VanaSheetRoute<void>(
        barrierLabel: 'Close',
        builder: (context) => VanaSheet(
          closeLabel: 'Close',
          fullScreenLabel: 'Full screen',
          onClose: () => Navigator.of(context).pop(),
          onFullScreen: () {},
          body: ValueListenableBuilder(
            valueListenable: rowCount,
            builder: (context, n, _) => ListView(
              key: const ValueKey('body'),
              shrinkWrap: true,
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(height: 60, child: Text('row $i')),
              ],
            ),
          ),
          composer: TextField(
            key: _composer,
            controller: text,
            focusNode: focus,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(navigator, rowCount, focus);
}

/// The glass as drawn: a drag moves it inside the sheet's own box.
Rect _sheet(WidgetTester tester) =>
    tester.getRect(find.byType(GlassSheetSurface));

double get _height => _screen.height * VanaSheet.heightFraction;

void main() {
  group('one height (mp-265)', () {
    testWidgets('one message opens at the standard height, the page visible '
        'above it', (tester) async {
      await _pump(tester);
      final sheet = _sheet(tester);
      expect(sheet.height, closeTo(_height, 0.5));
      expect(sheet.bottom, closeTo(_screen.height, 0.5));
      expect(sheet.top, greaterThan(0));
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('the height does not follow what the sheet holds: nothing '
        'grows as the conversation does', (tester) async {
      final h = await _pump(tester);
      final before = _sheet(tester);
      h.rows.value = 4;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_sheet(tester), before);
      await tester.pumpAndSettle();
      expect(_sheet(tester), before);
    });

    testWidgets('contents taller than the sheet scroll inside it', (
      tester,
    ) async {
      await _pump(tester, rows: 40);
      expect(_sheet(tester).height, closeTo(_height, 0.5));
      final composer = tester.getRect(find.byKey(_composer));
      expect(composer.bottom, lessThanOrEqualTo(_screen.height));
      await tester.drag(find.byKey(const ValueKey('body')), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('row 0'), findsNothing);
      expect(_sheet(tester).height, closeTo(_height, 0.5));
    });

    testWidgets('a drag up does not expand it', (tester) async {
      await _pump(tester, topInset: 47);
      final rest = _sheet(tester);
      await tester.drag(find.byKey(_grabber), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_sheet(tester), rest);
    });

    testWidgets('a tap on the grabber does not expand it', (tester) async {
      await _pump(tester);
      final rest = _sheet(tester);
      await tester.tap(find.byKey(_grabber));
      await tester.pumpAndSettle();
      expect(_sheet(tester), rest);
    });

    testWidgets('the composer keeps focus as the conversation grows', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.byKey(_composer));
      await tester.pump();
      h.rows.value = 20;
      await tester.pumpAndSettle();
      expect(h.focus.hasFocus, isTrue);
    });
  });

  group('VS-7: a plain drag down dismisses', () {
    testWidgets('the sheet follows the finger down while it is held', (
      tester,
    ) async {
      await _pump(tester);
      final rest = _sheet(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_grabber)),
      );
      await gesture.moveBy(const Offset(0, 30));
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(_sheet(tester).top, greaterThan(rest.top + 40));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a slow drag short of half the sheet springs back', (
      tester,
    ) async {
      await _pump(tester);
      final rest = _sheet(tester);
      await tester.timedDrag(
        find.byKey(_grabber),
        Offset(0, _height * VanaSheet.closeProgressThreshold - 40),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsOneWidget);
      expect(_sheet(tester), rest);
    });

    testWidgets('a slow drag past half the sheet dismisses', (tester) async {
      await _pump(tester);
      await tester.timedDrag(
        find.byKey(_grabber),
        Offset(0, _height * VanaSheet.closeProgressThreshold + 40),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsNothing);
    });

    testWidgets('a quick flick down dismisses', (tester) async {
      await _pump(tester);
      await tester.fling(find.byKey(_grabber), const Offset(0, 50), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsNothing);
    });

    testWidgets('a tap beside the buttons does nothing', (tester) async {
      await _pump(tester);
      final rest = _sheet(tester);
      final close = tester.getRect(find.byKey(_close));
      await tester.tapAt(Offset(close.left - 70, close.center.dy));
      await tester.pumpAndSettle();
      expect(_sheet(tester), rest);
    });
  });

  group('every dismissal condenses into the launcher (VS-2, VS-7, VS-9)', () {
    final paths = <String, Future<void> Function(WidgetTester, _Harness)>{
      'the dismiss button': (tester, _) => tester.tap(find.byKey(_close)),
      'the scrim': (tester, _) => tester.tapAt(const Offset(195, 40)),
      'system back': (tester, _) async {
        await tester.binding.handlePopRoute();
      },
      'the grabber, dragged down': (tester, _) =>
          tester.drag(find.byKey(_grabber), Offset(0, _height * 0.6)),
    };

    for (final MapEntry(key: name, value: dismiss) in paths.entries) {
      testWidgets(name, (tester) async {
        final h = await _pump(tester);
        await tester.tap(find.byKey(_composer));
        await tester.pump();
        expect(h.focus.hasFocus, isTrue);
        final open = _sheet(tester);

        await dismiss(tester, h);
        await tester.pump();
        await tester.pump(
          Duration(
            milliseconds: VanaSheet.condenseDuration.inMilliseconds ~/ 2,
          ),
        );
        final mid = _sheet(tester);
        final launcher = VanaLauncher.centerOn(_screen);
        // A slide keeps its width; a condense does not.
        expect(mid.width, lessThan(open.width * 0.8));
        expect(mid.bottom, lessThanOrEqualTo(_screen.height));
        expect(
          (mid.center - launcher).distance,
          lessThan((open.center - launcher).distance),
        );
        // The keyboard does not outlive the sheet.
        expect(h.focus.hasFocus, isFalse);

        await tester.pumpAndSettle();
        expect(find.byType(VanaSheet), findsNothing);
        expect(find.text('page'), findsOneWidget);
      });
    }
  });
}
