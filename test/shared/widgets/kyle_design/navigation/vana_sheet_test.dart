/// vana-sheet spec (PROPOSED), the gestures of ticket 08:
///   Q-VS1  three heights — `auto`, 75 % at rest, 100 % expanded; the page
///          stays visible at rest
///   VS-7   the grabber drags between them; down past the shortest dismisses
///   VS-2   scrim, grabber, system back (and the dismiss button) close it
///   VS-9   every dismissal condenses into the launcher, none slides away
///   and the composer lets go of focus when the sheet collapses or closes.
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
  _Harness(this.navigator, this.rest, this.focus);
  final NavigatorState navigator;
  final ValueNotifier<VanaSheetHeight> rest;
  final FocusNode focus;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  VanaSheetHeight rest = VanaSheetHeight.threeQuarters,
  double topInset = 0,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);

  final navigatorKey = GlobalKey<NavigatorState>();
  final restHeight = ValueNotifier(rest);
  final focus = FocusNode();
  final text = TextEditingController();
  addTearDown(restHeight.dispose);
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
        builder: (context) => ValueListenableBuilder(
          valueListenable: restHeight,
          builder: (context, value, _) => VanaSheet(
            rest: value,
            closeLabel: 'Close',
            fullScreenLabel: 'Full screen',
            onClose: () => Navigator.of(context).pop(),
            onFullScreen: () {},
            body: ListView(
              shrinkWrap: true,
              children: const [
                SizedBox(height: 60, child: Text('Run fuelling is set.')),
              ],
            ),
            composer: TextField(
              key: _composer,
              controller: text,
              focusNode: focus,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(navigator, restHeight, focus);
}

/// The glass as drawn: a drag moves it inside the sheet's own box.
Rect _sheet(WidgetTester tester) =>
    tester.getRect(find.byType(GlassSheetSurface));

double get _threeQuarters => _screen.height * VanaSheet.restHeightFraction;

/// Drag the grabber by [dy] and let the sheet settle where it lands.
Future<void> _dragGrabber(WidgetTester tester, double dy) async {
  await tester.drag(find.byKey(_grabber), Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  group('Q-VS1: three heights', () {
    testWidgets('75 % at rest, with the page visible above it', (tester) async {
      await _pump(tester);
      final sheet = _sheet(tester);
      expect(sheet.height, closeTo(_threeQuarters, 0.5));
      expect(sheet.bottom, closeTo(_screen.height, 0.5));
      expect(sheet.top, greaterThan(0));
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('auto is as tall as what it holds', (tester) async {
      await _pump(tester, rest: VanaSheetHeight.auto);
      final sheet = _sheet(tester);
      expect(sheet.height, lessThan(_threeQuarters / 2));
      expect(sheet.bottom, closeTo(_screen.height, 0.5));
      // The chrome, the one message and the composer, nothing more.
      expect(
        tester.getRect(find.byKey(_composer)).bottom,
        lessThanOrEqualTo(sheet.bottom),
      );
      expect(
        tester.getRect(find.text('Run fuelling is set.')).top,
        greaterThan(sheet.top),
      );
    });

    testWidgets('100 % stops under the status bar', (tester) async {
      await _pump(tester, topInset: 47);
      await _dragGrabber(tester, -120);
      expect(_sheet(tester).top, closeTo(47, 0.5));
    });

    testWidgets('an auto sheet grows to 75 % when it stops being one message', (
      tester,
    ) async {
      final h = await _pump(tester, rest: VanaSheetHeight.auto);
      h.rest.value = VanaSheetHeight.threeQuarters;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = _sheet(tester).height;
      await tester.pumpAndSettle();
      expect(_sheet(tester).height, closeTo(_threeQuarters, 0.5));
      // It grows rather than jumping.
      expect(mid, lessThan(_threeQuarters));
    });
  });

  group('VS-7: the grabber drags between the heights', () {
    testWidgets('up from 75 % expands to 100 %; down comes back to 75 %', (
      tester,
    ) async {
      await _pump(tester);
      await _dragGrabber(tester, -120);
      expect(_sheet(tester).top, closeTo(0, 0.5));
      expect(_sheet(tester).height, closeTo(_screen.height, 0.5));

      await _dragGrabber(tester, 140);
      expect(_sheet(tester).height, closeTo(_threeQuarters, 0.5));
      expect(find.byType(VanaSheet), findsOneWidget);
    });

    testWidgets('up from auto expands to 100 %; down comes back to auto', (
      tester,
    ) async {
      await _pump(tester, rest: VanaSheetHeight.auto);
      final auto = _sheet(tester);
      await _dragGrabber(tester, -120);
      expect(_sheet(tester).height, closeTo(_screen.height, 0.5));
      await _dragGrabber(tester, 140);
      expect(_sheet(tester).top, closeTo(auto.top, 0.5));
      expect(_sheet(tester).height, closeTo(auto.height, 0.5));
    });

    testWidgets('a tap on the grabber toggles 75 % and 100 %', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(_grabber));
      await tester.pumpAndSettle();
      expect(_sheet(tester).height, closeTo(_screen.height, 0.5));
      await tester.tap(find.byKey(_grabber));
      await tester.pumpAndSettle();
      expect(_sheet(tester).height, closeTo(_threeQuarters, 0.5));
    });

    testWidgets('a short drag either way springs back to where it was', (
      tester,
    ) async {
      await _pump(tester);
      final rest = _sheet(tester);
      await tester.timedDrag(
        find.byKey(_grabber),
        const Offset(0, 60),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(_sheet(tester), rest);
      await tester.timedDrag(
        find.byKey(_grabber),
        const Offset(0, -20),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(_sheet(tester), rest);
    });

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

    testWidgets('a slow pull up from auto, frame by frame, expands', (
      tester,
    ) async {
      await _pump(tester, rest: VanaSheetHeight.auto);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_grabber)),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -15));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_sheet(tester).height, closeTo(_screen.height, 0.5));
    });

    testWidgets('the composer keeps focus as auto grows to 75 %', (
      tester,
    ) async {
      final h = await _pump(tester, rest: VanaSheetHeight.auto);
      await tester.tap(find.byKey(_composer));
      await tester.pump();
      h.rest.value = VanaSheetHeight.threeQuarters;
      await tester.pumpAndSettle();
      expect(h.focus.hasFocus, isTrue);
    });

    testWidgets('a long drag down from 100 %, past 75 %, dismisses', (
      tester,
    ) async {
      await _pump(tester);
      await _dragGrabber(tester, -120);
      // 25 % of the screen to the rest line, and the dismiss distance again.
      await tester.drag(find.byKey(_grabber), const Offset(0, 420));
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsNothing);
    });

    testWidgets('a tap beside the buttons does not expand the sheet', (
      tester,
    ) async {
      await _pump(tester);
      final rest = _sheet(tester);
      final close = tester.getRect(find.byKey(_close));
      await tester.tapAt(Offset(close.left - 70, close.center.dy));
      await tester.pumpAndSettle();
      expect(_sheet(tester), rest);
    });

    testWidgets('collapsing from 100 % lets go of the composer', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _dragGrabber(tester, -120);
      await tester.tap(find.byKey(_composer));
      await tester.pump();
      expect(h.focus.hasFocus, isTrue);
      await _dragGrabber(tester, 140);
      expect(h.focus.hasFocus, isFalse);
    });
  });

  group('every dismissal condenses into the launcher (VS-2, VS-7, VS-9)', () {
    final paths = <String, Future<void> Function(WidgetTester, _Harness)>{
      'the dismiss button': (tester, _) => tester.tap(find.byKey(_close)),
      'the scrim': (tester, _) => tester.tapAt(const Offset(195, 40)),
      'system back': (tester, _) async {
        await tester.binding.handlePopRoute();
      },
      'the grabber, down past 75 %': (tester, _) =>
          tester.drag(find.byKey(_grabber), const Offset(0, 160)),
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

    testWidgets('down past an auto sheet dismisses too', (tester) async {
      await _pump(tester, rest: VanaSheetHeight.auto);
      await tester.drag(find.byKey(_grabber), const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsNothing);
    });

    testWidgets('a quick flick down dismisses from 75 %', (tester) async {
      await _pump(tester);
      await tester.fling(find.byKey(_grabber), const Offset(0, 50), 1500);
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsNothing);
    });

    testWidgets('down from 100 % collapses rather than dismissing', (
      tester,
    ) async {
      await _pump(tester);
      await _dragGrabber(tester, -120);
      await tester.drag(find.byKey(_grabber), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byType(VanaSheet), findsOneWidget);
      expect(_sheet(tester).height, closeTo(_threeQuarters, 0.5));
    });
  });
}
