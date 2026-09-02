import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_bar.dart';

import 'package:mealvana_endurance/features/content/application/content_service.dart';
import '../helpers/test_content.dart';

/// 05 §4 — the plan bar starts minimized, expands on tap, offers Review,
/// and `minimize()` collapses it again (the chat screen calls it on every
/// new turn).
void main() {
  final meals = List.generate(
    3,
    (i) => PlanMeal.fromJson({
      'id': 'pm-$i',
      'planId': 'plan-1',
      'source': 'library',
      'name': 'Meal $i',
      'mealType': 'dinner',
      'servings': 4,
      'servingsLeft': 4,
      'position': i,
    }),
  );

  Future<void> pumpBar(WidgetTester tester, GlobalKey<PlanBarState> key) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            // Like the chat screen: the bar sits in a bounded-width column
            // above the composer.
            body: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PlanBar(
                  key: key,
                  meals: meals,
                  onServings: (_, __) {},
                  onRemove: (_) {},
                  onSwap: (_, __) {},
                  onReview: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('starts minimized with the meal count', (tester) async {
    await pumpBar(tester, GlobalKey<PlanBarState>());
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
      findsOneWidget,
    );
    expect(find.text('3 meals picked'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.review')),
      findsNothing,
    );
  });

  testWidgets('tap expands: tiles, steppers, review button', (tester) async {
    await pumpBar(tester, GlobalKey<PlanBarState>());
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.expanded')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.tile_pm-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.review')),
      findsOneWidget,
    );
  });

  testWidgets('minimize() collapses an expanded bar', (tester) async {
    final key = GlobalKey<PlanBarState>();
    await pumpBar(tester, key);
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
    );
    await tester.pumpAndSettle();
    key.currentState!.minimize();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
      findsOneWidget,
    );
  });

  testWidgets('empty plan renders nothing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: PlanBar(
              meals: const [],
              onServings: (_, __) {},
              onRemove: (_) {},
              onSwap: (_, __) {},
              onReview: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PlanBar), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
      findsNothing,
    );
  });
}
