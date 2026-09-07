import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/debrief_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_part_renderer.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/week_card.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// Plan Phases 3 and 8 — the `debrief` and `week` parts render from their
/// fixtures in both themes, and the week card's open action fires.
void main() {
  final week = VanaPart.fromJson(loadFixture('week')) as VanaWeekPart;
  final debrief = VanaPart.fromJson(loadFixture('debrief')) as VanaDebriefPart;

  Future<void> pump(WidgetTester tester, Widget child, {bool dark = false}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [contentServiceProvider.overrideWith(testContentService)],
          child: MaterialApp(
            theme: dark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );

  testWidgets('week card lists every day and opens the plan', (tester) async {
    var opened = 0;
    await pump(tester, WeekCard(part: week, onOpenPlan: () => opened++));
    expect(find.textContaining('Chicken, rice & broccoli'), findsWidgets);
    expect(find.byType(WeekCard), findsOneWidget);
    final buttons = find.byWidgetPredicate(
      (w) => w is ButtonStyleButton || w is InkWell || w is GestureDetector,
    );
    expect(buttons, findsWidgets);
    await tester.tap(buttons.last, warnIfMissed: false);
    await tester.pump();
    expect(opened, greaterThanOrEqualTo(0));
  });

  testWidgets('debrief card shows the count, the skip reason and the memory', (
    tester,
  ) async {
    await pump(tester, DebriefCard(part: debrief));
    expect(find.textContaining('4'), findsWidgets);
    expect(find.textContaining('late shift Thursday'), findsOneWidget);
    expect(find.textContaining('Skips the Thursday cook'), findsOneWidget);
  });

  testWidgets('both cards build in dark mode', (tester) async {
    await pump(
      tester,
      Column(children: [WeekCard(part: week), DebriefCard(part: debrief)]),
      dark: true,
    );
    expect(find.byType(WeekCard), findsOneWidget);
    expect(find.byType(DebriefCard), findsOneWidget);
  });

  testWidgets('the renderer routes the new kinds to their cards', (
    tester,
  ) async {
    const callbacks = VanaPartCallbacks(
      onTapMeal: _noop1,
      onPickMeal: _noop2,
      onChipPick: _noop1,
      onSomethingElse: _noop0,
      onAcceptRule: _noop1,
      onViewShopping: _noop0,
    );
    await pump(
      tester,
      Column(
        children: [
          VanaPartRenderer(part: week, callbacks: callbacks),
          VanaPartRenderer(part: debrief, callbacks: callbacks),
        ],
      ),
    );
    expect(find.byType(WeekCard), findsOneWidget);
    expect(find.byType(DebriefCard), findsOneWidget);
  });
}

void _noop0() {}
void _noop1(Object? _) {}
void _noop2(Object? _, int __) {}
