import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_icon.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_picture_placeholder.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_bar.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_tile.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/review_sheet.dart';

import '../helpers/test_content.dart';

/// mp-145 — the plan tile, the plan bar tile and the review sheet row draw
/// no meal icon. The stored icon key stays on the meal (it is still parsed
/// and round-tripped) but the row's leading element is the plain placeholder.
void main() {
  PlanMeal meal(int i, {String? icon}) => PlanMeal.fromJson({
    'id': 'pm-$i',
    'planId': 'plan-1',
    'source': 'library',
    'name': 'Meal $i',
    'mealType': 'dinner',
    'servings': 4,
    'servingsLeft': 4,
    'position': i,
    if (icon != null) 'icon': icon,
  });

  final meals = [meal(0, icon: 'fish'), meal(1), meal(2, icon: 'pasta')];

  Widget host(Widget child) => ProviderScope(
    overrides: [contentServiceProvider.overrideWith(testContentService)],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  /// The leading element of a row draws nothing: no glyph painter, no icon.
  void expectPlain(Finder placeholder) {
    expect(
      find.descendant(of: placeholder, matching: find.byType(CustomPaint)),
      findsNothing,
    );
    expect(
      find.descendant(of: placeholder, matching: find.byType(Icon)),
      findsNothing,
    );
  }

  test('the stored icon key survives on the plan meal', () {
    expect(meals[0].icon, MealIcon.fish);
    expect(meals[1].icon, isNull);
    expect(meals[0].toJson()['icon'], 'fish');
  });

  testWidgets('plan tile: 36pt placeholder, no icon, with or without a key', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [for (final m in meals) PlanTile(meal: m, onTap: () {})],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(MealPicturePlaceholder), findsNWidgets(3));
    for (var i = 0; i < 3; i++) {
      final p = find.byType(MealPicturePlaceholder).at(i);
      expect(tester.getSize(p), const Size(36, 36));
      expectPlain(p);
    }
  });

  testWidgets('plan bar tile: 30pt placeholder, no icon', (tester) async {
    await tester.pumpWidget(
      host(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PlanBar(
              meals: meals,
              onServings: (_, __) {},
              onRemove: (_) {},
              onSwap: (_, __) {},
              onReview: () {},
            ),
          ],
        ),
      ),
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('meal_planning.plan_bar.tile_pm-0'));
    final p = find.descendant(
      of: tile,
      matching: find.byType(MealPicturePlaceholder),
    );
    expect(p, findsOneWidget);
    expect(tester.getSize(p), const Size(30, 30));
    expectPlain(p);
  });

  testWidgets('review sheet row: 28pt placeholder, no icon', (tester) async {
    final plan = MealPlan.fromJson({
      'id': 'plan-1',
      'weekStart': '2026-09-14',
      'status': 'draft',
      'batchCooking': false,
      'meals': [for (final m in meals) m.toJson()],
      'shopping': <Object>[],
    });
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showReviewSheet(
              context: context,
              ref: ref,
              plan: plan,
              onTapMeal: (_) {},
              onServings: (_, __) {},
              onRemove: (_) {},
              onConfirm: () async => true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(MealPicturePlaceholder), findsNWidgets(3));
    final p = find.byType(MealPicturePlaceholder).first;
    expect(tester.getSize(p), const Size(28, 28));
    expectPlain(p);
  });
}
