import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_icon.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_bar.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_tile.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/review_sheet.dart';

import '../helpers/test_content.dart';

/// ADR 0003 — where there is no photograph to show, the plan tile, the plan
/// bar tile and the review sheet row draw no picture at all: no placeholder
/// box, no meal icon. No row here has a library photo to look up, so every one
/// starts at the meal's name. The stored icon key survives on the meal — it is
/// kept for when it is wanted, just not drawn.
///
/// The join that gives a row its photograph is covered by
/// `plan_rows_library_photo_test.dart`.
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

  /// Nothing is drawn where a picture would go. The row's own controls — the
  /// plan bar's ×, the tile's stepper — are not pictures and are left alone,
  /// so this asks only that no image is fetched and no glyph stands in ahead
  /// of the meal's name.
  void expectNoPicture(WidgetTester tester_, Finder row, String name) {
    expect(find.descendant(of: row, matching: find.byType(Image)), findsNothing);
    final nameLeft = tester_.getTopLeft(find.text(name)).dx;
    for (final icon in tester_.widgetList<Icon>(
      find.descendant(of: row, matching: find.byType(Icon)),
    )) {
      final rect = tester_.getRect(find.byWidget(icon));
      expect(
        rect.left,
        greaterThanOrEqualTo(nameLeft),
        reason: 'nothing is drawn in the picture\'s place, ahead of the name',
      );
    }
  }

  test('the stored icon key survives on the plan meal', () {
    expect(meals[0].icon, MealIcon.fish);
    expect(meals[1].icon, isNull);
    expect(meals[0].toJson()['icon'], 'fish');
  });

  testWidgets('plan tile: no picture, the row starts at the name', (
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

    for (var i = 0; i < 3; i++) {
      expectNoPicture(tester, find.byType(PlanTile).at(i), 'Meal $i');
    }
    // Every name sits at the same inset, with or without a stored icon key.
    final lefts = [
      for (var i = 0; i < 3; i++) tester.getTopLeft(find.text('Meal $i')).dx,
    ];
    expect(lefts.toSet(), hasLength(1));
  });

  testWidgets('plan bar tile: no picture', (tester) async {
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

    expectNoPicture(
      tester,
      find.byKey(const ValueKey('meal_planning.plan_bar.tile_pm-0')),
      'Meal 0',
    );
  });

  testWidgets('review sheet row: no picture', (tester) async {
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

    expect(find.text('Meal 0'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
