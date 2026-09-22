/// slide-over-pager spec (PROPOSED v1, paywall ticket 14 — mp-493 §1, §6):
///   SOP-1  one way: once moved it never returns
///   SOP-2  the second page slides in from the trailing edge over the first
///   SOP-3  Reduce Motion (or animate: false) jumps, no slide
///   SOP-4  only the visible page takes input; the first leaves the tree
///          once covered, and its state is disposed
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/slide_over_pager.dart';

const _first = ValueKey('first');
const _second = ValueKey('second');

class _Disposes extends StatefulWidget {
  const _Disposes({required this.onDispose, required this.child});
  final VoidCallback onDispose;
  final Widget child;
  @override
  State<_Disposes> createState() => _DisposesState();
}

class _DisposesState extends State<_Disposes> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  late int firstTaps;
  late int secondTaps;
  late int firstDisposed;

  Widget app({
    required bool showSecond,
    bool animate = true,
    bool reduceMotion = false,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: SlideOverPager(
          showSecond: showSecond,
          animate: animate,
          first: _Disposes(
            onDispose: () => firstDisposed++,
            child: GestureDetector(
              key: _first,
              behavior: HitTestBehavior.opaque,
              onTap: () => firstTaps++,
              child: const Center(child: Text('first')),
            ),
          ),
          second: GestureDetector(
            key: _second,
            behavior: HitTestBehavior.opaque,
            onTap: () => secondTaps++,
            child: const Center(child: Text('second')),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    firstTaps = 0;
    secondTaps = 0;
    firstDisposed = 0;
  });

  testWidgets('shows the first page, not the second, until told', (
    tester,
  ) async {
    await tester.pumpWidget(app(showSecond: false));
    expect(find.byKey(_first), findsOneWidget);
    expect(find.byKey(_second), findsNothing);
    await tester.tap(find.byKey(_first));
    expect(firstTaps, 1);
  });

  testWidgets('SOP-2 the second page slides in from the trailing edge', (
    tester,
  ) async {
    await tester.pumpWidget(app(showSecond: false));
    await tester.pumpWidget(app(showSecond: true));
    await tester.pump(const Duration(milliseconds: 100));

    final width = tester.getSize(find.byType(SlideOverPager)).width;
    final secondLeft = tester.getTopLeft(find.byKey(_second)).dx;
    final firstLeft = tester.getTopLeft(find.byKey(_first)).dx;
    expect(secondLeft, greaterThan(0));
    expect(secondLeft, lessThan(width));
    // Parallax: the first page drifts back, less far than the second moves.
    expect(firstLeft, lessThan(0));
    expect(-firstLeft, lessThan(width - secondLeft));

    // SOP-4: nothing takes a tap mid-move.
    await tester.tapAt(const Offset(10, 400));
    expect(firstTaps + secondTaps, 0);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(_second)).dx, 0);
    expect(find.byKey(_first), findsNothing);
    expect(firstDisposed, 1);
    await tester.tap(find.byKey(_second));
    expect(secondTaps, 1);
  });

  testWidgets('SOP-1 never goes back', (tester) async {
    await tester.pumpWidget(app(showSecond: false));
    await tester.pumpWidget(app(showSecond: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(showSecond: false));
    await tester.pumpAndSettle();
    expect(find.byKey(_second), findsOneWidget);
    expect(find.byKey(_first), findsNothing);
  });

  testWidgets('SOP-3 Reduce Motion jumps', (tester) async {
    await tester.pumpWidget(app(showSecond: false, reduceMotion: true));
    await tester.pumpWidget(app(showSecond: true, reduceMotion: true));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_second)).dx, 0);
    expect(find.byKey(_first), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('SOP-3 animate: false jumps', (tester) async {
    await tester.pumpWidget(app(showSecond: false, animate: false));
    await tester.pumpWidget(app(showSecond: true, animate: false));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(_second)).dx, 0);
    expect(find.byKey(_first), findsNothing);
  });

  testWidgets('starting on the second page never builds the first', (
    tester,
  ) async {
    await tester.pumpWidget(app(showSecond: true));
    expect(find.byKey(_second), findsOneWidget);
    expect(find.byKey(_first), findsNothing);
    expect(firstDisposed, 0);
  });
}
